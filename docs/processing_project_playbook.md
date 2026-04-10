# Processing 工程通用开发手记（脚本 + 文档 + AI 协作）

本文从 **Processing 4** 桌面/Java 模式工程的一般规律出发，总结可复用的做法；其中 **PowerShell（`.ps1`）** 与 **Markdown（`.md`）** 的用法以本仓库实践为参照，也可迁移到其它操作系统（把 CLI 参数交给 `bash`/`make` 即可）。

更贴近本仓库目录与脚名的说明见：`docs/processing_ai_handoff.md`。

---

## 1. 工程与草图约定（通用）

- **一个草图 = 一个文件夹**，文件夹名与主 `.pde` 同名；同目录下多个 `.pde` 会合并进同一草图。
- **资源路径**：`data/` 相对**该草图目录**解析；多草图项目里要分清「改的是哪个草图的 `data/`」。
- **入口保持薄**：主 `.pde` 只负责 `setup` / `draw` / 输入回调，复杂逻辑拆到同目录其它 `.pde`（Processing 会一并编译）。
- **版本写进 README**：标明 Processing 3 还是 4、是否用 Java 模式、第三方库是否通过「导入库」管理。

---

## 2. 为什么用命令行 + 脚本固化流程

IDE 点运行对人不坏，但对 **CI、同事、AI 助手** 不可见：安装路径、是否点过 Run、输出目录都不一致。

把「怎么编译、怎么跑、怎么算通过」写进脚本后，得到三条好处：

1. **可重复**：任何人同一命令得到同一结果。  
2. **可检查退出码**：失败时构建/流水线能红。  
3. **可写进文档**：README 一行命令 + `docs/*.md` 里引用同一命令，减少口径漂移。

Processing 4 提供 CLI，典型形式为对 `Processing.exe` 传 `cli` 与子参数（与具体安装路径无关，脚本里用参数暴露即可）。

---

## 3. PowerShell（`.ps1`）推荐模式（通用模板思路）

以下模式与本仓库 `build.ps1`、`map-editor.ps1`、`smoke.ps1` 一致，可照抄结构换路径与参数名。

### 3.1 参数与前置检查

- 用 `param(...)` 暴露：`ProcessingExe`、`SketchDir`、（可选）`OutputDir`、`ProjectRoot`。  
- `$ErrorActionPreference = "Stop"`，对 `Processing.exe` 与草图目录做 `Test-Path`，缺失则 `throw`。  
- **避免把个人绝对路径提交为唯一来源**：默认值可以是你团队常用路径，但要在 README 说明如何用参数覆盖。

### 3.2 编译（export / build）

- 传 `cli`、`--sketch=<文件夹>`、`--output=<输出目录>`、`--force`、`--build`。  
- 用 `Start-Process -FilePath ... -ArgumentList ... -Wait -NoNewWindow -PassThru` 取进程，**检查 `ExitCode`**，非零则 `throw`。

### 3.3 运行（图形窗口）

- `cli`、`--sketch=...`、`--run`。  
- 适合工具类草图（地图编辑器、关卡预览器等）；自动化验收可再配合截图或人工检查清单。

### 3.4 调用方式（避免执行策略绊脚）

在 README 中统一写：

```powershell
powershell -ExecutionPolicy Bypass -File .\your-script.ps1
```

### 3.5 组合脚本（smoke / 门禁）

- **smoke**：调用 `build.ps1`，再断言输出目录存在、且存在 `.jar` / `.exe` 等预期产物（本仓库 `smoke.ps1` 即此思路）。  
- 合并前只要求通过 smoke，比「打开 IDE 看一眼」更适合协作与 AI 闭环。

### 3.6 非 Windows 环境

同一套语义在 macOS/Linux 上改为：`processing-java` 或官方文档中的 CLI 等价命令；**保持参数名（sketch/output/force/build）在文档里中英文对照**，便于迁移。

---

## 4. Markdown（`.md`）写什么、给谁看

### 4.1 仓库根 `README.md`（给人 + 给 AI）

建议固定包含：

- 环境：Processing 版本、可选 JDK、可选 Python 等。  
- **一键命令**：至少「如何 build」「如何 run 主草图」「如何 run 附属草图」。  
- 目录树一级说明：主草图路径、`data/`、脚本、文档。  
- 已知限制：例如「基准生成物不默认提交」。

### 4.2 `docs/` 下的专题文档

- **工作流**：如性能采集、资源导入流水线（本仓库 `benchmark_workflow.md`）。  
- **Handoff / 重构交接**：`docs/<topic>_handoff.md`，写「改了什么、谁依赖谁、如何验收」。  
- **Playbook / 手记**（本文档一类）：原则与模板，不随单次需求过期。

### 4.3 Handoff 文档最短清单（可复制到每次大改）

- 涉及的草图目录名。  
- 依赖的 `data/` 或外部文件路径。  
- **一条**验收命令（脚本 + 参数）。  
- 期望现象（窗口标题、关键 UI、某配置项）。  
- 已知坑（坐标系、输入焦点、仅 Windows 脚本等）。

### 4.4 与 AI 编码工具配合

- 新会话用 `@README.md`、`@docs/xxx.md`、`@build.ps1` 等把**入口钉死**。  
- 规则文件（如 `.cursor/rules` 或 `AGENTS.md`）只写**长期不变**的三五句：Processing 版本、主草图路径、默认验收命令。  
- 具体任务仍用手写 `docs/*_handoff.md`，避免规则文件臃肿。

---

## 5. 本类工程里的高频技术坑（通用）

- **视口与坐标**：屏幕空间与世界空间、是否先 `translate` 再 `scale`、`camera` 表示的是「左上角」还是「中心」，要在草图内**统一**；混用会导致「只在某一角显示、平移像失灵、与游戏不一致」等问题（本仓库地图编辑器曾因此调整过变换链与 clamp）。  
- **按键检测**：Processing 中空格等字符键优先用 `key == ' '`，勿只依赖 `keyCode`。  
- **多草图**：公共代码若复制两份会分叉；长期应抽库或文档明确「以哪份为准」。  
- **生成物**：导出目录、基准日志、大屏截图等应在 `.gitignore` 或文档中说明是否入库。

---

## 6. 最小「新项目」检查表

| 项 | 说明 |
|----|------|
| 草图目录与主 `.pde` 同名 | 满足 Processing 约定 |
| 根目录 `build.ps1`（或等价） | `--sketch` 指向文件夹，`--build` 可 CI |
| 可选 `run.ps1` / `run-editor.ps1` | `--run` 启动工具型草图 |
| 可选 `smoke.ps1` | build + 产物断言 |
| `README.md` | 环境 + 命令 + 目录说明 |
| `docs/` | 工作流或 handoff，随项目变大再补 |

---

## 7. 与本仓库的对应关系（便于跳转）

| 通用概念 | 本仓库示例 |
|----------|------------|
| 主草图 build | `build.ps1` → `_cli_build_out` |
| 运行辅助草图 | `map-editor.ps1` |
| 编译门禁 | `smoke.ps1` |
| 仓库专用 AI 手记 | `docs/processing_ai_handoff.md` |
| 基准工作流文档 | `docs/benchmark_workflow.md` |

将「原则」记在本文，将「本仓库路径与脚本名」记在 `processing_ai_handoff.md`，可避免单份文档既冗长又难以复用到其它 Processing 项目。
