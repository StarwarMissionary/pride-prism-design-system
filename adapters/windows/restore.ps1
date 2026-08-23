[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$installRoot = Join-Path $env:LOCALAPPDATA 'PridePrism'
$previousThemeFile = Join-Path $installRoot 'previous-theme.txt'
$fallbackTheme = Join-Path $env:WINDIR 'Resources\Themes\aero.theme'
$targetTheme = $fallbackTheme

if (Test-Path -LiteralPath $previousThemeFile) {
    $savedTheme = (Get-Content -LiteralPath $previousThemeFile -Raw -Encoding Unicode).Trim()
    if ($savedTheme -and (Test-Path -LiteralPath $savedTheme)) {
        $targetTheme = $savedTheme
    }
}

Start-Process -FilePath $targetTheme
[pscustomobject]@{ RestoredTheme = $targetTheme }
