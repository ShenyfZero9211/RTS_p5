# 星际争霸1（SC/BW）脚本系统调研

## 1. 结论速览

SC1 并不是“单一脚本语言”架构，而是多层并存：

- `地图触发器（TRIG/MBRF）`：UMS 地图逻辑主系统，条件-动作（if-then）模型。
- `AI Script（aiscript.bin / bwscript.bin）`：电脑玩家建造/进攻/防守行为脚本，常见“Run AI Script”触发动作会调用它。
- `iscript.bin`：单位/特效动画行为脚本（播放帧、等待、叠加图像、跳转等），偏“渲染/动作状态机”层。
- `EUD`：利用触发器数据路径实现的扩展能力（历史上与漏洞利用相关，后在 Remastered 用模拟器方式“安全回归”）。

如果从工程视角看，SC1 的“脚本系统”是 `玩法逻辑 + AI行为 + 动画微脚本 + 社区扩展` 的组合，而非一门统一语言。

---

## 2. 地图触发器系统（TRIG）

### 2.1 触发器模型

经典 StarEdit/SCMDraft 的触发器是固定格式：

- 条件（Conditions）满足 -> 执行动作（Actions）。
- 通过 `Preserve Trigger`（或对应标志位）决定是否保留重复执行。
- 执行目标绑定玩家（P1-P8、Force、All Players 等）。

在 CHK 格式层面，`TRIG` 分块记录触发器；每个触发器是固定 2400 字节结构，含：

- 16 条条件槽位
- 64 条动作槽位
- 执行标志与玩家执行掩码

这解释了为何早期编辑器里很多“空槽位”依然存在：底层本就是定长结构。

### 2.2 Mission Briefing（MBRF）

`MBRF` 结构与 TRIG 近似，但用于任务简报阶段。可以理解为同一触发框架的“简报模式分支”。

### 2.3 触发器循环与性能

社区实践里，触发器按循环轮询执行（常见提法是约每 2 秒轮次），这也是 Hyper Trigger 等技巧诞生的背景：通过特定 Wait 结构压缩逻辑响应延迟。

> 注意：这部分属于社区长期实践结论，具体时序会受版本、动作类型与编辑方式影响。

---

## 3. AI Script 系统（aiscript.bin / bwscript.bin）

### 3.1 定位

这套脚本不是地图触发器替代品，而是“电脑玩家行为内核”：

- 开矿/造农民/补给时机
- 科技和兵种生产策略
- 进攻组织（集结、攻击波次、骚扰）
- 防守和区域响应

地图触发器通常通过 “Run AI Script / Run AI Script At Location” 触发 AI 线程，形成“触发器驱动 AI 模块”的组合。

### 3.2 脚本内容特征

来自社区文档（ASC3 命令集）可见，指令大类包括：

- 城镇/基地初始化：`start_town`, `start_areatown`, `start_campaign`
- 训练与产能：`train`, `wait_force`, `defaultbuild_off`
- 进攻流程：`attack_add`, `attack_prepare`, `attack_do`, `attack_clear`, `target_expansion`
- 防守流程：`defensebuild_*`, `defenseuse_*`, `max_force`

这更像“策略行为 DSL（领域脚本）”，而不是通用编程语言。

### 3.3 aiscript 与 bwscript

社区资料普遍提到：

- `aiscript.bin` 为原始 AI 脚本容器。
- `bwscript.bin` 在 Brood War 时代加入，用于扩展与规避旧容量限制。

---

## 4. iscript.bin（动画/图像行为脚本）

### 4.1 系统角色

`iscript.bin` 控制的是“图像/动画行为”，不是宏观 AI：

- 某 image header 对应的动作入口（如 idle/walk/attack/death 等）
- 帧播放（`playfram`）
- 等待（`wait` / `waitrand`）
- 叠加图像（overlay/underlay）
- 跳转与结束

它可视为“单位表现层状态机脚本”。

### 4.2 数据关系

社区教程常把 iscript 与 `images.dat` 绑定讲解：image 记录索引到对应 iscript header。  
因此改单位表现通常不是只改一个文件，而是 `images.dat + iscript.bin (+ 资源)` 联动。

