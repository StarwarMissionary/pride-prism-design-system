[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'bin')
)

$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$source = Join-Path $PSScriptRoot 'PridePrankLab.cs'
$output = Join-Path $OutputDirectory 'PridePrankLab.exe'

if (-not (Test-Path -LiteralPath $compiler)) { throw "C# compiler not found: $compiler" }
if (-not (Test-Path -LiteralPath $source)) { throw "Source not found: $source" }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

& $compiler /nologo /target:winexe /optimize+ "/out:$output" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll $source
if ($LASTEXITCODE -ne 0) { throw "Compilation failed with exit code $LASTEXITCODE" }
Get-Item -LiteralPath $output | Select-Object FullName, Length, LastWriteTime
