param(
  [string]$ProjectRoot = "D:\projects\cursor\RTS_p5",
  [string]$ProcessingExe = "D:\Program Files\Processing\Processing.exe",
  [string]$MapFile = "map_stress_template.json",
  [string[]]$Profiles = @("balanced", "rush", "greed", "turtle"),
  [string]$BattleIntensity = "",
  [string[]]$Intensities = @("medium", "heavy", "extreme"),
  [ValidateSet("balanced","anti-armor","swarm")]
  [string]$TroopProfile = "balanced",
  [switch]$SkipVisualize,
  [int]$DurationSec = 30,
  [int]$WarmupSec = 5,
  [int]$RunTimeoutSec = 240,
  [string]$RunTagPrefix = "matrix"
)

$ErrorActionPreference = "Stop"

$benchScript = Join-Path $ProjectRoot "benchmark.ps1"
$vizScript = Join-Path $ProjectRoot "benchmark-viz.ps1"
$dashboardScript = Join-Path $ProjectRoot "tools\benchmark_dashboard.py"
$uiPath = Join-Path $ProjectRoot "RTS_p5\data\ui.json"
$backupUiPath = Join-Path $ProjectRoot "RTS_p5\data\ui.matrix_backup.json"
$summaryDir = Join-Path $ProjectRoot "benchmarks"
$runtimeCsv = Join-Path $ProjectRoot "RTS_p5\benchmarks\runtime_metrics.csv"

if (!(Test-Path $benchScript)) { throw "benchmark.ps1 not found: $benchScript" }
if (!(Test-Path $uiPath)) { throw "ui.json not found: $uiPath" }

New-Item -ItemType Directory -Force -Path $summaryDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$summaryPath = Join-Path $summaryDir "matrix-$timestamp.md"
$rows = @()
 $normalizedProfiles = @()
$normalizedIntensities = @()

foreach ($entry in $Profiles) {
  if ($null -eq $entry) { continue }
  $parts = $entry -split ","
  foreach ($part in $parts) {
    $v = $part.Trim().ToLower()
    if ($v.Length -gt 0) {
      $normalizedProfiles += $v
    }
  }
}
if ($normalizedProfiles.Count -le 0) {
  throw "No valid profiles provided"
}
if (![string]::IsNullOrWhiteSpace($BattleIntensity)) {
  $Intensities = @($BattleIntensity)
}
foreach ($entry in $Intensities) {
  if ($null -eq $entry) { continue }
  $parts = $entry -split ","
  foreach ($part in $parts) {
    $v = $part.Trim().ToLower()
    if ($v -in @("medium","heavy","extreme")) {
      $normalizedIntensities += $v
    }
  }
}
if ($normalizedIntensities.Count -le 0) {
  throw "No valid intensities provided"
}

Copy-Item $uiPath $backupUiPath -Force
try {
  foreach ($intensity in $normalizedIntensities) {
    foreach ($profile in $normalizedProfiles) {
      $ui = Get-Content $uiPath -Raw | ConvertFrom-Json
      $ui.enemyAiProfile = $profile
      ($ui | ConvertTo-Json -Depth 16) | Out-File -FilePath $uiPath -Encoding UTF8

      $tag = "$RunTagPrefix-$profile-$intensity"
      Write-Host "[MATRIX] Running profile=$profile intensity=$intensity"
      $benchArgs = @(
        "-ExecutionPolicy","Bypass",
        "-File",$benchScript,
        "-ProjectRoot",$ProjectRoot,
        "-ProcessingExe",$ProcessingExe,
        "-MapFile",$MapFile,
        "-RunTag",$tag,
        "-BattleIntensity",$intensity,
        "-TroopProfile",$TroopProfile,
        "-DurationSec",$DurationSec,
        "-WarmupSec",$WarmupSec,
        "-RunTimeoutSec",$RunTimeoutSec
      )
      powershell @benchArgs
      if ($LASTEXITCODE -ne 0) {
        throw "benchmark.ps1 failed for profile=$profile intensity=$intensity with code $LASTEXITCODE"
      }
      $rows += [pscustomobject]@{ profile=$profile; intensity=$intensity; result="OK"; run_tag=$tag }
    }
  }
}
finally {
  if (Test-Path $backupUiPath) {
    Move-Item -Path $backupUiPath -Destination $uiPath -Force
  }
}

