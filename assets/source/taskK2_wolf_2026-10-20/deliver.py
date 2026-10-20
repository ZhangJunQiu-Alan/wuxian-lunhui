from pathlib import Path
import hashlib, html, json, shutil
from PIL import Image

BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(path,data):(BASE/path).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
checks=[]
def check(name,ok,detail=None):checks.append(dict(check=name,passed=bool(ok),detail=detail))

plan=json.loads((ROOT/'assets/source/taskK_contract_2026-10-20/production_plan_v1.1.json').read_text())
rows=[r for r in plan['assets'] if r.get('task')=='K2' and r.get('decision')=='new_proposed']
versions={'fenrir_move':'v02','fenrir_windup':'v02'}
assets=[]
for row in rows:
    name=row['id'];version=versions.get(name,'v01');size=row['frame_size'];n=row['frames'];file=BASE/f'candidates/{name}_{version}.png'
    im=Image.open(file).convert('RGBA');check(name+':sheet_size',im.size==(size[0]*n,size[1]))
    frames=[im.crop((i*size[0],0,(i+1)*size[0],size[1])) for i in range(n)]
    palette=set();boxes=[]
    for i,f in enumerate(frames):
        colors=set(f.get_flattened_data());palette|={c[:3] for c in colors if c[3]};b=f.getchannel('A').getbbox();boxes.append(b)
        check(f'{name}:{i}:binary_alpha',{c[3] for c in colors}<={0,255})
        check(f'{name}:{i}:transparent_rgb_zero',all(c[:3]==(0,0,0) for c in colors if not c[3]))
        margin=8 if 'maw_' in name else 2
        check(f'{name}:{i}:margin',b is not None and b[1]>=margin and b[3]<=size[1]-margin and (name=='fenrir_bind_link' or b[0]>=margin and b[2]<=size[0]-margin),b)
        if name.startswith('vidar') or name.startswith('fenrir_') and size==[192,192]:
            check(f'{name}:{i}:ground_baseline',b[3]==size[1]-2,b[3])
    check(name+':48rgb',len(palette)<=48,len(palette))
    check(name+':unique_frames',len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})==n)
    if n>1:
        for kind in ['native','slow8']:
            gif=BASE/f'previews/{name}_{version}_{kind}.gif'
            check(name+':'+kind+':gif_exists',gif.exists())
            g=Image.open(gif);check(name+':'+kind+':gif_count',g.n_frames==n,g.n_frames)
            for i in range(g.n_frames):g.seek(i);check(f'{name}:{kind}:{i}:duration',g.info.get('duration',0)>0)
    prompt=BASE/f'records/prompt_{name}_{version}.json'
    if name in ['fenrir_attack','fenrir_swallow']:prompt=BASE/f'records/prompt_{name}_{version}_final.json'
    if name in ['fenrir_maw_upper','fenrir_maw_lower','fenrir_bind_link']:prompt=BASE/f'records/prompt_{name}_{version}_actual.json'
    raw=BASE/f'originals/{name}_{version}_raw.png'
    check(name+':actual_source',prompt.exists() and raw.exists())
    assets.append(dict(id=name,formal_path=row['path'],frame_size=size,frames=n,fps=row['fps'],loop=row['loop'],anchor=row.get('anchor_px',row.get('anchor')),alpha=[0,255],rgb_count=len(palette),bboxes=boxes,
                       candidate=str(file.relative_to(BASE)),approved='approved/'+name+'.png',sha256=sha(file),raw=str(raw.relative_to(BASE)),raw_sha256=sha(raw),prompt=str(prompt.relative_to(BASE)),
                       source='OpenAI built-in image_gen; actual reference and prompt in records',license='assets/LICENSES.md; OpenAI Terms Content/Ownership; nonexclusive output',self_check='see records/final_audit.json',game_acceptance='not_tested'))

geometry=json.loads((BASE/'records/render_geometry_audit.json').read_text())
for r in geometry:
    check(f'{r["mode"]}:{r["frame"]}:protected_rect_empty',r['protected_occupied']==0)
    if r['mode']=='binding':check('binding:'+str(r['frame'])+':coverage',r['alpha_weighted_coverage']<=.12,r['alpha_weighted_coverage'])
