[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$adapterRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceWallpaper = Join-Path $adapterRoot 'assets\pride-prism-wallpaper.png'
$template = Join-Path $adapterRoot 'Pride Prism.theme.template'
$installRoot = Join-Path $env:LOCALAPPDATA 'PridePrism'
$themeRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Themes'
$installedWallpaper = Join-Path $installRoot 'pride-prism-wallpaper.png'
$installedTheme = Join-Path $themeRoot 'Pride Prism.theme'
$previousThemeFile = Join-Path $installRoot 'previous-theme.txt'

if (-not (Test-Path -LiteralPath $sourceWallpaper)) {
    throw 'Wallpaper is missing. Run ../../scripts/generate-assets.ps1 first.'
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
New-Item -ItemType Directory -Path $themeRoot -Force | Out-Null

$currentTheme = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes' -ErrorAction SilentlyContinue).CurrentTheme
if ($currentTheme -and
    (Test-Path -LiteralPath $currentTheme) -and
    -not [string]::Equals($currentTheme, $installedTheme, [System.StringComparison]::OrdinalIgnoreCase)) {
    Set-Content -LiteralPath $previousThemeFile -Value $currentTheme -Encoding Unicode
}

Copy-Item -LiteralPath $sourceWallpaper -Destination $installedWallpaper -Force
$themeText = (Get-Content -LiteralPath $template -Raw -Encoding UTF8).Replace('{{WALLPAPER}}', $installedWallpaper)
Set-Content -LiteralPath $installedTheme -Value $themeText -Encoding Unicode
Start-Process -FilePath $installedTheme

[pscustomobject]@{
    Theme = $installedTheme
    Wallpaper = $installedWallpaper
    PreviousTheme = $currentTheme
}
