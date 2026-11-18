# 接入约定

资产位于 assets/models/midgard/rooms/。先实例化 GLB，再用独立 Godot 场景添加碰撞、交互与伤害区域，便于模型重新导出时保留逻辑。

- 地面顶面约为原点高度，雪层略高。断台向下延伸，中央空洞需要明确的坠落或禁行区域。
- 地刺用 SpikeCarrier 升降。Godot 的 spike 循环动画约两秒，实际伤害阶段由游戏时间轴同步。前摇预警可单独调节。
- 踏板的 MovingPlate 负责下压，press 动画表现运动。探测范围由碰撞体确定。
- 闸门 GateMoving 独立于石柱，open 动画升起闸门。出口探测可对齐 ExitAnchor。
- 拉杆围绕 HandlePivot 转动，activate 动画切换姿态。机关目标用关卡数据关联。
- 符文陷阱 BlastOrigin 为喷发特效中心。范围标识必须与伤害判定一致。
- 火盆 FireOrigin 用于添加粒子和灯光。

预览是 Blender 渲染。Godot 另有模型合集渲染，用来检查导入、材质和轴向。导出动画已检查实际活动部件位移，玩法联动待接入。
