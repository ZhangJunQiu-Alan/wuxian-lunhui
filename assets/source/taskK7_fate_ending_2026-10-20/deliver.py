from pathlib import Path
import json,hashlib,itertools
from PIL import Image,ImageDraw
B=Path(__file__).resolve().parent;R=B.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):(B/p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
checks=[]
def ck(n,ok,d=None):checks.append(dict(check=n,passed=bool(ok),detail=d))
timeline=json.loads((B/'ending_timeline.json').read_text());fates=json.loads((B/'fate_contract.json').read_text());world=(R/'docs/世界观设定.md').read_text();ck('world_hash_current',sha(R/'docs/世界观设定.md')==timeline['source_sha256']);ck('exactly5orderedbeats',[r['index'] for r in timeline['beats']]==list(range(5)));ck('uniqueids',len({r['id'] for r in timeline['beats']})==5)
for r in timeline['beats']:
 for line in r['text'].splitlines():ck('canonical_text:'+r['id']+':'+line[:8],line in world)
 ck(r['id']+':skippable',r['skippable'])
ck('loki_canonical',timeline['settlement']['loki_hint']['text'] in world);ck('actual3bossentry',timeline['entry']['required_boss_ids']==['jormungandr','fenrir','surtr'] and timeline['entry']['require_actual_deaths']);ck('noillustrations',timeline['presentation']['new_illustrations']==timeline['presentation']['new_character_sprites']==0);ck('manualreading',timeline['presentation']['manual_advance'] and not timeline['presentation']['auto_advance']);ck('skipsafe',timeline['presentation']['skip_entire_sequence'] and not timeline['presentation']['skip_changes_fate']);ck('noinvented_reward_formula',timeline['settlement']['reward_formula'].startswith('not_defined_here'));ck('thor90inclusive',fates['flags']['thor_saved']['inclusive_deadline_seconds']==90.0);ck('vidarodin','odin' in fates['flags']['vidar_intervened']['prerequisite']);ck('freyrfreyja','freyja' in fates['flags']['freyr_assisted']['prerequisite']);ck('lokiever',fates['flags']['ever_faith_loki']['monotonic'])
rows=json.loads((B/'preview_project/captures/result.json').read_text());ck('10captures',len(rows)==10)
for r in rows:
 p=B/'preview_project'/r['file'];im=Image.open(p);ck(r['file']+':saved',r['save_error']==0 and im.size==(r['actual_width'],r['actual_height']));ck(r['file']+':glyphs',not r['missing_characters']);ck(r['file']+':height',r['lines']*r['line_height']<=r['body_rect_height']);
log=(B/'records/godot_story.log').read_text();ck('fixture_noscripterror','SCRIPT ERROR' not in log and 'ERROR:' not in log)
refs=json.loads((B/'records/source_refs.json').read_text())
for r in refs:ck('source:'+r['path'],sha(R/r['path'])==r['sha256'])
scenarios=[]
for a,b,c in itertools.product([False,True],repeat=3):
 for loki in [False,True]:scenarios.append(dict(id=f'fates{int(a)}{int(b)}{int(c)}_loki{int(loki)}',input={'thor_saved':a,'vidar_intervened':b,'freyr_assisted':c,'ever_faith_loki':loki},expected_fate_count=int(a)+int(b)+int(c),expected_loki_hint=loki,game_execution='not_run'))
scenarios.extend([dict(id='thor_at90',faith='thor',encounter_unpaused_age=90.,expected=True,game_execution='not_run'),dict(id='thor_after90',faith='thor',encounter_unpaused_age=90.001,expected=False,game_execution='not_run'),dict(id='paused60seconds',faith='thor',encounter_unpaused_age=89.,wall_clock_age=149.,expected=True,game_execution='not_run'),dict(id='no_thor_faith',faith='odin',encounter_unpaused_age=40.,expected=False,game_execution='not_run'),dict(id='freyr_faith_not_freyja',faith='freyr',awakened=True,expected_freyr_assisted=False,game_execution='not_run'),dict(id='loki_lost_current_faith',ever_faith_loki=True,current_faith=[],expected_loki_hint=True,game_execution='not_run'),dict(id='new_run_reset',prior_flags=[True,True,True,True],expected_flags=[False,False,False,False],game_execution='not_run')])
for index in range(5):scenarios.append(dict(id='skip_at_'+str(index),beat=index,expected='same frozen result snapshot; no repeated rewards; preserve fate and loki hint',game_execution='not_run'))
dump('acceptance_cases.json',dict(scope='expected integration cases, not executed in production',cases=scenarios))
audit=dict(task='K7',checks=len(checks),failures=sum(not x['passed'] for x in checks),items=checks,scope='data/source integrity and independent text layout; integration cases NOT run');dump('records/final_audit.json',audit)
if audit['failures']:raise SystemExit(str([c for c in checks if not c['passed']]))
board=Image.new('RGB',(1280,720*5))
frames=[]
for i in range(5):
 im=Image.open(B/f'preview_project/captures/story_1280x720_{i:02d}.png').convert('RGB');board.paste(im,(0,720*i));frames.append(im)
board.save(B/'previews/storyboard_1x.png');frames[0].save(B/'previews/storyboard_preview.gif',save_all=True,append_images=frames[1:],duration=2000,loop=0)
page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>K7 结局分镜</title><style>body{background:#121721;color:#ddd;font:16px/1.7 system-ui;margin:30px}a{color:#9cd}img{max-width:100%}</style><h1>K7 结局文字与命运契约</h1><p>五段原文；0新增插画/人物/正式音频。分镜是独立Godot文本预览，游戏演出与跳过未实现。GIF仅展示五段，正式方案为手动继续。</p><p><a href="ending_timeline.json">五段数据</a> · <a href="fate_contract.json">命运契约</a> · <a href="integration.md">接入</a> · <a href="records/final_audit.json">自检</a> · <a href="acceptance_cases.json">待运行场景清单</a></p>'
for r in timeline['beats']:page+=f'<h2>{r["index"]+1} · {r["id"]}</h2><img src="preview_project/captures/story_1280x720_{r["index"]:02d}.png">'
page+='<h2>小窗口最后一页</h2><img src="preview_project/captures/story_960x540_04.png"></html>';(B/'gallery.html').write_text(page)
dump('records/visual_review.json',dict(viewed=['1280x720 survivors page','960x540 final page'],findings=['full canonical text legible','names intact','no missing glyphs reported in10renders','subtitle explicitly labels unintegrated fixture'],game_acceptance='not_tested'))
dump('manifest.json',dict(task='K7',production='complete_as_text_data_and_contract',new_formal_art=0,delivered_data=[dict(file=p,sha256=sha(B/p)) for p in ['ending_timeline.json','fate_contract.json','acceptance_cases.json']],reused=refs,independent_render_captures=10,self_check='passed',checks=len(checks),game_acceptance='not_tested'))
dump('completion.json',dict(task='K7',production='complete_as_text_data_and_contract',new_formal_art=0,self_check='passed',checks=len(checks),independent_text_renders=10,integration_cases=len(scenarios),integration_cases_executed_in_game=0,game_integration='not_implemented',game_acceptance='not_tested',remaining=['fate event flags','ending state machine and skip','Save and result fields','fate reward formula unspecified','full third-level victory playthrough'],git_commit=False,git_push=False))
dump('source_inventory.json',[dict(path=str(p.relative_to(B)),sha256=sha(p)) for p in sorted(B.rglob('*')) if p.is_file() and p.name!='source_inventory.json' and '.godot' not in p.parts]);print(json.dumps(dict(checks=len(checks),failures=audit['failures'],captures=len(rows),pending_game_cases=len(scenarios))))
