# Build release APK for Chicken Farm Management
# Output: release/ChickenFarm-v<version>.apk

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $Root "app"
$ReleaseDir = Join-Path $Root "release"

$pubspec = Get-Content (Join-Path $AppDir "pubspec.yaml") -Raw
if ($pubspec -match 'version:\s*(\S+)') {
    $version = $Matches[1].Replace('+', '-')
} else {
    $version = "unknown"
}

$apiUrl = $env:API_BASE_URL
if (-not $apiUrl) {
    $apiUrl = "https://chick-production.up.railway.app/api"
}

Write-Host "Building APK (version $version) -> API: $apiUrl"

Push-Location $AppDir
try {
    flutter pub get
    flutter build apk --release --dart-define=API_BASE_URL=$apiUrl
} finally {
    Pop-Location
}

$apkSource = Join-Path $AppDir "build\app\outputs\flutter-apk\app-release.apk"
$apkDest = Join-Path $ReleaseDir "ChickenFarm-v$version.apk"

if (-not (Test-Path $apkSource)) {
    throw "APK not found at $apkSource"
}

Copy-Item -Force $apkSource $apkDest
Write-Host "Done: $apkDest"
