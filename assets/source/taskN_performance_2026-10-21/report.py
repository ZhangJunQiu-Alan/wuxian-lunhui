from pathlib import Path
import json, hashlib, difflib, zipfile
from datetime import datetime
from zoneinfo import ZoneInfo
p=Path(__file__).resolve().parent

def read(path):
 f=p/path
 return json.loads(f.read_text()) if f.exists() else None

def pressure(name):
 d=read('results/'+name+'/soak.json')
 if not d:return None
 return {'completed':d.get('completed',False),'wall_seconds':d.get('wall_seconds'),'violations':d['violations'],'stages':[{k:s[k] for k in ['boss','p50_ms','p95_ms','p99_ms','max_ms','frames','over_100ms','unpaused_seconds','wall_seconds','max_enemies']} for s in d['stages']],'returns':d['reentry']}
summary={'generated_at':datetime.now(ZoneInfo('Asia/Singapore')).isoformat(),'production_integration':bool((read('integration_status.json') or {}).get('production_integration',False)),'git_commit':False,'git_push':False,'pressure':{n:pressure(n) for n in ['baseline','baseline_seeded','final_extreme','reachable']},'technical_checks':read('results/regression_summary.json'),'realtime_command':read('realtime_command.json'),'checks':read('commands.json'),'normal_runs':{}}
for name in ['normal_meta_probe','normal_bare_probe','midgard_meta_probe','helheim_meta_probe','normal_realtime']:
 d=read('results/'+name+'/playthrough.json')
 if d:summary['normal_runs'][name]={k:d.get(k) for k in ['cleared_this_run','headless','wall_seconds','level_seconds','character','level_id','driver','invincible','meta_profile','muted','render_metrics_valid','render_intervals','frame_ms_p95','frame_ms_p99','frame_ms_max','damage_events','max_enemies','max_nodes','god_build','final_hp','max_hp','result']}
