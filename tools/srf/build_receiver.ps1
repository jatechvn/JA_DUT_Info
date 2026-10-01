param(
    [Parameter(Mandatory = $true)][string]$R8Jar,
    [string]$JavaHome = 'C:\Program Files\Java\jdk-17'
)
$ErrorActionPreference = 'Stop'
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$r8Path = (Resolve-Path -LiteralPath $R8Jar).Path
$stage = Join-Path $project ('build\srf-helper-' + [guid]::NewGuid().ToString('N'))
$classes = Join-Path $stage 'classes'
$dex = Join-Path $stage 'dex'
New-Item -ItemType Directory -Path $classes, $dex -Force | Out-Null
& "$JavaHome\bin\javac.exe" --release 8 -d $classes "$PSScriptRoot\SrfReceiver.java" "$PSScriptRoot\SrfReceiverTest.java"
if ($LASTEXITCODE -ne 0) { throw 'javac failed' }
& "$JavaHome\bin\java.exe" -cp $classes com.jatech.srf.SrfReceiverTest
if ($LASTEXITCODE -ne 0) { throw 'SRF regression checks failed' }
$inputs = @(Get-ChildItem -LiteralPath "$classes\com\jatech\srf" -Filter 'SrfReceiver*.class' |
    Where-Object { $_.Name -notlike 'SrfReceiverTest*' } | ForEach-Object { $_.FullName })
& "$JavaHome\bin\java.exe" -cp $r8Path com.android.tools.r8.D8 --min-api 26 --output $dex @inputs
if ($LASTEXITCODE -ne 0) { throw 'D8 failed' }
$asset = Join-Path $project 'assets\tools\srf\SrfReceiver.jar'
& "$JavaHome\bin\jar.exe" cf $asset -C $dex classes.dex
if ($LASTEXITCODE -ne 0) { throw 'jar failed' }
Write-Output "Built $asset (dist was not touched)"
