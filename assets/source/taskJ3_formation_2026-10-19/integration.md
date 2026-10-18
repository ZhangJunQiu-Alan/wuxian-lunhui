# J3 逐文件接入交接


## 最终文件合同

### `assets/sprites/effects/ultimates/formation_cavalry.png`

- 单帧 96×64，6帧，8fps，循环。
- 锚点 `[48.0, 62]`；正式SHA256：`e90f55f3ba2c7fe52a8bd809b7d9ae6b652fb9dfdae2a1fc0968ba7c82487049`。
- 接入点：`scripts/ultimates/enter_formation.gd::_draw()`。
- 只替代14行×3列的马身/骑手多边形和长枪draw_line；复用原p(x+jitter-k*70,y)及alpha=0.55-k*0.15，同一节点集中绘制，不创建42个节点。脚底锚点(48,62)放在p+(0,6)，默认朝右，1倍尺度，8fps循环；可用行列相位避免整队同姿。保留_cavalry_x、CAVALRY_WIDTH=90、CAVALRY_TIME=1.1、判伤、击退和原范围淡红提示。
- 最近邻采样；保持透明，不把画布矩形视为碰撞。坐标/尺度预览为离线示意，实际范围与遮挡需游戏确认。

### `assets/sprites/effects/ultimates/formation_slash.png`

- 单帧 64×32，4帧，16fps，单次。
- 锚点 `[32.0, 16.0]`；正式SHA256：`2d90b362fd9306f76747e27cadf00c9f27f3bc4dd1bb70ac6cc9779f93bbc5ce`。
- 接入点：`scripts/ultimates/enter_formation.gd::_draw()`。
- 替代_trails的红黑draw_line；以from/to中点定位，旋转(to-from).angle()并沿x拉伸至原距离。以0.35-trail.life作为动画年龄，16fps单次0.25秒后最后一帧在剩余0.1秒淡出；保留瞬移、_strike判伤、15刀上限、无敌与_trails回收。
- 最近邻采样；保持透明，不把画布矩形视为碰撞。坐标/尺度预览为离线示意，实际范围与遮挡需游戏确认。

## 游戏验收待办

逐技能比较新旧表现、检查目标与预警可读、正确播放方式、真实范围裁切、场景切换清理和密集战斗性能。本轮未运行游戏，全部运行项未测。不得因正式文件存在标记接入或游戏通过。


## 2026-10-19 代码接入与受控运行验收更新

用户追加授权后已完成本任务代码接入；全部14项在独立提交副本中完成626项专项检查和46张实际Godot Game截图复核，工作区现有战斗回归997项通过。正式PNG哈希未变。完整手动通关、长期平衡及其他设备未测。以[本轮验收记录](../taskJ1_dimension_2026-10-19/integration_2026-10-19/README.md)为当前状态；上文制作阶段的“尚未接入/未运行”保留为历史记录，不代表当前仍未接入。
