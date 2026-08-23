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
$previousDwmFile = Join-Path $installRoot 'previous-dwm.json'
$dwmPath = 'HKCU:\Software\Microsoft\Windows\DWM'

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

if (-not (Test-Path -LiteralPath $previousDwmFile)) {
    $dwm = Get-ItemProperty -LiteralPath $dwmPath -ErrorAction SilentlyContinue
    [pscustomobject]@{ ColorPrevalence = [int]$dwm.ColorPrevalence } |
        ConvertTo-Json |
        Set-Content -LiteralPath $previousDwmFile -Encoding UTF8
}

Copy-Item -LiteralPath $sourceWallpaper -Destination $installedWallpaper -Force
$themeText = (Get-Content -LiteralPath $template -Raw -Encoding UTF8).Replace('{{WALLPAPER}}', $installedWallpaper)
Set-Content -LiteralPath $installedTheme -Value $themeText -Encoding Unicode
Start-Process -FilePath $installedTheme
Start-Sleep -Seconds 1
Set-ItemProperty -LiteralPath $dwmPath -Name ColorPrevalence -Type DWord -Value 1

[pscustomobject]@{
    Theme = $installedTheme
    Wallpaper = $installedWallpaper
    PreviousTheme = $currentTheme
    AccentOnTitleBars = $true
}
