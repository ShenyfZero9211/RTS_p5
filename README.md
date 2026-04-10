# RTS_p5

A Processing-based RTS prototype inspired by classic games (StarCraft / Red Alert), with a refactored `GameEngine` architecture, configurable benchmark tooling, and scriptable performance workflows.

![RTS gameplay showcase](assets/screenshots/benchmark-manual-session.png)

## Highlights

- Fullscreen RTS prototype built with Processing 4 CLI.
- `GameEngine` wrapper over `GameState` with fixed-step simulation.
- Data-driven runtime and gameplay knobs via JSON files in `RTS_p5/data`.
- Localization support (`zh/en/auto`) with persisted user settings.
- Configurable benchmark system:
  - single-run benchmark (`benchmark.ps1`)
  - matrix benchmark (`benchmark-matrix.ps1`)
  - grouped compare report (`benchmark-compare.ps1`)
  - markdown/HTML visualization (`benchmark-viz.ps1`, `tools/benchmark_dashboard.py`)
- Manual controllable benchmark mode:
  - `-ManualControl`
  - `-ManualEndKey`
  - `-ManualAutoFrontline`

## Repository Layout

- `RTS_p5/` - main Processing sketch folder
  - `RTS_p5.pde` - thin app entrypoint
  - `GameEngine.pde` - top-level app/game orchestrator
  - `GameState.pde` - gameplay state and subsystem coordination
  - subsystem files (`EnemyAiController.pde`, `CombatSystem.pde`, `ProductionSystem.pde`, `FogSystem.pde`, `UISystem.pde`, etc.)
  - `data/` - game configs, map files, runtime settings
  - `benchmarks/runtime_metrics.csv` - runtime benchmark metrics
- root scripts
  - `build.ps1` - build sketch through Processing CLI
  - `smoke.ps1` - lightweight build smoke check
  - `benchmark.ps1` - single benchmark run
  - `benchmark-matrix.ps1` - profile x intensity batch benchmark
  - `benchmark-compare.ps1` - latest-vs-previous grouped comparison
  - `benchmark-viz.ps1` - markdown visual report generation
- `tools/benchmark_dashboard.py` - interactive HTML dashboard generator
- `docs/benchmark_workflow.md` - benchmark usage guide

## Requirements

- Windows + PowerShell
- Processing 4 (default path used by scripts):
  - `D:\Program Files\Processing\Processing.exe`
- Python 3 (for HTML dashboard script)

## Build

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

Default output:

- `_cli_build_out`

## Run Benchmarks

### 1) Single benchmark run

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark.ps1 -DurationSec 120 -WarmupSec 10 -BattleIntensity heavy -TroopProfile balanced
```

### 2) Manual controllable benchmark session

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark.ps1 -RunTag manual-session -ManualControl -ManualEndKey F10 -ManualAutoFrontline -DurationSec 180 -WarmupSec 10 -BattleIntensity heavy -TroopProfile balanced
```

Notes:

- `-ManualControl`: user controls gameplay.
- `-ManualEndKey F10`: press F10 to finish and write metrics.
- `-ManualAutoFrontline`: keep AI mutual frontline push in manual mode.

### 3) Matrix benchmark (batch)

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark-matrix.ps1 -Profiles balanced,rush -Intensities medium,heavy -TroopProfile swarm
```

This runs combinations and (by default) auto-generates:

- matrix markdown summary
- visual markdown report
- HTML dashboard

### 4) Compare and visualize

```powershell
powershell -ExecutionPolicy Bypass -File .\benchmark-compare.ps1
powershell -ExecutionPolicy Bypass -File .\benchmark-viz.ps1
python .\tools\benchmark_dashboard.py
```

## Benchmark Data Notes

- Runtime CSV path: `RTS_p5/benchmarks/runtime_metrics.csv`
- Grouped comparison key:
  - `enemy_ai_profile | battle_intensity | reinforce_interval_sec | reinforce_count_per_faction | troop_profile`
- Legacy/mixed CSV compatibility is handled in compare script with fallbacks (`unknown/default`).

## Architecture Summary

- `RTS_p5.pde` delegates all app callbacks to `GameEngine`.
- `GameEngine` manages:
  - mode switching (`MENU` / `PLAYING`)
  - time stepping (`TimeSystem`)
  - benchmark runtime hook (`BenchmarkRuntime`)
  - localization/font bootstrap
- `GameState` owns world/session data and delegates domains to subsystem classes.

## Development Tips

- Keep generated benchmark artifacts in `benchmarks/` out of feature commits unless explicitly needed.
- For benchmark workflow details, read:
  - `docs/benchmark_workflow.md`