### 4.3 工具链

历史主流工具有 ICE / IceCC / PyMS 相关工具。  
共同痛点是：脚本偏移与引用关系复杂，手改二进制风险高，通常依赖工具做重定位与编译。

---

## 5. EUD（Extended Unit Death）机制

### 5.1 本质

EUD 最早来源于 Trigger/Deaths 路径可被非常规参数利用，从而访问更广泛内存区域。  
这使地图作者能做大量“原版触发器做不到”的功能，也带来安全问题。

### 5.2 历史演进

- 1.13f 起官方曾修补相关漏洞面。
- Remastered 1.21.0 公告中，Blizzard 明确说明通过 `EUD emulator` 回归部分 EUD 地图能力，同时限制高风险能力（如某些图形操控类行为）。

### 5.3 工程意义

EUD 体现了“社区需求 > 引擎原始能力”的长期拉扯：

- 一方面说明触发器可扩展性不足导致“旁路方案”兴起。
- 另一方面也说明脚本沙箱与兼容层（模拟器）在老游戏生态中非常关键。

---

## 6. SC1 脚本分层图（建议理解模型）

可把 SC1 逻辑分成 4 层：

1. **地图逻辑层**：TRIG/MBRF（胜负、事件、任务流程）
2. **AI 行为层**：aiscript/bwscript（电脑玩家策略）
3. **表现层**：iscript（动画、特效、武器视觉节奏）
4. **扩展层**：EUD 与社区工具生态（突破原生约束）

这套分层解释了为什么“改 AI”和“改动画”在工具、风险、验证方式上完全不同。

---

## 7. 对我们项目（RTS_p5）的可借鉴点

结合当前项目，建议参考 SC1 的经验做以下抽象：

- **把“玩法触发”与“AI策略”拆层**：避免一个脚本系统承担所有责任。
- **为 AI 提供领域命令集**：类似 `train/attack/defense` 的高层指令，比直接写底层状态机更稳。
- **渲染表现独立脚本化**：动画与战斗逻辑解耦，便于调特效不破坏玩法。
- **明确执行周期与预算**：SC1 社区大量问题都与“触发器轮询节奏”相关。
- **扩展能力必须安全边界清晰**：EUD 历史说明“可玩性扩展”和“安全性”必须同时设计。

---

## 8. 资料来源（按主题）

### 官方/准官方

- Blizzard（Remastered 1.21.0 EUD 回归公告）：  
  [Patch 1.21.0 – The Return of EUD Maps](https://news.blizzard.com/en-us/article/21313396/patch-1-21-0-the-return-of-eud-maps)

### 社区技术文档（核心）

- CHK 格式与 TRIG/MBRF 结构：  
  [StarCraft AI Wiki - CHK Format](https://www.starcraftai.com/wiki/CHK_Format)
- AI 命令参考（ASC3）：  
  [Pr0nogo - AI Command Guide](http://pr0nogo.wikidot.com/rs-ai)
- StarCraftAI Wiki 主页（汇总了 BWAPI、map editing、iscript 资料入口）：  
  [StarCraftAI Wiki Main Page](https://www.starcraftai.com/wiki/Main_Page)

### 安全与 EUD 技术背景

- EUD 漏洞分析与利用背景（含历史脉络）：  
  [Exploiting the Starcraft 1 EUD Bug](https://zeta-two.com/software/exploit/2020/04/05/exploiting-starcraft1.html)

> 说明：SC1 旧资料大量分散在论坛、镜像和社区 Wiki，存在“版本老、术语不统一、部分内容失效”的情况。上面选取的是目前仍可访问且信息密度较高的入口。

---

## 9. 后续建议（若要继续深入）

如果你希望下一步做“可落地到 RTS_p5 的脚本设计”，建议再做一轮专项：

1. 设计 `触发器 DSL`（事件、条件、动作）草案；
2. 设计 `AI 行为 DSL`（build/attack/defense）草案；
3. 确定两者调度关系（tick、优先级、中断）；
4. 做最小可运行样例（例如“开局 3 分钟攻击波 + 触发器胜利条件”）。

