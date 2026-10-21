# 第三关代码交接：Claude

交接日期：2026-10-20。项目：`~/Desktop/无限恐怖`，Godot 4／GDScript，游戏名「无限轮回」。目标：复用已交付K素材，实现可运行的第三关「最后之战」，从选关、战斗、命运事件走到篇章结算。此文件是代码任务；历史素材制作阶段的“只改assets”限制不适用于本次实现。

## 1. 当前基线与权限

- 第1/2关已有实现；`scripts/data/level_db.gd`的ORDER有vigrid，但ALL只有midgard/helheim。BossDB没有第三关三Boss，`scripts/world/vigrid_map.gd`尚不存在。开始前重新核对，其他代理可能已更新代码。
- K0布局与K1～K7素材/数据已交付。42PNG／156帧、1OGG+4WAV；文件/独立渲染检查不是第三关游戏验收。K6四声及音乐三遍已由用户确认，不需再生成。
- 可修改完成第三关所必需的`scripts/`、`scenes/`、`tools/`、`locale/`及对应docs；仅在必要且有证据时改项目配置/导入描述。保持前两关、四角色、成长规则兼容。
- 复用正式素材；不重新生成、重命名或覆盖已接受PNG/WAV/OGG，不改归档原图/退稿/来源记录。不新增支线、人物插画或其他篇章。
- 保留他人改动，实施前检查Git；不使用正式个人存档测试。实现和验证记录写新目录，例如`assets/source/taskK_code_integration_YYYY-MM-DD/`。本交接不自动授权新的commit/push。

## 2. 必读资料与冲突优先级

1. [世界观：第3关](世界观设定.md)；[局内成长与关卡节奏](局内成长与关卡节奏.md)、[信仰系统](信仰系统设计.md)。
2. [K总接入](../assets/source/taskK_contract_2026-10-20/integration.md)、[K最终交付清单](../assets/source/taskK_contract_2026-10-20/manifest.json)。
3. [基础契约C1～C8](../assets/source/taskK_contract_2026-10-20/contract.json)以及以下**覆盖原值的增量**：
   - [K2 v1.1](../assets/source/taskK_contract_2026-10-20/K2_maw_bind_addendum_v1.1.json)：独立上下颚、束缚条带；废弃合并巨口/全身束缚图方案。
   - [K3 v1.2](../assets/source/taskK_contract_2026-10-20/K3_action_canvas_addendum_v1.2.json)：六个苏尔特动作320×320，覆盖基础契约旧256值。
   - [K5 v1.3](../assets/source/taskK_contract_2026-10-20/K5_reuse_addendum_v1.3.json)：复用12遮罩/现有角色，只新交付脚印与远景2PNG。
4. [K0布局](../assets/source/taskK0_vigrid_plan_2026-10-20/layout.json)、[K0布局说明](../assets/source/taskK0_vigrid_plan_2026-10-20/layout.md)、[v1.3生产计划](../assets/source/taskK_contract_2026-10-20/production_plan_v1.3.json)。
5. 各批最终`manifest.json`与`integration.md`：

| 批次 | 最终接口 | 接入说明 |
| --- | --- | --- |
| K1 | [巨蛇清单](../assets/source/taskK1_serpent_2026-10-20/manifest.json) | [K1](../assets/source/taskK1_serpent_2026-10-20/integration.md) |
| K2 | [巨狼清单](../assets/source/taskK2_wolf_2026-10-20/manifest.json) | [K2](../assets/source/taskK2_wolf_2026-10-20/integration.md) |
| K3 | [苏尔特清单](../assets/source/taskK3_fire_2026-10-20/manifest.json) | [K3](../assets/source/taskK3_fire_2026-10-20/integration.md) |
| K4 | [普通敌人清单](../assets/source/taskK4_enemies_2026-10-20/manifest.json) | [K4](../assets/source/taskK4_enemies_2026-10-20/integration.md) |
| K5 | [地图新增清单](../assets/source/taskK5_map_2026-10-20/manifest.json) | [K5](../assets/source/taskK5_map_2026-10-20/integration.md) |
| K6 | [音频清单](../assets/source/taskK6_audio_2026-10-20/manifest.json) | [K6](../assets/source/taskK6_audio_2026-10-20/integration.md) |
| K7 | [结局时间线](../assets/source/taskK7_fate_ending_2026-10-20/ending_timeline.json)、[命运契约](../assets/source/taskK7_fate_ending_2026-10-20/fate_contract.json) | [K7](../assets/source/taskK7_fate_ending_2026-10-20/integration.md) |

