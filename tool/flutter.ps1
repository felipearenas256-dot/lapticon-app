# Ejecuta Flutter con el SDK y las cachés en D:, sin cambiar la configuración global.
# Uso: .\tool\flutter.ps1 run --dart-define-from-file=config/firebase.json

$env:PUB_CACHE = 'D:\dev\pub-cache'
$env:GRADLE_USER_HOME = 'D:\dev\gradle'
$env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-23'

Set-Location (Join-Path $PSScriptRoot '..')
& 'D:\dev\flutter\bin\flutter.bat' @args
exit $LASTEXITCODE
