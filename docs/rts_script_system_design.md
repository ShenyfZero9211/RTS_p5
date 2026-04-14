# RTS_p5 Script System Design (v1)

## Scope

This document describes the first implementation pass of scripting in `RTS_p5`:

- Trigger DSL (conditions + actions)
- AI DSL (state machine + command queue)
- Runtime scheduler and action bridge to existing game systems

The visual-layer script system (iscript-style animation scripting) is intentionally out of scope for v1.

## Runtime Wiring

- Runtime owner: `GameState.scriptRuntime`
- Tick point: `GameState.update(dt)` immediately after input update
- Legacy AI interaction: if AI script has `ownsEnemyAi=true`, built-in `EnemyAiController` update is skipped
- Profiling:
  - `GameState.profileScriptMs`
  - `GameState.scriptActionsLastTick`
  - `GameState.scriptBudgetOverrunCount`
  - Benchmark CSV adds `avg_script_ms`

## Data Layout

- Trigger scripts: `RTS_p5/data/scripts/triggers/<bundle>.json`
- AI scripts: `RTS_p5/data/scripts/ai/<bundle>.json`
- Map binding: add optional `scriptBundle` in map JSON root (e.g. `map_001.json`)

If `scriptBundle` is absent, script runtime stays disabled and gameplay behavior remains compatible with previous versions.

## Trigger DSL v1

### Rule Structure

Each trigger entry supports:

- `id`
- `preserve` (default `true`)
- `cooldownMs` (default `0`)
- `priority` (higher runs first)
- `conditions[]`
- `actions[]`

### Conditions (implemented)

- `timeElapsed`
- `resourceAtLeast`
- `resourceAtMost`
- `unitCountCmp`
- `buildingExists`
- `switchIs`

Unknown condition types evaluate to false (safe fail).

### Actions (implemented)

- `spawnUnit`
- `grantResource`
- `setSwitch`
- `showMessage`
- `issueAttackWave`
- `winOrLose`

Unknown action types do not crash runtime; they are logged to the script action ring buffer.

## AI DSL v1

### Top-level Structure

- `profile`
- `ownsEnemyAi`
- `threads[]`

Each thread has:

- `id`
- `owner` (`enemy` or `player`)
- `initialState`
- `states[]`

Each state supports:

- `id`
- `commands[]`
- `transitions[]`

### Commands (implemented)

- `train`
- `build`
- `attackPrepare`
- `attackDo`
- `retreat`
- `setRally`
- `wait`

### Execution Semantics

- One thread keeps:
  - current state
  - command index
  - local wait timer
- Transition checks run before command execution
- Commands execute under per-frame budget (`maxCommandsPerTick`)

## Error Model & Safety Limits

- Invalid script file or parse failure: runtime disabled for the session; game loop continues
- Unknown condition/action/command: log and continue
- Per-frame limits:
  - Trigger action budget (`maxActionsPerTick`)
  - AI command budget (`maxCommandsPerTick`)
  - Runtime budget monitor (`frameBudgetMs`) with overrun counter

## MVP Scenario (implemented)

Bundle: `default_battle`

- Trigger A: at 120s, launch an enemy attack wave
- Trigger B: one-time relief package when player credits are low
- AI: `eco -> prepare -> attack` state loop for enemy-side scripted behavior
- Debug visibility:
  - trigger hits / actions per tick
  - active AI state
  - recent action logs (latest 10 shown in side panel)

## Validation Checklist

- Build: `powershell -ExecutionPolicy Bypass -File .\\build.ps1`
- Expected:
  - build succeeds
  - `map_001.json` loads `scriptBundle: default_battle`
  - side panel debug area shows script counters and recent actions during play
  - benchmark CSV includes `avg_script_ms`