capture=json.loads((BASE/'preview_project/captures/result.json').read_text())
check('52_isolated_captures',len(capture['captures'])==52 and all(r['save_error']==0 for r in capture['captures']))
check('3_contact_registration_views',len(capture['contacts'])==3)
log=(BASE/'records/godot_fixture_final.log').read_text();check('final_fixture_no_script_error','SCRIPT ERROR' not in log and 'ERROR:' not in log)
baseline=json.loads((ROOT/'assets/source/taskK_contract_2026-10-20/records/baseline.json').read_text())
changed=[p for p,h in baseline.items() if not (ROOT/p).exists() or sha(ROOT/p)!=h]
check('1453_preexisting_inputs_unchanged',not changed,changed)
check('12_formal_png_44frames',len(assets)==12 and sum(a['frames'] for a in assets)==44)
audit=dict(task='K2',checks=len(checks),failures=sum(not c['passed'] for c in checks),items=checks,scope='asset files and isolated Godot rendering; not Game scene or third-level acceptance')
dump('records/final_audit.json',audit)
if audit['failures']:raise SystemExit(json.dumps([c for c in checks if not c['passed']],ensure_ascii=False))
for r in assets:
    source=BASE/r['candidate'];target=ROOT/r['formal_path'];target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists() and sha(target)!=r['sha256']:raise SystemExit('refuse overwrite different file '+str(target))
    shutil.copyfile(source,BASE/r['approved'])
    if not target.exists():shutil.copyfile(source,target)
reuse_paths=['assets/sprites/bosses/fenrir.png','assets/sprites/effects/bosses/garm_chain_break.png','assets/sprites/effects/bosses/skoll_dash_trail.png','assets/sprites/effects/hit_bite.png']
reuse=[dict(path=p,sha256=sha(ROOT/p),decision='reuse_unchanged_no_new_production') for p in reuse_paths]
dump('manifest.json',dict(task='K2',status='art_delivered_self_checked_not_game_integrated',formal_png=12,frames=44,assets=assets,reused=reuse,rejected_generations=json.loads((BASE/'records/rejections.json').read_text()),
                         generated_originals=len(list((BASE/'originals').glob('*_raw.png'))),contract='K-assets-v1.0 plus K2-maw-bind-v1.1',addendum=json.loads((BASE/'records/addendum_ref.json').read_text()),self_check='passed',game_acceptance='not_tested'))
dump('completion.json',dict(task='K2',production='complete',formal_png=12,frames=44,self_check='passed',isolated_godot='52 captures',code_integration='not_implemented',game_acceptance='not_tested',git_commit=False,git_push=False,
                          remaining=['actual attraction and escape timer','authoritative swallow warning/damage geometry','charge contact','fragment pickup/binding lifecycle','Odin faith and awakening condition','Vidar full cinematic timing','dense scene and third-level playthrough']))
page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>K2狼王素材</title><style>body{background:#121721;color:#dde5e8;font:16px/1.6 system-ui;margin:30px}img{image-rendering:pixelated;max-width:100%;height:auto}a{color:#a0d6cf}section{margin:36px 0}.flex{display:flex;gap:20px;flex-wrap:wrap}.flex img{max-width:420px}</style><h1>K2 狼王、巨口、束缚与维达</h1><p>12PNG / 44帧；素材自检通过。独立Godot素材场景，未接入实际第三关。</p><p><a href="manifest.json">manifest</a> · <a href="integration.md">接入交接</a> · <a href="records/final_audit.json">自检</a> · <a href="records/rejections.json">退回稿原因</a></p>'
for r in assets:
    name=r['id'];v=versions.get(name,'v01');page+='<section><h2>'+name+'</h2><p>'+str(r['frame_size'])+' / '+str(r['frames'])+'帧 / '+str(r['fps'])+'fps / '+('循环' if r['loop'] else '单次或静态')+'</p>'
    if r['frames']>1:page+=f'<div class="flex"><div>原速<br><img src="previews/{name}_{v}_native.gif"></div><div>8fps检查<br><img src="previews/{name}_{v}_slow8.gif"></div></div>'
    page+=f'<p><a href="{r["candidate"]}">原尺寸帧条</a> · <a href="{r["raw"]}">生成原图</a> · <a href="{r["prompt"]}">实际提示词与输入</a></p></section>'
page+='<h2>独立渲染合成</h2><div class="flex"><img src="previews/fixture_maw_native.gif"><img src="previews/fixture_binding_native.gif"><img src="previews/fixture_contact_native.gif"></div><h2>52张原生渲染检查</h2><img src="previews/godot_all_cases.png"><h2>编带材料4×4重复预览</h2><img src="previews/bind_material_repeat_4x4.png"></html>'
(BASE/'gallery.html').write_text(page)
dump('source_inventory.json',[dict(path=str(p.relative_to(BASE)),sha256=sha(p)) for p in sorted(BASE.rglob('*')) if p.is_file() and p.name!='source_inventory.json' and '.godot' not in p.parts])
print(json.dumps(dict(formal_png=12,frames=44,checks=len(checks),failures=audit['failures'],originals=len(list((BASE/'originals').glob('*_raw.png')))),ensure_ascii=False))
