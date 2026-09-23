$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

# Player app only. The admin panel is a separate web build.
flutter build appbundle --release -t lib/main.dart `
  --dart-define=API_BASE_URL=https://api-production-bf3c9.up.railway.app
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Play paketi: build\app\outputs\bundle\release\app-release.aab"
