param(
  [switch]$Minor,
  [switch]$Major
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if ($Minor -and $Major) {
  Write-Error 'Orta ve büyük adım birlikte seçilemez.'
}

$step = 'patch'
if ($Minor) { $step = 'minor' }
if ($Major) { $step = 'major' }

$versionFile = Join-Path (Get-Location) 'lib\core\constants\game_version.dart'
$original = Get-Content -Raw -Path $versionFile
dart run tool/version.dart $step
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

railway up --service api --environment production -c -y --no-gitignore --message "Bump Luno League $step"
$code = $LASTEXITCODE
if ($code -ne 0) {
  Set-Content -Path $versionFile -Value $original -NoNewline
  exit $code
}
