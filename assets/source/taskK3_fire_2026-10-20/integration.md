# K3 接入交接

本轮仅素材。需新增苏尔特控制器、BossDB注册和第三关调度；实际仍未接入。基准K-assets-v1.0，六条身体尺寸以K3_action_canvas_addendum_v1.2.json优先；文件和SHA见manifest／records/contract_ref.json。

|正式路径（assets/sprites/）|单帧／帧／播放|目标与事件|
|---|---|---|
|bosses/surtr_idle.png|320×320／4／8fps循环|新增bosses/surtr.gd `_ready/_update_state` idle|
|bosses/surtr_move.png|320×320／6／8fps循环|同上move，位置跟随控制器|
|bosses/surtr_windup.png|320×320／3／8fps单次末帧保持|同上windup，等明确release事件|
|bosses/surtr_attack.png|320×320／4／16fps单次|同上挥剑；zero-based1接触，2延续，3恢复|
|bosses/surtr_plant.png|320×320／4／16fps单次|同上显式plant映射；zero-based2剑触地，3保持|
|bosses/surtr_summon.png|320×320／4／16fps单次|同上summon，zero-based2张掌事件，门／生成仍由控制器|
|effects/bosses/surtr_sword_arc.png|128×128／4／16fps单次|同上sweep视图；中心锚(64,64)，右侧弧，按实际扇形裁切|
|effects/bosses/surtr_gate.png|128×128／4／8fps循环|同上gate视图；落地锚(64,126)，角色通过时前后层次明确|
|effects/bosses/surtr_firewall_band.png|64×64／4／8fps循环|同上firewall，锚(32,32)为权威边界切线，左／右接续端口|
|effects/bosses/surtr_final_fire.png|64×64／4／16fps单次|同上final_fire单危险格，不是全屏贴图|
|effects/bosses/surtr_safe_rune.png|64×64／1|同上safegrid，中心锚(32,32)，安全格顶层可读|
|allies/freyr.png|64×64／1|新增allies/freyr_aid.gd世界内人物，脚锚(32,62)|
|allies/freyr_idle.png|64×64／4／8fps循环|同上idle|
|allies/freyr_heal.png|64×64／4／16fps单次|同上heal，zero-based1～2张掌；治疗由事件控制|

身体统一脚锚(160,318)，静态surtr.png仍脚锚(96,190)，可在320透明画布位置(64,128)预览，切换时不能沿用中心锚造成跳位。默认右向3/4，朝左镜像时所有剑口／接触点同步镜像，身体整数1倍最近邻。六条动作采用320正方帧，现SpriteVisual可以按宽／高切帧，但新Boss尚不存在；Boss._ready默认attack8fps必须仅对新苏尔特覆盖16fps，plant/summon还须显式载入／映射。

挥剑：伤害扇形／角度／半径由控制器提供，贴图按同一几何裁切，不能按火星alpha猜范围；剑弧中心保持空，允许旋转及范围缩放。身体的剑姿势需要与控制器击中事件对齐，不以animation_finished判伤。独立演示中弧位已贴近剑路，但不是生产socket校准；接入时按实际手／剑口坐标确定。

门：128px轮廓与96px火巨人尺度并排；洞口保护区local(40,46)-(88,116)。角色可先画在门框后、越过落地线后再前置，不把门装饰变成碰撞。门只在活跃期循环，生成逻辑与数量保持控制器决定；开启／退出可用材质淡入淡出，不增加伤害。

火墙：64px短带上半侧是圈外火焰，下半侧透明。沿权威边界连续UV铺设，向外的法线对应纹理上方；内侧不铺材质，保留明确程序边界线。参考演示以镜像重复采样避免首尾色带突变，不强制把未严格同色的左右边硬拼。半径／可行走／判伤边界读取同一region，60%生命阈值只触发一次缩圈阶段，不借贴图改变阈值。

终焉之火：25%生命阈值一次触发插剑／最终阶段。格宽64，global_cell=floor(world/64)，控制器提供唯一unsafe_cell_set/safe_cell_set。火焰只对unsafe格绘制并裁切，安全格不绘制火焰，safe_rune放在安全格轮廓层，玩家／预警上层保持可读；不能以贴图留白当安全判定。预警需在爆发前清楚显示相同格集合，具体计时和伤害由玩法实现。

弗雷援助条件保留世界观：本局弗蕾亚信仰且弗蕾亚已觉醒，不能误写成弗雷信仰。世界内64px人物不加入Enemy组、空间索引或受击第2层。治疗场复用effects/gods/freyr_field.png，残火复用effects/gods/loki_fire_patch.png，事件分别归援助／苏尔特控制器，不能意外触发玩家洛基／弗雷技能计数。弗雷不附送未定义飞剑／野猪或新奖励。

需真实游戏后续验收：全部技能与阶段、插剑落点、刷怪层次、火墙与伤害边界、安全格移动／爆发、弗蕾亚条件和治疗、350敌人密度、完整关卡与结局。本批81张Godot独立渲染截图不覆盖这些项目。

残火色相补充：loki_fire_patch原色偏绿，不直接用原色。复用纹理时只对该实例做HSV色相固定0.04（约橙红）、保留饱和度／明度／alpha；正式原PNG不改。独立预览已采用这项材质等效转换，生产需用同等shader／纹理实例，不能全局改洛基火焰。
