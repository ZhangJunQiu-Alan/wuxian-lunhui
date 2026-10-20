# K2 接入交接

第三关Boss尚未实现。以下是新增文件的接入契约，不是已执行的代码修改。K-assets-v1.0基准加K2-maw-bind-v1.1补充，补充对巨口／束缚旧方案优先，SHA见records/addendum_ref.json。

|正式路径（assets/sprites/）|单帧／帧／播放|目标脚本／函数与坐标|
|---|---|---|
|bosses/fenrir_idle.png|192×192／4／8fps循环|新增bosses/fenrir.gd `_ready/_update_state`；脚锚(96,190)|
|bosses/fenrir_move.png|192×192／6／8fps循环|同上move，世界位移由控制器，脚锚(96,190)|
|bosses/fenrir_windup.png|192×192／3／8fps单次末帧保持|同上windup，不靠动画结束提前释放技能|
|bosses/fenrir_attack.png|192×192／4／16fps单次|同上attack，新Boss单独覆盖Boss默认attack8fps，接触事件由控制器|
|bosses/fenrir_swallow.png|192×192／6／16fps单次|同上显式新增swallow动作；不认为现加载器会自动映射|
|effects/bosses/fenrir_maw_upper.png|256×128／4／8fps循环|新增fenrir.gd巨口视图；锚(32,128)，铰点上方分件|
|effects/bosses/fenrir_maw_lower.png|256×128／4／8fps循环|同上；锚(32,0)，铰点下方分件|
|effects/bosses/fenrir_bind_link.png|16×8／1|新增fenrir.gd束缚带视图；锚(8,4)，水平左右端口允许触边|
|pickups/gleipnir_fragment.png|24×24／1|新增fenrir.gd碎片拾取与生命周期；锚(12,12)，原有拾取光点程序可保留|
|allies/vidar.png|96×96／1|新增allies/vidar_aid.gd世界内援助视图；脚锚(48,94)|
|allies/vidar_idle.png|96×96／4／8fps循环|同上idle，同脚锚|
|allies/vidar_pry.png|96×96／6／16fps单次|同上pry，zero-based2帧开始抓握、2～4帧撑口，结束由事件控制|

全部RGBA实体二值alpha，横向无间距，默认向右，身体整数1倍、最近邻。镜像时脚锚／颚铰点／接触点同步镜像；不得单独翻图后仍沿右向吸引。上下颚属于巨口表现，不是整个狼头，不用于替换身体静态。不得将非正方形颚帧直接交给当前按正方形切帧的SpriteVisual，需要显式区域大小和锚点。

活动玩家吞噬阶段：控制器提供mouth_hinge、mouth_axis、gap>=64、权威attraction_region、fatal_region和逃脱剩余时间。上下颚分别从hinge±gap/2绘制，图形只占各自半侧；区域预警与真实判伤使用同一几何数据，清楚显示倒计时。贴图alpha和animation_finished均不得决定即死／吸引时长。口腔不额外填黑底，警戒线和玩家需保持可读。独立检查使用288×352画布、hinge(32,176)，保护区(96,144)-(208,208)。

援助撕口阶段：玩家已逃离或交互已关闭，停止吞噬伤害；依据维达手靴接触点定位颚材质，而不是拉长96px人物。preview_project/render_review.gd仅含2～4帧注册样例，接触取自实际PNG像素，未实现完整演出／移交相机。不能照搬援助近合口姿势到仍有玩家的攻击阶段。触发条件严格为本局奥丁信仰且奥丁已觉醒；本轮没有执行条件测试。维达无Enemy组／空间索引／受击第2层，不得成为自动瞄准对象。

束缚：一条连续UV带，16×8编带沿椭圆／控制器路径映射；参考半径(82,84)、纹理横轴切线方向，draw quad全宽8、实际像素约4px。镜像重复采样避免端点接色断开；不可拉成粗实线。小亮点可由程序四相位8fps移动，不声称这个静态PNG有4帧。保护区(56,54)-(136,138)不绘制带，alpha加权总覆盖<=12%；独立Godot实测约4.11%。实际束缚范围仍由控制器负责。

狂奔轨迹复用effects/bosses/skoll_dash_trail.png、冲撞／咬击复用effects/hit_bite.png，几何路径预警保留，不烘焙进身体帧。解除束缚复用effects/bosses/garm_chain_break.png，允许按项目现有材质做暖金染色；不能将断铁链当格莱普尼尔实体。原fenrir.png保持原路径／哈希。

需后续新增BossDB注册、第三关生成／计时调度、技能控制器与援助触发。实际吞噬逃脱窗口、吸引与伤害边界、冲撞、拾取计数／掉落、奥丁条件、完整撕口流程、密集场景和第三关通关均未验收。独立52张素材截图不能勾选这些项目。
