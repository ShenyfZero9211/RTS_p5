param(
  [string]$ProjectRoot = "D:\projects\cursor\RTS_p5",
  [string]$CsvPath = "",
  [string]$OutputPath = "",
  [switch]$LegacyBuildLog
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($CsvPath)) {
  if ($LegacyBuildLog) {
    $CsvPath = Join-Path $ProjectRoot "benchmarks\benchmark_log.csv"
  } else {
    $CsvPath = Join-Path $ProjectRoot "RTS_p5\benchmarks\runtime_metrics.csv"
  }
}
if (!(Test-Path $CsvPath)) {
  throw "Benchmark CSV not found: $CsvPath"
}

$benchDir = Join-Path $ProjectRoot "benchmarks"
New-Item -ItemType Directory -Force -Path $benchDir | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $OutputPath = Join-Path $benchDir "compare-$stamp.md"
}

$rows = Import-Csv -Path $CsvPath
$isRuntimeCsv = $false
if ($rows.Count -gt 0 -and ($rows[0].PSObject.Properties.Name -contains "avg_fps")) {
  $isRuntimeCsv = $true
}
# Supplement parser for mixed/legacy runtime CSV headers:
# If runtime rows have more columns than current header, Import-Csv drops tail fields.
$runtimeTailByRunId = @{}
if (!$LegacyBuildLog -and (Test-Path $CsvPath)) {
  $rawLines = Get-Content $CsvPath
  foreach ($ln in $rawLines) {
    if ([string]::IsNullOrWhiteSpace($ln)) { continue }
    if ($ln.StartsWith("run_id,")) { continue }
    $parts = $ln.Split(",")
    if ($parts.Count -ge 26) {
      $rid = $parts[0]
      $runtimeTailByRunId[$rid] = [pscustomobject]@{
        battle_intensity = $parts[21]
        reinforce_interval_sec = $parts[22]
        reinforce_count_per_faction = $parts[23]
        troop_profile = $parts[24]
      }
    }
  }
}
$valid = @()
foreach ($r in $rows) {
  if ($null -eq $r.timestamp -or $r.timestamp -notmatch "^\d{8}-\d{6}$") {
    continue
  }
  $runId = "$($r.run_id)"
  $profile = "unknown"
  if ($isRuntimeCsv) {
    $profile = "$($r.enemy_ai_profile)".ToLower()
    if ([string]::IsNullOrWhiteSpace($profile)) { $profile = "unknown" }
  } else {
    $parts = $runId -split "-"
    if ($parts.Length -gt 0) { $profile = $parts[-1].ToLower() }
  }
  $buildSeconds = [double]::NaN
  if ($r.PSObject.Properties.Name -contains "build_seconds" -and "$($r.build_seconds)".Length -gt 0) {
    [void][double]::TryParse("$($r.build_seconds)", [ref]$buildSeconds)
  }
  $fps = [double]::NaN
  if ($isRuntimeCsv) {
    [void][double]::TryParse("$($r.avg_fps)", [ref]$fps)
  } elseif ("$($r.fps_avg_manual)".Length -gt 0) {
    [void][double]::TryParse("$($r.fps_avg_manual)", [ref]$fps)
  }
  $p95 = [double]::NaN
  if ($isRuntimeCsv -and "$($r.p95_frame_ms)".Length -gt 0) {
    [void][double]::TryParse("$($r.p95_frame_ms)", [ref]$p95)
  }
  $p99 = [double]::NaN
  if ($isRuntimeCsv -and "$($r.p99_frame_ms)".Length -gt 0) {
    [void][double]::TryParse("$($r.p99_frame_ms)", [ref]$p99)
  } elseif ("$($r.p99_frame_ms_manual)".Length -gt 0) {
    [void][double]::TryParse("$($r.p99_frame_ms_manual)", [ref]$p99)
  }
  $maxFrame = [double]::NaN
  if ($isRuntimeCsv -and "$($r.max_frame_ms)".Length -gt 0) {
    [void][double]::TryParse("$($r.max_frame_ms)", [ref]$maxFrame)
  }
  $battleIntensity = "unknown"
  if ($r.PSObject.Properties.Name -contains "battle_intensity" -and "$($r.battle_intensity)".Length -gt 0) {
    $battleIntensity = "$($r.battle_intensity)".ToLower()
  }
  $reinforceInterval = "default"
  if ($r.PSObject.Properties.Name -contains "reinforce_interval_sec" -and "$($r.reinforce_interval_sec)".Length -gt 0) {
    $reinforceInterval = "$($r.reinforce_interval_sec)"
  }
  $reinforceCount = "default"
  if ($r.PSObject.Properties.Name -contains "reinforce_count_per_faction" -and "$($r.reinforce_count_per_faction)".Length -gt 0) {
    $reinforceCount = "$($r.reinforce_count_per_faction)"
  }
  $troopProfile = "unknown"
  if ($r.PSObject.Properties.Name -contains "troop_profile" -and "$($r.troop_profile)".Length -gt 0) {
    $troopProfile = "$($r.troop_profile)".ToLower()
  } elseif ($isRuntimeCsv) {
    $troopProfile = "balanced"
  }
  if ($runtimeTailByRunId.ContainsKey($runId)) {
    $tail = $runtimeTailByRunId[$runId]
    if (![string]::IsNullOrWhiteSpace($tail.battle_intensity)) { $battleIntensity = $tail.battle_intensity.ToLower() }
    if (![string]::IsNullOrWhiteSpace($tail.reinforce_interval_sec)) { $reinforceInterval = $tail.reinforce_interval_sec }
    if (![string]::IsNullOrWhiteSpace($tail.reinforce_count_per_faction)) { $reinforceCount = $tail.reinforce_count_per_faction }
    if (![string]::IsNullOrWhiteSpace($tail.troop_profile)) { $troopProfile = $tail.troop_profile.ToLower() }
  }
  $groupKey = "$profile|$battleIntensity|$reinforceInterval|$reinforceCount|$troopProfile"
  $valid += [pscustomobject]@{
    run_id = $runId
    timestamp = "$($r.timestamp)"
    profile = $profile
    battle_intensity = $battleIntensity
    reinforce_interval_sec = $reinforceInterval
    reinforce_count_per_faction = $reinforceCount
    troop_profile = $troopProfile
    group_key = $groupKey
    map = "$($r.map)"
    build_seconds = $buildSeconds
    fps = $fps
    p95 = $p95
    p99 = $p99
    max_frame = $maxFrame
    notes = "$($r.notes)"
  }
}

