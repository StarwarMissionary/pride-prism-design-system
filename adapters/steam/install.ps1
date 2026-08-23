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
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
New-Item -ItemType Directory -Path $skinsRoot -Force | Out-Null

if (Test-Path -LiteralPath $destination) {
    $backup = Join-Path $skinsRoot "PridePrism.backup-$timestamp"
    Move-Item -LiteralPath $destination -Destination $backup
    Write-Host "Previous theme preserved at: $backup"
}

Copy-Item -LiteralPath $source -Destination $destination -Recurse
Write-Host "Pride Prism installed at: $destination"

if (Test-Path -LiteralPath $currentMillenniumDll) {
    $configRoot = Join-Path $SteamPath 'millennium\config'
    $quickCssPath = Join-Path $configRoot 'quick.css'
    $configPath = Join-Path $configRoot 'config.json'
    New-Item -ItemType Directory -Path $configRoot -Force | Out-Null

    if (Test-Path -LiteralPath $quickCssPath) {
        $quickCss = Get-Content -LiteralPath $quickCssPath -Raw -Encoding UTF8
        if ($quickCss -match 'global Quick CSS is intentionally empty') {
            Write-Host 'Pride Prism global Quick CSS is already neutralized.'
        } elseif (($quickCss -match 'Pride Prism') -and ($quickCss -match '--pp-surface|generated fallback|Steam desktop \+ webviews')) {
            $quickCssBackup = Join-Path $configRoot "quick.css.backup-$timestamp"
            Copy-Item -LiteralPath $quickCssPath -Destination $quickCssBackup
            Set-Content -LiteralPath $quickCssPath -Value '/* Pride Prism uses scoped Millennium theme patches; global Quick CSS is intentionally empty. */' -Encoding UTF8
            Write-Host "Old Pride Prism Quick CSS preserved at: $quickCssBackup"
            Write-Host 'Removed the obsolete global Quick CSS injection.'
        } else {
            Write-Host 'Existing unrelated Millennium Quick CSS was left unchanged.'
        }
    }

    if (Test-Path -LiteralPath $configPath) {
        $configBackup = Join-Path $configRoot "config.json.backup-$timestamp"
        Copy-Item -LiteralPath $configPath -Destination $configBackup

        $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $config.PSObject.Properties['themes']) {
            $config | Add-Member -MemberType NoteProperty -Name themes -Value ([pscustomobject]@{})
        }
        if (-not $config.themes.PSObject.Properties['activeTheme']) {
            $config.themes | Add-Member -MemberType NoteProperty -Name activeTheme -Value 'PridePrism'
        } else {
            $config.themes.activeTheme = 'PridePrism'
        }
        if (-not $config.themes.PSObject.Properties['allowedStyles']) {
            $config.themes | Add-Member -MemberType NoteProperty -Name allowedStyles -Value $true
        } else {
            $config.themes.allowedStyles = $true
        }
        if (-not $config.themes.PSObject.Properties['allowedScripts']) {
            $config.themes | Add-Member -MemberType NoteProperty -Name allowedScripts -Value $false
        } else {
            $config.themes.allowedScripts = $false
        }
        if ($config.PSObject.Properties['general']) {
            if (-not $config.general.PSObject.Properties['injectCSS']) {
                $config.general | Add-Member -MemberType NoteProperty -Name injectCSS -Value $true
            } else {
                $config.general.injectCSS = $true
            }
        }

        $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding UTF8
        Write-Host "Millennium configuration preserved at: $configBackup"
        Write-Host 'Pride Prism selected with scoped CSS enabled and theme JavaScript disabled.'
    } else {
        Write-Warning 'Millennium config.json was not found; select Pride Prism in Steam after Millennium creates its configuration.'
    }
}

$millennium = Get-Command millennium -ErrorAction SilentlyContinue
if ($millennium) {
    & $millennium.Source themes use PridePrism
    if ($LASTEXITCODE -ne 0) { throw 'Millennium could not select Pride Prism.' }
    Write-Host 'Pride Prism selected through the Millennium CLI.'
} elseif (-not (Test-Path -LiteralPath $currentMillenniumDll)) {
    Write-Host 'Open Steam -> Millennium -> Themes and select Pride Prism.'
}

Write-Host 'Restart Steam once to load the repaired Library, Friends, Big Picture, Store, and Community patches.'
