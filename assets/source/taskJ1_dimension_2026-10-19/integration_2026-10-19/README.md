# J1～J8 代码接入与受控运行验收

2026-10-19。14张正式PNG/49帧哈希不变，四个大招、双刃、新星、集中爪击/咬击/死亡、狼息已接入。其他J8反馈保留动态程序方案。用户本轮明确授权代码修改、验收、commit和push；此前仅素材权限的历史记录不代表本轮禁止代码。

## 已执行

- 共享工作区运行：621项初版专项通过，现有战斗回归997项0失败。
- 独立提交副本：从cff5bbd加仅J变更组装，最终626项专项0失败；没有依赖未提交的H/G6/玩法修改。测试实际Game节点、14资源、49帧相位、循环/单次、扇形边界、双刃冷却/一次伤害、新星一次命中、次元斩原时点/屏幕边界、骑兵原伤害/推进/清理、巨石阵落地/阻挡/远程拦截、狼息原判伤、狂热8秒、120标记上限和零新增节点。
- 实际Godot4.7.2/OpenGL Compatibility/Apple M2/1280×720渲染46张Game视角图，全部写出成功。逐张查看全部28张新表现图（含不同阶段/方向）及新旧对照，暂停覆盖和角色回退的中间稿不采用。最终渲染日志无GDScript或资源加载错误。
- 固定负载性能：350个动画敌人（AI停用以隔离绘制成本）、42骑兵和每次绘制恰好120标记，禁用自动渲染、每采样强制一次引擎绘制；每阶段1秒预热＋4秒测量，旧/新各两次。旧平均57.0/57.7FPS，新94.7/77.6FPS；节点均1985。新第二轮p95约20.14ms，高于旧约19.29ms，短测有抖动，不声称所有帧或长期帧率更好。停发后标记/粒子归零，节点数不增加。详见verified_commit/performance.json。
- 对比制作前函数：除绘制函数外，只改双刃纯视觉常量0.1→0.25秒、集中标记记录/死亡视觉分流；原攻击/伤害/冷却/AI函数未改。保留缺图几何回退。

## 证据

[验收JSON](acceptance.json) · [626专项](verified_commit/combat_art_checks.json) · [46截图清单](verified_commit/render_review.json) · [性能](verified_commit/performance.json) · [新旧对照图](final_before_after.png) · [仅J代码补丁](J_code_only.patch) · [函数变化](function_change_audit.json) · [失败验证记录](rejected_verification/README.md)

原始素材、实际Prompt、生成许可和拒绝版本在各J目录。当前验收不修改任何PNG像素。

## 实际接入

新增scripts/effects/combat_fx.gd统一14文件的帧相位、锚点和按真实扇形裁切。四个ultimate及两种weapon只替换局部绘制；集中FxLayer维持120标记上限，死亡不重复发旧碎片。loki只替换狼息纯色面；其他三类J8程序状态反馈保留。全部正式PNG提供Godot默认导入描述，最近邻沿用项目设置。

双刃动画16fps/4帧，仅将原_slash_time视觉寿命改为0.25秒，_timer与即时伤害不变；爪击/咬击/死亡单独0.25秒，通用slash0.22秒不变。双刃遮罩以实际_aim角度0.7半角、reach为界，独立于左右手±0.25偏转；狼息以_breath_dir、220长度、0.45半角裁切。圆环保留精确程序边界，石头/横石脚底和端点对齐；骑兵仍原14×3阵列，未新增42个节点。

## 未测边界

完整手动关卡通关、长期平衡、长时内存趋势、其他设备与导出包未测。本次通过的是J素材/接入/受控运行专项验收，不标记全游戏发行验收通过。浏览器不用于本次引擎验收，没有改变浏览器权限或绕过Work禁用。

## 复跑

在项目根运行本目录assemble_validation.py可按固定基线和仅J补丁重建runtime_commit。该副本为可重建缓存，不提交。第一次导入可能报告旧font导入映射，完成导入后再运行即可；最终运行必须检查日志。

```sh
python3 assets/source/taskJ1_dimension_2026-10-19/integration_2026-10-19/assemble_validation.py
godot --headless --path assets/source/taskJ1_dimension_2026-10-19/integration_2026-10-19/runtime_commit --editor --import
godot --headless --path assets/source/taskJ1_dimension_2026-10-19/integration_2026-10-19/runtime_commit --script tools/test_combat_art.gd -- --save-file=res://validation/save.json --settings-file=res://validation/settings.cfg
godot --path assets/source/taskJ1_dimension_2026-10-19/integration_2026-10-19/runtime_commit --script tools/review_combat_art.gd -- --save-file=res://validation/render_save.json --settings-file=res://validation/settings.cfg
godot --disable-render-loop --path assets/source/taskJ1_dimension_2026-10-19/integration_2026-10-19/runtime_commit --script tools/review_combat_art.gd -- --save-file=res://validation/benchmark_save.json --settings-file=res://validation/settings.cfg --benchmark
```

测试存档和设置只写独立副本validation，不使用玩家真实存档。