接口冲突时，最终批次manifest与对应增量优先于基础契约和K0旧拟议矩阵；世界观决定剧情/条件。基础契约的`scope_exclusions`记录旧制作阶段权限，不限制本次代码实现。预览里的R1024/R640/R240/R150是演示几何，不是新增碰撞常量。

## 3. 实施顺序与代码接入点

| 顺序 | 工作 | 现有接口／建议落点 | 该步完成条件 |
| --- | --- | --- | --- |
| 1 | 地图与可启动关卡骨架 | `scripts/data/level_db.gd`注册NORSE_3/ALL；新增`world/vigrid_map.gd`继承MapLayer；沿用Game、主神空间和Save选关解锁 | 第二关通关后第三关可选；进入后场地/出生/相机正确；不留最终版占位Boss |
| 2 | 四类普通敌人 | `data/enemy_db.gd`、`entities/enemy.gd`的新ID分支或专用子类；亡者复用dead | 火巨人爆炸/残火一次；精锐冲锋/正面举盾；狼皮人类低血狂暴；普通怪上限350 |
| 3 | 三Boss及专属表现 | `data/boss_db.gd`、新增`bosses/jormungandr.gd`、`fenrir.gd`、`surtr.gd`；复用Boss/Enemy信号及集中效果，必要时增加有界K专用绘制器 | 所有技能/阶段/预警/伤害/召唤/清理能实际运行，动作映射显式对应 |
| 4 | 援助、拾取与事件 | 新K专用控制器/节点，接`game.gd`；复用神术效果/声音和普通拾取模式 | 一般周期援助、碎片绑定、三命运援助实际触发且去重 |
| 5 | 音频及结局存档 | `core/audio.gd`现有按名加载；`game.gd::_on_level_cleared/_finish_run`、`ui/hud.gd::show_result/_numbers_column`、`core/save_data.gd::record_run/load_game`及翻译表 | 五段字幕可跳过、统计正确、奖励一次、旧存档兼容、返回/重开可靠 |
| 6 | 自测与交回Codex | 新K测试/真实截图/日志/范围报告；保留前两关回归 | 满足下述检查，逐项标明已测/未测；不要仅交计划或仅注册空关卡 |

已有工具/模块路径：`scripts/entities/sprite_visual.gd`、`scripts/world/map_layer.gd`、`scripts/bosses/boss.gd`、`scripts/effects/boss_fx.gd`、`combat_fx.gd`、`fx_layer.gd`、`scripts/core/audio.gd`、`scripts/core/save_data.gd`。不要误找`core/sprite_visual.gd`或`core/save.gd`。

## 4. 地图、动画与几何硬约束

- 地图5120×5120，中心出生(0,0)，边界带256，可走Rect2(-2304,-2304,4608,4608)。出生清空R384，中央R1280不放固定障碍，道路256宽；地标精确位置/半径按layout.json。Boss沿用靠近玩家的生成政策，不强制玩家跑到地标或瞬移玩家。
- 地面64格；复用6张vigrid地块、5张物件。12个midgard/path_edge遮罩必须在调用MapLayer._make_edges前显式跨目录加载；单改ground_dir无效。不复制12套正式地块，也不改前两关遮罩。
- 北侧远景Rect2(-768,-2480,1536,128)，三段512×128条带；4帧/8fps，内部0.5倍角色已烘焙，不二次缩放。无碰撞/伤害/锁定/敌人索引，独立裁切绘制。
- 像素最近邻。实体root到脚为(0,20)；按manifest脚锚定位，不按透明画布中心猜脚底。身体维持1倍，不能把320透明画布当作放大320像素人物。
- SpriteVisual默认只自动切方帧。上下颚256×128、16×8绳带、512×128远景及矩形复用特效必须用显式Atlas区域或专用绘制；不能直接套方帧解析器。
- 新动作一般待机/行走8fps循环，攻击16fps单次，特殊帧数/速度见附表；Boss._ready会把动作统一设8fps，需只对K演员修正。新增plant/swallow/heal等须显式注册映射。非循环播完可保持末帧；GIF审核末帧停留不是玩法延时。
- 预警、渲染和判伤消费同一权威路径/扇形/多边形/格集合；伤害由玩法事件控制，不从PNG alpha或animation_finished推断。边界火条上半部朝外，内侧透明；旧绿火HSV色相置0.04并保留S/V/A，实例处理，不覆盖旧图。

