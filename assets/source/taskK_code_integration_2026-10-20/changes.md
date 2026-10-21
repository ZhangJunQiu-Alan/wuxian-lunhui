# 第三关代码集成：逐文件变更清单

只改了 scripts / tools / locale，没有改 project.godot、场景文件、assets 里的正式素材，也没有改前两关的数据。其他代理在 docs/ 里未提交的改动没有动。没有 commit，也没有 push。

## 新增

| 文件 | 内容 | 对应项 |
| --- | --- | --- |
| `scripts/data/vigrid_tuning.gd` | 第三关的集中数值表：冻结规则单独列出，其余都标【暂定】。第二版加强三个 Boss，新增三个本体接触伤害常量（原来写在 setup_boss 调用里） | 全部 |
| `scripts/data/vigrid_ending_timeline.json` | K7 `ending_timeline.json` 的运行时副本（SHA256 0a3b88b8…相同） | K-CODE-07 |
| `scripts/world/vigrid_map.gd` | VigridMap 地图脚本。<br>地面：焦土底；道路按 K0 的 10 条，256 宽；焦草、裂地斑块。<br>物件：K0 的样例摆位加地标散布，中央 1280 内没有带碰撞的物件，出生点 384 内是空地。<br>装饰：巨人脚印；装饰火（色相 0.04 的材质实例）。<br>屏障带：烟雾 + 沿可走矩形的火墙条带（上半朝外，转角是扇形）+ 一条边界线。<br>北侧远景：3 段 512×128 条带，4 帧 8 帧/秒，不碰撞、不索敌。<br>过渡块：开局前显式加载 midgard 的 12 张 path_edge 遮罩，再派生焦草过渡块 | K-CODE-01 |
| `scripts/entities/vigrid_enemy.gd` | 三种新敌人的专属行为。<br>火焰巨人：死亡时只爆炸一次，留下残火，不放通用死亡碎片。<br>霜巨人精锐：冲锋有路线预警；举盾只挡正面扇区，绕到背后能打。<br>狂狼战士：低于 40% 狂暴一次。<br>脚锚按素材清单对齐 | K-CODE-02 |
| `scripts/bosses/fire_hazard.gd` | 地上的火：预警 → 爆炸只结算一次 → 持续火焰。判定和绘制共用圆心半径，场上最多 60 个 | K-CODE-02 / 05 |
| `scripts/bosses/jormungandr.gd` | 耶梦加得。第三版加了猛噬、毒液弹、狂怒、按距离选招、毒息预判瞄准，蛇颈改成三次贝塞尔（猛噬拉长时不折角），见 design_decisions §3。<br>只有蛇头是 Boss 节点；蛇身是沿闭合圆角矩形路径连续采样的 UV 带，一次提交绘制，同一条中线做接触判定（撞飞，有命中冷却）。<br>路径 = 玩家 2048 方区与地图内缩 96 求交，每次收紧不超过 128。<br>毒息：蓄力 → 出招第 1 帧喷出；扇形预警、命中、毒雾是同一个多边形。<br>托尔条件按本场遭遇的未暂停时长判断 | K-CODE-03 |
| `scripts/bosses/fenrir.gd` | 芬里尔。<br>独立上下颚（256×128 显式区域，锚点 32,128 / 32,0）；朝左时整体镜像。<br>吸引区和致死区由铰点和轴线算出；吸引阶段张口 ≥64，先有逃脱倒计时再提交吞噬（走玩家正常受伤流程）。<br>扑咬、狂奔：预警路线就是移动路线。<br>格莱普尼尔碎片：只能捡一次，束缚时受伤加成，吸引中被束缚则取消吞噬；束缚带是一条细编带，镜像重复采样，不画进躯干保护区。<br>维达：撑口时上下颚对准维达手和靴子的接触点（不拉伸人物），演出期间关闭所有判定 | K-CODE-04 |
| `scripts/entities/gleipnir_fragment.gd` | 锁链碎片拾取物，不在敌人组 | K-CODE-04 |
| `scripts/bosses/surtr.gd` | 苏尔特。<br>320 动作，脚锚 160,318；出招、插剑、召唤 16 帧/秒；释放帧按契约（横扫第 1 帧、张掌第 2 帧、插剑第 2 帧）。<br>横扫：扇形预警、伤害、剑弧裁切是同一几何，留残火。<br>火门放出火焰巨人，受敌人上限约束。<br>60% 九界燃烧：安全圆收缩，圆外持续伤害，火墙条带上半朝外。<br>25% 插剑后进入终焉之火：64 格 floor 坐标，同一份不安全格集合同时驱动预警、火焰、伤害，安全格画符文。<br>两个阈值各触发一次 | K-CODE-05 |
| `scripts/world/vigrid_battle.gd` | 一般神明周期援助（附近交战判定、轮流、复用神术、事件字段）；托尔获救后在苏尔特战中落雷；弗蕾亚觉醒时弗雷参战治疗 | K-CODE-05 / 06 |
| `tools/test_vigrid.gd` | 第三关专项逻辑测试，348 项（第二版把吸引速度和火门巨人数两项改成读 VigridTuning） | 自测 |
| `tools/review_vigrid.gd` | 真实窗口截图（1280×720 / 960×540 / 1600×900） | 自测 |
| `tools/playthrough_vigrid.gd` | 受控完整流程：无敌机器人，自动走位和选卡，正常刷怪和 Boss 调度，一直跑到结算；记录事件和性能 | 自测 |
| `tools/stress_vigrid.gd` | 350 混合敌人 + 各 Boss 技能的帧时间，再反复进出关卡 | 自测 |
| `tools/review_vigrid_aid.gd` | 第三版：真实窗口拍四位神（和托尔对照）周期援助的现状，给 M-ART-03 | 交接 |
| `tools/make_codex_m_art_images.py` | 第三版：拼 `docs/images/codex_m_art/` 的三张对比图 | 交接 |
| `tools/review_vigrid_codex.gd` | 第二版：真实窗口打开主神空间图鉴页，逐个选中第三关的敌人和 Boss 截图 | 自测 |
| `docs/Codex_第三关美术优化任务.md` | 第二版：交给 Codex 的美术优化任务书（地面、剑弧、四位神援助特效） | 交接 |

