# Rocket 弹道与烟雾说明

## 结论先说

当前弹道**不是**“用 vector 点去拼一个面(mesh)”的做法，  
而是：

- 用 `PVector` 记录导弹位置与速度（运动学）
- 用一组历史烟雾粒子（每个粒子也是一个位置点 + 生命周期）
- 渲染时把这些点画成 `ellipse`（圆点）并做透明度/尺寸衰减

也就是“**点精灵轨迹**”方案，不是多边形面片方案。

---

## 1) 关键数据结构

在 `GameState.pde` 的 `RocketProjectile` 中：

- `PVector pos`：导弹当前位置
- `PVector vel`：导弹当前速度向量
- `Unit target / Building buildingTarget`：目标引用
- `PVector fixedTargetPos`：目标死亡后的锁定坐标
- `ArrayList<RocketSmoke> smokeTrail`：烟雾粒子列表
- `boolean impactDone`：是否已命中

烟雾粒子 `RocketSmoke`：

- `PVector pos`：粒子位置
- `float ttl`：总寿命
- `float age`：当前年龄
- `float size`：初始尺寸

---

## 2) 导弹运动逻辑（跟踪）

每帧 `update(dt)`：

1. 先更新烟雾粒子年龄，超时删除
2. 若已命中（`impactDone`），仅等待烟雾自然消失
3. 计算目标点 `aim`（目标活着就跟随，死了用 `fixedTargetPos`）
4. 算期望速度 `desiredVel = normalize(aim-pos) * speed`
5. 用 `vel.lerp(desiredVel, steer)` 做转向平滑（导弹会弯而不是硬转）
6. 位置推进 `pos += vel * dt`
7. 生成一个烟雾粒子并压入 `smokeTrail`

---

## 3) 渲染逻辑

`render(camera)` 分两层：

1. **烟雾层**：遍历 `smokeTrail`，按 `life = 1 - age/ttl` 衰减  
   - 半径：`size * life`
   - 透明度：`alpha * life`
   - 使用 `ellipse` 画圆点
2. **弹头层**：若未命中，画一个亮点火花（一个点）

命中后只剩烟雾层继续淡出，不会立即全部消失。

---

## 4) 你问的“vector定义点绘制面”对比

- 现在：`PVector` 仅作为**点位置/速度**数据，最终是多个圆点叠加
- 不是：通过 `beginShape()/vertex()` 去拉带状面、三角面

如果以后要做“真正面片尾迹”，可改成：

- 保存一条中心线采样点
- 计算法线偏移生成左右边
- 用三角带连接（`TRIANGLE_STRIP`）

---

## 5) 可调参数建议

可直接调这些值改变观感：

- `maxTrail`：尾迹长度
- `RocketSmoke.ttl` 随机范围：烟雾停留时长
- `RocketSmoke.size` 随机范围：烟雾颗粒大小
- `steer`：导弹转向灵敏度（越大越“黏目标”）
- 烟雾 alpha、弹头点大小：整体视觉强度

---

## 6) 适用场景

这套方案适合：

- RTS 大量弹体并发（性能更稳）
- 需要“跟踪 + 拖尾 + 命中后余烟”效果
- 代码维护成本低，参数化方便

