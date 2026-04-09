param(
  [string]$ProcessingExe = "D:\Program Files\Processing\Processing.exe",
  [string]$SketchDir = "D:\projects\cursor\RTS_p5\RTS_p5",
  [string]$OutputDir = "D:\projects\cursor\RTS_p5\_cli_build_out"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $ProcessingExe)) {
  throw "Processing executable not found: $ProcessingExe"
}
if (!(Test-Path $SketchDir)) {
  throw "Sketch directory not found: $SketchDir"
}

Write-Host "Building sketch..."
Write-Host "  Processing: $ProcessingExe"
Write-Host "  Sketch:     $SketchDir"
Write-Host "  Output:     $OutputDir"

$args = @(
  "cli",
  "--sketch=$SketchDir",
  "--output=$OutputDir",
  "--force",
  "--build"
)

$proc = Start-Process -FilePath $ProcessingExe -ArgumentList $args -Wait -NoNewWindow -PassThru
if ($proc.ExitCode -ne 0) {
  throw "Build failed with exit code $($proc.ExitCode)"
}

Write-Host ""
Write-Host "Build finished: $OutputDir"
