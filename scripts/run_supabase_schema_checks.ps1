# Run supabase/tests/schema_checks.sql against your Supabase Postgres database.
#
# Prerequisites: psql on PATH (e.g. from PostgreSQL client tools).
# Set one of:
#   $env:SUPABASE_DB_URL = "postgresql://postgres.[ref]:[password]@aws-0-....pooler.supabase.com:6543/postgres"
#   $env:DATABASE_URL     = same connection string (direct or pooler)
#
# Usage (from repo root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_supabase_schema_checks.ps1
#
# Exit codes: 0 = all checks passed or skipped (no URL); 1 = failures or psql error; 2 = URL set but psql missing

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$SqlFile = Join-Path $Root 'supabase\tests\schema_checks.sql'

if (-not (Test-Path $SqlFile)) {
    Write-Error "SQL file not found: $SqlFile"
}

$dbUrl = $env:SUPABASE_DB_URL
if ([string]::IsNullOrWhiteSpace($dbUrl)) {
    $dbUrl = $env:DATABASE_URL
}

if ([string]::IsNullOrWhiteSpace($dbUrl)) {
    Write-Host 'SUPABASE_DB_URL / DATABASE_URL not set — skipping remote check.' -ForegroundColor Yellow
    Write-Host 'Paste supabase/tests/schema_checks.sql into the Supabase SQL Editor, or set SUPABASE_DB_URL and re-run.' -ForegroundColor Yellow
    exit 0
}

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    Write-Error 'psql not found on PATH. Install PostgreSQL client tools or run schema_checks.sql in the Dashboard.'
    exit 2
}

Write-Host "Running schema checks via psql..." -ForegroundColor Cyan
$raw = Get-Content -LiteralPath $SqlFile -Raw -Encoding UTF8
$out = $raw | & psql $dbUrl -v ON_ERROR_STOP=1 -t -A -f - 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host $out
    exit 1
}

$line = $out | Where-Object { $_ -match '^\d+\|' } | Select-Object -First 1
if (-not $line) {
    Write-Host $out
    Write-Error 'Could not parse psql output (expected one line like "0|[]").'
    exit 1
}

$sep = $line.IndexOf('|')
$countStr = $line.Substring(0, $sep).Trim()
$detailsJson = $line.Substring($sep + 1).Trim()
$failed = [int]$countStr

if ($failed -gt 0) {
    Write-Host "failed_count=$failed" -ForegroundColor Red
    Write-Host $detailsJson
    exit 1
}

Write-Host 'Supabase schema checks passed (failed_count=0).' -ForegroundColor Green
exit 0
