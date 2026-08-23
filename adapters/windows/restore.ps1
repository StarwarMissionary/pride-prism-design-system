[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$installRoot = Join-Path $env:LOCALAPPDATA 'PridePrism'
$previousThemeFile = Join-Path $installRoot 'previous-theme.txt'
$previousDwmFile = Join-Path $installRoot 'previous-dwm.json'
$dwmPath = 'HKCU:\Software\Microsoft\Windows\DWM'
$fallbackTheme = Join-Path $env:WINDIR 'Resources\Themes\aero.theme'
$targetTheme = $fallbackTheme

if (Test-Path -LiteralPath $previousThemeFile) {
    $savedTheme = (Get-Content -LiteralPath $previousThemeFile -Raw -Encoding Unicode).Trim()
    if ($savedTheme -and (Test-Path -LiteralPath $savedTheme)) {
        $targetTheme = $savedTheme
    }
}

Start-Process -FilePath $targetTheme
if (Test-Path -LiteralPath $previousDwmFile) {
    $dwm = Get-Content -LiteralPath $previousDwmFile -Raw -Encoding UTF8 | ConvertFrom-Json
    Set-ItemProperty -LiteralPath $dwmPath -Name ColorPrevalence -Type DWord -Value ([int]$dwm.ColorPrevalence)
}
[pscustomobject]@{ RestoredTheme = $targetTheme }
