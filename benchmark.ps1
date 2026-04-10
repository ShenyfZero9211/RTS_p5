param(
  [string]$ProjectRoot = "D:\projects\cursor\RTS_p5",
  [string]$ProcessingExe = "D:\Program Files\Processing\Processing.exe",
  [string]$MapFile = "map_stress_template.json",
  [string]$RunTag = "",
  [int]$DurationSec = 120,
  [int]$WarmupSec = 10,
  [int]$RunTimeoutSec = 240,
  [ValidateSet("medium","heavy","extreme")]
  [string]$BattleIntensity = "heavy",
  [ValidateSet("balanced","anti-armor","swarm")]
  [string]$TroopProfile = "balanced",
  [switch]$ManualControl,
  [string]$ManualEndKey = "F10",
  [switch]$ManualAutoFrontline,
  [double]$ReinforceIntervalSec = -1,
  [int]$ReinforceCountPerFaction = -1
)

$ErrorActionPreference = "Stop"

$sketchDir = Join-Path $ProjectRoot "RTS_p5"
$dataDir = Join-Path $sketchDir "data"
$sourceMap = Join-Path $dataDir $MapFile
$activeMap = Join-Path $dataDir "map_test.json"
$backupMap = Join-Path $dataDir "map_test.benchmark_backup.json"
$buildScript = Join-Path $ProjectRoot "build.ps1"
$benchDir = Join-Path $ProjectRoot "benchmarks"
$runDir = Join-Path $benchDir "runs"
$csvPath = Join-Path $benchDir "benchmark_log.csv"
$runtimeCsvPath = Join-Path $sketchDir "benchmarks\runtime_metrics.csv"
$runtimeCfgPath = Join-Path $dataDir "benchmark_runtime.json"
$runtimeCfgBackup = Join-Path $dataDir "benchmark_runtime.benchmark_backup.json"

if (!(Test-Path $sourceMap)) { throw "Map template not found: $sourceMap" }
if (!(Test-Path $activeMap)) { throw "map_test.json not found: $activeMap" }
if (!(Test-Path $buildScript)) { throw "build.ps1 not found: $buildScript" }

New-Item -ItemType Directory -Force -Path $benchDir | Out-Null
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ([string]::IsNullOrWhiteSpace($RunTag)) { $RunTag = "stress-template" }
$runId = "$timestamp-$RunTag"

Copy-Item $activeMap $backupMap -Force
Copy-Item $sourceMap $activeMap -Force
if (Test-Path $runtimeCfgPath) {
  Copy-Item $runtimeCfgPath $runtimeCfgBackup -Force
}

