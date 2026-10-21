from pathlib import Path
import hashlib
import html
import json

B=Path(__file__).parent
summary=json.loads((B/'results/final_summary.json').read_text())
soak=summary['long_runs']['soak_final']
normal=summary['long_runs']['realtime_meta_final']
controlled=json.loads((B/'results/controlled_render_final/playthrough.json').read_text())
assert soak['complete'] and len(soak['stages'])==4 and soak['reentries']==12
assert controlled['invincible'] and controlled['events'][-1]['cleared_vigrid']
fmt=lambda value: f'{int(value)//60:02d}:{int(value)%60:02d}'
rows='\n'.join(f"| {s['id']} | {s['checks']:,} | 0 |" for s in summary['suites'])
performance='\n'.join(f"| {s['boss']} | {s['wall_seconds']:.2f} | {s['unpaused_seconds']:.2f} | {s['p95_ms']:.2f} | {s['p99_ms']:.2f} | {s['max_ms']:.2f} |" for s in soak['stages'])
text=f'''# M 正式接入与完整测试结果

2026-10-20。**M01～03正式代码接入完成。技术回归、受控流程、图像接入与清理检查通过；正常伤害机器人通关未通过，不标整体游戏验收通过。** 未提交或推送Git。

## 文件与正式接入

- 地图正式读取ash_road、12张碎边过渡、burnt_grass_02及cracked_lava_02，路线/障碍/相机参数保留。
- 苏尔特正式调用surtr_sword_arc_large，640×640原生1×，4帧16fps，R290/半角1.05。
- 四神援助正式从VigridBattle周期逻辑进入FxLayer：8帧12fps、1×、持久纹理缓存、上限32实例、单次清理；有专属图时去掉通用ring/burst。
- 弗蕾亚的视觉和事件中心与其伤害中心同为玩家；另三位使用本次选中的密集敌人点。不改伤害、治疗、控制、冷却或延迟判伤数值。
- 20张正式PNG哈希保持素材交付版本；Godot已导入，mipmap关闭。详见results/formal_asset_import_audit.json。
- 精确改动和归属见changes.md；共享目录其他代理的修改保留，没有归为本代理成果。

## 自动化回归

最终固定快照八组共 **{summary['assertions_total']:,} 项断言，0失败**。最终日志没有脚本/资源加载错误或退出泄漏报错。断言数包括多点几何检查，不等同于同数量独立玩法案例。

| 组 | 断言数 | 失败 |
|---|---:|---:|
{rows}

独立acceptance覆盖地图连通/障碍、实际安全格与火墙叠加伤害、三Boss暂停恢复、真实60秒暂停、八神援助、返回重开、重复回调、奖励/存档，以及K7全部28种结局情形。新M专项另外验证四神实际派发、位置、帧规格、末帧和清理、32实例上限、暂停、场景重入，以及真正Surtr._sweep发出的新剑弧。

另有三窗口结算布局补充检查8项0失败（screenshots/result_layout_final/layout.json）；这是实际HUD布局夹具，不能冒充完整流程中的自然结算截图。

报告：results/final_regression_summary.json、results/final_summary.json、logs/final_*.log。翻译检查834条、缺0。

## 完整流程：分别记录

| 运行 | 条件 | 实际结果 |
|---|---|---|
| 正常伤害、实际窗口实时 | 满级合法局外成长，枪手，固定seed，机器人正常移动/冲刺/大招/选卡；无无敌、无改时钟或Boss血量 | **未通关**。{fmt(normal['level_seconds'])}在苏尔特第二阶段阵亡；已击败巨蛇和芬里尔，托尔获救；378次血量下降事件。死亡结算、奖励与存档正常，日志干净 |
| 无敌、实际窗口固定60Hz加速模拟 | 同版正式Game，满局外成长，机器人输入，仅开启无敌；自然刷怪/Boss调度和实际攻击 | **受控完整流程通过**。{fmt(controlled['level_seconds'])}击败三个Boss，苏尔特60%/25%阶段触发，五段字幕后胜利结算，2/3命运、第三关通关存档；不是自然通关 |

受控胜利：击杀{controlled['result']['kills']}，等级{controlled['result']['level']}，本局奖励{controlled['result']['reward_points']}。没有用强制Boss掉血、直接切结局或跳时钟来代替这次完整流程。原始完整流程的结算抓图仍处于淡入或待布局状态，不能作为完整布局通过证据；另以实际HUD、四神构筑在三种窗口中逐项检查布局并截图。截图夹具现额外等待两个process帧，以便容器布局更新，不改变玩法。

记录：results/realtime_meta_final/playthrough.json、results/controlled_render_final/playthrough.json；截图在各自目录。早期旧快照的正常伤害固定步长通关不用于代替当前版实时阵亡结论。

## 350敌人密集与内存趋势

Apple M2、Godot4.7.2、实际Compatibility渲染器。四场景各90秒；合法四神构筑，一位觉醒，其余路径；为持续施法把普通敌人HP维持高值、Boss阶段受控、玩家无敌，Master静音但真实音频流继续运行。不是难度验收。

| 场景 | 墙钟秒 | 未暂停游戏秒 | p95 ms | p99 ms | 最大 ms |
|---|---:|---:|---:|---:|---:|
{performance}

全程含12次真实返回主神空间，共 **{soak['wall_seconds']:.2f} 秒**。返回后节点325恒定，资源首次275、后续稳定276；孤儿0，敌人/火焰/碎片残留0。RSS首次158.59MiB，预热后约135～136MiB，未见逐次累积增长。RSS是操作系统驻留量，不等于活跃堆大小。战斗内资源增加包含首次加载不同构筑素材，不能仅凭战斗资源曲线判泄漏。

声道池上限24，采样同时音效最多6条、同音最多3条，未越界。**未进行主观听感验收。**

峰值仍有284～331ms，统计包含截图/采样开销；p95约17～18ms也不能宣称所有场景稳定60fps。性能发行验收仍保留，不能把本机短段结果外推到其他硬件。原始样本和解释见results/soak_final/soak.json、results/memory_interpretation.json；图见results/soak_memory_trend.png。

## 画面与运行证据

正式接入测试已有两类画面：M的实际周期派发与剑弧/地面，及整关Boss/地图/结局画面。两种或三种窗口包含1280×720、960×540、1600×900。M截图没有使用素材阶段的预览绘制器；年龄和敌人/Boss状态受控，证明真实正式加载与绘制，不代表自然触发全覆盖。

screenshots/k_final_v3的64张截图和M接入30张图已检查尺寸、成功状态、相机可见矩形，0越界。最终补拍的M图独立列出，不与旧图重复累计成更多独立验收项。逐帧图/实际范围核对与生命周期断言互相补充。

## 剩余问题与明确边界

- 正常伤害实时机器人在苏尔特第二阶段阵亡；真人正常通关、构筑/难度/阶段节奏尚未验收。机器人失败不能单独证明应采用哪组平衡数值，本轮没有擅自改数值。
- 350敌人时仍有帧峰值，未达全设备稳定60fps验收；操作系统后台/采样/截图开销与实际发布性能需要区分。
- 手柄硬件、跨设备/DPI、导出包、实际音频听感没有在本轮验收。
- 早期长测虽退出0但缺完成标记和结果文件，已判未完成；旧并发截图停顿、headless截图等待及报告路径拼错的日志保留，不计为最终通过。早期附加神术比较工具的退出泄漏日志同样保留，最终八组与最终完整流程日志单独核实。

授权与版本：before/和baseline_hashes.json保留接入前状态；final_snapshot_hashes.json绑定267个文件的回归/长测版本。末期仅截图夹具等待及补充布局测试另记results/final_capture_fixture_change.json；不改变已测玩法。最终交付校验另附当前代码与快照差异，不能让共享工作区后续修改隐式继承本结果。
'''
(B/'RESULTS.md').write_text(text)
(B/'README.md').write_text('''# M 正式代码接入与测试

**接入完成；9,148项技术断言0失败，受控完整流程与350敌人/12次返回测试完成。正常伤害实时机器人未通关，整体游戏验收不标通过。**

- [完整结果与剩余问题](RESULTS.md)
- [实际改动及与其他代理的归属](changes.md)
- [浏览截图和内存趋势](gallery.html)
- [机器可读汇总](results/final_summary.json)
- [原始最终回归命令](final_logic_jobs.json)
- [长时实际命令与完成状态](final_long_test_status.json)

测试存档和设置均隔离在saves/；runtime/是本次冻结测试副本，由.gitignore排除。before/和patches/保留本代理接入前后证据。所有失败/未完成材料保留。本轮未提交或推送Git。
''')
parts=[]
for folder in ['screenshots/m_final','screenshots/k_final_v3','results/realtime_meta_final','results/controlled_render_capture','screenshots/result_layout_final']:
    directory=B/folder
    for p in sorted(directory.glob('*.png')):
        rel=str(p.relative_to(B));parts.append(f'<figure><a href="{html.escape(rel)}"><img loading="lazy" src="{html.escape(rel)}"></a><figcaption>{html.escape(rel)}</figcaption></figure>')
doc='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>M正式接入测试</title><style>body{background:#151a1e;color:#e4e9e5;font:16px/1.6 system-ui;margin:32px}a{color:#a6d3c4}main{max-width:1400px;margin:auto}figure{display:inline-block;vertical-align:top;width:46%;margin:1%}img{width:100%;image-rendering:pixelated}figcaption{font-size:12px;overflow-wrap:anywhere}</style><main><h1>M正式接入测试</h1><p>代码接入与技术回归完成；正常伤害实时机器人未通关。无敌受控流程通过，不能替代自然通关。</p><p><a href="RESULTS.md">完整测试结论</a> · <a href="changes.md">改动</a> · <a href="results/final_summary.json">JSON</a></p><a href="results/soak_memory_trend.png"><img src="results/soak_memory_trend.png"></a>'''+''.join(parts)+'</main></html>'
(B/'gallery.html').write_text(doc)
print('wrote RESULTS, README and gallery')