(p/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
lines=['# 性能与正常伤害流程续验 · 2026-10-21','','本报告仅记录实际执行的数据。密集性能仍需逐项判断；脚本退出0不等于帧率或整体验收通过。', '', '## 压力条件与结果','','- Apple M2 / Godot 4.7.2 / Compatibility真实窗口，最大60fps；各进程串行运行。','- baseline_seeded/final_extreme：350普通敌人、合法四神构筑、奥丁觉醒、小怪一百万HP、Boss HP维持；不作为数值/正常通关证据。','- reachable为早期候选的正常敌人HP对照，但每秒强制补满350，远高于正式刷怪率；它也属于合成负载，不能称自然场景。','- 卡顿目标参考p95≤33.3ms、p99≤50ms及游戏时间推进≥墙钟95%；此为本次技术检查目标，不宣称用户已冻结发行标准。','','| 记录 | Boss | p95 ms | p99 ms | 最大 ms | 游戏/墙钟 s |','|---|---|---:|---:|---:|---|']
for name,d in summary['pressure'].items():
 if not d:continue
 for s in d['stages']:
  lines.append(f"| {name} | {s['boss']} | {s['p95_ms']:.3f} | {s['p99_ms']:.3f} | {s['max_ms']:.3f} | {s['unpaused_seconds']:.2f}/{s['wall_seconds']:.2f} |")
lines+=['','## 回归检查','','| 项目 | 退出码 | 引擎错误 |','|---|---:|---|']
for row in summary['checks'] or []:lines.append(f"| {row['id']} | {row.get('exit_code','在运行')} | {row.get('engine_errors','待检查')} |")
lines+=['','## 正常伤害流程','','机器人仅操作移动/冲刺/大招/选卡，读取画面已揭示的Boss状态与危险区；没有HP、伤害、敌人、游戏时钟覆盖。满局外成长和未升级配置分别记录。固定初始种子不保证渲染随机反馈下逐帧重现。','','| 记录 | 关卡 | 本局胜利 | 游戏/墙钟 s | HP下降事件 |','|---|---|---|---|']
for name,d in summary['normal_runs'].items():lines.append(f"| {name} | {d['level_id']} | {d['cleared_this_run']} | {d['level_seconds']:.2f}/{d['wall_seconds']:.2f} | {d['damage_events']} |")
real=summary['normal_runs'].get('normal_realtime')
if real:
 intervals=real.get('render_intervals') or {}
 lines+=['','## 实时正常伤害结果与限制','',f"正式项目真实窗口实时通关：关卡{real['level_seconds']:.3f}秒；进程墙钟{summary['realtime_command']['wall_seconds']:.3f}秒（包含启动/退出）。满局外成长枪手，四神为托尔/奥丁/弗蕾亚/斯卡蒂，没有神明觉醒。本局命运1/3，2590击杀、40级、1455奖励；保存本局运行1次。正常输入、正常伤害、包含合法局外复活，没有测试无敌、HP/伤害/敌人/游戏时钟覆盖。",'',f"真正idle渲染回调间隔：p95={intervals.get('p95_ms')}ms，p99={intervals.get('p99_ms')}ms，最大={intervals.get('max_ms')}ms；{intervals.get('frames')}帧里{intervals.get('over_100ms')}次超过100ms。包含选卡/截图/存档等开销，未对每次尖峰单独归因，不宣称全程稳定60fps。旧frame_ms字段是物理回调间隔，不能冒充渲染帧率。",'','- 巨蛇201.22秒击败，芬里尔403.89秒击败（触发过束缚、吞噬及正常复活），苏尔特582.73秒击败。','- 苏尔特554.15秒进入60%阶段，561.36秒进入25%阶段；终焉之火实际烧5轮。结局由正常跳过/推进接口完成，最后结算截图已实际查看。','- 正常实时构筑没有觉醒奥丁，不能替代觉醒奥丁的百万HP压力负载。','- 满成长headless流程549.15秒通关；零成长193.77秒阵亡，不能据此宣称低成长已验收。第一、二关满成长正常伤害headless流程通过，不包含全部支线组合或真人体验。','- 密集压力K-QA-04保持未通过；完整游戏/真人/全构筑/设备/听感/发行验收未完成。']

lines+=['','## 版本与未采用方案','','- before/source.zip与baseline_hashes.json保留开始时的源码；candidate_v1～v5保留各候选。','- candidate_v5增加了符文阵目标缓存，22项等价检查通过，但整场密集负载收益不足，未作为最终实现。原始日志保留。','- 最终候选只改Game的位置校正及Enemy索引/查询；技能、伤害、冷却、范围、敌人数量上限和数值表未改。','- 初次spatial_v3曾有启动期编译错误，即使同时打印481检查0失败也不算通过；改为运行期加载后，spatial_v3_clean干净重跑。','- 被中断的check_runner.log只是修改串行调度前的等待进程，没有执行其后测试；使用check_runner_final.log。','- 原始失败、截图和不完整记录均保留，不用后续记录覆盖它们。','','实时首轮在约一分钟时主动中止，以补充独立渲染帧间隔计量；保留normal_realtime_incomplete，不计入完成通关。', '', '最终文件接入、完整测试结果和剩余问题以README.md及integration.md的最终记录为准。']
(p/'RESULTS.md').write_text('\n'.join(lines)+'\n')
with zipfile.ZipFile(p/'before/source.zip') as z:
 for name in ['scripts/game.gd','scripts/entities/enemy.gd']:
  old=z.read(name).decode().splitlines(True);new=(p/'candidate_final'/name).read_text().splitlines(True)
  target=p/'patches'/Path(name).with_suffix('.patch').name;target.parent.mkdir(exist_ok=True)
  target.write_text(''.join(difflib.unified_diff(old,new,fromfile=name+' before',tofile=name+' candidate')))
print('updated report, recorded suites:',len(summary['checks'] or []))
