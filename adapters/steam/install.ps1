[CmdletBinding()]
param(
    [string]$SteamPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SteamPath)) {
    $SteamPath = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath
}

$SteamPath = [IO.Path]::GetFullPath($SteamPath)
$steamExe = Join-Path $SteamPath 'steam.exe'
if (-not (Test-Path -LiteralPath $steamExe)) {
    throw "Steam was not found at: $SteamPath"
}

$currentMillenniumDll = Join-Path $SteamPath 'millennium\lib\millennium.dll'
$legacyMillenniumDll = Join-Path $SteamPath 'millennium.dll'
if (-not (Test-Path -LiteralPath $currentMillenniumDll) -and -not (Test-Path -LiteralPath $legacyMillenniumDll)) {
    throw 'Millennium is not installed. Use the official installer linked in README.md first.'
}

$source = Join-Path $PSScriptRoot 'PridePrism'
if (Test-Path -LiteralPath $currentMillenniumDll) {
    $skinsRoot = Join-Path $SteamPath 'millennium\themes'
} else {
    $skinsRoot = Join-Path $SteamPath 'steamui\skins'
}
$destination = Join-Path $skinsRoot 'PridePrism'
New-Item -ItemType Directory -Path $skinsRoot -Force | Out-Null

if (Test-Path -LiteralPath $destination) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = Join-Path $skinsRoot "PridePrism.backup-$timestamp"
    Move-Item -LiteralPath $destination -Destination $backup
    Write-Host "Previous theme preserved at: $backup"
}

Copy-Item -LiteralPath $source -Destination $destination -Recurse
Write-Host "Pride Prism installed at: $destination"

$millennium = Get-Command millennium -ErrorAction SilentlyContinue
if ($millennium) {
    & $millennium.Source themes use PridePrism
    if ($LASTEXITCODE -ne 0) { throw 'Millennium could not select Pride Prism.' }
    Write-Host 'Pride Prism selected through the Millennium CLI.'
} else {
    Write-Host 'Open Steam -> Millennium -> Themes and select Pride Prism.'
}
