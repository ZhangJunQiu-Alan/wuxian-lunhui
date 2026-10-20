# K0：第三关代码接入交接

本轮只写assets规划文件和LICENSES追加。以下路径中「新增」均为建议，不代表文件存在；代码实施属于关卡集成。逐文件路径/尺寸/播放/锚点/参考图以asset_plan.json与asset_matrix.md为唯一矩阵，触发/音频见audio_events.json。现有接口索引含行号和输入快照，见records/code_interfaces.json及records/input_snapshot.json。

## 当前代码事实

1. scripts/data/level_db.gd 的ORDER含vigrid，ALL只有midgard/helheim；is_built(vigrid)为false。BossDB.create只登记前两关六个Boss。EnemyDB.ALL没有fire_giant/frost_veteran/wolf_berserker。
2. Game._ready从map.size计算view_bounds，再grow(-border)得bounds，清理MapLayer.obstacles，再实例化map.layout。VigridMap需遵循这套生命周期。
3. Game._update_bosses按既定时间顺延，Boss由_point_around(player,520)生成。当前没有Boss专用活动区API，也没有第三关的围场、吞噬、命运控制器。地图示例中心不得直接替换这套行为。
4. Enemy._ready注册enemies组、空间索引和collision_layer=2，projectile只检测mask=2。蛇身/尾/远景/援助人物不能继承并保留这套敌人注册，否则会被自动武器瞄准/受伤。
5. SpriteVisual.create_actions按单帧高度切正方形横条。非方形效果必须走draw_frame/自有元数据。其默认枢轴按纹理高度推导，不能读取本方案anchor_px。显式锚点适配需由新Boss/盟友视图完成。
6. Boss.BOSS_ACTIONS现无swallow/plant；state_actions需新增对应映射。Boss._ready会把attack设成8fps，与本K提案16fps不同；只给新Boss定好速度，不能顺手改变前两关六个Boss。
7. BossFx元数据只有H的登记；新增贴图不能因文件名存在就自动播放。PoisonPool._inside固定椭圆与半径，不能复制到耶梦加得后声称覆盖大片毒雾的判定正确。
8. player.faith及player.gods[id].awakened可读；当前Game._finish_run返回elapsed/kills等，没有改写命运统计；_begin_ending会暂停SceneTree。新结局若用定时动画需明确PROCESS_MODE_ALWAYS并允许跳过。

## 需要新增/修改的接入点

|范围|目标|工作与约束|
|---|---|---|
|关卡注册|scripts/data/level_db.gd|新增NORSE_3并登记ALL.vigrid；配置music=vigrid、map.layout、waves/elite/events/bosses。Boss时间180/360/540沿用世界观，其余平衡字段由集成定稿。未设计的quests/hidden_quests保持空，不复用其他关任务填空|
|地图|新增scripts/world/vigrid_map.gd，继承MapLayer|按layout.json落地；ground_dir/props_dir指向vigrid；decals直接引用已有helheim中性痕迹或独立加载，禁止复制成新素材。自定义边界替代MapLayer.border缺图占位；动态活动区与装饰分层|
|Boss工厂|scripts/data/boss_db.gd|新增jormungandr/fenrir/surtr分支；所有需要的脚本齐全后才启用关卡|
|耶梦加得|新增scripts/bosses/jormungandr.gd及分节视图/危害组件|type_id=jormungandr，sprite_name=jormungandr_head；idle/windup/attack映射；移动由环绕路径驱动，不新增move帧条。头颈socket(0,62)对齐body(0,30)/(64,30)。主体只做一个可受伤Boss；身体用轻量路径碰撞，不进enemies索引/第2层；头部受击提示与身体接触击退区分别标识|
|蛇身绘制|建议新增scripts/effects/serpent_ribbon.gd|已有64pxbody沿弧长连续UV映射，头尾在切线方向接合；不能独立刚性旋转十几张矩形后忽略楔形空隙。路径、内侧边界、宽度需同时供绘制和接触查询；最近邻采样与遮罩检查|
|毒雾|新增可参数化危害组件或扩展专属组件|复用既有nidhogg_poison_breath/poison_pool图，按新权威cone/polygon裁切；毒雾范围/持续时间/伤害tick均由K1控制器，不能直接继承固定半径毒池。绘制在玩家之下，边界标记在纹理之上|
|芬里尔|新增scripts/bosses/fenrir.gd|idle/move/windup/attack/swallow；巨口256特效显式元数据，吸引与致死中心由同一几何数据供给；逃脱时长未定。碎片作为拾取物单独登记，绑定状态有开始/结束/增伤接口；不得增加EnemyDB锁桩冒充捡链|
|苏尔特|新增scripts/bosses/surtr.gd及火场组件|统一256动作，显式foot(128,254)，回退192静态foot(96,190)。attack/plant/summon分别切动作；60%/25%阶段只触发一次。剑扇区/火墙圆带/终焉格分别输出几何，贴图裁切不扩大实际伤害。特效四帧衰减与判伤窗口解耦|
|敌人|scripts/data/enemy_db.gd、scripts/entities/enemy.gd或专属行为组件|注册fire_giant/frost_veteran/wolf_berserker；fire death仅一次爆炸及余火；frost charge/shield与可绕背方向；berserker低血狂暴一次触发。普通move8/attack16，特殊状态显式加载；行为只限这些类型，不影响旧敌人|
|盟友|新增scripts/allies/vidar_aid.gd、freyr_aid.gd（路径建议）|非Enemy，不进敌人组/受伤层；世界内小像素人物，不把720×1200卡面缩小。维达96脚锚(48,94)，弗雷64脚锚(32,62)。维达与狼颚接触由事件提供坐标；弗雷治疗实际生效后再出光和声音，不能重复玩家已有Freyr神术计时器|
|命运与援助|新增scripts/world/vigrid_encounter.gd或局内专属控制器|每局保存thor_saved/vidar_intervened/freyr_assisted三标志；战斗计时从Jormungandr实际登场起，按暂停/结算门控；信仰判定读player.faith，觉醒读player.gods[id].awakened。数据最终字段名为提议，尚未加入保存|
|音频|scripts/core/audio.gd调用点、level.music|当前Audio已有24声部、同名50ms最短间隔及4同名上限。按事件播放，终焉格不能一格一声；零散怪死亡火焰须有场景级预算。复用已有入口不重做G6；新vigrid.ogg应在启动前有文件，当前缺曲会淡出旧曲，不是自动音乐回退|
|结局/结果|Game._on_boss_defeated/_finish_run/_on_level_cleared、HUD结果视图、Save.record_run|第三Boss败后五段文字演出，再结算现有存活/击杀及新增命运数；不要发明奖励公式。Loki彩蛋取「本关曾信仰过」事件记录，不能只在结算查当前技能节点。存档需可选字段兼容旧档；双次killed/defeated/跳过不重复发奖励|