## 修改

| 文件 | 改了什么 | 对前两关的影响 |
| --- | --- | --- |
| `scripts/data/level_db.gd` | 新增 NORSE_3，登记进 ALL；音乐 vigrid，Boss 在 180/360/540 秒，没有支线；新增 ending / fates / routes / horizon 字段。第二版：NORSE_3 加 `enemy_growth`，精英间隔 28，后两段刷怪间隔 0.3 / 0.22 | 无。ORDER 原来就有 vigrid；前两关没有 `enemy_growth`，成长不变 |
| `scripts/data/enemy_db.gd` | 新增三种敌人；新字段 `script`（专属脚本）、`foot`（脚锚） | 无 |
| `scripts/data/boss_db.gd` | 登记三个 Boss | 无 |
| `scripts/game.gd` | 敌人按 EnemyDB 的 script 字段生成。<br>新增本局命运字典和 `ever_faith_loki`（监听 `Player.god_added`）、`confirm_fate`、`fate_count`。<br>有 fates 的关卡才创建 VigridBattle。<br>`_finish_run` 只结算一次，之后返回同一份冻结数据，第三关额外带上命运字段。<br>第二版：`enemy_hp_scale` / `enemy_damage_scale` 可以被关卡的 `enemy_growth` 覆盖。<br>`_on_level_cleared`：先结算并存档，再按关卡的 ending 字段播放分段字幕（篇章完成音只响一次），读完或跳过后显示同一份结算。<br>`load_ending` 显式解析并校验字段 | 前两关没有 ending / fates 字段，流程和以前一样；只是重复调用 `_finish_run` 时返回第一次的数据（以前每次重新拼一个字典，内容相同） |
| `scripts/ui/hud.gd` | `show_ending`：五段字幕，继续 / 跳过 / Esc / 点击推进，可以重复调用；结算界面新增命运一行（有 fates 时）和洛基伏笔（胜利且本局信仰过洛基时）；没有支线的关卡隐藏支线那一行 | 前两关的结算界面不变（有支线行，没有命运行） |
| `scripts/core/save_data.gd` | 新增 `fates` 和 `record_fates`（取并集）；版本 5；旧档或格式错误时读成空字典；reset 时清空 | 旧存档照常读取 |
| `scripts/bosses/boss.gd` | 拆出 `_update_visual`（内容没变）。<br>`touches_player` 钩子（默认等于原来的 `not untouchable`）。<br>新增 `fit_k_actor`：只有第三关 Boss 调用，脚锚对齐，出招动作 16 帧/秒，影子画在脚下 | 前六个 Boss 不调用 `fit_k_actor`，行为不变 |
| `scripts/entities/player.gd` | 新增 `god_added` 信号、`shove`（撞飞位移，闪现中不受影响）、`is_invulnerable` | 没有调用方时没有影响 |
| `scripts/world/map_layer.gd` | 新增 `extra_tiles`：开局时从别的目录显式加载地块 | 前两关没有设置，空字典 |
| `scripts/effects/boss_fx.gd` | 新特效登记播放速度、单帧和火门锚点；新增 `draw_quads`（多个四边形一次提交） | 只是追加 |
| `scripts/data/codex_db.gd` | 第二版：登记第三关的 3 个敌人和 3 个 Boss；Boss 行可选第 6 项指定图片（耶梦加得用 `jormungandr_head`） | 只是追加 |
| `scripts/ui/codex_view.gd` | 第二版：读 Boss 行的可选图片名；高于 1.5 倍展示高度的动作图（苏尔特 320）按整数分之一缩小放进展示台 | 前两关的图都不超过 192，不触发 |
| `locale/text.csv` | 新增 45 条英文；第二版再加图鉴 12 条 | — |
| `tools/check_translations.py` | 也检查 `scripts/**/*_timeline.json` 里的结局字幕 | — |

