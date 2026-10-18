# J4 逐文件接入交接


## 最终文件合同

### `assets/sprites/effects/ultimates/stonehenge_stone.png`

- 单帧 48×64，1帧，0fps，静态。
- 锚点 `[24.0, 62]`；正式SHA256：`405569397918a2c6f2ae7f1b3340d09809236c4a88a97e012cde3e008dca226f`。
- 接入点：`scripts/ultimates/stonehenge.gd::_draw()`。
- 替代立石的两个draw_rect；脚底锚点(24,62)定位base+drop+(0,14)，对应原矩形落地端。有效宽24/高60像素，建议0.75倍接近旧18×44外观，依据实景复核；保留原落地影子、drop轨迹、十根石、DROP_TIME=0.45、阻挡、弹幕拦截和吸血防护。
- 最近邻采样；保持透明，不把画布矩形视为碰撞。坐标/尺度预览为离线示意，实际范围与遮挡需游戏确认。

### `assets/sprites/effects/ultimates/stonehenge_lintel.png`

- 单帧 64×24，1帧，0fps，静态。
- 锚点 `[32, 15]`；正式SHA256：`45ea2219fd7400588eb1b9362aa66f4da2bef295310478aac73540b0a0c31cab`。
- 接入点：`scripts/ultimates/stonehenge.gd::_draw()`。
- 替代偶数立石到下一根的横石draw_line；绘制中心为(base+next)/2+(0,-32)，旋转(next-base).angle()，沿x拉伸使有效石体两端接到立石。有效图形60×14，横轴中点锚点(32,15)，高度缩放至原约9单位。仅_landed时显示，保持原最后1秒fade与阻挡逻辑。
- 最近邻采样；保持透明，不把画布矩形视为碰撞。坐标/尺度预览为离线示意，实际范围与遮挡需游戏确认。

### `assets/sprites/effects/ultimates/stonehenge_circle.png`

- 单帧 128×128，1帧，0fps，静态。
- 锚点 `[64.0, 64.0]`；正式SHA256：`725561e1e9b1b36ebf50b8c7888a66a4d9b3ec3d6825b09cdcaac2b1efba6df9`。
- 接入点：`scripts/ultimates/stonehenge.gd::_draw()`。
- 替代_landed后的低alpha填充底色，锚点中心，外缘按有效最大半径缩放至RADIUS=140；保留精确半径140的原程序细边界，装饰不能代表更大阻挡区。保持pulse和最后1秒fade，禁止用贴图alpha代替shields或碰撞，中心透明。
- 最近邻采样；保持透明，不把画布矩形视为碰撞。坐标/尺度预览为离线示意，实际范围与遮挡需游戏确认。

## 游戏验收待办

逐技能比较新旧表现、检查目标与预警可读、正确播放方式、真实范围裁切、场景切换清理和密集战斗性能。本轮未运行游戏，全部运行项未测。不得因正式文件存在标记接入或游戏通过。


## 2026-10-19 代码接入与受控运行验收更新

用户追加授权后已完成本任务代码接入；全部14项在独立提交副本中完成626项专项检查和46张实际Godot Game截图复核，工作区现有战斗回归997项通过。正式PNG哈希未变。完整手动通关、长期平衡及其他设备未测。以[本轮验收记录](../taskJ1_dimension_2026-10-19/integration_2026-10-19/README.md)为当前状态；上文制作阶段的“尚未接入/未运行”保留为历史记录，不代表当前仍未接入。
