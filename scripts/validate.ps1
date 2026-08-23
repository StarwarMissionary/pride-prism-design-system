[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$jsonFiles = @(
    (Join-Path $repoRoot 'tokens\pride-prism.tokens.json'),
    (Join-Path $repoRoot 'adapters\discord\pride-prism-gradient.json'),
    (Join-Path $repoRoot 'adapters\chrome\manifest.json')
)

foreach ($file in $jsonFiles) {
    $null = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "JSON OK: $file"
}

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

$discordTheme = Join-Path $repoRoot 'adapters\discord\PridePrism.theme.css'
if (-not (Test-Path -LiteralPath $discordTheme)) { throw "Discord theme missing: $discordTheme" }
if (-not (Select-String -LiteralPath $discordTheme -Pattern '@name Pride Prism' -Quiet)) {
    throw 'Discord theme metadata is invalid.'
}
Write-Host "DISCORD THEME OK: $discordTheme"

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    & $node.Source --check (Join-Path $repoRoot 'docs\app.js')
    if ($LASTEXITCODE -ne 0) { throw 'Website JavaScript validation failed.' }
    Write-Host 'JAVASCRIPT OK: docs\app.js'
}

$buildScript = Join-Path $repoRoot 'tools\PridePrankLab\build.ps1'
& $buildScript | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Pride Prank Lab build failed.' }

Write-Host 'Pride Prism validation passed.'
