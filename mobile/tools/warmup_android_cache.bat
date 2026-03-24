@echo off
setlocal

cd /d "%~dp0\.."
powershell -ExecutionPolicy Bypass -File ".\tools\warmup_android_cache.ps1"

if %errorlevel% neq 0 (
  echo.
  echo Warmup failed. Please retry on a better network.
  pause
  exit /b %errorlevel%
)

echo.
echo Warmup finished. You can run:
echo flutter run -d emulator-5554
pause
