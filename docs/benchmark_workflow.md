# Benchmark Workflow

Use this workflow for Phase B performance regression checks.

## Assets
- Stress map template: `RTS_p5/data/map_stress_template.json`
- Manual arena map: `RTS_p5/data/map_benchmark_manual.json` (wider lanes, fewer obstacles than stress template)
- Benchmark script: `benchmark.ps1`
- Output CSV: `benchmarks/benchmark_log.csv`
- Runtime metrics CSV: `benchmarks/runtime_metrics.csv` (repo root; gitignored)
- Per-run report: `benchmarks/runs/<timestamp>-<tag>.md`

## Run

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark.ps1 -DurationSec 120 -WarmupSec 10 -BattleIntensity heavy -TroopProfile balanced
```

Optional params:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark.ps1 -MapFile map_stress_template.json -RunTag ai-turtle -BattleIntensity extreme -TroopProfile anti-armor -ReinforceIntervalSec 6 -ReinforceCountPerFaction 18
```

Manual control benchmark (script launched):

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark.ps1 -RunTag manual-session -ManualControl -ManualEndKey F10 -ManualAutoFrontline -DurationSec 180 -WarmupSec 10 -BattleIntensity heavy -TroopProfile balanced
```

Manual map + hotkeys (open arena `map_benchmark_manual.json`; **set `-RunTimeoutSec` above `-DurationSec`** so the script does not kill the game early):

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark.ps1 -MapFile map_benchmark_manual.json -RunTag manual-arena -ManualControl -ManualEndKey F10 -DurationSec 300 -WarmupSec 10 -BattleIntensity heavy -TroopProfile balanced -RunTimeoutSec 400
```

During **manual** benchmark only:

- **Q**: spawn one reinforcement wave (same as the timed wave), **~0.9s cooldown**; status line shows success or cooldown.
- **W**: toggle **auto frontline** on/off at runtime (side panel shows `ON`/`OFF`); overrides training hotkeys **Q/W** for that session.
- **F10**: finish benchmark / request write (unchanged).

Optional: mostly **Q-only** reinforcements — set a huge interval, e.g. `-ReinforceIntervalSec 99999`. To disable timed wave size from defaults, `-ReinforceCountPerFaction 0` is supported (no periodic spawns until Q).

Matrix run (all AI profiles):

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark-matrix.ps1 -Intensities medium,heavy,extreme -TroopProfile balanced
```

Compare latest vs previous runs:

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark-compare.ps1
```

Visual report (lightweight markdown):

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark-viz.ps1
```

Interactive dashboard (HTML):

```powershell
python .\tools\benchmark_dashboard.py
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
- Appends one runtime row to `benchmarks/runtime_metrics.csv`
- Creates a markdown run sheet for manual runtime metrics
- `BattleIntensity` supports: `medium`, `heavy`, `extreme`
- `TroopProfile` supports: `balanced`, `anti-armor`, `swarm`
- Manual mode supports `-ManualControl` and `-ManualEndKey` (default `F10`)
- `-ManualAutoFrontline` optionally keeps AI mutual push enabled during manual mode
- Reinforcement waves can be overridden with `-ReinforceIntervalSec` and `-ReinforceCountPerFaction`
- `benchmark-compare.ps1` now groups by scenario key: `profile|intensity|reinforce_interval|reinforce_count|troop_profile`
- `benchmark-matrix.ps1` supports profile × intensity matrix output
- `benchmark-viz.ps1` generates a markdown visual report from runtime CSV
- `tools/benchmark_dashboard.py` generates an interactive Plotly HTML dashboard
- In manual mode, benchmark ends on `F10` or when duration expires, then appends one runtime row
- In manual mode without `-ManualAutoFrontline`, only reinforcement waves are auto-driven (player orders are not overridden)

## Suggested Regression Gate
- Build must pass
- No severe stutter during 60s pan + 60s combat
- Track avg FPS and p99 frame ms trend in `benchmark_log.csv`
- For AI changes, compare `balanced/rush/greed/turtle` across at least two intensity levels
- Generate a compare report after matrix runs for quick trend checks