## K6 的 25 个音频事件

| # | 事件 | 声音 | 调用点 | 去重方式 |
| --- | --- | --- | --- | --- |
| 1 | jormungandr_windup | boss_windup | `Boss.change_state("breath_windup")` | 每次进入蓄力一次 |
| 2 | jormungandr_poison_release | **jormungandr_hiss** | `Jormungandr._breathe` | `_released`：每次出招一次 |
| — | （第三版新增，不在 K6 表里）猛噬蓄力 / 咬地 / 毒液弹 / 狂怒 | boss_windup（基类规则）/ boss_slam / jormungandr_hiss -8dB / jormungandr_hiss +2dB | `lunge_windup` / `_bite` / `_spit` / 狂怒 | 每次出招一次；狂怒只一次 |
| 3 | jormungandr_body_hit | boss_slam | `Jormungandr._body_contact`（命中被接受时） | 0.9 秒命中冷却 |
| 4 | thor_fate_rescued | quest_done | `Jormungandr._check_thor` | `confirm_fate` 只成功一次 |
| 5 | thor_final_aid | lightning | `VigridBattle._tick_thor`（实际落雷） | 每 6 秒一次 |
| 6 | fenrir_maw_windup | boss_windup | `Boss.change_state("maw_windup")` | 每次一次 |
| 7 | fenrir_gulp | **fenrir_swallow** | `Fenrir._commit_swallow`（逃脱窗口结束） | `_committed`；被束缚或维达介入时不放 |
| 8 | fenrir_charge | boss_howl | 狂奔开始（`run_prep` → `run`） | 每次一次 |
| 9 | gleipnir_pickup | chest_open | `GleipnirFragment`（实际拾取） | `taken` |
| 10 | gleipnir_bind | **gleipnir_tension** | `Fenrir.bind`（束缚生效） | 每次束缚一次 |
| 11 | vidar_arrive | awaken | `Fenrir._begin_vidar` | `confirm_fate`，每场一次 |
| 12 | vidar_pry | boss_slam | `Fenrir._update_vidar`（撕开） | `_vidar_pried` |
| 13 | surtr_sword | katana_slash | `Surtr._sweep`（伤害帧） | `_released` |
| 14 | surtr_residual_fire | fire_burn | `FireHazard._ready`（残火开始） | 同一帧的 3 块残火由 Audio 的 MIN_GAP 0.05 合成一声 |
| 15 | surtr_gate | **surtr_gate** | `Surtr._open_gates`（开门） | 每次召唤一次，不按巨人或帧放 |
| 16 | surtr_phase60 | boss_warning | `Surtr._check_phases` | phase 只升不降 |
| 17 | surtr_phase25 | boss_warning | 同上 | 同上 |
| 18 | surtr_final_fire | boss_slam + fire_burn | `Surtr._tick_final`（一批格子爆发） | 每轮一次，不按格子放 |
| 19 | freyr_heal | heal_pickup | `VigridBattle._tick_freyr`（实际给了治疗） | 满血不放 |
| 20 | fire_giant_explosion | big_death + fire_burn | `FireHazard._explode` | 每个巨人一次 |
| 21 | frost_veteran_charge | boss_windup | `VigridEnemy._update_veteran` 冲锋开始 | 每次冲锋一次 |
| 22 | frost_veteran_block | boss_block | `VigridEnemy.take_damage`（真的挡下） | Audio 限流 |
| 23 | wolf_berserker_rage | boss_howl | `VigridEnemy._update_berserker` | `raged` 只一次 |
| 24 | battlefield_ambience | 省略 | — | 契约 v1 省略 |
| 25 | chapter_clear | quest_done | `Game._on_level_cleared` | 只调用一次 |

音乐：
- 关卡音乐 `vigrid`（LevelDB）。
- Boss 登场用原有的 `boss`。
- Boss 被击败、关卡没打完时，恢复成 `vigrid`。
- 胜利用 `victory`，失败用 `defeat`。

Audio 的 24 个声道、MIN_GAP 0.05、MAX_SAME 4 都没有改。周期援助用的是各位神原来的音效。

清单外的声音：Boss 基类原来就会给每个 `*windup` 状态放 `boss_windup`，所以芬里尔扑咬、苏尔特横扫蓄力也有这个声音，见 design_decisions §8。
