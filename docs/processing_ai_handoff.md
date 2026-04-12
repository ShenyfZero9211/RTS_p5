# Processing + AI 辅助开发手记

本文总结在本仓库中用 **Processing 4** 开发、并用 **PowerShell 脚本** 与 **简短文档** 配合 AI 编码工具（如 Cursor）时的推荐做法，便于新会话或新同事快速对齐。

## 目标

- 用可重复的命令代替「本机点一下运行」，让 **人类和 AI 都能用同一套步骤** 编译、运行、做最小验收。
- 用一份 **handoff 式 Markdown** 压缩上下文：目录结构、脚本入口、验收方式、常见坑。

## 仓库里的 Processing 草图

| 草图目录 | 用途 | 主入口 |
|----------|------|--------|
| `RTS_p5/` | 主游戏原型 | `RTS_p5.pde` |
| `map_editor/` | RTS 地图编辑器 | `map_editor.pde` |

**地图编辑器 UI（鼠标优先）**：顶部菜单栏（Save / Load / New / Export / 切换地图文件）；左侧工具条（点选工具、**笔刷占地网格示意**、`+/-` 调笔刷、建筑/单位放置时的 **Player/Enemy**）；中间地图视口，**右上角小地图**（与游戏内缩略图风格一致，左键点击跳转视野）；右侧建筑/单位列表。按钮与列表行带**悬停高亮**，滚轮在列表上滚动、在地图上缩放。快捷键（Ctrl+S 等与菜单并列）仍可用。

Processing 要求：**草图文件夹名与主 `.pde` 文件名一致**；同目录下多个 `.pde` 属于同一草图。

游戏数据与配置主要在 `RTS_p5/data/`（JSON 等），运行时与基准相关说明见根目录 `README.md` 与 `docs/benchmark_workflow.md`。

## 根目录脚本（可执行契约）

脚本默认假设 Processing 安装在：

`D:\Program Files\Processing\Processing.exe`

若路径不同，调用时用 `-ProcessingExe` 覆盖即可。

| 脚本 | 作用 | Processing CLI 要点 |
|------|------|---------------------|
| `build.ps1` | 将主草图编译导出到 `_cli_build_out` | `--sketch=...` `--output=...` `--force` `--build` |
| `smoke.ps1` | 调用 `build.ps1` 并检查输出目录是否存在可运行产物 | 轻量 CI / 改代码后快速验收 |
| `map-editor.ps1` | 运行地图编辑器草图 | `--sketch=...\map_editor` `--run` |
| `run-game.ps1` | 启动主游戏并指定地图；可选直进对局 | **`RTS_MAP_FILE`**（绝对路径）、**`RTS_DIRECT_ENTER`**（`1`/`0`，默认直进）；仍附带 `--map=` / `--DirectEnter=`（宿主若转发 `args` 则草图内也生效） |
| `rts.ps1` | 同上，**位置参数地图** + 可选 **`-DirectEnter`** | 内部调用 `run-game.ps1` |
| `benchmark.ps1` 等 | 性能基准与报告流水线 | 见 `README.md`、`docs/benchmark_workflow.md` |

### 常用命令（在仓库根目录）

主游戏编译：

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

编译后最小检查：

```powershell
powershell -ExecutionPolicy Bypass -File .\smoke.ps1
```

指定地图启动主游戏（`RTS_p5/data` 下的文件名，或绝对路径；可选先编译）。默认 **`RTS_DIRECT_ENTER=1`**：跳过主菜单直进对局；**`-DirectEnter:$false`** 时只应用地图，仍显示主菜单。

```powershell
powershell -ExecutionPolicy Bypass -File .\run-game.ps1 -MapFile map_001.json
powershell -ExecutionPolicy Bypass -File .\run-game.ps1 -MapFile map_001.json -DirectEnter:$false
powershell -ExecutionPolicy Bypass -File .\run-game.ps1 -MapFile map_stress_template.json -Build
```

