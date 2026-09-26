Add-Type -AssemblyName System.Drawing

$outDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'store'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$out = Join-Path $outDir 'feature-graphic.png'

$w = 1024
$h = 500
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
  $rect,
  [System.Drawing.Color]::FromArgb(255, 8, 12, 28),
  [System.Drawing.Color]::FromArgb(255, 16, 42, 72),
  20
)
$g.FillRectangle($bg, $rect)

$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(40, 40, 420, 420)
$glowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
$glowBrush.CenterColor = [System.Drawing.Color]::FromArgb(90, 26, 188, 156)
$glowBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 26, 188, 156))
$g.FillPath($glowBrush, $glow)

$logo = [System.Drawing.Image]::FromFile((Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\images\logo.png'))
$g.DrawImage($logo, 56, 70, 360, 360)

$titleFont = New-Object System.Drawing.Font 'Segoe UI', 48, ([System.Drawing.FontStyle]::Bold)
$langFont = New-Object System.Drawing.Font 'Segoe UI', 15, ([System.Drawing.FontStyle]::Regular)
$tileFont = New-Object System.Drawing.Font 'Segoe UI', 22, ([System.Drawing.FontStyle]::Bold)
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 245, 248, 252))
$muted = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 186, 214, 224))
$g.DrawString('Luno League', $titleFont, $white, 440, 118)

function Join-Lang([string[]]$names) {
  $dot = '  ' + [char]0x00B7 + '  '
  return ($names -join $dot)
}
$turkish = 'T' + [char]0x00FC + 'rk' + [char]0x00E7 + 'e'
$spanish = 'Espa' + [char]0x00F1 + 'ol'
$french = 'Fran' + [char]0x00E7 + 'ais'
$portuguese = 'Portugu' + [char]0x00EA + 's'
$russian = [string]::new([char[]]@(0x0420, 0x0443, 0x0441, 0x0441, 0x043A, 0x0438, 0x0439))
$row1 = Join-Lang @($turkish, 'English', 'Deutsch', $spanish, $french)
$row2 = Join-Lang @('Italiano', $russian, 'Nederlands', $portuguese, 'Polski')
$g.DrawString($row1, $langFont, $muted, 446, 198)
$g.DrawString($row2, $langFont, $muted, 446, 228)

$tiles = @(
  @{ L = 'L'; C = [System.Drawing.Color]::FromArgb(255, 46, 204, 113) },
  @{ L = 'U'; C = [System.Drawing.Color]::FromArgb(255, 255, 193, 7) },
  @{ L = 'N'; C = [System.Drawing.Color]::FromArgb(255, 55, 62, 92) },
  @{ L = 'O'; C = [System.Drawing.Color]::FromArgb(255, 46, 204, 113) }
)
$x = 446
foreach ($tile in $tiles) {
  $tileRect = New-Object System.Drawing.Rectangle $x, 292, 64, 64
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $radius = 12
  $path.AddArc($tileRect.X, $tileRect.Y, $radius, $radius, 180, 90)
  $path.AddArc($tileRect.Right - $radius, $tileRect.Y, $radius, $radius, 270, 90)
  $path.AddArc($tileRect.Right - $radius, $tileRect.Bottom - $radius, $radius, $radius, 0, 90)
  $path.AddArc($tileRect.X, $tileRect.Bottom - $radius, $radius, $radius, 90, 90)
  $path.CloseFigure()
  $fill = New-Object System.Drawing.SolidBrush $tile.C
  $g.FillPath($fill, $path)
  $size = $g.MeasureString($tile.L, $tileFont)
  $g.DrawString($tile.L, $tileFont, $white, ($x + (64 - $size.Width) / 2), (292 + (64 - $size.Height) / 2))
  $fill.Dispose()
  $path.Dispose()
  $x += 76
}

$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$logo.Dispose()
$g.Dispose()
$bmp.Dispose()
$bg.Dispose()
Write-Output $out
