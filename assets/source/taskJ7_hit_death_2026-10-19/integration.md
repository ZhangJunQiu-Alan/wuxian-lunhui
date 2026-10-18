# J7 逐文件接入交接


## 最终文件合同

### `assets/sprites/effects/hit_claw.png`

- 单帧 32×32，4帧，16fps，单次。
- 锚点 `[16.0, 16.0]`；正式SHA256：`671207266a071a053c2b9799f84001a7b09723b8ac7dbc6e75a5c058db7dce4b`。
- 接入点：`scripts/effects/fx_layer.gd::_draw_mark()`。
- 仅kind=claw改为现有FxLayer节点内draw_texture_region，保持MAX_MARKS=120。以m.pos中心、m.angle旋转，沿x按m.length缩放。为贴图claw/bite单独记录0.25秒视觉duration，按16fps单次播放4帧；原通用slash仍用MARK_LIFE=0.22。此寿命只影响痕迹绘制与回收，不是攻击判伤窗口；保留粒子/数字集中绘制。
- 最近邻采样；保持透明，不把画布矩形视为碰撞。坐标/尺度预览为离线示意，实际范围与遮挡需游戏确认。

### `assets/sprites/effects/hit_bite.png`

- 单帧 64×64，4帧，16fps，单次。
- 锚点 `[32.0, 32.0]`；正式SHA256：`1e0e0b18432621b5d502d6936867c51cd5b306683651c3cd097a86e28c6feadc`。
- 接入点：`scripts/effects/fx_layer.gd::_draw_mark()`。
- 仅kind=bite替代上下draw_arc；m.pos中心、m.angle旋转，按m.length缩放，支持m.color染色。保留上下合拢的反馈和MAX_MARKS=120；与hit_claw共用独立0.25秒贴图duration，16fps单次4帧，原通用slash的0.22秒不变。新贴图不定义咬击判伤，也不新增节点。
- 最近邻采样；保持透明，不把画布矩形视为碰撞。坐标/尺度预览为离线示意，实际范围与遮挡需游戏确认。

### `assets/sprites/effects/death_shards.png`

- 单帧 32×32，4帧，16fps，单次。
- 锚点 `[16.0, 16.0]`；正式SHA256：`7e8fd5876468702299206d8f6183aafb42f90a1d25e304a10492340e33eda0e8`。
- 接入点：`scripts/effects/fx_layer.gd::_draw / burst()`。
- 提供可选一次性抽象死亡碎片条，不把现有800粒子逐个换为完整爆炸或新增节点。实际触发点是scripts/entities/enemy.gd::_die()中的FxLayer.burst；应只在该处切换为一个集中绘制的death标记（复用MAX_MARKS=120上限，视觉寿命0.25秒），沿用敌人color染色、普通/精英尺度区分；只播一组16fps4帧，结束回收。保留MAX_PARTICLES=800及所有非死亡burst，不能全局替换。性能未实测前可继续保留现有程序碎片；记录取舍后才启用此文件。
- 最近邻采样；保持透明，不把画布矩形视为碰撞。坐标/尺度预览为离线示意，实际范围与遮挡需游戏确认。

## 游戏验收待办

逐技能比较新旧表现、检查目标与预警可读、正确播放方式、真实范围裁切、场景切换清理和密集战斗性能。本轮未运行游戏，全部运行项未测。不得因正式文件存在标记接入或游戏通过。


## 2026-10-19 代码接入与受控运行验收更新

用户追加授权后已完成本任务代码接入；全部14项在独立提交副本中完成626项专项检查和46张实际Godot Game截图复核，工作区现有战斗回归997项通过。正式PNG哈希未变。完整手动通关、长期平衡及其他设备未测。以[本轮验收记录](../taskJ1_dimension_2026-10-19/integration_2026-10-19/README.md)为当前状态；上文制作阶段的“尚未接入/未运行”保留为历史记录，不代表当前仍未接入。
