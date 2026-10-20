from pathlib import Path
from PIL import Image
import json,hashlib,shutil
B=Path(__file__).resolve().parent;R=B.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):(B/p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
checks=[]
def ck(n,p,d=None):checks.append(dict(check=n,passed=bool(p),detail=d))
rows=[]
for name,candidate,w,h,n,path in [('giant_tread','giant_tread_v01.png',64,64,1,'assets/sprites/decals/vigrid/giant_tread.png'),('distant_battle','distant_battle_composite_v01.png',512,128,4,'assets/sprites/effects/environment/vigrid/distant_battle.png')]:
 p=B/'candidates'/candidate;im=Image.open(p);ck(name+':RGBA',im.mode=='RGBA');ck(name+':sheet',im.size==(w*n,h));pixels=set(im.get_flattened_data());colors={p[:3] for p in pixels if p[3]};ck(name+':palette',len(colors)<=24,len(colors));ck(name+':alpha',len({p[3] for p in pixels})<=8);ck(name+':transparentRGB',all(p[:3]==(0,0,0) for p in pixels if p[3]==0));frames=[]
 for i in range(n):
  f=im.crop((w*i,0,w*(i+1),h));frames.append(f);box=f.getchannel('A').getbbox();ck(f'{name}:{i}:2pxmargin',box[0]>=2 and box[1]>=2 and box[2]<=w-2 and box[3]<=h-2,box)
 ck(name+':distinct',len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})==n)
 rows.append(dict(id=name,formal_path=path,candidate=str(p.relative_to(B)),frame_size=[w,h],frames=n,fps=8 if n>1 else 0,loop=n>1,anchor=[0,0] if n>1 else [32,32],rgb_count=len(colors),sha256=sha(p),game_acceptance='not_tested'))
for r in rows:
 if r['id']=='giant_tread':r.update(raw='originals/giant_tread_v01_raw.png',prompt='records/prompt_giant_tread_v01.json',source_result='records/result_giant_tread_v01.json',license='OpenAI output ownership extent law; nonexclusive; assets/LICENSES.md')
 else:r.update(source_recipe='records/distant_composition.json',source_captures=[f'originals/distant_composite_{i:02d}_godot.png' for i in range(4)],license='composite existing project K2/K3/K4 assets; assets/LICENSES.md')
terrain=json.loads((B/'records/terrain_audit.json').read_text())
for m in terrain['mask16cases']:ck('cornercase:'+str(m['code']),m['passed'])
for t in terrain['tiles']:ck(t['path']+':64opaque',t['size']==[64,64] and t['opaque'])
for i in range(4):
 p=B/f'preview_project/captures/boundary_{i:02d}.png';im=Image.open(p).convert('RGBA');ck('boundary:'+str(i)+':actual768x480',im.size==(768,480));ck('boundary:'+str(i)+':innerclear',im.crop((124,140,644,340)).getchannel('A').getextrema()==(0,0))
for log in ['godot_distant_final.log','godot_boundary_final.log']:ck(log+':noscripterror',all(s not in (B/'records'/log).read_text() for s in ['SCRIPT ERROR','ERROR:']))
base=json.loads((R/'assets/source/taskK_contract_2026-10-20/records/baseline.json').read_text());changed=[p for p,h in base.items() if not (R/p).exists() or sha(R/p)!=h];asset_changes=[p for p in changed if p.startswith('assets/')];ck('baseline_assets_unchanged',not asset_changes,asset_changes);dump('records/baseline_external_changes.json',dict(changed_paths=changed,scope='read-only observation; changes outside own assets not attributed or reverted'))
audit=dict(task='K5',checks=len(checks),failures=sum(not c['passed'] for c in checks),items=checks,scope='files, mask bit cases, isolated closed-boundary render; not game');dump('records/final_audit.json',audit)
if audit['failures']:raise SystemExit(str([c for c in checks if not c['passed']]))
for r in rows:
 src=B/r['candidate'];p=R/r['formal_path'];p.parent.mkdir(parents=True,exist_ok=True)
 if p.exists() and sha(p)!=r['sha256']:raise SystemExit('refuse overwrite '+str(p))
 if not p.exists():shutil.copyfile(src,p)
 shutil.copyfile(src,B/'approved'/p.name)
dump('records/visual_review.json',dict(viewed=['map_context_1x.png','transition_16cases_1x.png','distant_battle_1x.png','giant_tread_context8x.png','boundary_02.png full768x480'],findings=['muted distant actors remain background','human boot impression not paw','complete rounded visual boundary no inner fill','first viewport fixture rejected as cropped'],game='not_tested'))
dump('manifest.json',dict(task='K5',formal_png=2,frames=5,assets=rows,reused_tiles=terrain['tiles'],reused_masks=json.loads((B/'records/reused_masks.json').read_text()),contract='K5_reuse_addendum_v1.3.json',production='complete',game_acceptance='not_tested'))
dump('completion.json',dict(task='K5',production='complete',formal_png=2,frames=5,self_check='passed',checks=audit['checks'],game_integration='not_implemented',game_acceptance='not_tested',remaining=['map loader and mask adapter','world layout and clipping','collision/visual alignment','periodic aid gameplay definition','dense fulllevel runtime'],git_commit=False,git_push=False))
page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>K5 地图</title><style>body{background:#121721;color:#ddd;font:16px/1.6 system-ui;margin:30px}a{color:#9cd}img{image-rendering:pixelated;max-width:100%}</style><h1>K5 地图素材</h1><p>2新PNG/5帧；复用6地面、5物件、12遮罩及边界火焰。素材预览，未接入游戏。</p><a href="integration.md">接入契约</a> · <a href="manifest.json">清单</a> · <a href="records/final_audit.json">自检</a>'
for title,file in [('局部陈列','map_context_1x.png'),('16角点过渡','transition_16cases_4x.png'),('远景原速','distant_battle_composite_v01_native.gif'),('远景四帧','distant_battle_1x.png'),('足迹8倍','giant_tread_context8x.png'),('闭合边界原速','boundary_native.gif')]:page+=f'<h2>{title}</h2><img src="previews/{file}">'
for t in terrain['tiles']:
 name=Path(t['path']).stem;page+=f'<h2>{name} 4×4平铺</h2><img src="previews/{name}_4x4_1x.png"><p><a href="previews/{name}_4x4_4x.png">4倍平铺检查</a></p>'
(B/'gallery.html').write_text(page+'</html>')
dump('source_inventory.json',[dict(path=str(p.relative_to(B)),sha256=sha(p)) for p in sorted(B.rglob('*')) if p.is_file() and p.name!='source_inventory.json' and '.godot' not in p.parts]);print(json.dumps(dict(checks=audit['checks'],failures=audit['failures'],formal_png=2)))