$content = @()
$content += "# Benchmark Matrix $timestamp"
$content += ""
$content += "- Map: $MapFile"
$content += "- Profiles: " + ($normalizedProfiles -join ", ")
$content += "- Intensities: " + ($normalizedIntensities -join ", ")
$content += "- TroopProfile: $TroopProfile"
$content += "- Runtime CSV: RTS_p5/benchmarks/runtime_metrics.csv"
$content += ""
$content += "## Run Summary"
$content += "| profile | intensity | result | run_tag |"
$content += "| --- | --- | --- | --- |"
foreach ($r in $rows) {
  $content += "| $($r.profile) | $($r.intensity) | $($r.result) | $($r.run_tag) |"
}
$content += ""
$content += "## Profile x Intensity (latest)"
$content += "| profile \\ intensity | " + ($normalizedIntensities -join " | ") + " |"
$content += "| --- | " + (($normalizedIntensities | ForEach-Object { "---" }) -join " | ") + " |"

$metricsByKey = @{}
if (Test-Path $runtimeCsv) {
  $rawLines = Get-Content $runtimeCsv
  foreach ($ln in $rawLines) {
    if ([string]::IsNullOrWhiteSpace($ln) -or $ln.StartsWith("run_id,")) { continue }
    $parts = $ln.Split(",")
    if ($parts.Count -lt 26) { continue }
    $runId = $parts[0]
    $mProfile = $parts[20].ToLower()
    $mIntensity = $parts[21].ToLower()
    $mTroop = $parts[24].ToLower()
    if (!($normalizedProfiles -contains $mProfile)) { continue }
    if (!($normalizedIntensities -contains $mIntensity)) { continue }
    if ($mTroop -ne $TroopProfile) { continue }
    $key = "$mProfile|$mIntensity"
    $metricsByKey[$key] = [pscustomobject]@{
      avg_fps = $parts[8]
      p99_frame_ms = $parts[11]
      max_frame_ms = $parts[12]
      run_id = $runId
    }
  }
}
foreach ($profile in $normalizedProfiles) {
  $line = "| $profile "
  foreach ($intensity in $normalizedIntensities) {
    $key = "$profile|$intensity"
    if ($metricsByKey.ContainsKey($key)) {
      $last = $metricsByKey[$key]
      $cell = "fps " + $last.avg_fps + " / p99 " + $last.p99_frame_ms + " / max " + $last.max_frame_ms
      $line += "| $cell "
    } else {
      $line += "| n/a "
    }
  }
  $line += "|"
  $content += $line
}
$content += ""
$content += "Matrix cells show latest metrics for each profile-intensity combination."

$content -join "`r`n" | Out-File -FilePath $summaryPath -Encoding UTF8
Write-Host "[MATRIX] Summary created: $summaryPath"

if (!$SkipVisualize) {
  $vizOut = Join-Path $summaryDir "visual-report-$timestamp.md"
  $dashOut = Join-Path $summaryDir "dashboard-$timestamp.html"

  if (Test-Path $vizScript) {
    Write-Host "[MATRIX] Running visual markdown report..."
    powershell -ExecutionPolicy Bypass -File $vizScript -ProjectRoot $ProjectRoot -CsvPath $runtimeCsv -OutputPath $vizOut -TroopProfile $TroopProfile
    if ($LASTEXITCODE -ne 0) {
      throw "benchmark-viz.ps1 failed with code $LASTEXITCODE"
    }
    Write-Host "[MATRIX] Visual report: $vizOut"
  } else {
    Write-Host "[MATRIX] Skip visual markdown: script not found ($vizScript)"
  }

  if (Test-Path $dashboardScript) {
    Write-Host "[MATRIX] Running dashboard generation..."
    python $dashboardScript --project-root $ProjectRoot --csv-path $runtimeCsv --output-path $dashOut
    if ($LASTEXITCODE -ne 0) {
      throw "benchmark_dashboard.py failed with code $LASTEXITCODE"
    }
    Write-Host "[MATRIX] Dashboard: $dashOut"
  } else {
    Write-Host "[MATRIX] Skip dashboard: script not found ($dashboardScript)"
  }
}
