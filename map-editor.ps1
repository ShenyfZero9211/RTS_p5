param(
  [string]$ProcessingExe = "D:\Program Files\Processing\Processing.exe",
  [string]$SketchDir = "",
  [string]$BuildOutDir = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SketchDir)) {
  $SketchDir = Join-Path $PSScriptRoot "map_editor"
}
if ([string]::IsNullOrWhiteSpace($BuildOutDir)) {
  $BuildOutDir = Join-Path $PSScriptRoot "_cli_build_map_editor_check"
}

if (!(Test-Path $ProcessingExe)) {
  throw "Processing executable not found: $ProcessingExe`nInstall Processing 4 or pass -ProcessingExe."
}
if (!(Test-Path $SketchDir)) {
  throw "Map editor sketch directory not found: $SketchDir`nPass -SketchDir to your repo's map_editor folder."
}

Write-Host "RTS map editor"
Write-Host "  Processing: $ProcessingExe"
Write-Host "  Sketch:     $SketchDir"
Write-Host ""

# Use Start-Process so ExitCode is reliable; $LASTEXITCODE is often $null after native EXEs in PowerShell 5.1.
function Invoke-ProcessingCli {
  param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )
  $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -Wait -NoNewWindow -PassThru
  return $p.ExitCode
}

Write-Host "Compiling sketch (compiler messages print below)..." -ForegroundColor Cyan
$buildExit = Invoke-ProcessingCli -Exe $ProcessingExe -Arguments @(
  "cli",
  "--sketch=$SketchDir",
  "--output=$BuildOutDir",
  "--force",
  "--build"
)
if ($buildExit -ne 0) {
  throw "Compile failed (exit $buildExit). Fix errors above, or open this sketch in the Processing app."
}

Write-Host ""
Write-Host "Launching editor (close window when done)..." -ForegroundColor Cyan
$runExit = Invoke-ProcessingCli -Exe $ProcessingExe -Arguments @(
  "cli",
  "--sketch=$SketchDir",
  "--run"
)
if ($runExit -ne 0) {
  Write-Host ""
  Write-Warning "Processing reported exit code $runExit after --run. If the editor opened and you only closed the window, you can ignore this. If it flashed closed, open the sketch in the Processing app and read the console for a stack trace."
}
