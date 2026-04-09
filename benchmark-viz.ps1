param(
  [string]$ProjectRoot = "D:\projects\cursor\RTS_p5",
  [string]$CsvPath = "",
  [string]$OutputPath = "",
  [string]$TroopProfile = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($CsvPath)) {
  $CsvPath = Join-Path $ProjectRoot "RTS_p5\benchmarks\runtime_metrics.csv"
}
if (!(Test-Path $CsvPath)) {
  throw "Runtime CSV not found: $CsvPath"
}

$benchDir = Join-Path $ProjectRoot "benchmarks"
New-Item -ItemType Directory -Force -Path $benchDir | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $OutputPath = Join-Path $benchDir "visual-report-$stamp.md"
}

function Parse-RuntimeRow {
  param([string]$Line)
  if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
  if ($Line.StartsWith("run_id,")) { return $null }
  $parts = $Line.Split(",")
  if ($parts.Count -lt 22) { return $null }

  $row = [ordered]@{
    run_id = $parts[0]
    timestamp = $parts[1]
    avg_fps = [double]$parts[8]
    p95_frame_ms = [double]$parts[10]
    p99_frame_ms = [double]$parts[11]
    max_frame_ms = [double]$parts[12]
    enemy_ai_profile = ($parts[20]).ToLower()
    battle_intensity = "unknown"
    reinforce_interval_sec = "default"
    reinforce_count_per_faction = "default"
    troop_profile = "balanced"
  }
  if ($parts.Count -ge 23 -and $parts[21].Length -gt 0) { $row.battle_intensity = ($parts[21]).ToLower() }
  if ($parts.Count -ge 24 -and $parts[22].Length -gt 0) { $row.reinforce_interval_sec = $parts[22] }
  if ($parts.Count -ge 25 -and $parts[23].Length -gt 0) { $row.reinforce_count_per_faction = $parts[23] }
  if ($parts.Count -ge 26 -and $parts[24].Length -gt 0) { $row.troop_profile = ($parts[24]).ToLower() }
  $row.group_key = "$($row.enemy_ai_profile)|$($row.battle_intensity)|$($row.reinforce_interval_sec)|$($row.reinforce_count_per_faction)|$($row.troop_profile)"
  return [pscustomobject]$row
}

$rows = @()
foreach ($ln in (Get-Content $CsvPath)) {
  $r = Parse-RuntimeRow -Line $ln
  if ($null -ne $r) { $rows += $r }
}
if ($rows.Count -le 0) {
  throw "No valid runtime rows found in: $CsvPath"
}
if (![string]::IsNullOrWhiteSpace($TroopProfile)) {
  $tp = $TroopProfile.ToLower()
  $rows = $rows | Where-Object { $_.troop_profile -eq $tp }
}
if ($rows.Count -le 0) {
  throw "No rows left after troop profile filter: $TroopProfile"
}

$grouped = $rows | Group-Object group_key
$latestByGroup = @()
$regressions = @()
foreach ($g in $grouped) {
  $ordered = $g.Group | Sort-Object timestamp
  $last = $ordered[-1]
  $latestByGroup += $last
  if ($ordered.Count -ge 2) {
    $prev = $ordered[-2]
    $fpsDelta = [Math]::Round($last.avg_fps - $prev.avg_fps, 2)
    $p99Delta = [Math]::Round($last.p99_frame_ms - $prev.p99_frame_ms, 2)
    if ($fpsDelta -lt -2 -or $p99Delta -gt 5) {
      $regressions += [pscustomobject]@{
        group_key = $g.Name
        latest_run = $last.run_id
        previous_run = $prev.run_id
        fps_delta = $fpsDelta
        p99_delta = $p99Delta
      }
    }
  }
}

$intensities = @("medium", "heavy", "extreme")
$profiles = @("balanced", "rush", "greed", "turtle")

$lines = @()
$lines += "# Benchmark Visual Report"
$lines += ""
$lines += "- Source CSV: $CsvPath"
$lines += "- Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
if (![string]::IsNullOrWhiteSpace($TroopProfile)) {
  $lines += "- Filter: troop_profile = $($TroopProfile.ToLower())"
}
$lines += ""

$lines += "## Latest Snapshot By Group"
$lines += "| group_key | run_id | avg_fps | p99_ms | max_ms |"
$lines += "| --- | --- | ---: | ---: | ---: |"
foreach ($r in ($latestByGroup | Sort-Object group_key)) {
  $lines += "| $($r.group_key) | $($r.run_id) | $([Math]::Round($r.avg_fps, 2)) | $([Math]::Round($r.p99_frame_ms, 2)) | $([Math]::Round($r.max_frame_ms, 2)) |"
}
$lines += ""

$lines += "## Regression Alerts (latest vs previous)"
$lines += "| group_key | latest_run | previous_run | fps_delta | p99_delta |"
$lines += "| --- | --- | --- | ---: | ---: |"
if ($regressions.Count -le 0) {
  $lines += "| (none) | - | - | - | - |"
} else {
  foreach ($r in ($regressions | Sort-Object group_key)) {
    $lines += "| $($r.group_key) | $($r.latest_run) | $($r.previous_run) | $($r.fps_delta) | $($r.p99_delta) |"
  }
}
$lines += ""

$lines += "## Profile x Intensity (Latest avg_fps / p99 / max)"
$lines += "| profile \\ intensity | medium | heavy | extreme |"
$lines += "| --- | --- | --- | --- |"
foreach ($p in $profiles) {
  $line = "| $p "
  foreach ($i in $intensities) {
    $cands = $rows | Where-Object { $_.enemy_ai_profile -eq $p -and $_.battle_intensity -eq $i } | Sort-Object timestamp
    if ($cands.Count -gt 0) {
      $x = $cands[-1]
      $line += "| $([Math]::Round($x.avg_fps,2)) / $([Math]::Round($x.p99_frame_ms,2)) / $([Math]::Round($x.max_frame_ms,2)) "
    } else {
      $line += "| n/a "
    }
  }
  $line += "|"
  $lines += $line
}
$lines += ""

$lines += "## Notes"
$lines += '- Use `tools/benchmark_dashboard.py` for interactive filtering and charts.'
$lines += "- Group key keeps scenario dimensions isolated to avoid mixed comparisons."

$lines -join "`r`n" | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "[VIZ] Report created: $OutputPath"
