$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $project ('build\package-test-' + [guid]::NewGuid().ToString('N'))
$release = Join-Path $fixture 'build\windows\x64\runner\Release'
New-Item -ItemType Directory -Path (Join-Path $release 'data'),(Join-Path $fixture 'dist\logs') -Force | Out-Null
foreach ($name in @('ja_dut_info.exe','flutter_windows.dll','data\app.so','data\icudtl.dat')) {
    Set-Content -LiteralPath (Join-Path $release $name) -Value 'fixture runtime'
}
Set-Content -LiteralPath (Join-Path $fixture 'pubspec.yaml') -Value 'version: 1.0.0+1'
foreach ($name in @('install.bat','uninstall.bat','uninstall.ps1')) {
    Set-Content -LiteralPath (Join-Path $fixture $name) -Value 'fixture helper'
}
foreach ($name in @('config.json','old.zip','logs\keep.log','unknown.dat')) {
    Set-Content -LiteralPath (Join-Path $fixture ('dist\' + $name)) -Value ('private-' + $name)
}
$before = @(Get-ChildItem (Join-Path $fixture 'dist') -Recurse -File | Get-FileHash)
$locked = [IO.File]::Open((Join-Path $fixture 'dist\logs\keep.log'), 'Open', 'Read', 'None')
try {
    & (Join-Path $project 'windows\packaging\package_dist.ps1') -ProjectRoot $fixture
} finally { $locked.Dispose() }
foreach ($item in $before) {
    if ((Get-FileHash -LiteralPath $item.Path).Hash -ne $item.Hash) { throw "Changed: $($item.Path)" }
}
$published = @(Get-ChildItem -LiteralPath $fixture -Directory -Filter 'dist.release-*')
if ($published.Count -ne 1) { throw 'Expected separate output' }
if (-not (Test-Path (Join-Path $published[0].FullName 'ja_dut_info.exe'))) { throw 'Missing runtime' }
# Invalid input must fail without another publication or altering the old dist.
Set-Content -LiteralPath (Join-Path $fixture 'pubspec.yaml') -Value 'invalid'
$failed = $false
try { & (Join-Path $project 'windows\packaging\package_dist.ps1') -ProjectRoot $fixture }
catch { $failed = $true }
if (-not $failed) { throw 'Invalid input reported success' }
if (@(Get-ChildItem -LiteralPath $fixture -Directory -Filter 'dist.release-*').Count -ne 1) { throw 'Unexpected publication' }
Write-Host "PASS: old configs/logs/ZIP/unknown files preserved with locked file; separate publication; invalid input rejected. Fixture retained: $fixture"
