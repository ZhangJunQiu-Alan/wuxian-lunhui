from pathlib import Path
import json,hashlib,shutil,html
from PIL import Image

BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):(BASE/p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
checks=[]
def check(n,ok,d=None):checks.append(dict(check=n,passed=bool(ok),detail=d))
plan=json.loads((ROOT/'assets/source/taskK_contract_2026-10-20/production_plan_v1.2.json').read_text())
spec=[r for r in plan['assets'] if r.get('task')=='K3' and r.get('decision')=='new_proposed']
versions={'surtr_windup':'v02','surtr_attack':'v02','surtr_sword_arc':'v02','surtr_gate':'v03','freyr_heal':'v02'}
assets=[]
for r in spec:
    name=r['id'];v=versions.get(name,'v01');size=r['frame_size'];n=r['frames'];file=BASE/f'candidates/{name}_{v}.png';im=Image.open(file).convert('RGBA')
    check(name+':RGBA',Image.open(file).mode=='RGBA');check(name+':sheet',im.size==(size[0]*n,size[1]));frames=[];colors=set()
    binary=name.startswith('freyr') or name in ['surtr_idle','surtr_move','surtr_windup','surtr_attack','surtr_plant','surtr_summon']
    for i in range(n):
        f=im.crop((size[0]*i,0,size[0]*(i+1),size[1]));frames.append(f);data=set(f.get_flattened_data());colors|={p[:3] for p in data if p[3]};box=f.getchannel('A').getbbox()
        check(f'{name}:{i}:alpha',all(p[3] in [0,255] for p in data) if binary else len({p[3] for p in data})<=8)
        check(f'{name}:{i}:transparent_rgb_zero',all(p[:3]==(0,0,0) for p in data if not p[3]))
        check(f'{name}:{i}:2pxmargin',box is not None and box[1]>=2 and box[3]<=size[1]-2 and (name=='surtr_firewall_band' or box[0]>=2 and box[2]<=size[0]-2),box)
        if binary:check(f'{name}:{i}:ground_baseline',box[3]==size[1]-2,box[3])
    check(name+':max48rgb',len(colors)<=48,len(colors));check(name+':unique_frames',len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})==n)
    gifs=[]
    if n>1:
        for kind in ['native','slow8']:
            gpath=BASE/f'previews/{name}_{v}_{kind}.gif';g=Image.open(gpath);check(name+':'+kind+':frames',g.n_frames==n);ms=[]
            for i in range(g.n_frames):g.seek(i);ms.append(g.info.get('duration',0))
            check(name+':'+kind+':timing',all(x>0 for x in ms),ms);gifs.append(dict(file=str(gpath.relative_to(BASE)),durations_ms=ms,note='10ms GIF quantization; single animation lastframe600ms extra reviewhold, not gameplay delay'))
    prompt=BASE/f'records/prompt_{name}_{v}.json';raw=BASE/f'originals/{name}_{v}_raw.png';check(name+':actual_source',prompt.exists() and raw.exists())
    assets.append(dict(id=name,formal_path=r['path'],frame_size=size,frames=n,fps=r['fps'],loop=r['loop'],anchor=r['anchor_px'],rgb_count=len(colors),alpha_policy='binary' if binary else '8levels',
                       candidate=str(file.relative_to(BASE)),approved='approved/'+name+'.png',sha256=sha(file),raw=str(raw.relative_to(BASE)),raw_sha256=sha(raw),prompt=str(prompt.relative_to(BASE)),preview_gifs=gifs,
                       additional_source='originals/surtr_sword_arc_peak_v03_raw.png; records/prompt_surtr_sword_arc_peak_v03.json' if name=='surtr_sword_arc' else None,
                       license='assets/LICENSES.md; OpenAI Terms Content/Ownership; output nonexclusive',game_acceptance='not_tested'))
effects=json.loads((BASE/'records/effects_normalization.json').read_text())
for r in effects:
    for i,x in enumerate(r['protected_occupied']):check(f'{r["id"]}:{i}:protected_empty',x==0,x)
