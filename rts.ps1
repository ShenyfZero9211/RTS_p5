<#
.SYNOPSIS
  One-line friendly launcher: forwards to run-game.ps1 (RTS_MAP_FILE + auto-start).

.EXAMPLE
  .\rts.ps1 map_001.json
  .\rts.ps1 map_001.json -DirectEnter:$false
  .\rts.ps1 D:\projects\cursor\RTS_p5\RTS_p5\data\map_stress_template.json -Build
#>
param(
  [Parameter(Position = 0)]
  [string]$Map = "map_001.json",
  [bool]$DirectEnter = $true,
  [switch]$Build
)

$here = $PSScriptRoot
$target = Join-Path $here "run-game.ps1"
if (!(Test-Path $target)) {
  throw "run-game.ps1 not found next to rts.ps1: $target"
}
& $target -MapFile $Map -DirectEnter:$DirectEnter -Build:$Build
