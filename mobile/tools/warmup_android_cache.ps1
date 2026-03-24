param(
  [int]$Retries = 5,
  [int]$SleepSeconds = 8
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $projectRoot "android"
$flutter = "C:\Users\Administrator\.puro\envs\stable\flutter\bin\flutter.bat"
$javaHome = "C:\Program Files\Android\Android Studio\jbr"

if (-not (Test-Path $flutter)) {
  throw "Flutter not found at $flutter"
}
if (-not (Test-Path $javaHome)) {
  throw "Android Studio JBR not found at $javaHome"
}

$env:JAVA_HOME = $javaHome
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:Path = "C:\Users\Administrator\AppData\Local\Android\Sdk\platform-tools;C:\Users\Administrator\AppData\Local\Android\Sdk\cmdline-tools\latest\bin;$env:JAVA_HOME\bin;$env:Path"

Write-Host "==> Step 1: flutter pub get"
Push-Location $projectRoot
& $flutter pub get
Pop-Location

Write-Host "==> Step 2: flutter precache --android"
Push-Location $projectRoot
& $flutter precache --android
Pop-Location

Write-Host "==> Step 3: Gradle cache warmup with retries"
Push-Location $androidDir
$success = $false
for ($i = 1; $i -le $Retries; $i++) {
  try {
    Write-Host "Attempt $i/$Retries: gradlew help --refresh-dependencies"
    & .\gradlew.bat help --refresh-dependencies --no-daemon
    $success = $true
    break
  } catch {
    Write-Warning "Attempt $i failed: $($_.Exception.Message)"
    if ($i -lt $Retries) {
      Start-Sleep -Seconds $SleepSeconds
    }
  }
}
Pop-Location

if (-not $success) {
  throw "Cache warmup failed after $Retries attempts. Try again on a more stable network."
}

Write-Host "==> Warmup completed. You can now run: flutter run -d emulator-5554"
