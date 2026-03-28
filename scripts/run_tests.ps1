# Automated checks for family-app (run from repo root or any directory).
# Usage: powershell -ExecutionPolicy Bypass -File scripts\run_tests.ps1
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Mobile = Join-Path $Root 'mobile'

if (-not (Test-Path $Mobile)) {
    Write-Error "mobile folder not found: $Mobile"
}

Push-Location $Mobile
try {
    Write-Host '== flutter pub get ==' -ForegroundColor Cyan
    flutter pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host '== flutter analyze ==' -ForegroundColor Cyan
    # Info/warning lints do not fail the script; only analyzer errors exit non-zero.
    flutter analyze --no-fatal-infos --no-fatal-warnings
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host '== flutter test ==' -ForegroundColor Cyan
    flutter test
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host 'All checks passed.' -ForegroundColor Green
    exit 0
}
finally {
    Pop-Location
}
