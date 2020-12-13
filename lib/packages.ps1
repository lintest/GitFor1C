$root = (Split-Path -Parent $PSCommandPath) + '\'
$temp = $root + 'package.tmp'
$json = Get-Content "$root\packages.json" | Out-String | ConvertFrom-Json
ForEach ($package in $json) {
    $path = $root + $package.path | Split-Path
    Invoke-RestMethod -Method Get -Uri $package.url -OutFile $temp
    $hash = (get-filehash -Algorithm SHA256 $temp).Hash
    if ($hash -ne $package.hash) { throw "Wrong file hash: " + $package.url }
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    Copy-Item $temp -Force -Destination ($root + $package.path)
}