仅用手动 `cli --run` 时，请设置环境变量（**`RTS_MAP_FILE` 必填**才会换图；**`RTS_DIRECT_ENTER`** 缺省等同 `1`）。一行示例：

```powershell
$env:RTS_MAP_FILE = "D:\projects\cursor\RTS_p5\RTS_p5\data\map_001.json"; $env:RTS_DIRECT_ENTER = "1"; & "D:\Program Files\Processing\Processing.exe" cli "--sketch=D:\projects\cursor\RTS_p5\RTS_p5" "--run" "--map=map_001.json" "--DirectEnter=true"
```

若将来 Processing 将尾随参数传入草图 `args`，`GameState` 会解析 **`--map=`** 与 **`--DirectEnter=true|false`**；当前仍以 **env 为准**。

更短：仓库根目录的 **`rts.ps1`**（第一个参数为地图，`data/` 下文件名或绝对路径均可）：

```powershell
powershell -ExecutionPolicy Bypass -File D:\projects\cursor\RTS_p5\rts.ps1 map_001.json
powershell -ExecutionPolicy Bypass -File D:\projects\cursor\RTS_p5\rts.ps1 map_001.json -DirectEnter:$false
```

地图编辑器（需图形界面）：

```powershell
powershell -ExecutionPolicy Bypass -File .\map-editor.ps1
```

自定义 Processing 路径示例：

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1 -ProcessingExe "C:\Path\To\Processing.exe"
powershell -ExecutionPolicy Bypass -File .\map-editor.ps1 -ProcessingExe "C:\Path\To\Processing.exe" -SketchDir "D:\projects\cursor\RTS_p5\map_editor"
```

## 给 AI 会话用的使用方式

1. **在对话里引用文件**：例如 `@build.ps1`、`@README.md`、相关 `.pde` 与 `data/` 下的 JSON，减少路径与入口的猜测。
2. **改完逻辑后优先跑脚本**：游戏核心改动可跑 `smoke.ps1`；地图编辑器改动跑 `map-editor.ps1` 做手动验证（工具栏/调色板点击与地图涂抹）。
3. **大功能或跨文件重构**：在对话或单独 handoff 中写清「验收命令」和「预期现象」（窗口标题、某张地图、某配置项）。

## 建议在其它 handoff 文档里重复的最短信息

若你为某次重构另写 `docs/xxx_handoff.md`，建议至少包含：

-  touched 的草图是 `RTS_p5` 还是 `map_editor`（或两者）。
- 验收用的一条 PowerShell 命令（上表之一）。
- 若依赖特定 `data/` 文件，写出相对路径。

## 常见坑

- **草图路径错误**：CLI 的 `--sketch=` 必须指向**文件夹**，且该文件夹名与主 `.pde` 同名。
- **资源路径**：`data/` 下资源相对草图目录解析；多草图时注意改的是哪一个草图下的 `data/`。
- **仅 Windows 脚本**：当前 `.ps1` 面向 PowerShell；其它系统需自行对照 CLI 参数等价调用。
- **基准产物**：仓库根目录 `benchmarks/` 已在 `.gitignore` 中，不会进入版本库；跑分后仅保留在本地。

## 与 Cursor / 规则文件的衔接（可选）

可在 `.cursor/rules` 或 `AGENTS.md` 中用几句话固定：

- 使用 Processing 4 CLI。
- 默认脚本与路径；主游戏与 `map_editor` 为两个独立草图。
- 合并前建议至少通过 `smoke.ps1`（或你团队约定的脚本）。

这样新会话无需重复交代环境。

## 相关文档

- `docs/processing_project_playbook.md`：通用 Processing 工程手记（`.ps1` / `.md` / AI 协作模板），可与本文搭配使用。
- `README.md`：总览、架构摘要、基准命令。
- `docs/benchmark_workflow.md`：基准流水线细节。
- `docs/gamestate_refactor_handoff.md`：示例 handoff 写法（可按同样风格为 Processing 功能追加短文）。
