# M-ART-01～03 接入契约

> 状态更新：用户随后已授权本代理正式代码接入与完整测试。历史素材契约保留，实际接入和最新测试结果见 [integration_2026-10-20/README.md](integration_2026-10-20/README.md)。

日期：2026-10-20。本包只交付新增素材。正式项目的 scripts/、scenes/、project.godot 未由本任务修改。下述切换交给 Claude，不能把独立预览副本里的辅助脚本直接当作正式功能。

## M01 地面

正式目录：`assets/sprites/ground/vigrid/`。全部 RGBA、64×64、Nearest、不生成 mipmap、1×。旧 K 地块保持原名原内容。

| 用途 | 新文件 | 接入位置 |
|---|---|---|
| 道路 | `ash_road.png` | `VigridMap.ROUTE` 改为 `ash_road` |
| 直边 | `ash_road_edge_{n,s,e,w}.png` | 道路边缘前缀登记为 `ash_road_edge` |
| 内角 | `ash_road_edge_inner_{ne,nw,se,sw}.png` | 拼法与 helheim/bone_path_edge 一致 |
| 外角 | `ash_road_edge_outer_{ne,nw,se,sw}.png` | 拼法与 helheim/bone_path_edge 一致 |
| 焦草 | `burnt_grass_02.png` | `_layout()` 的焦草地块 ID 和 `edge_masks` 的 key 同步改为新 ID；过渡轮廓仍可复用原 path_edge |
| 裂地 | `cracked_lava_02.png` | 穆斯贝尔前线装饰地块改读新 ID，继续不造成伤害 |

独立副本采用 `edges["ash_road"] = "ash_road_edge"`，不改路线坐标、宽度、碰撞、相机或危险区。道路边缘保留原 helheim 遮罩拓扑，沿轮廓按新道路已有碎石纹理减去 1～3 像素，形成碎边；不是另外生成一套角落规则。

## M02 苏尔特横扫

`assets/sprites/effects/bosses/surtr_sword_arc_large.png`：2560×640，横排 4 帧，每帧 640×640，16 fps，一次播放，中心锚点 (320,320)，原生比例 (1,1)。朝向 +x；旋转沿 `_sweep_dir.angle()`。半径 290，半角 1.05。末帧最高 alpha 72/255。

1. `BossFx.FAST` 登记 `surtr_sword_arc_large`，帧数保持 4。
2. `Surtr._sweep()` 改播新 ID；缩放改为 `Vector2.ONE`，继续传实际伤害扇形的半径和半角。
3. 保留现有 geometry clip。素材本身也已限制在 R290 / ±1.05 内。
4. 不复用旧的 `SWEEP_RADIUS / ARC_RADIUS` 浮点放大。以后数值改变，应重新确认整数比例与伤害几何的关系。

拟接入调用（仅说明，不是本次正式代码修改）：

```gdscript
BossFx.play("surtr_sword_arc_large", global_position, _sweep_dir.angle(), Vector2.ONE,
    Color.WHITE, false, VigridTuning.SWEEP_RADIUS, VigridTuning.SWEEP_HALF)
```

## M03 普通周期援助

正式目录：`assets/sprites/effects/gods/`。四张均为 2560×320 横排 8 帧，单帧 320×320，12 fps，单次播放 8/12 秒，锚点 (160,160)，比例 (1,1)，白色 tint。第 8 帧完全透明，不能循环。

| ID | 新文件 | 位置 | 半径 | 视觉识别 |
|---|---|---|---:|---|
| freyja / feathers | `aid_freyja.png` | 请求时玩家位置 | 140 | 黄金额羽落下，羽毛花环展开 |
| baldr / light | `aid_baldr.png` | 该次实际选中的密集敌人点 | 110 | 象牙白光柱落地，八芒日轮展开 |
| ran / net | `aid_ran.png` | 该次实际选中的密集敌人点 | 130 | 蓝色结绳渔网落下，菱形网眼展开 |
| skadi / frost | `aid_skadi.png` | 该次实际选中的密集敌人点 | 130 | 冰箭下落，雪晶与箭尖组成碎冰环 |

帧序：1～2 下落；3 小范围落点；4 展开；5 完整范围；6 破碎；7 消散；8 空帧。第 5 帧外沿受控在规定半径附近，所有援助像素 alpha 不超过 216/255；落地阶段中心额外限到 112/255，避免盖住敌人和预警。

接入建议：

- 在 `VigridBattle.request_aid()` 相应四个分支记录该次位置并请求新特效。弗蕾亚用玩家位置，另三位使用本次计算的 `at`，不能等下一帧重新找密集点。
- 新增轻量的 8 帧援助播放路径，或扩展现有 FX 层的独立表项。**不要直接使用 BossFx 当前默认的 4 帧规则**；这些文件在 gods/，也不在 BossFx 的 bosses/ 目录。
- `Texture2D` 必须由成员或资源缓存持有；不要只在 `_draw()` 中临时 load 后立即失去引用。独立预览已复现过这种写法导致白色方块，修正后重新截图。
- 帧号 `mini(7, int(age * 12.0))`；`age >= 8.0 / 12.0` 后移除。复用 `SpriteVisual.draw_frame(canvas, cached_texture, 8, frame, at, Vector2(160,160))`。
- 新特效承担四位神的主要视觉识别；原有通用 ring/burst 如保留，应明显降弱，避免压住新图或让四位又变成同一光圈。
- 托尔、奥丁、洛基、弗雷的普通援助不在本包改动范围。伤害、减速、治疗等既有数值本包没有修改。正式接入时检查动画落地与原效果触发的同步，不把前两帧误当作新增伤害预警。

## 已做的运行检查与边界

- 在 assets/source/ 内复制当前 Game、地图、Boss、敌人和已有资源，使用独立存档和设置，开实际 Godot 窗口渲染。
- 地面：两种分辨率各 9 张，共 18 张；含出生点、四角、北侧远景、焦草、裂地及十只敌人 + 苏尔特预警 + 火焰地面。
- 特效：1280×720，剑弧四帧及 R290 扇形对照 5 张；四种援助各八帧及范围对照 36 张，共 41 张。
- 剑弧通过现有 BossFx 原生绘制；援助使用独立预览用的 8 帧绘制器叠在实际 Game 里。玩家无敌、刷怪关闭、十只敌人和 Boss 状态冻结；不是自然触发或完整战斗验收。
- 正式代码尚未切换。接入后仍需 K-QA：自然援助触发与位置、实际伤害范围和时序、怪群叠加、结束移除、镜头运动、低分辨率与性能回归。

重现材料：`preview_project/m_art_overlay.gd`、`preview_project/review_m_fx.gd`、`records/review_m_terrain.gd.txt`、`prepare_fx_review.py`、运行日志和 `records/runtime_baseline.json`。临时 runtime/ 由 .gitignore 排除，source 根由 .gdignore 排除正式游戏导入；请勿把预览场景接进正式游戏。
