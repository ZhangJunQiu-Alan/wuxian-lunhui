from pathlib import Path
import json,html,collections,hashlib
p=Path(__file__).resolve().parent.parent
load=lambda name:json.loads((p/name).read_text())
logic=load('results/release_logic/acceptance.json');flow=load('results/flow_final/playthrough.json');fast=load('results/release_flow_v2/playthrough.json');soak=load('results/soak_final/soak.json')
points=collections.Counter(x['kind'] for x in logic['damage_points'])
summary={'status':'functional_pass_performance_pending','logic':{'checks':logic['checks'],'failures':logic['failures'],'cases':len(logic['cases']),'damage_samples':dict(points)},'real_time_flow':{k:flow[k] for k in ['wall_seconds','level_seconds','invincible','muted','max_enemies','frame_ms_p95','frame_ms_p99','frame_ms_max']},'accelerated_current_flow':{k:fast[k] for k in ['wall_seconds','level_seconds','headless','invincible','muted','max_enemies']},'long_soak':{'wall_seconds':soak['wall_seconds'],'violations':soak['violations'],'reentries':len(soak['reentry']),'all_exits_clean':all(x['enemies_left']==x['hazards_left']==x['fragments_left']==x['orphans']==0 for x in soak['reentry']),'hub_nodes':[x['nodes'] for x in soak['reentry']],'hub_resources':[x['resources'] for x in soak['reentry']]},'exclusive':{},'limitations':['No natural clear claim','Master mute: no auditory validation','Earlier stress frame times contaminated by concurrent Godot runs','cpu_profile zone wrapper reset callbacks: invalid diagnostic','M art is owned by another task']}
for name in ['exclusive_odin','exclusive_skadi']:
 f=p/f'results/{name}/soak.json'
 if f.exists():
  s=json.loads(f.read_text());summary['exclusive'][name]={'completed':s.get('completed',False),'violations':s['violations'],'stages':[{k:x[k] for k in ['boss','p50_ms','p95_ms','p99_ms','max_ms','max_enemies','unpaused_seconds','wall_seconds']} for x in s['stages']]}
