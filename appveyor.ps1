param(
  [string]$account = $env:APPVEYOR_ACCOUNT_NAME,
  [string]$project = $env:APPVEYOR_PROJECT_NAME,
  [string]$name = $env:APPVEYOR_PROJECT_NAME
)

$path = $env:APPVEYOR_BUILD_FOLDER
$version = $env:APPVEYOR_BUILD_VERSION
$postfix = '_' + $version -replace '\.', '-'

Rename-Item "$path\lib${name}Win32.dll" "${name}Win32$postfix.dll"
Rename-Item "$path\lib${name}Win64.dll" "${name}Win64$postfix.dll"

$compress = @{
  Path            = "$path\$name*.dll", "$path\manifest.xml"
  DestinationPath = "$path\AddIn.zip"
}
Compress-Archive @compress

New-Item -ItemType Directory -Force -Path "$path\Example\Templates\$name\Ext\" | Out-Null
Copy-Item -Path "$path\AddIn.zip" -Destination "$path\Example\Templates\$name\Ext\Template.bin"