if ($valid.Count -lt 2) {
  throw "Need at least 2 valid benchmark rows to compare."
}

$grouped = $valid | Group-Object group_key
$lines = @()
$lines += "# Benchmark Compare"
$lines += ""
$lines += "- Source CSV: $CsvPath"
$lines += "- Mode: " + ($(if ($isRuntimeCsv) { "runtime metrics" } else { "legacy build log" }))
$lines += "- Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
$lines += ""
if ($isRuntimeCsv) {
  $lines += "| group_key | latest run | previous run | fps delta | p95 ms delta | p99 ms delta | max ms delta |"
  $lines += "| --- | --- | --- | ---: | ---: | ---: | ---: |"
} else {
  $lines += "| group_key | latest run | previous run | build s delta | fps delta | p99 ms delta |"
  $lines += "| --- | --- | --- | ---: | ---: | ---: |"
}

foreach ($g in $grouped) {
  $ordered = $g.Group | Sort-Object timestamp
  if ($ordered.Count -lt 2) { continue }
  $prev = $ordered[-2]
  $last = $ordered[-1]
  $dfps = if (![double]::IsNaN($prev.fps) -and ![double]::IsNaN($last.fps)) { [Math]::Round(($last.fps - $prev.fps), 2) } else { "n/a" }
  $dp99 = if (![double]::IsNaN($prev.p99) -and ![double]::IsNaN($last.p99)) { [Math]::Round(($last.p99 - $prev.p99), 2) } else { "n/a" }
  if ($isRuntimeCsv) {
    $dp95 = if (![double]::IsNaN($prev.p95) -and ![double]::IsNaN($last.p95)) { [Math]::Round(($last.p95 - $prev.p95), 2) } else { "n/a" }
    $dmax = if (![double]::IsNaN($prev.max_frame) -and ![double]::IsNaN($last.max_frame)) { [Math]::Round(($last.max_frame - $prev.max_frame), 2) } else { "n/a" }
    $lines += "| $($g.Name) | $($last.run_id) | $($prev.run_id) | $dfps | $dp95 | $dp99 | $dmax |"
  } else {
    $db = if (![double]::IsNaN($prev.build_seconds) -and ![double]::IsNaN($last.build_seconds)) { [Math]::Round(($last.build_seconds - $prev.build_seconds), 2) } else { "n/a" }
    $lines += "| $($g.Name) | $($last.run_id) | $($prev.run_id) | $db | $dfps | $dp99 |"
  }
}

$lines += ""
$lines += "## Notes"
$lines += "- Positive fps delta means latest runtime is faster."
$lines += "- Positive p95/p99/max delta means latest tail latency is worse."
$lines += "- For build-time-only compare, run with -LegacyBuildLog."
$lines += "- Rows with malformed timestamp are ignored."

$lines -join "`r`n" | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "[COMPARE] Report created: $OutputPath"
