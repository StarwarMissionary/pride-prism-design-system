[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ThemeJson,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputRoot
)

# Local bundle assets only. This script never installs or applies a theme.
# Example: ./scripts/generate-assets.ps1 -ThemeJson dist/bisexual/theme.json -OutputRoot dist/bisexual
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$distRoot = Join-Path $repoRoot 'dist'

function Get-AbsoluteAssetPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

function Assert-RealAssetPath([string]$Path) {
    # Inspect each existing ancestor before following it. Resolve-Path alone
    # does not reject Windows junctions/reparse points.
    $rootPath = [IO.Path]::GetPathRoot($Path)
    $current = $rootPath
    $separators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $segments = $Path.Substring($rootPath.Length).Split($separators, [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($segment in $segments) {
        $current = Join-Path $current $segment
        try { $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop }
        catch {
            if ($_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::ObjectNotFound) { break }
            throw
        }
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Asset paths must not contain symlinks or junctions: $current"
        }
        if ($current -ne $Path -and -not $item.PSIsContainer) {
            throw "An asset path ancestor is not a directory: $current"
        }
    }
}

function Assert-AssetFileTarget([string]$Path) {
    Assert-RealAssetPath $Path
    if (Test-Path -LiteralPath $Path -PathType Container) {
        throw "An output file target is a directory: $Path"
    }
}

$bundleRoot = Get-AbsoluteAssetPath $OutputRoot
$distPrefix = $distRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $bundleRoot.StartsWith($distPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputRoot must be a generated bundle directory strictly inside this repository''s dist directory.'
}
Assert-RealAssetPath $bundleRoot
if (-not (Test-Path -LiteralPath $bundleRoot -PathType Container)) {
    throw 'OutputRoot must already exist. Generate the bundle with scripts/build-theme.mjs first.'
}

$markerPath = Join-Path $bundleRoot '.pride-prism-export.json'
Assert-AssetFileTarget $markerPath
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
    throw 'OutputRoot is not a marked Pride Prism export.'
}
$marker = Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($marker.generator -ne 'Pride Prism' -or $marker.schemaVersion -ne 1) {
    throw 'OutputRoot has an invalid Pride Prism export marker.'
}

$themePath = Get-AbsoluteAssetPath $ThemeJson
Assert-AssetFileTarget $themePath
$theme = Get-Content -LiteralPath $themePath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($theme.schemaVersion -ne 1 -or $theme.mode -ne 'dark') {
    throw 'ThemeJson must contain a generated schemaVersion 1 dark theme.'
}

function Get-ThemeDrawingColor([object]$Value, [string]$Label) {
    if ($Value -isnot [string] -or $Value -notmatch '^#[0-9a-fA-F]{6}$') {
        throw "$Label must be an opaque six-digit hex color."
    }
    return [Drawing.ColorTranslator]::FromHtml($Value)
}

Add-Type -AssemblyName System.Drawing
$surface = Get-ThemeDrawingColor $theme.colors.surface 'colors.surface'
$surfaceRaised = Get-ThemeDrawingColor $theme.colors.surfaceRaised 'colors.surfaceRaised'
$referenceColors = @($theme.palette.colors)
$referenceWeights = @($theme.palette.weights)
if ($referenceColors.Count -lt 1 -or $referenceColors.Count -gt 32 -or $referenceColors.Count -ne $referenceWeights.Count) {
    throw 'The theme palette requires 1-32 colors and one weight per color.'
}
$paletteColors = @($referenceColors | ForEach-Object { Get-ThemeDrawingColor $_ 'palette color' })
$paletteWeights = @()
$totalWeight = 0.0
foreach ($weight in $referenceWeights) {
    if ($null -eq $weight -or $weight -is [string] -or $weight -is [bool] -or $weight -isnot [ValueType]) {
        throw 'Palette weights must be positive finite numbers.'
    }
    $numericWeight = [double]$weight
    if ([double]::IsNaN($numericWeight) -or [double]::IsInfinity($numericWeight) -or $numericWeight -le 0) {
        throw 'Palette weights must be positive finite numbers.'
    }
    $paletteWeights += $numericWeight
    $totalWeight += $numericWeight
}
if ([double]::IsInfinity($totalWeight)) { throw 'The palette weight total must be finite.' }