geometry=json.loads((BASE/'records/render_geometry_audit.json').read_text())
for r in geometry:check('render:'+r['id'],r['passed'],r.get('occupied'))
captures=json.loads((BASE/'preview_project/captures/result.json').read_text())['captures'];check('81captures',len(captures)==81 and all(r['save_error']==0 for r in captures))
log=(BASE/'records/godot_fixture_hue_final.log').read_text();check('final_fixture_no_script_error','SCRIPT ERROR' not in log and 'ERROR:' not in log)
baseline=json.loads((ROOT/'assets/source/taskK_contract_2026-10-20/records/baseline.json').read_text());changed=[p for p,h in baseline.items() if not (ROOT/p).exists() or sha(ROOT/p)!=h];check('1453_preexisting_inputs_unchanged',not changed,changed)
check('14PNG51frames',len(assets)==14 and sum(a['frames'] for a in assets)==51)
audit=dict(task='K3',checks=len(checks),failures=sum(not r['passed'] for r in checks),items=checks,scope='asset and isolated Godot rendering only; not Game scene')
dump('records/final_audit.json',audit)
if audit['failures']:raise SystemExit(json.dumps([r for r in checks if not r['passed']],ensure_ascii=False))
for r in assets:
    source=BASE/r['candidate'];target=ROOT/r['formal_path'];target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists() and sha(target)!=r['sha256']:raise SystemExit('refuse existing different formal '+str(target))
    shutil.copyfile(source,BASE/r['approved'])
    if not target.exists():shutil.copyfile(source,target)
reuse=[dict(path=r['path'],sha256=sha(ROOT/r['path']),decision='reuse_unchanged') for r in plan['assets'] if r.get('task')=='K3' and r.get('decision')=='reuse_unchanged']
dump('manifest.json',dict(task='K3',status='art_delivered_self_checked_not_game_integrated',formal_png=14,frames=51,assets=assets,reused=reuse,contract=json.loads((BASE/'records/contract_ref.json').read_text()),generated_originals=len(list((BASE/'originals').glob('*_raw.png'))),rejected=json.loads((BASE/'records/rejections.json').read_text()),self_check='passed',game_acceptance='not_tested'))
dump('completion.json',dict(task='K3',production='complete',formal_png=14,frames=51,self_check='passed',isolated_godot='81 captures; rotated arc, two wall radii, safe grid and allies',code_integration='not_implemented',game_acceptance='not_tested',remaining=['Surtr AI allskills','60/25 percent transitions','actual safegrid damage','Freyja faith and awakening aid condition','healing and full battle','dense scene/full third-level ending'],git_commit=False,git_push=False))
page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>K3苏尔特</title><style>body{background:#121721;color:#dce5e8;font:16px/1.6 system-ui;margin:30px}img{max-width:100%;height:auto;image-rendering:pixelated}a{color:#9cd7cd}section{margin:32px 0}.flex{display:flex;flex-wrap:wrap;gap:20px}.flex img{max-width:400px}</style><h1>K3 苏尔特与弗雷援助</h1><p>14PNG /51帧；身体单帧320×320，保持原192px角色尺度。素材自检通过；未接入第三关。</p><p><a href="manifest.json">清单</a> · <a href="integration.md">接入</a> · <a href="records/final_audit.json">自检</a> · <a href="records/rejections.json">退回稿</a></p>'
for r in assets:
    name=r['id'];v=versions.get(name,'v01');page+=f'<section><h2>{name}</h2><p>{r["frame_size"]} / {r["frames"]}帧 / {r["fps"]}fps</p>'
    if r['frames']>1:page+=f'<div class="flex"><div>原速<br><img src="previews/{name}_{v}_native.gif"></div><div>8fps检查<br><img src="previews/{name}_{v}_slow8.gif"></div></div>'
    page+=f'<p><a href="{r["candidate"]}">原尺寸帧条</a> · <a href="{r["raw"]}">生成原图</a> · <a href="{r["prompt"]}">实际Prompt</a></p></section>'
page+='<h2>独立Godot合成，不是实际关卡</h2><div class="flex">'+''.join(f'<img src="previews/fixture_{n}_native.gif">' for n in ['grid','wall_r150','gate','freyr_heal'])+'</div><p><a href="previews/godot_all_cases.png">81张渲染总览</a></p><h2>火墙材料4×4重复</h2><img src="previews/firewall_repeat_4x4.png"></html>'
(BASE/'gallery.html').write_text(page)
dump('source_inventory.json',[dict(path=str(p.relative_to(BASE)),sha256=sha(p)) for p in sorted(BASE.rglob('*')) if p.is_file() and p.name!='source_inventory.json' and '.godot' not in p.parts])
print(json.dumps(dict(formal_png=14,frames=51,checks=len(checks),failures=audit['failures'])))
