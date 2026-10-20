# H0～H6 素材与代码收尾（2026-10-19）

用户本轮授权同时完成素材和代码。33张正式PNG未改像素或哈希；斯库尔嚎叫动作、海拉第一阶段弹体及28项Boss效果已接入。制作/文件自检完成、代码接入完成、Godot受控运行验证完成。完整手动通关、长时平衡、其他设备表现未测；未将其标记通过。G6/I/J/K/L不接管，未commit/push。

## 文件与代码

- [逐文件接入清单与代码哈希](integrated_files.json)。原图/候选/失败稿/manifest/README/gallery/integration均保留原H目录。
- `scripts/effects/boss_fx.gd`：缓存纹理、按源fps绘制、扇形/圆形裁切、沿动态圆弧铺波带和逐节铁链；缺图返回回退信号。
- `scripts/effects/fx_layer.gd`：短时Boss效果集中绘制，最多96项，按动画寿命清空，不为每次效果增加Node。
- 六Boss及哈提分身/冲击波/冰柱的实际技能挂接；角色碰撞/血量/速度/AI/冷却不改。
- 加姆驱散检查使用击退前距离；范围外保留buff，范围内驱散。三段扑击每段只生成一次咬痕。
- 赫列姆两缺口由同一GAP_HALF几何裁切；26px淡底带显示判伤厚度。盾弧放到前景，显示半径随192px身体避免遮挡，仅±1.3rad。
- 尼德霍格喷口/300px扇形、潜地隐藏和啃根状态保留；啃根绿流光前景显示，打断后立即停止。
- 海拉两侧纹理按分界裁切并平铺；安全圈亮线和圈外压暗保留；第二阶段仍为9枚原指甲弹。

## 自检和实际运行

|检查|结果|证据|
|---|---|---|
|正式PNG、118帧、56GIF|最终文件审计见链接|[审计](../records/final_delivery_audit.json)|
|专项行为/范围/回退/清理|572项断言，0失败|[结果](runtime_checks.json)、[日志](boss_art_test_final.log)|
|既有战斗回归|997项断言，0失败|[日志](combat_regression_final.log)|
|实际游戏视角|40张受控技能截图已查看|[图库](gallery.html)、[捕获记录](render_review.json)|
|350怪与40短效|见下方短测；效果清空到0，节点数不增长|[性能记录](performance.json)、[日志](performance.log)|
|范围外修改保护|原代码/场景/配置96文件对比，非本轮范围零变更|[范围检查](scope_check.json)|

专项目标包含：女巨人6格8fps/4格16fps、普通1倍与精英1.2倍；隐藏支线接受、首次击倒后逃跑替身仍加载动作、第二次击倒完成；六Boss关键判伤边界、赫列姆半血双波和变化缺口、加姆三段/四锁桩/范围内外驱散、尼德霍格潜地/6%打断/2秒硬直、海拉生死侧与登船/弹体区分；360方向检查纹理弧段与判伤缺口一致；96项效果上限/到期清空/缺图回退。

所有断言不是完整游玩证据。实际截图运行的是当前项目Game场景，使用测试驱动冻结/定位并受控触发技能；未声称人工连续打完六场Boss战。首轮第2关未解锁被回退第1关，已退回并在`first_run_fixture_rejected/`保留；最终解锁隔离测试存档后重跑，正确第2关暗地面。身体遮挡的中间稿保留在`second_run_layer_fix/`，修正后最终截图重新渲染。新增波带厚度最后复核见[单独捕获记录](wave_review.json)。

## 短时性能

Apple M2、Godot4.7.2、OpenGL Compatibility、1280×720，第2关。每阶段预热1.5秒、采样5秒；只描述本次机器短测，不能当作长局保证。

- 350_animated_sprites_no_fx：平均帧间隔13.1ms，期间帧率76.4，p95 25.84ms；效果峰值0，节点1589。
- 350_animated_sprites_40_fx：平均帧间隔11.98ms，期间帧率83.4，p95 24.25ms；效果峰值40，节点1589。
- 350_animated_sprites_no_fx_repeat：平均帧间隔11.65ms，期间帧率85.8，p95 16.07ms；效果峰值0，节点1589。
- 350_live_AI_no_fx：平均帧间隔13.74ms，期间帧率72.8，p95 24.47ms；效果峰值0，节点1589。
- 350_live_AI_40_fx：平均帧间隔6.9ms，期间帧率144.9，p95 7.61ms；效果峰值40，节点1589。

各阶段有预热/调度波动，不解释成新效果提升帧率。动画精灵对照与活跃AI对照分开；40效果同时活跃，节点保持1589，结束效果归零。原首轮未预热且关卡错误的性能记录已作废保留。

## 复跑

使用独立存档/设置参数，避免修改真实进度：

```sh
godot --headless --path . --script tools/test_boss_art.gd -- --save-file=res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/test_save.json --settings-file=res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/test_settings.cfg
godot --headless --path . --script tools/test_combat_regressions.gd -- --save-file=res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/regression_save.json --settings-file=res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/regression_settings.cfg
```

实际视角捕获工具`tools/review_boss_art.gd`（`--skip-stress`跳过旧首轮压力方式）；独立预热基准`tools/benchmark_boss_art.gd`。不需要浏览器运行这些Godot测试。

## 剩余边界

- 本轮素材/代码没有待接入文件；正式PNG均已Godot导入。静态女巨人PNG保留为后备，不替代已有行走/攻击动画。
- 完整手动通关与长期平衡、其他设备帧率仍未测试；由后续整体游戏验收覆盖。
- G6声音和I/J/K/L不在本轮；未修改其源码素材或接入代码。
- 浏览器以后按用户偏好默认内置；当前内置控制组件缺失的问题未在本轮修改设置或绕过。


## 最后入口和测试诊断

实际窗口入口以Godot Compatibility启动并运行120帧后退出，`startup_rendered_final.log`无Godot脚本错误或资源泄漏警告（保留macOS输入法mach port诊断）。快速headless/Dummy音频退出仍可出现hub.ogg的4对象/2资源回收警告；正常窗口未复现，详见startup.log/early_exit_verbose.log。尝试Audio._exit_tree清理未能消除，已撤回，scripts/core/audio.gd与本轮前哈希一致；尝试diff保留为audio_cleanup_attempt.diff。没有把无窗口快速退出标记成完全无警告。

既有回归一次精确1点伤害断言被前序信仰测试留下的随机暴击率干扰。已只在`tools/test_combat_regressions.gd::_test_zone`重置crit_chance为0，使该边界检查可重复；生产伤害逻辑没有改动。失败日志和修正记录保留，最终997项0失败。