(p/'verification.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False))
(p/'README.md').write_text(f'''# 第三关独立验收 · 2026-10-20

功能验收通过；独占性能复测待收齐结果。没有自然通关或整体验收通过的声明。

| 执行项目 | 实际结果 | 证据 |
|---|---|---|
| 地图、战斗、逐点判伤、暂停、结局 | {logic['checks']}项0失败；28/28结局情形；{len(logic['damage_points'])}条实际判伤样本 | results/release_logic/acceptance.json、logs/release_logic.log |
| 实际60秒暂停 | 遭遇89秒、关卡269秒冻结，恢复后按游戏时钟判截止时间 | release_logic.log 中 PAUSE_MEASURE |
| 正常伤害吞噬/复活/死亡 | 3项0失败，关闭无敌后第一次复活，第二次死亡，重复回调不重复结算 | results/death/death.json及两张实际截图 |
| 战斗回归 | 997项0失败，最新限频及缓存版本 | logs/release_combat_v3.log |
| Boss动作回归 | 572项0失败 | logs/release_boss.log |
| 60张卡牌及三种窗口 | 中英文各1840项0失败，选择与回退通过 | results/release_card_zh/、results/release_card_en/ |
| 翻译覆盖 | 834条，缺0条 | logs/release_translations.log |
| 奥丁重叠阵及优化等价 | 17项0失败：1阵=24阵、亚秒限频、满秒恢复、传播上限、直射保留、过期历史清理；移动与死亡后的伤害/印记等价 | results/odin_pending/odin.json |
| 永冬削弱及冰面 | 日志含清理13项0失败；平衡数据文件11项0失败 | results/skadi_final/balance.json、logs/skadi_final.log |
| 三种窗口真实渲染 | 64张已实际查看；63张游戏相机均在地图内，主神空间1张不适用 | screenshots/release/captures.json、previews/release_*.jpg |
| 实时完整流程 | 墙钟{flow['wall_seconds']:.3f}秒，关卡{flow['level_seconds']:.3f}秒；三个Boss按时钟登场并死亡，五段结局、单次存档；无敌/静音/合法自动输入 | results/flow_final/、logs/flow_final.log |
| 当前代码加速完整流程 | 墙钟{fast['wall_seconds']:.3f}秒，关卡{fast['level_seconds']:.3f}秒；三Boss死亡、命运2/3、单次存档；固定步长headless，无敌/静音 | results/release_flow_v2/、logs/release_flow_v2.log |
| 长时与反复进出 | {soak['wall_seconds']:.3f}秒；4场景各225秒；12次真正返回主神空间后，敌人/火焰/碎片/孤儿均0；主神空间325节点、277资源恒定 | results/soak_final/soak.json |

## 平衡修改

- 永冬：单跳倍率0.30→0.15，周期0.50→0.75秒，最短周期0.45秒；每跳1层霜冻，不再吃冰箭寒意额外层数。12秒对照普通冷却DPS9.6→3.2，约降67%；极端0.1冷却下DPS5.2。保留700觉醒范围。
- 同位置30像素内冰面刷新既有区域；静止叠冰从约22层降为1层。
- 九夜符文：每名敌人所有重叠阵共用1秒阵伤/印记间隔；觉醒传播印记另有每敌人1秒上限。直射与共鸣保留自身结算。普通阵印记和觉醒传播是两条各自限频的来源。
- 已传播对象同帧不再反复遍历。144次引爆、120敌人、24阵的等价微基准：朴素344561微秒→优化10197微秒；此数不是整局帧率。

## 未通过及边界

- 旧长测苏尔特场景225.291墙钟秒只推进167.673游戏秒，p95=201.068毫秒，不能判性能通过；当时多个Godot进程并发。原始失败保留，独占复测单列。
- 四神全部觉醒的合成极限构筑超过实际选卡预算，保留作诊断，不作为可达构筑验收。
- cpu_profile的GodZone计时包装在换脚本时重置回调，该记录无效，不用于伤害或性能结论。
- complete_logic测试禁用物理体后手动调用move_and_slide，曾产生引擎报错和8个假失败；修正为真实物理帧处理输入后，walk与release_logic已干净重跑通过。
- 早期固定步长退出出现音频资源未排空；最终工具停止/释放音频并等待真实200毫秒让混音线程排空，最终中英文卡牌、战斗及完整流程日志干净。实际场景资源趋势另由12次返回验证。
- 实时完整流程进程早于后续永冬/奥丁修改启动；其时长与画面只证明该进程版本。最新版平衡由专项、战斗回归及当前加速完整流程验证，不追认旧进程加载新代码。
- 最新画面可包含M代理更新的道路、剑弧、援助素材。本批没有重新制作、覆盖或宣称拥有它们；旧画面中的美术问题不代表当前M素材结论。
- Master静音保留实际音频流和声道池；没有听感验收。所有存档隔离在本目录。没有提交或推送Git。

[实际画面图库](gallery.html) · [接入范围](integration.md) · [结构化汇总](verification.json) · [初始工作区](baseline.json) · [当前源码哈希](source_hashes.json)
''')
blocks=[]
for folder,title in [('screenshots/release','三窗口受控画面：64张已查看'),('results/death','实际吞噬判伤：复活与死亡'),('results/flow_final','实时无敌完整流程截图')]:
 cards=''.join(f'<figure><a href="{html.escape(str(f.relative_to(p)))}"><img loading="lazy" src="{html.escape(str(f.relative_to(p)))}"></a><figcaption>{html.escape(f.name)}</figcaption></figure>' for f in sorted((p/folder).glob('*.png')))
 blocks.append(f'<h2>{title}</h2><div class="grid">{cards}</div>')
(p/'gallery.html').write_text('<!doctype html><meta charset="utf-8"><title>第三关独立验收画面</title><style>body{background:#101419;color:#e1e6eb;font:15px system-ui;margin:28px}a{color:#e4bd74}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:16px}figure{margin:0}img{width:100%}figcaption{padding:8px;color:#b5bfcb}h2{margin-top:36px}</style><h1>第三关 · 实际Godot渲染证据</h1><p>受控状态、无敌与实际伤害分开记录。截图证明画面，不代表自然通关；密集性能独占复测单列。<a href="README.md">验收说明</a></p>'+''.join(blocks))
print('reports written',dict(points))
