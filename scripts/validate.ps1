[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$jsonFiles = @(
    (Join-Path $repoRoot 'tokens\pride-prism.tokens.json'),
    (Join-Path $repoRoot 'adapters\discord\pride-prism-gradient.json'),
    (Join-Path $repoRoot 'adapters\chrome\manifest.json'),
    (Join-Path $repoRoot 'adapters\chrome-start-page\manifest.json'),
    (Join-Path $repoRoot 'adapters\steam\PridePrism\skin.json')
)

foreach ($file in $jsonFiles) {
    $null = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "JSON OK: $file"
}

$steamSkinPath = Join-Path $repoRoot 'adapters\steam\PridePrism\skin.json'
$steamSkin = Get-Content -LiteralPath $steamSkinPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($steamSkin.UseDefaultPatches -ne $true) {
    throw 'Steam skin must use Millennium default scoped patches.'
}
if ($steamSkin.'Steam-WebKit' -ne 'webkit.css') {
    throw 'Steam skin must route webviews through webkit.css.'
}
if ($steamSkin.PSObject.Properties['Patches']) {
    throw 'Steam skin must not define a global catch-all patch.'
}
Write-Host 'STEAM PATCH ROUTING OK: Library, Friends, Big Picture, and webviews are scoped.'

Add-Type -AssemblyName System.Drawing
$images = @(
    (Join-Path $repoRoot 'adapters\chrome\images\theme_frame.png'),
    (Join-Path $repoRoot 'adapters\chrome\images\theme_toolbar.png'),
    (Join-Path $repoRoot 'adapters\chrome\images\theme_ntp_background.png'),
    (Join-Path $repoRoot 'adapters\windows\assets\pride-prism-wallpaper.png')
)
foreach ($file in $images) {
    $image = [Drawing.Image]::FromFile($file)
    try { Write-Host "IMAGE OK: $file ($($image.Width)x$($image.Height))" }
    finally { $image.Dispose() }
}

$siteFiles = @(
    (Join-Path $repoRoot 'docs\index.html'),
    (Join-Path $repoRoot 'docs\styles.css'),
    (Join-Path $repoRoot 'docs\app.js'),
    (Join-Path $repoRoot 'docs\assets\pride-prism-og.png')
)
foreach ($file in $siteFiles) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Site asset missing: $file" }
    Write-Host "SITE OK: $file"
}

$cursorScripts = @(
    (Join-Path $repoRoot 'adapters\windows\cursor\install.ps1'),
    (Join-Path $repoRoot 'adapters\windows\cursor\restore.ps1'),
    (Join-Path $repoRoot 'adapters\windows\cursor\refresh.ps1')
)
foreach ($file in $cursorScripts) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Cursor adapter script missing: $file" }
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "Cursor adapter syntax invalid: $file ($($errors.Message -join ' | '))" }
    Write-Host "CURSOR SCRIPT OK: $file"
}

$discordTheme = Join-Path $repoRoot 'adapters\discord\PridePrism.theme.css'
if (-not (Test-Path -LiteralPath $discordTheme)) { throw "Discord theme missing: $discordTheme" }
if (-not (Select-String -LiteralPath $discordTheme -Pattern '@name Pride Prism' -Quiet)) {
    throw 'Discord theme metadata is invalid.'
}
Write-Host "DISCORD THEME OK: $discordTheme"

$steamThemeRoot = Join-Path $repoRoot 'adapters\steam\PridePrism'
$steamThemeFiles = @(
    'libraryroot.custom.css',
    'libraryroot.custom.js',
    'friends.custom.css',
    'friends.custom.js',
    'bigpicture.custom.css',
    'bigpicture.custom.js',
    'webkit.css'
)
foreach ($name in $steamThemeFiles) {
    $file = Join-Path $steamThemeRoot $name
    if (-not (Test-Path -LiteralPath $file)) { throw "Steam theme asset missing: $file" }
    Write-Host "STEAM THEME OK: $file"
}

$steamScriptFiles = $steamThemeFiles | Where-Object { $_ -like '*.js' }
foreach ($name in $steamScriptFiles) {
    $file = Join-Path $steamThemeRoot $name
    $activeCode = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    $activeCode = $activeCode -replace '(?s)/\*.*?\*/', '' -replace '(?m)^\s*//.*$', ''
    if (-not [string]::IsNullOrWhiteSpace($activeCode)) {
        throw "Steam adapter must remain CSS-only: $file"
    }
}

$steamInstaller = Join-Path $repoRoot 'adapters\steam\install.ps1'
$steamInstallerTokens = $null
$steamInstallerErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($steamInstaller, [ref]$steamInstallerTokens, [ref]$steamInstallerErrors)
if ($steamInstallerErrors.Count) {
    throw "Steam installer syntax invalid: $($steamInstallerErrors.Message -join ' | ')"
}
Write-Host "STEAM INSTALLER OK: $steamInstaller"

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    & $node.Source --check (Join-Path $repoRoot 'docs\app.js')
    if ($LASTEXITCODE -ne 0) { throw 'Website JavaScript validation failed.' }
    Write-Host 'JAVASCRIPT OK: docs\app.js'

    & $node.Source --check (Join-Path $repoRoot 'adapters\chrome-start-page\app.js')
    if ($LASTEXITCODE -ne 0) { throw 'Chrome start-page JavaScript validation failed.' }
    Write-Host 'JAVASCRIPT OK: adapters\chrome-start-page\app.js'
}

$buildScript = Join-Path $repoRoot 'tools\PridePrankLab\build.ps1'
& $buildScript | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Pride Prank Lab build failed.' }

Write-Host 'Pride Prism validation passed.'