## 5. 战斗与命运行为

**总流程**：未暂停实际关卡时间180/360/540秒依次生成三Boss；前Boss存活时后Boss等待。三个实际击败才通关，超过10分钟不直接失败。普通怪/召唤统一走现有数量上限与ENDING生成保护，不修改前两关节奏。

**耶梦加得**：仅头是一个可攻击Enemy/空间索引条目；身体/尾巴不进Enemy组或敌人碰撞层2，使用共享路径独立接触/击退及命中冷却。弧长连续UV，头颈socket(0,62)，身体两端(0,30)/(64,30)，转角不裂。闭合路径从玩家附近2048方区与bounds inset96求交，圆角至少128，按契约收紧；毒息/毒池使用K1复用表。托尔条件为巨蛇死亡时有thor信仰，且**该次巨蛇遭遇未暂停年龄<=90.0秒**，90.001不通过；不是关卡总elapsed。成功设置thor_saved，最终苏尔特战实际提供雷击援助。

**芬里尔**：身体192方帧；巨口上下模块分别256×128，锚点(32,128)/(32,0)，共享hinge与轴线。活动玩家仍在吸引/逃脱阶段时可见通道至少64；attract/fatal形状共享预警定义，先有清楚逃脱窗口再提交吞噬。即死伤害通过现有玩家伤害/复活/死亡结算入口，明确无敌交互，不直接删除玩家或绕过复活。狂奔有路线预警与接触冷却；格莱普尼尔24方碎片一次性拾取，启动有时限束缚/增伤，16×8绳带沿路径绕身，保护区不遮。维达条件**odin信仰且奥丁觉醒**，实际介入后记vidar_intervened；撕颚接触使用96方人物实际手/靴socket，角色不拉伸。接触合拢演出放在玩家已逃脱/控制隔离、判伤关闭的时段。

**苏尔特**：六身体动作320方帧，脚锚(160,318)，原静态仍192。横扫/火门/插剑的释放点在0基帧1；预警时长由控制器持有，不能缩成瞬发。60%和25%阈值各触发一次；25%阶段包含此前机制或按明确状态机衔接，不能反复重置。火墙内侧安全与判伤一致。终焉格为64、origin(0,0)，格地址使用floor，特别覆盖负坐标：-1→-1、-64→-1、-65→-2；同一unsafe_cell_set同时驱动预警、符文、火焰和伤害，保留可达的安全格。弗雷条件**freyja信仰且弗蕾亚觉醒**，不是freyr信仰；实际援助后记freyr_assisted，治疗只在真实授予事件闪光。

**一般神援助**：它与上述三命运是两套条件。按当前信仰与附近交战判断周期触发，复用已有八神效果，不新增八个人物；god_id/world_position/source_encounter/aid_kind/event_id字段见C6。援助演员/远景不进入敌人索引，装饰不自动带伤害。

**本局状态**：thor_saved、vidar_intervened、freyr_assisted从false单调变true，每种至多1；仅请求未实际发生不记。ever_faith_loki在实际获得信仰时记true，换信仰仍保留，菜单预览不记，新run/重开清空，不能继承上一局。命运数只加前三个布尔(0～3)。

## 6. 音频、结局与待定参数

- 关卡音乐`vigrid`，Boss音乐复用`boss`，胜败复用`victory/defeat`；新SFX为`jormungandr_hiss`、`fenrir_swallow`、`gleipnir_tension`、`surtr_gate`。严格按[25事件清单](../assets/source/taskK6_audio_2026-10-20/audio_events.json)接入：4新、20复用、1可选常驻环境声省略。每cast/phase的event_id只放一次，不逐火格/绳节/动画帧放声；保留24声音/同名4条/0.05秒限流。
- 胜利冻结战斗与统计，再进入五段原文字幕：灰烬与海→新大地→巴德尔归来→两人类走出→篇章完成。UI暂停时继续处理，手动继续、任意段跳过到同一结算，不重复发奖/保存/胜利音乐。保留显式返回按钮，不在阅读中强制切场景。
- 结果显示elapsed/kills/三命运；洛基伏笔按本局曾信仰显示原文。在_finish_run返回、Hud和Save层显式接入字段；旧存档缺字段采用安全默认值，前两关保留兼容。具体JSON并非现有Loader自动支持，需要明确解析。
- 未冻结数值包括刷怪权重/成长、冷却/逃脱/束缚参数、一般八神援助附近/间隔/强度、命运额外奖励公式。先核对当前设计是否已补充；仍缺时可采用集中可配置、可回退的暂定值完成实现，在`design_decisions.md`逐项写来源/暂定值/理由/待确认，不能假称原文给定。涉及与世界观/硬约束冲突时再向用户澄清，不静默删掉功能或编新支线。

