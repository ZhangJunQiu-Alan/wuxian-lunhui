# 本轮接入改动

以本目录 before/ 和 baseline_hashes.json 为接入前边界；共享目录在本轮之前就有第三关代码与其他代理未提交的修改。本表只说明本任务追加内容。

| 文件 | 本任务改动 |
|---|---|
| scripts/world/vigrid_map.gd | 道路切换ash_road、登记12边缘；焦草与裂地读_02。保留路线、障碍、相机和伤害规则 |
| scripts/bosses/surtr.gd | 横扫改surtr_sword_arc_large，去掉旧128px图的60px半径放大常量，按Vector2.ONE绘制 |
| scripts/effects/boss_fx.gd | 在既有FAST表追加新大剑弧，16fps/4帧，不改变既有表项 |
| scripts/effects/fx_layer.gd | 新增四神纹理缓存、8帧12fps队列、32实例上限、按生命期移除及1×绘制；同文件中MAX_RINGS与opacity优化来自并行代理，本任务保留 |
| scripts/world/vigrid_battle.gd | 四位神请求新援助FX；弗蕾亚视觉/事件中心与原伤害中心统一到玩家位置；有专属图时不叠通用ring/burst，无图仍fallback；既有伤害治疗数值和时机保留 |
| tools/test_vigrid.gd | 原地图断言使用新焦草ID；其他代理同文件追加/修复内容保留 |
| tools/test_vigrid_art.gd | 72项正式调用、范围/帧规格、生命周期/暂停/队列上限/重入清理专项 |
| tools/review_vigrid_art.gd | 两种窗口共30张正式Game接入截图，调用实际Surtr._sweep、VigridBattle周期派发与FxLayer；没有素材阶段的预览绘制器 |
| tools/acceptance_vigrid_visual.gd | 截图夹具禁用角色武器和神术主动攻击，避免受控Boss姿态在截图等待期间被误杀；保留真实Boss运动与技能。检查中途加入的神术也禁用主动处理 |

新aid图像头两帧是落下动作，但本轮不擅自添加延迟判伤：原版援助在请求时即时生效，接入后保持该时机。图像不充当新的伤害预警。

为避免旧回归脚本把报告写回已归档批次，tests/保存了仅替换输出路径的Boss/J/I脚本副本；执行的是当前真实Game节点。源素材/玩法没有为了测试被替换。非图形测试在固定快照运行；压力与实时通关串行执行，均使用独立存档与设置、Master静音但保留真实音频流。

本轮未修改scenes/或project.godot；未stage、commit、push。before_long_snapshot_scripts.zip保存被中断的上一份长测代码，final_snapshot_hashes.json绑定本轮最终测试代码，不能用前一份长测未完成数据代替结果。

截图夹具补充：tools/acceptance_vigrid_run.gd 仅在final_result截图前等0.8真实秒，让现有淡入结束。未改变机器人操作、实际战斗或结算。该末期夹具改动绑定results/final_capture_fixture_change.json，并另跑完整受控窗口复核。

补充结算布局：tools/test_vigrid_result_layout.gd加载真实HUD、JSON结果及四神构筑，在1280×720、960×540、1600×900验证操作按钮都在画布内并截图；8项0失败。首轮清理夹具BossDB未初始化产生报错，已修正后干净重跑。原始全流程末尾截图仍保留为过渡/待布局抓图，不标其布局通过。
