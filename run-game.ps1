<#
.SYNOPSIS
  Launch RTS_p5 via Processing CLI with an optional map (same host pattern as benchmark.ps1).

.DESCRIPTION
  benchmark.ps1 copies a template into map_test.json for automated runs.
  This script passes the map to the engine via sketch args (--map=...) so you can load
  any file under RTS_p5/data (or an absolute path) without touching map_test.json.

.EXAMPLE
  .\run-game.ps1 -MapFile map_001.json
  .\run-game.ps1 -MapFile map_001.json -DirectEnter:$false
  .\run-game.ps1 -MapFile map_stress_template.json -Build
#>
param(
  [string]$ProjectRoot = "",
  [string]$ProcessingExe = "D:\Program Files\Processing\Processing.exe",
  [string]$MapFile = "map_001.json",
  [bool]$DirectEnter = $true,
  [switch]$Build
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = $PSScriptRoot
}

$sketchDir = Join-Path $ProjectRoot "RTS_p5"
$dataDir = Join-Path $sketchDir "data"
$buildScript = Join-Path $ProjectRoot "build.ps1"

if (!(Test-Path $ProcessingExe)) {
  throw "Processing executable not found: $ProcessingExe`nInstall Processing 4 or pass -ProcessingExe."
}
if (!(Test-Path $sketchDir)) {
  throw "Sketch directory not found: $sketchDir"
}

if (![System.IO.Path]::IsPathRooted($MapFile)) {
  $candidate = Join-Path $dataDir $MapFile
  if (!(Test-Path $candidate)) {
    throw "Map not found under data: $candidate`nPass -MapFile as a basename in data/ or an absolute path."
  }
}

if ($Build) {
  if (!(Test-Path $buildScript)) {
    throw "build.ps1 not found: $buildScript"
  }
  Write-Host "[RUN] Building sketch..." -ForegroundColor Cyan
  $outDir = Join-Path $ProjectRoot "_cli_build_out"
  & powershell -ExecutionPolicy Bypass -File $buildScript `
    -ProcessingExe $ProcessingExe `
    -SketchDir $sketchDir `
    -OutputDir $outDir
  if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
  }
}

Write-Host "[RUN] RTS_p5"
Write-Host "  Processing: $ProcessingExe"
Write-Host "  Sketch:     $sketchDir"
Write-Host "  Map:        $MapFile"
Write-Host "  DirectEnter: $DirectEnter"
Write-Host ""

# Processing cli --run often does NOT forward trailing args to the sketch's `args` array.
# GameState reads RTS_MAP_FILE (absolute path) and RTS_DIRECT_ENTER (1/0) for map + auto-start.
$resolvedMap = if ([System.IO.Path]::IsPathRooted($MapFile)) { $MapFile } else { (Join-Path $dataDir $MapFile) }
$env:RTS_MAP_FILE = $resolvedMap
$env:RTS_DIRECT_ENTER = if ($DirectEnter) { "1" } else { "0" }

$deStr = if ($DirectEnter) { "true" } else { "false" }
$mapArg = "--map=$MapFile"
$deArg = "--DirectEnter=$deStr"
$runArgs = @(
  "cli",
  "--sketch=$sketchDir",
  "--run",
  $mapArg,
  $deArg
)

$p = Start-Process -FilePath $ProcessingExe -ArgumentList $runArgs -Wait -NoNewWindow -PassThru
if ($p.ExitCode -ne 0) {
  Write-Warning "Processing exited with code $($p.ExitCode). If the game ran and you only closed the window, you can ignore this."
}