## 7. 验证、交付与完成标准

1. 保留现有回归：`tools/test_combat_regressions.gd`当前997项、`tools/test_boss_art.gd`当前572项、`tools/test_card_art.gd`headless当前1840项；新增K行为可能改变计数，要报告真实结果。用独立副本和测试存档，Boss测试还需要H规格JSON，卡面测试需要60ID清单；不要漏输入后把引导错误当玩法错误。
2. 最小命令参考（Godot可执行文件本机为`/Applications/Godot.app/Contents/MacOS/Godot`）：

```sh
godot --headless --path <隔离副本> --editor --import
godot --headless --path <隔离副本> --script tools/test_combat_regressions.gd -- --save-file=user://k_combat_test.json
python3 tools/check_translations.py
```

先完成导入；冷缓存首轮字体映射可能需第二轮，最终运行不得有脚本/资源错误。使用独立`--settings-file`和Save路径；不要reset真实玩家存档。headless只证明逻辑，不证明画面或GPU帧时间。

3. 新K测试至少覆盖：时间顺序/前Boss等待/暂停、三个Boss全部技能和阈值、头部唯一索敌、吞噬逃脱/复活、碎片生命周期、三命运边界与去重、64格负坐标/安全区、敌人上限、清场/返回后无残留；结局按[K7的28情形](../assets/source/taskK7_fate_ending_2026-10-20/acceptance_cases.json)。
4. 实际Godot画面必须查看：蛇身转弯、巨口活动通道/维达接触、苏尔特剑尖/火门洞口/火墙内侧/安全格、地图四角/远景/窗口尺寸、五段字幕与结算。保留截图及条件，不以source图库替代Game视角。
5. 自测到一个可运行的选关→三Boss→结局闭环再交回；加速/无敌/强制扣血的控制脚本明确标注。Codex后续负责独立技术验收、正常流程和本机压力/长时复核；不能借用旧J长测证明新关卡。
6. 交付`README.md`、逐文件变更/集成清单、测试命令与结果JSON/日志/截图、`design_decisions.md`、未解决问题及复现步骤。分别报告**代码完成、受控验收、完整通关、压力长时、未测项**。更新[未完成任务清单](未完成任务清单.md)时只勾实际有证据的项。

## 8. 正式新增素材逐文件速查

以下从各批最终manifest提取，路径以`assets/sprites/`为根；列的是单帧尺寸，PNG实际宽度为帧宽×帧数。复用静态/特效与详细socket仍看各批integration，不从本表另造资源。

