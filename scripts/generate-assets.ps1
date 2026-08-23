[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$chromeImages = Join-Path $repoRoot 'adapters\chrome\images'
$windowsAssets = Join-Path $repoRoot 'adapters\windows\assets'
New-Item -ItemType Directory -Path $chromeImages -Force | Out-Null
New-Item -ItemType Directory -Path $windowsAssets -Force | Out-Null

$pride = @(
    [Drawing.ColorTranslator]::FromHtml('#E40303'),
    [Drawing.ColorTranslator]::FromHtml('#FF8C00'),
    [Drawing.ColorTranslator]::FromHtml('#FFED00'),
    [Drawing.ColorTranslator]::FromHtml('#008026'),
    [Drawing.ColorTranslator]::FromHtml('#004DFF'),
    [Drawing.ColorTranslator]::FromHtml('#750787')
)
$progress = @(
    [Drawing.ColorTranslator]::FromHtml('#000000'),
    [Drawing.ColorTranslator]::FromHtml('#613915'),
    [Drawing.ColorTranslator]::FromHtml('#74D7EE'),
    [Drawing.ColorTranslator]::FromHtml('#FFAFC8'),
    [Drawing.ColorTranslator]::FromHtml('#FFFFFF')
)
$dark = [Drawing.ColorTranslator]::FromHtml('#140021')
$raised = [Drawing.ColorTranslator]::FromHtml('#24103A')
$ink = [Drawing.ColorTranslator]::FromHtml('#FFF9F2')

function New-QualityGraphics([Drawing.Bitmap]$bitmap) {
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    return $graphics
}

function Save-Png([Drawing.Bitmap]$bitmap, [string]$path) {
    $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
}

function Draw-RainbowBand([Drawing.Graphics]$graphics, [int]$width, [int]$top, [int]$height) {
    $stripeWidth = [Math]::Ceiling($width / $pride.Count)
    for ($index = 0; $index -lt $pride.Count; $index++) {
        $brush = New-Object Drawing.SolidBrush($pride[$index])
        try {
            $x = $index * $stripeWidth
            $points = [Drawing.Point[]]@(
                [Drawing.Point]::new($x + 70, $top),
                [Drawing.Point]::new($x + $stripeWidth + 72, $top),
                [Drawing.Point]::new($x + $stripeWidth - 72, $top + $height),
                [Drawing.Point]::new($x - 70, $top + $height)
            )
            $graphics.FillPolygon($brush, $points)
        }
        finally { $brush.Dispose() }
    }
}

function Draw-ProgressChevron([Drawing.Graphics]$graphics, [int]$top, [int]$height, [int]$depth) {
    $step = [Math]::Floor($depth / $progress.Count)
    # Paint the largest chevron first so each smaller stripe remains visible.
    for ($index = 0; $index -lt $progress.Count; $index++) {
        $brush = New-Object Drawing.SolidBrush($progress[$index])
        try {
            $offset = $index * $step
            $points = [Drawing.Point[]]@(
                [Drawing.Point]::new(0, $top),
                [Drawing.Point]::new($depth - $offset, $top + [Math]::Floor($height / 2)),
                [Drawing.Point]::new(0, $top + $height)
            )
            $graphics.FillPolygon($brush, $points)
        }
        finally { $brush.Dispose() }
    }
}

function New-Wallpaper {
    $width = 2560
    $height = 1440
    $bitmap = New-Object Drawing.Bitmap($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = New-QualityGraphics $bitmap
    try {
        $rect = [Drawing.Rectangle]::new(0, 0, $width, $height)
        $background = New-Object Drawing.Drawing2D.LinearGradientBrush($rect, $dark, $raised, 28.0)
        try { $graphics.FillRectangle($background, $rect) } finally { $background.Dispose() }

        Draw-RainbowBand $graphics $width 320 760
        Draw-ProgressChevron $graphics 320 760 760

        $veilTop = New-Object Drawing.Drawing2D.LinearGradientBrush([Drawing.Rectangle]::new(0, 0, $width, 420), [Drawing.Color]::FromArgb(235, $dark), [Drawing.Color]::FromArgb(80, $dark), 90.0)
        try { $graphics.FillRectangle($veilTop, 0, 0, $width, 420) } finally { $veilTop.Dispose() }
        $veilBottom = New-Object Drawing.Drawing2D.LinearGradientBrush([Drawing.Rectangle]::new(0, 980, $width, 460), [Drawing.Color]::FromArgb(70, $dark), [Drawing.Color]::FromArgb(240, $dark), 90.0)
        try { $graphics.FillRectangle($veilBottom, 0, 980, $width, 460) } finally { $veilBottom.Dispose() }

        $titleFont = New-Object Drawing.Font('Segoe UI', 92, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
        $subtitleFont = New-Object Drawing.Font('Segoe UI', 30, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
        $textBrush = New-Object Drawing.SolidBrush($ink)
        try {
            $graphics.DrawString('PRIDE PRISM', $titleFont, $textBrush, 120, 1160)
            $graphics.DrawString('LOVE WINS  -  BUILD BRIGHTLY', $subtitleFont, $textBrush, 126, 1275)
        }
        finally {
            $titleFont.Dispose()
            $subtitleFont.Dispose()
            $textBrush.Dispose()
        }

        Save-Png $bitmap (Join-Path $windowsAssets 'pride-prism-wallpaper.png')
        Save-Png $bitmap (Join-Path $chromeImages 'theme_ntp_background.png')
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function New-ChromeFrame {
    $width = 3000
    $height = 240
    $bitmap = New-Object Drawing.Bitmap($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = New-QualityGraphics $bitmap
    try {
        $rect = [Drawing.Rectangle]::new(0, 0, $width, $height)
        $background = New-Object Drawing.Drawing2D.LinearGradientBrush($rect, $raised, $dark, 0.0)
        try { $graphics.FillRectangle($background, $rect) } finally { $background.Dispose() }
        Draw-RainbowBand $graphics $width 155 85
        Draw-ProgressChevron $graphics 155 85 250
        Save-Png $bitmap (Join-Path $chromeImages 'theme_frame.png')
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function New-ChromeToolbar {
    $width = 3000
    $height = 160
    $bitmap = New-Object Drawing.Bitmap($width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = New-QualityGraphics $bitmap
    try {
        $rect = [Drawing.Rectangle]::new(0, 0, $width, $height)
        $background = New-Object Drawing.Drawing2D.LinearGradientBrush($rect, $dark, $raised, 0.0)
        try { $graphics.FillRectangle($background, $rect) } finally { $background.Dispose() }
        $stripeWidth = [Math]::Ceiling($width / $pride.Count)
        for ($index = 0; $index -lt $pride.Count; $index++) {
            $brush = New-Object Drawing.SolidBrush($pride[$index])
            try { $graphics.FillRectangle($brush, $index * $stripeWidth, 150, $stripeWidth + 1, 10) } finally { $brush.Dispose() }
        }
        Save-Png $bitmap (Join-Path $chromeImages 'theme_toolbar.png')
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

New-Wallpaper
New-ChromeFrame
New-ChromeToolbar

Get-Item -LiteralPath (Join-Path $windowsAssets 'pride-prism-wallpaper.png'), (Join-Path $chromeImages 'theme_frame.png'), (Join-Path $chromeImages 'theme_toolbar.png'), (Join-Path $chromeImages 'theme_ntp_background.png') |
    Select-Object FullName, Length
