# J8 接入合同（制作前固定，2026-10-19）

方案见effect_proposals.md。仅新增loki_wolf_breath，其他三个反馈保留现有程序绘制，不复用本任务名重画G4/G5。

正式文件：assets/sprites/effects/gods/loki_wolf_breath.png；96×64单帧，4帧横条，16fps单次，喷口锚点(4,32)，默认朝右，允许半透明，中心线沿+x。

目标：scripts/gods/loki.gd::_draw_wolf()现有_breath_flash分支。仅替代draw_colored_polygon(cone,...)，保留狼身体、火光、_wolf_pos、_breath_dir、_breath_flash及_tick_wolf中的0.45半角和BREATH_LENGTH=220判伤逻辑。用to_local(_wolf_pos)定位喷口，按_breath_dir.angle()旋转；贴图不得跟随狼身体face错误翻转。

最终素材的有效长度与宽度将在制作后测量。集成时均匀缩放使有效最远点对齐220游戏单位，并按以喷口为原点、半角0.45、半径220的扇形裁切。喷口之外的左侧必须透明。播放与原0.4秒显示窗口协调：0.25秒播完4帧，剩余窗口只对最后一帧淡出，不重复循环、不延长实际伤害窗口。以原节点绘制，不新增攻击节点或额外判伤。

静电：thor.gd::_draw的_links逐端点折线保留。光明：baldr.gd::_draw的ward弧、immune_time与_flash_show保留。猎物：skadi.gd::_draw的_prey半径标记和_snipe_line保留。现有baldr_glow等已归档主体效果不覆盖。

当前仅固定设计/制作合同，未接入代码，未运行游戏；本文件后续追加实际素材和自检结果，不能因方案存在标记游戏通过。

## 最终文件合同

### `assets/sprites/effects/gods/loki_wolf_breath.png`

- 单帧 96×64，4帧，16fps，单次。
- 锚点 `[4, 32]`；正式SHA256：`acfa9f957ef6bdb8ca6116441418c2769930eac45790a3077796bc0eb392242f`。
- 接入点：`scripts/gods/loki.gd::_draw_wolf()`。
- 只替代_breath_flash下的draw_colored_polygon(cone)，喷口(4,32)定位to_local(_wolf_pos)，沿_breath_dir.angle()旋转。按有效最远距离缩放至BREATH_LENGTH=220，并按喷口为圆心、半角0.45、半径220的扇形裁切。4帧16fps单次0.25秒，剩余原0.4秒窗口淡出末帧；狼身体、_tick_wolf判伤、_breath_flash、冷却和回收不改。
- 最近邻采样；保持透明，不把画布矩形视为碰撞。坐标/尺度预览为离线示意，实际范围与遮挡需游戏确认。

## 游戏验收待办

逐技能比较新旧表现、检查目标与预警可读、正确播放方式、真实范围裁切、场景切换清理和密集战斗性能。本轮未运行游戏，全部运行项未测。不得因正式文件存在标记接入或游戏通过。


## 2026-10-19 代码接入与受控运行验收更新

用户追加授权后已完成本任务代码接入；全部14项在独立提交副本中完成626项专项检查和46张实际Godot Game截图复核，工作区现有战斗回归997项通过。正式PNG哈希未变。完整手动通关、长期平衡及其他设备未测。以[本轮验收记录](../taskJ1_dimension_2026-10-19/integration_2026-10-19/README.md)为当前状态；上文制作阶段的“尚未接入/未运行”保留为历史记录，不代表当前仍未接入。