$chromeImages = Join-Path $bundleRoot 'adapters\chrome\images'
$windowsAssets = Join-Path $bundleRoot 'adapters\windows\assets'
$manifestPath = Join-Path $bundleRoot 'adapters\chrome\manifest.json'
$framePath = Join-Path $chromeImages 'theme_frame.png'
$toolbarPath = Join-Path $chromeImages 'theme_toolbar.png'
$ntpPath = Join-Path $chromeImages 'theme_ntp_background.png'
$wallpaperPath = Join-Path $windowsAssets 'pride-prism-wallpaper.png'
foreach ($assetPath in @($manifestPath, $framePath, $toolbarPath, $ntpPath, $wallpaperPath)) {
    Assert-AssetFileTarget $assetPath
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($null -eq $manifest.theme -or $null -eq $manifest.theme.colors) {
    throw 'The generated Chrome manifest must contain theme colors before assets are added.'
}

function New-AssetBitmap([int]$Width, [int]$Height) {
    $bitmap = [Drawing.Bitmap]::new($Width, $Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bitmap.SetResolution(96, 96)
    return $bitmap
}

function New-AssetGraphics([Drawing.Bitmap]$Bitmap) {
    $graphics = [Drawing.Graphics]::FromImage($Bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::None
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::None
    $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceOver
    return $graphics
}

function Draw-IdentityBand([Drawing.Graphics]$Graphics, [int]$Left, [int]$Top, [int]$Width, [int]$Height, [int]$Alpha = 255) {
    $usedWeight = 0.0
    $start = 0
    for ($index = 0; $index -lt $paletteColors.Count; $index++) {
        $usedWeight += $paletteWeights[$index]
        if ($index -eq $paletteColors.Count - 1) { $end = $Width }
        else { $end = [int][Math]::Round($usedWeight / $totalWeight * $Width, [MidpointRounding]::AwayFromZero) }
        if ($end -gt $start) {
            $brush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb($Alpha, $paletteColors[$index]))
            try { $Graphics.FillRectangle($brush, $Left + $start, $Top, $end - $start, $Height) }
            finally { $brush.Dispose() }
        }
        $start = $end
    }
}

function New-ChromeFrame {
    $bitmap = New-AssetBitmap 3000 240
    $graphics = New-AssetGraphics $bitmap
    try {
        # Every control-area pixel below the very top rail remains neutral.
        $graphics.Clear($surfaceRaised)
        Draw-IdentityBand $graphics 0 0 3000 3
        $bitmap.Save($framePath, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}

function New-ChromeToolbar {
    $bitmap = New-AssetBitmap 3000 160
    $graphics = New-AssetGraphics $bitmap
    try {
        $graphics.Clear($surface)
        $bitmap.Save($toolbarPath, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}

function New-Wallpaper {
    $bitmap = New-AssetBitmap 2560 1440
    $graphics = New-AssetGraphics $bitmap
    try {
        $graphics.Clear($surface)
        # Centered, six-pixel identity rail at restrained opacity. No text,
        # logos, flag emblems, noise, or content behind desktop controls.
        Draw-IdentityBand $graphics 768 717 1024 6 140
        $bitmap.Save($ntpPath, [Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Save($wallpaperPath, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}

# Preflight is complete. Only the generated bundle is modified below.
New-Item -ItemType Directory -Path $chromeImages -Force | Out-Null
New-Item -ItemType Directory -Path $windowsAssets -Force | Out-Null
New-ChromeFrame
New-ChromeToolbar
New-Wallpaper

$imagePaths = [ordered]@{
    theme_frame = 'images/theme_frame.png'
    theme_toolbar = 'images/theme_toolbar.png'
    theme_ntp_background = 'images/theme_ntp_background.png'
}
$manifest.theme | Add-Member -MemberType NoteProperty -Name images -Value $imagePaths -Force
$manifestJson = ($manifest | ConvertTo-Json -Depth 30) + [Environment]::NewLine
[IO.File]::WriteAllText($manifestPath, $manifestJson, [Text.UTF8Encoding]::new($false))

Get-Item -LiteralPath $framePath, $toolbarPath, $ntpPath, $wallpaperPath |
    Select-Object FullName, Length
