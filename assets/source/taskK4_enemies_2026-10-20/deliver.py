from pathlib import Path
import json,hashlib,shutil,math
from PIL import Image,ImageDraw

BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):(BASE/p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
checks=[]
def check(n,ok,d=None):checks.append(dict(check=n,passed=bool(ok),detail=d))
spec=json.loads((BASE/'records/specification.json').read_text());assets=[]
for r in spec:
    if r.get('decision')!='new_proposed':continue
    name=r['id'];n=r['frames'];size=r['frame_size'][0];file=BASE/f'candidates/{name}_v01.png';im=Image.open(file).convert('RGBA');check(name+':RGBA',Image.open(file).mode=='RGBA');check(name+':sheet',im.size==(size*n,size));soft=name=='fire_giant_explosion';colors=set();frames=[]
    for i in range(n):
        f=im.crop((size*i,0,size*(i+1),size));frames.append(f);pixels=set(f.get_flattened_data());colors|={p[:3] for p in pixels if p[3]};box=f.getchannel('A').getbbox()
        check(f'{name}:{i}:alpha',len({p[3] for p in pixels})<=8 if soft else {p[3] for p in pixels}<={0,255})
        check(f'{name}:{i}:transparent_rgb',all(p[:3]==(0,0,0) for p in pixels if not p[3]))
        check(f'{name}:{i}:margin',box[0]>=2 and box[1]>=2 and box[2]<=size-2 and box[3]<=size-2,box)
        if not soft:check(f'{name}:{i}:ground_baseline',box[3]==size-2)
    check(name+':48rgb',len(colors)<=48,len(colors));check(name+':unique_frames',len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})==n)
    gifs=[]
    if n>1:
        for kind in ['native','slow8']:
            gpath=BASE/f'previews/{name}_v01_{kind}.gif';g=Image.open(gpath);check(name+':'+kind+':gif_frames',g.n_frames==n);ms=[]
            for i in range(g.n_frames):g.seek(i);ms.append(g.info.get('duration',0))
            check(name+':'+kind+':gif_timing',all(x>0 for x in ms));gifs.append(dict(file=str(gpath.relative_to(BASE)),duration_ms=ms))
    raw=BASE/f'originals/{name}_v01_raw.png';prompt=BASE/f'records/prompt_{name}_v01.json';check(name+':source',raw.exists() and prompt.exists())
    assets.append(dict(id=name,formal_path=r['path'],frame_size=[size,size],frames=n,fps=r['fps'],loop=r['loop'],anchor=[size//2,size-2] if not soft else [48,48],alpha_policy='8levels' if soft else 'binary',rgb_count=len(colors),candidate=str(file.relative_to(BASE)),approved='approved/'+name+'.png',sha256=sha(file),raw=str(raw.relative_to(BASE)),raw_sha256=sha(raw),prompt=str(prompt.relative_to(BASE)),preview_gifs=gifs,license='assets/LICENSES.md; OpenAI output ownership toextent law, nonexclusive',game_acceptance='not_tested'))
captures=json.loads((BASE/'preview_project/captures/result.json').read_text())['captures'];check('44isolated_captures',len(captures)==44 and all(r['save_error']==0 for r in captures))
log=(BASE/'records/godot_fixture_hue_final.log').read_text();check('final_fixture_no_script_error','SCRIPT ERROR' not in log and 'ERROR:' not in log)
baseline=json.loads((ROOT/'assets/source/taskK_contract_2026-10-20/records/baseline.json').read_text());changed=[p for p,h in baseline.items() if not (ROOT/p).exists() or sha(ROOT/p)!=h];check('1453inputs_unchanged',not changed,changed)
check('11PNG45frames',len(assets)==11 and sum(a['frames'] for a in assets)==45)
audit=dict(task='K4',checks=len(checks),failures=sum(not r['passed'] for r in checks),items=checks,scope='asset files and isolated Godot render only');dump('records/final_audit.json',audit)
if audit['failures']:raise SystemExit(json.dumps([r for r in checks if not r['passed']],ensure_ascii=False))
for r in assets:
    source=BASE/r['candidate'];target=ROOT/r['formal_path'];target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists() and sha(target)!=r['sha256']:raise SystemExit('refuse overwrite '+str(target))
    shutil.copyfile(source,BASE/r['approved'])
    if not target.exists():shutil.copyfile(source,target)
reuse=[dict(path=r['path'],sha256=sha(ROOT/r['path']),decision='reuse_unchanged') for r in spec if r.get('decision')=='reuse_unchanged']
reuse.append(dict(path='assets/sprites/effects/gods/loki_fire_patch.png',sha256=sha(ROOT/'assets/sprites/effects/gods/loki_fire_patch.png'),decision='reuse_unchanged_for_residual'))
dump('manifest.json',dict(task='K4',status='art_delivered_self_checked_not_integrated',formal_png=11,frames=45,assets=assets,reused=reuse,generated_originals=11,rejected_generations=0,self_check='passed',game_acceptance='not_tested'))
dump('completion.json',dict(task='K4',production='complete',formal_png=11,frames=45,self_check='passed',isolated_godot='44captures including4x4 composition, not a performance test',code_integration='not_implemented',game_acceptance='not_tested',remaining=['EnemyDB registrations','actual shield/charge rules','lowhealth rage','deathblast/residual damage','350enemy performance','thirdlevel spawn/balance'],git_commit=False,git_push=False))
board=Image.new('RGB',(1280,180*math.ceil(len(captures)/4)),'#121721');draw=ImageDraw.Draw(board)
for i,r in enumerate(captures):
    im=Image.open(BASE/'preview_project'/r['file']).convert('RGB');im.thumbnail((320,180),Image.Resampling.NEAREST);board.paste(im,((i%4)*320,(i//4)*180));draw.text(((i%4)*320+3,(i//4)*180+3),Path(r['file']).stem,fill='white')
board.save(BASE/'previews/godot_all_cases.png')
for k in range(2):board.crop((0,k*1080,1280,min((k+1)*1080,board.height))).save(BASE/f'previews/godot_cases_page{k+1}.png')
density=Image.open(BASE/'preview_project/captures/fire_giant_move_00.png').crop((650,300,1260,640));density.save(BASE/'previews/actors_4x4_context.png')
page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>K4敌人</title><style>body{background:#121721;color:#dce6e9;font:16px/1.6 system-ui;margin:30px}a{color:#99d4cf}img{image-rendering:pixelated;max-width:100%;height:auto}.flex{display:flex;flex-wrap:wrap;gap:20px}.flex img{max-width:384px}section{margin:32px 0}</style><h1>K4 第三关普通敌人</h1><p>11PNG /45帧；文件自检通过，独立素材渲染，未接入实际第三关。</p><p><a href="manifest.json">清单</a> · <a href="integration.md">接入</a> · <a href="records/final_audit.json">自检</a></p>'
for r in assets:
    n=r['id'];page+=f'<section><h2>{n}</h2><p>{r["frame_size"]} / {r["frames"]}帧 / {r["fps"]}fps</p>'
    if r['frames']>1:page+=f'<div class="flex"><div>原速<br><img src="previews/{n}_v01_native.gif"></div><div>8fps检查<br><img src="previews/{n}_v01_slow8.gif"></div></div>'
    page+=f'<img src="previews/{n}_v01_1x.png"><p><a href="previews/{n}_v01_4x.png">4倍逐帧</a> · <a href="{r["raw"]}">原图</a> · <a href="{r["prompt"]}">实际Prompt</a></p></section>'
page+='<h2>独立4×4角色合成，不是压力测试</h2><img src="previews/actors_4x4_context.png"><p><a href="previews/godot_all_cases.png">全部44张Godot截图</a></p></html>'
(BASE/'gallery.html').write_text(page)
dump('source_inventory.json',[dict(path=str(p.relative_to(BASE)),sha256=sha(p)) for p in sorted(BASE.rglob('*')) if p.is_file() and p.name!='source_inventory.json' and '.godot' not in p.parts])
print(json.dumps(dict(formal_png=11,frames=45,checks=len(checks),failures=audit['failures'])))
