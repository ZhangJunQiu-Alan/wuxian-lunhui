# K1 接入交接

本轮未改生产代码。契约：K-assets-v1.0，SHA见records/contract_ref.json。新增Boss脚本仍需由集成实施，不能因PNG已存在就认定能播放。

|正式文件|单帧/帧/播放|目标与事件|
|---|---|---|
|assets/sprites/bosses/jormungandr_head_idle.png|128×128 / 4 / 8fps循环|新Jormungandr视图的idle；运动跟随环绕路径，不重做move|
|assets/sprites/bosses/jormungandr_head_windup.png|128×128 / 3 / 8fps单次|poison_windup；播完末帧保持至控制器release|
|assets/sprites/bosses/jormungandr_head_attack.png|128×128 / 4 / 16fps单次|poison_attack；release在zero-based1帧对应事件，但实际判伤由控制器，非animation_finished|

共同锚点(64,64)，左颈socket(0,62)，面向右。身体/尾使用旧64px图，body socket(0,30)/(64,30)，tail右口(64,30)。生成颈口中心稳定，边缘RGBA并非与原身体逐像素相同；直线预览和曲线最近邻已检查无开放缝隙。允许实际视图用2px几何重叠消除采样边界，不修改原PNG。

参考实现是preview_project/render_review.gd：弧长UV带按完整纹理周期映射，避免每段硬卡片独立旋转留缝；这个演示不是完整Boss脚本。只有头在enemies组/空间索引/第2受击层，身体和尾是无受伤注册的视图与几何接触，不能建立一串Enemy节点。

需要在BossDB加入jormungandr并实现新脚本；sprite_name必须为jormungandr_head。新Boss单独设置attack16fps，现Boss._ready默认8fps不能直接沿用，不改动前六Boss。保留明显头部可受击提示；身体接触击退与伤害冷却由几何控制器负责。

复用nidhogg_poison_breath（96×64/4/16fps，喷口4,32），poison_pool（48×48/8帧）、hit_bite、thor_hammer/cloud以及现有LightningFx；均沿原路径加载，不复制新正式文件。新毒区不可直接照搬PoisonPool固定半径/椭圆判定；用权威region裁切，薄雾之上保留清楚预警。毒息口示例坐标head local(108,66)，实际动画帧释放点再由控制器确认，其他方向旋转必须同步变换socket。

托尔条件读本局信仰并从本场实际登场计未暂停时长，<=90秒击败时记录thor_saved，最终战援助只触发对应事件；本轮未运行此条件。游戏验收仍需实际瞄准/判伤/缩圈、所有动作衔接、托尔援助、密集场景及整关流程，不借用独立22张截图作通过。
