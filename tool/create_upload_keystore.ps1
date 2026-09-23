# Creates android/upload-keystore.jks and android/key.properties if missing.
# Back up both files. They are gitignored and cannot be recovered.

$ErrorActionPreference = "Stop"
$androidDir = Join-Path $PSScriptRoot "..\android" | Resolve-Path
$keystorePath = Join-Path $androidDir "upload-keystore.jks"
$propsPath = Join-Path $androidDir "key.properties"

function Find-Keytool {
    $candidates = @()
    if ($env:JAVA_HOME) {
        $candidates += Join-Path $env:JAVA_HOME "bin\keytool.exe"
    }
    $studio = @(
        "${env:ProgramFiles}\Android\Android Studio\jbr\bin\keytool.exe",
        "${env:ProgramFiles}\Android\Android Studio\jre\bin\keytool.exe",
        "${env:LocalAppData}\Programs\Android\Android Studio\jbr\bin\keytool.exe"
    )
    $candidates += $studio
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    $fromPath = Get-Command keytool -ErrorAction SilentlyContinue
    if ($fromPath) { return $fromPath.Source }
    throw "keytool bulunamadı. Android Studio veya a JDK kurulu olmalı (JAVA_HOME)."
}

if ((Test-Path $keystorePath) -and (Test-Path $propsPath)) {
    Write-Host "Keystore zaten var: $keystorePath"
    Write-Host "key.properties zaten var: $propsPath"
    exit 0
}

if ((Test-Path $keystorePath) -xor (Test-Path $propsPath)) {
    throw "keystore veya key.properties tek başına duruyor. İkisini de yedekleyip silmeden yeni üretme."
}

$keytool = Find-Keytool
$chars = [char[]]((48..57) + (65..90) + (97..122))
$password = -join (1..28 | ForEach-Object { $chars | Get-Random })
$alias = "upload"

& $keytool -genkeypair -v `
    -keystore $keystorePath `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias $alias `
    -storepass $password `
    -keypass $password `
    -dname "CN=Luno League, OU=Luno League, O=Luno League, L=Istanbul, C=TR"

if ($LASTEXITCODE -ne 0) { throw "keytool başarısız (exit $LASTEXITCODE)" }

@"
storePassword=$password
keyPassword=$password
keyAlias=$alias
storeFile=upload-keystore.jks
"@ | Set-Content -Path $propsPath -Encoding ascii -NoNewline

Write-Host "Oluşturuldu:"
Write-Host "  $keystorePath"
Write-Host "  $propsPath"
Write-Host "Bu iki dosyayı yedekle. Git'e ekleme."
Write-Host "AAB: flutter build appbundle --release"
