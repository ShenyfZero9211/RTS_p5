# Benchmark Workflow

Use this workflow for Phase B performance regression checks.

## Assets
- Stress map template: `RTS_p5/data/map_stress_template.json`
- Benchmark script: `benchmark.ps1`
- Output CSV: `benchmarks/benchmark_log.csv`
- Runtime metrics CSV: `RTS_p5/benchmarks/runtime_metrics.csv`
- Per-run report: `benchmarks/runs/<timestamp>-<tag>.md`

## Run

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark.ps1 -DurationSec 120 -WarmupSec 10 -BattleIntensity heavy -TroopProfile balanced
```

Optional params:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark.ps1 -MapFile map_stress_template.json -RunTag ai-turtle -BattleIntensity extreme -TroopProfile anti-armor -ReinforceIntervalSec 6 -ReinforceCountPerFaction 18
```

Matrix run (all AI profiles):

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark-matrix.ps1 -Intensities medium,heavy,extreme -TroopProfile balanced
```

Compare latest vs previous runs:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark-compare.ps1
```

Legacy (build log) compare:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark-compare.ps1 -LegacyBuildLog
```

## What It Does
- Temporarily swaps `data/map_test.json` to the selected benchmark map
- Runs `build.ps1`
- Enables runtime benchmark mode via `data/benchmark_runtime.json`
- Launches game with `processing cli --run`, waits for runtime metrics row append
- Restores original `data/map_test.json`
- Appends one row to `benchmarks/benchmark_log.csv`
- Appends one runtime row to `RTS_p5/benchmarks/runtime_metrics.csv`
- Creates a markdown run sheet for manual runtime metrics
- `BattleIntensity` supports: `medium`, `heavy`, `extreme`
- `TroopProfile` supports: `balanced`, `anti-armor`, `swarm`
- Reinforcement waves can be overridden with `-ReinforceIntervalSec` and `-ReinforceCountPerFaction`
- `benchmark-compare.ps1` now groups by scenario key: `profile|intensity|reinforce_interval|reinforce_count|troop_profile`
- `benchmark-matrix.ps1` supports profile × intensity matrix output

## Suggested Regression Gate
- Build must pass
- No severe stutter during 60s pan + 60s combat
- Track avg FPS and p99 frame ms trend in `benchmark_log.csv`
- For AI changes, compare `balanced/rush/greed/turtle` across at least two intensity levels
- Generate a compare report after matrix runs for quick trend checks
