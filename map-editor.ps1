param(
  [string]$ProcessingExe = "D:\Program Files\Processing\Processing.exe",
  [string]$SketchDir = "D:\projects\cursor\RTS_p5\map_editor"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $ProcessingExe)) {
  throw "Processing executable not found: $ProcessingExe"
}
if (!(Test-Path $SketchDir)) {
  throw "Map editor sketch directory not found: $SketchDir"
}

Write-Host "Launching RTS map editor..."
Write-Host "  Processing: $ProcessingExe"
Write-Host "  Sketch:     $SketchDir"

$args = @(
  "cli",
  "--sketch=$SketchDir",
  "--run"
)

$proc = Start-Process -FilePath $ProcessingExe -ArgumentList $args -Wait -NoNewWindow -PassThru
if ($proc.ExitCode -ne 0) {
  throw "Map editor exited with code $($proc.ExitCode)"
}
