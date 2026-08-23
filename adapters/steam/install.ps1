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

if (Test-Path -LiteralPath $currentMillenniumDll) {
    $configRoot = Join-Path $SteamPath 'millennium\config'
    $quickCssPath = Join-Path $configRoot 'quick.css'
    New-Item -ItemType Directory -Path $configRoot -Force | Out-Null

    if (Test-Path -LiteralPath $quickCssPath) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $quickCssBackup = Join-Path $configRoot "quick.css.backup-$timestamp"
        Copy-Item -LiteralPath $quickCssPath -Destination $quickCssBackup
        Write-Host "Previous Millennium Quick CSS preserved at: $quickCssBackup"
    }

    $libraryCss = Get-Content -LiteralPath (Join-Path $source 'libraryroot.custom.css') -Raw
    $webkitCss = Get-Content -LiteralPath (Join-Path $source 'webkit.css') -Raw
    $quickCss = "/* Pride Prism generated fallback: Steam desktop + webviews */`r`n$libraryCss`r`n$webkitCss"
    Set-Content -LiteralPath $quickCssPath -Value $quickCss -Encoding UTF8
    Write-Host "Pride Prism Quick CSS fallback installed at: $quickCssPath"
}

$millennium = Get-Command millennium -ErrorAction SilentlyContinue
if ($millennium) {
    & $millennium.Source themes use PridePrism
    if ($LASTEXITCODE -ne 0) { throw 'Millennium could not select Pride Prism.' }
    Write-Host 'Pride Prism selected through the Millennium CLI.'
} else {
    Write-Host 'Open Steam -> Millennium -> Themes and select Pride Prism.'
}
