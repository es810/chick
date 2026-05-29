# Fix: "sdkmanager not found" / "Unable to locate Android SDK"
$sdk = "$env:LOCALAPPDATA\Android\Sdk"

if (-not (Test-Path $sdk)) {
    Write-Host "Android SDK folder not found. Install Android Studio first:" -ForegroundColor Red
    Write-Host "https://developer.android.com/studio"
    exit 1
}

Write-Host "Setting Flutter Android SDK to:" $sdk -ForegroundColor Cyan
flutter config --android-sdk $sdk

$sdkmanager = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"
if (-not (Test-Path $sdkmanager)) {
    Write-Host ""
    Write-Host "MISSING: Android SDK Command-line Tools" -ForegroundColor Yellow
    Write-Host "Install them in Android Studio:"
    Write-Host "  1. Open Android Studio"
    Write-Host "  2. More Actions -> SDK Manager  (or Settings -> Languages & Frameworks -> Android SDK)"
    Write-Host "  3. Tab: SDK Tools"
    Write-Host "  4. Check: Android SDK Command-line Tools (latest)"
    Write-Host "  5. Apply -> OK -> wait for download"
    Write-Host ""
    Write-Host "Then run again:"
    Write-Host "  flutter doctor --android-licenses"
    exit 1
}

Write-Host "Running license acceptance..." -ForegroundColor Cyan
flutter doctor --android-licenses

Write-Host ""
flutter doctor