| 批次 | 正式文件 | 单帧 | 帧数 | fps／循环 | 锚点 |
| --- | --- | --- | ---: | --- | --- |
| K1 | `bosses/jormungandr_head_idle.png` | 128×128 | 4 | 8／循环 | (64,64) |
| K1 | `bosses/jormungandr_head_windup.png` | 128×128 | 3 | 8／单次/静态 | (64,64) |
| K1 | `bosses/jormungandr_head_attack.png` | 128×128 | 4 | 16／单次/静态 | (64,64) |
| K2 | `bosses/fenrir_idle.png` | 192×192 | 4 | 8／循环 | (96,190) |
| K2 | `bosses/fenrir_move.png` | 192×192 | 6 | 8／循环 | (96,190) |
| K2 | `bosses/fenrir_windup.png` | 192×192 | 3 | 8／单次/静态 | (96,190) |
| K2 | `bosses/fenrir_attack.png` | 192×192 | 4 | 16／单次/静态 | (96,190) |
| K2 | `bosses/fenrir_swallow.png` | 192×192 | 6 | 16／单次/静态 | (96,190) |
| K2 | `pickups/gleipnir_fragment.png` | 24×24 | 1 | 0／单次/静态 | (12,12) |
| K2 | `allies/vidar.png` | 96×96 | 1 | 0／单次/静态 | (48,94) |
| K2 | `allies/vidar_idle.png` | 96×96 | 4 | 8／循环 | (48,94) |
| K2 | `allies/vidar_pry.png` | 96×96 | 6 | 16／单次/静态 | (48,94) |
| K2 | `effects/bosses/fenrir_maw_upper.png` | 256×128 | 4 | 8／循环 | (32,128) |
| K2 | `effects/bosses/fenrir_maw_lower.png` | 256×128 | 4 | 8／循环 | (32,0) |
| K2 | `effects/bosses/fenrir_bind_link.png` | 16×8 | 1 | 0／单次/静态 | (8,4) |
| K3 | `bosses/surtr_idle.png` | 320×320 | 4 | 8／循环 | (160,318) |
| K3 | `bosses/surtr_move.png` | 320×320 | 6 | 8／循环 | (160,318) |
| K3 | `bosses/surtr_windup.png` | 320×320 | 3 | 8／单次/静态 | (160,318) |
| K3 | `bosses/surtr_attack.png` | 320×320 | 4 | 16／单次/静态 | (160,318) |
| K3 | `bosses/surtr_plant.png` | 320×320 | 4 | 16／单次/静态 | (160,318) |
| K3 | `bosses/surtr_summon.png` | 320×320 | 4 | 16／单次/静态 | (160,318) |
| K3 | `effects/bosses/surtr_sword_arc.png` | 128×128 | 4 | 16／单次/静态 | (64,64) |
| K3 | `effects/bosses/surtr_gate.png` | 128×128 | 4 | 8／循环 | (64,126) |
| K3 | `effects/bosses/surtr_firewall_band.png` | 64×64 | 4 | 8／循环 | (32,32) |
| K3 | `effects/bosses/surtr_final_fire.png` | 64×64 | 4 | 16／单次/静态 | (32,32) |
| K3 | `effects/bosses/surtr_safe_rune.png` | 64×64 | 1 | 0／单次/静态 | (32,32) |
| K3 | `allies/freyr.png` | 64×64 | 1 | 0／单次/静态 | (32,62) |
| K3 | `allies/freyr_idle.png` | 64×64 | 4 | 8／循环 | (32,62) |
| K3 | `allies/freyr_heal.png` | 64×64 | 4 | 16／单次/静态 | (32,62) |
| K4 | `enemies/fire_giant_move.png` | 96×96 | 6 | 8／循环 | (48,94) |
| K4 | `enemies/fire_giant_attack.png` | 96×96 | 4 | 16／单次/静态 | (48,94) |
| K4 | `enemies/frost_veteran_move.png` | 96×96 | 6 | 8／循环 | (48,94) |
| K4 | `enemies/frost_veteran_attack.png` | 96×96 | 4 | 16／单次/静态 | (48,94) |
| K4 | `enemies/frost_veteran_charge.png` | 96×96 | 4 | 8／循环 | (48,94) |
| K4 | `enemies/frost_veteran_shield.png` | 96×96 | 3 | 8／单次/静态 | (48,94) |
| K4 | `enemies/wolf_berserker.png` | 64×64 | 1 | 0／单次/静态 | (32,62) |
| K4 | `enemies/wolf_berserker_move.png` | 64×64 | 6 | 8／循环 | (32,62) |
| K4 | `enemies/wolf_berserker_attack.png` | 64×64 | 4 | 16／单次/静态 | (32,62) |
| K4 | `enemies/wolf_berserker_rage.png` | 64×64 | 3 | 8／单次/静态 | (32,62) |
| K4 | `effects/bosses/fire_giant_explosion.png` | 96×96 | 4 | 16／单次/静态 | (48,48) |
| K5 | `decals/vigrid/giant_tread.png` | 64×64 | 1 | 0／单次/静态 | (32,32) |
| K5 | `effects/environment/vigrid/distant_battle.png` | 512×128 | 4 | 8／循环 | (0,0) |

音频正式路径：`assets/audio/music/vigrid.ogg`，以及`assets/audio/sfx/`下上述4个新ID的`.wav`。结局正式交接数据仍保存在K7 source目录，需代码主动加载，不能依赖文件名自动接入。