## 状态/动作提议

|角色|状态→动作|单次动作关键帧提议|时序所有权|
|---|---|---|---|
|蛇头|环绕→idle；poison_windup→windup；喷吐→attack|attack第1帧开口，第2帧释放；结束回idle|喷吐判伤由控制器释放事件，不由动画finished猜测|
|芬里尔|chase→move；maw_windup→windup；swallow→swallow；charge→move；recover→idle|吞噬第2帧张颚，第3帧保持；逃脱阶段和关闭阶段需显式相位|巨口循环层与吞噬身体单次层分离；hold/release不硬挤进四帧|
|苏尔特|chase→move；slash_windup→windup；sweep→attack；plant→plant；summon→summon|挥剑第2帧接触；插剑第2帧触地；召唤第2帧开门|状态时长和伤害窗口不因16fps图条长度改变；动画末帧可保持|
|霜巨人精锐|chase→move；charge→charge；shield→shield；attack→attack|举盾第2帧到位并保持|后方免疫/伤害判定由朝向和代码，不由盾牌alpha|
|狂狼战士|move/attack；低血进入rage单次后恢复move|rage第1帧抬肩，第2帧咆哮|阈值与速度倍率未定，不在图稿中假定|

关键帧是待C2冻结的契约提案，未修改玩法。回退时使用现有静态图/清楚的程序预警，不用缺图静默掩盖危险。

## 绘制、坐标、遮罩

- 世界实体为脚底锚点；根位置和脚底之间的MapLayer.FOOT=20偏移应统一。地图prop使用画布底中点，贴花用中心；蛇/效果使用元数据socket，不套脚底。
- 实体1倍、最近邻；镜像必须同时镜像锚点和喷口。非正方形特效使用draw_frame，不能用默认正方形自动切条。
- 地面/贴花 < 危害薄纹理 < 角色/身体 < 清楚的预警/安全线 < HUD。巨口和火墙中心透明，不能盖掉玩家位置。
- 共用一份arena_center/radius、cone_angle、cell_set给判伤与绘制；外侧纹理超出区域必须裁切。装饰火标damage=false，素材本身不产生碰撞。
- 所有循环、音效、纹理缓存与辅助节点在Boss败亡/场景退出时有明确清理；身体段不按视觉段数新增Enemy节点。复用H/J集中绘制思路，但不假定现有硬编码元数据已经兼容K。

## 运行验收（全部未测）

- 三Boss全技能与全部阶段；每个命运条件的满足/不满足/边界90秒/暂停/重复事件路径。
- 蛇头唯一可受击、身体不会被自动瞄准，缩圈后仍有内部安全空间；蛇身在实际最小半径最近邻采样下无洞/接缝/反向鳞片。
- 巨口警告、逃脱、吞噬和绑定期可读；链片不与残骸混淆；维达真正对上上下颚。
- 苏尔特剑不裁边、不跳脚；60%/25%转阶段、火墙收缩、符文安全格与判伤一致；受火焰叠加后玩家可见。
- 普通怪特殊状态，死亡爆炸只一次，暂停/大招冻结/退出时无残留伤害。
- 地图80×80铺设、边界不可越、负坐标、所有通道连通、350怪负载及前台帧率；不能借用J隔离副本长测结论。
- 音频实际触发和混音、音乐连续三遍无缝；结局只结算一次、旧存档兼容、导出包资源路径齐全。