try {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  & powershell -ExecutionPolicy Bypass -File $buildScript -ProcessingExe $ProcessingExe
  if ($LASTEXITCODE -ne 0) { throw "Build failed with code $LASTEXITCODE" }
  $sw.Stop()
  $buildSec = [Math]::Round($sw.Elapsed.TotalSeconds, 2)

  $runtimeCfg = [ordered]@{
    enabled = $true
    autoStartGame = $true
    autoExit = (-not $ManualControl.IsPresent)
    durationSec = [Math]::Max(5, $DurationSec)
    warmupSec = [Math]::Max(0, [Math]::Min($WarmupSec, $DurationSec - 1))
    orbitPeriodSec = 24
    runId = $runId
    battleIntensity = $BattleIntensity
    troopProfile = $TroopProfile
    manualControl = $ManualControl.IsPresent
    manualEndKey = $ManualEndKey
    manualAutoFrontline = $ManualAutoFrontline.IsPresent
    reinforceIntervalSec = $ReinforceIntervalSec
    reinforceCountPerFaction = $ReinforceCountPerFaction
    outputCsv = "benchmarks/runtime_metrics.csv"
  }
  ($runtimeCfg | ConvertTo-Json -Depth 8) | Out-File -FilePath $runtimeCfgPath -Encoding UTF8

  Write-Host "[BENCH] Running runtime benchmark..."
  $runArgs = @(
    "cli",
    "--sketch=$sketchDir",
    "--run"
  )
  $runProc = Start-Process -FilePath $ProcessingExe -ArgumentList $runArgs -PassThru
  $deadline = (Get-Date).AddSeconds($RunTimeoutSec)
  $found = $false
  while ((Get-Date) -lt $deadline) {
    if (Test-Path $runtimeCsvPath) {
      $hits = Select-String -Path $runtimeCsvPath -Pattern ("^" + [regex]::Escape($runId) + ",") -SimpleMatch:$false
      if ($hits) {
        $found = $true
        break
      }
    }
    Start-Sleep -Seconds 2
  }
  if (!$found) {
    try {
      if ($runProc -and !$runProc.HasExited) {
        $runProc.Kill()
      }
    } catch {}
    throw "Runtime metrics did not append expected run_id within timeout: $runId"
  }

  $ui = Get-Content (Join-Path $dataDir "ui.json") -Raw | ConvertFrom-Json
  $settings = Get-Content (Join-Path $dataDir "settings_user.json") -Raw | ConvertFrom-Json

  if (!(Test-Path $csvPath)) {
    "run_id,timestamp,map,fixed_step_hz,max_steps_per_frame,fog_budget_ms,fx_density,profiling_overlay,build_seconds,fps_avg_manual,p99_frame_ms_manual,notes" | Out-File -FilePath $csvPath -Encoding UTF8
  }

  $row = "$runId,$timestamp,$MapFile,$($ui.fixedStepHz),$($ui.maxStepsPerFrame),$($ui.fogUpdateBudgetMs),$($ui.fxDensityLevel),$($settings.runtimeProfilingOverlay),$buildSec,,,"
  Add-Content -Path $csvPath -Value $row

  $reportPath = Join-Path $runDir "$runId.md"
  @"
# Benchmark Run $runId

- Map: $MapFile
- Build seconds: $buildSec
- fixedStepHz: $($ui.fixedStepHz)
- maxStepsPerFrame: $($ui.maxStepsPerFrame)
- fogUpdateBudgetMs: $($ui.fogUpdateBudgetMs)
- fxDensityLevel: $($ui.fxDensityLevel)
- runtimeProfilingOverlay: $($settings.runtimeProfilingOverlay)
- battleIntensity: $BattleIntensity
- troopProfile: $TroopProfile
- manualControl: $($ManualControl.IsPresent)
- manualEndKey: $ManualEndKey
- manualAutoFrontline: $($ManualAutoFrontline.IsPresent)
- reinforceIntervalSec: $ReinforceIntervalSec
- reinforceCountPerFaction: $ReinforceCountPerFaction

## Manual Runtime Capture
- [ ] Launch game and start a match
- [ ] Enable profiling overlay in settings if needed
- [ ] Pan camera over full map for 60s
- [ ] Trigger medium/large combat for 60s
- [ ] Fill metrics below

## Metrics To Fill
- avg FPS:
- p99 frame ms:
- observed stutter events:
- notes:
"@ | Out-File -FilePath $reportPath -Encoding UTF8

  Write-Host "[BENCH] Build OK in $buildSec s"
  Write-Host "[BENCH] Runtime benchmark completed"
  Write-Host "[BENCH] Log row appended: $csvPath"
  Write-Host "[BENCH] Run report created: $reportPath"
}
finally {
  if (Test-Path $backupMap) {
    Move-Item -Path $backupMap -Destination $activeMap -Force
  }
  if (Test-Path $runtimeCfgBackup) {
    Move-Item -Path $runtimeCfgBackup -Destination $runtimeCfgPath -Force
  } else {
    $offCfg = [ordered]@{
      enabled = $false
      autoStartGame = $true
      autoExit = $true
      durationSec = 120
      warmupSec = 10
      orbitPeriodSec = 24
      runId = ""
      battleIntensity = "heavy"
      troopProfile = "balanced"
      manualControl = $false
      manualEndKey = "F10"
      manualAutoFrontline = $false
      reinforceIntervalSec = -1
      reinforceCountPerFaction = -1
      outputCsv = "benchmarks/runtime_metrics.csv"
    }
    ($offCfg | ConvertTo-Json -Depth 8) | Out-File -FilePath $runtimeCfgPath -Encoding UTF8
  }
}
