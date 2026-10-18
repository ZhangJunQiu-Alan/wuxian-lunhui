from pathlib import Path
from PIL import Image, ImageDraw, ImageSequence
import json, hashlib, math, shutil, sys, html

SOURCE=Path(__file__).resolve().parents[2]
ASSETS=SOURCE.parent
ROOTS=[SOURCE/'taskG4_original_gods_fx_2026-10-18',SOURCE/'taskG5_new_gods_fx_2026-10-18']
PUBLISH='--publish' in sys.argv
BG=(18,23,33,255)
NOTES={
 'thor_hammer':'重做为方块锤头和短柄；锤头向右，旋转预览未见独立地面投影。',
 'thor_cloud':'深灰云团及冰蓝电光；1倍可辨，边缘完整。',
 'odin_spear':'紫色长枪朝右，最右枪尖精确位于(56,8)。',
 'odin_raven':'重新生成大头短喙渡鸦，两帧共用原图纵向裁切范围；头身位置保持，翼上拍/下拍变化。',
 'odin_rune_circle':'紫色环和角形符号；中心透明，地块叠加可辨角色。',
 'loki_wolf':'前三稿退回；第四原稿连续青绿色躯干、少量橙色火尖，伸腿/收腿，脚底统一y24。',
 'loki_decoy':'四帧青绿橙色火焰人形；火苗变化、脚底统一y44，不含实体服装武器。',
 'loki_fire_patch':'青绿与橙色诡火，低透明度；叠在角色上方仍可辨其轮廓。',
 'freyja_cat':'灰白战猫朝右，伸腿/收腿两相，脚底统一y18。',
 'freyja_chariot':'两只灰白猫拉金色空战车朝右；轮/脚底落y32，无驾驶人物。',
 'freyja_ring':'金色链节构成环形；中心透明，地块叠加不遮住角色。',
 'pickup_feather':'16px金色羽毛，斜向，1倍可辨。',
 'pickup_tear':'16px竖直金色泪滴，二值透明，无外部光晕。',
 'baldr_beam':'暖白金色亮芯及柔和侧缘；两端4列一致，4倍长2倍宽预览连续。',
 'baldr_spear':'金白光矛朝右，最右矛尖位于(56,8)。',
 'baldr_glow':'保留原图自然渐淡端部；整体比主光束暗且透明，拉伸后无硬端块。',
 'ran_net':'俯视蓝色圆形渔网、透明菱形孔及贝壳；地块叠加人物轮廓可辨。',
 'ran_wave':'蓝白浪头朝上；去掉排版产生的竖直端块，整段拉长后形状连续。',
 'ran_whirl':'深蓝与白色水纹漩涡；单张96px，整体淡入淡出由程序控制。',
 'freyr_sword':'第一稿缩小成细线而退回；新版绿金厚刃、金色护手，剑尖朝右。',
 'freyr_boar':'金鬃野猪朝右，两相冲锋；脚底统一y20，GIF平均12fps。',
 'freyr_field':'俯视圆形金色麦田，自然边缘、中心较淡；角色上下层叠加均可辨。',
 'skadi_arrow':'原稿v02重新取样，保留完整箭杆和箭羽；最终箭尖(28,4)。',
 'skadi_blizzard':'冰蓝雪片与风纹环，中心透明；旋转和地面叠加均已查看。',
 'skadi_ice':'自然渐淡冰面带、少量裂纹；移除硬端块，拉伸后连续。',
 'pickup_apple':'16px金色苹果及绿叶，1倍可辨。'
}
REJECTS={
 'thor_hammer':{'v01':'缩小后锤头过窄，方头短柄特征不够明确。'},
 'odin_raven':{'v01':'头翼轮廓弱、原图分帧边界不干净。','v02':'独立裁切缩放导致头身纵向位置不同。','v03':'平移后仍显破碎、头喙在小尺寸下不够清楚。','v04':'原图可用，按各帧单独裁切排版会使头部上下跳动；改用v05共用纵向边界。'},
 'loki_wolf':{'v01':'火星相连、帧边界不干净，躯干破碎。','v02':'原图幼狼贴边，分帧会切到嘴部。','v03':'缩小后躯干仍过于破碎。'},
 'freyr_sword':{'v01':'缩小后剑刃仅细线，护手和长剑轮廓不够清楚。'},
 'skadi_arrow':{'v01':'小尺寸箭头不清楚。','v02':'最近邻取样丢失细箭杆。','v03':'改变纵向取样仍未保住完整箭杆。'},
 'ran_wave':{'v01':'端口排版复制中央高浪列，在两端形成竖块。'},
 'baldr_glow':{'v01':'复制的端口过于规整，与自然淡出光带不一致。'},
 'skadi_ice':{'v01':'端口出现不自然的平直色块。'}
}

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,obj):p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
def check(a,r,v):
 id=a['id'];p=r/'candidates'/f'{id}_{v}.png';im=Image.open(p);w,h,n=a['w'],a['h'],a['frames'];px=list(im.getdata());semi=any(s in a['flags'] for s in ['area','stretch']);frames=[im.crop((k*w,0,(k+1)*w,h)) for k in range(n)];boxes=[f.getbbox() for f in frames];pad=[bool(b and b[0]>=2 and b[1]>=2 and b[2]<=w-2 and b[3]<=h-2) if 'stretch' not in a['flags'] else bool(b and b[1]>=2 and b[3]<=h-2) for b in boxes]
 checks={'exact_size':im.size==(w*n,h),'png_rgba':im.format=='PNG' and im.mode=='RGBA','nonempty_all_frames':all(boxes),'transparent_background':any(p[3]==0 for p in px),'alpha_rule':semi or set(p[3] for p in px)<={0,255},'palette_budget_32_rgb':len(set(p[:3] for p in px if p[3]))<=32,'padding':all(pad),'zero_rgb_where_alpha_zero':all(p[:3]==(0,0,0) for p in px if not p[3]),'generation_record_exists':(r/'records'/f'generation_{id}_{v}.json').exists()}
 details={'frame_bboxes':boxes,'rgb_colors':len(set(p[:3] for p in px if p[3])),'rgba_values':len(set(p for p in px if p[3])),'alpha_values':sorted(set(p[3] for p in px)),'padding_exception':'stretchable strip left/right ends' if 'stretch' in a['flags'] else None}
 if 'tip' in a['flags']:
  x,y=a['anchor'];checks['tip_on_anchor']=im.getpixel((x,y))[3]==255 and boxes[0][2]==x+1
 if 'feet' in a['flags'] or 'chariot' in a['flags']:checks['baseline_matches_anchor']=all(b[3]-1==a['anchor'][1] for b in boxes)
 if 'hole' in a['flags']:
  cx,cy=a['anchor'];rad=min(math.hypot(x-cx,y-cy) for y in range(h) for x in range(w) if im.getpixel((x,y))[3]);details['fully_transparent_center_radius_exclusive']=rad;checks['transparent_center_disk']=rad>=min(w,h)*0.22
 if n>1:
  checks['distinct_frames']=len({f.tobytes() for f in frames})==n
  gp=r/'previews'/f'{id}_{v}.gif';gif=Image.open(gp);decoded=[];dur=[]
  for f in ImageSequence.Iterator(gif):decoded.append(f.convert('RGB').copy());dur.append(f.info['duration'])
  expected=[]
  for f in frames:
   z=Image.new('RGBA',(w,h),BG);z.alpha_composite(f);expected.append(z.convert('RGB').resize((w*4,h*4),Image.Resampling.NEAREST))
  checks['gif_pixels_match_sheet']=all(f.tobytes()==expected[k%n].tobytes() for k,f in enumerate(decoded))
  checks['gif_loops']=gif.info.get('loop')==0 and len(decoded)%n==0
  checks['gif_average_fps']=abs(len(decoded)*1000/sum(dur)-a['fps'])<0.001
  details.update(gif_frames=len(decoded),gif_duration_ms=dur,gif_average_fps=len(decoded)*1000/sum(dur),gif_scale=4)
 if id=='baldr_beam':checks['matching_beam_endports']=im.crop((0,0,4,h)).tobytes()==im.crop((w-4,0,w,h)).tobytes()
 return checks,details

for r in ROOTS:
 plan=json.loads((r/'records/production_plan.json').read_text())['assets'];versions=json.loads((r/'records/final_versions.json').read_text());group=plan[0]['group'];entries=[];errors=[];manual={}
 for a in plan:
  id=a['id'];v=versions[id];checks,detail=check(a,r,v);errors +=[f'{id}: {k}' for k,ok in checks.items() if not ok];manual[id]={'version':v,'status':'pass','reviewed':['native on #121721','nearest 4x','style reference comparison','no text/watermark/scene','right facing where applicable']+(['all animation frames, body proportions, head alignment, first/last transition'] if a['frames']>1 else [])+(['0/90/180 rotation'] if 'rotate' in a['flags'] else [])+(['4x length / 2x width stretch'] if 'stretch' in a['flags'] else [])+(['Midgard ground: characters above and below effect; scale1 and1.6'] if 'area' in a['flags'] else []),'notes':NOTES[id]}
  p=r/'candidates'/f'{id}_{v}.png';dest=ASSETS/'sprites/effects/gods'/f'{id}.png';gen=json.loads((r/'records'/f'generation_{id}_{v}.json').read_text());sourceversion=v
  while not (r/'originals'/f'{id}_{sourceversion}_raw.png').exists():
   sourceversion='v04' if id=='odin_raven' else 'v02' if id=='skadi_arrow' else 'v01'
  raw=r/'originals'/f'{id}_{sourceversion}_raw.png'
  previews={'review':f'previews/{id}_{v}_review.png'}
  for flag,suffix in [('rotate','rotations.png'),('stretch','stretch.png'),('area','ground.png')]:
   if flag in a['flags']:previews[suffix.split('.')[0]]=f'previews/{id}_{v}_{suffix}'
  if a['frames']>1:previews['gif']=f'previews/{id}_{v}.gif'
  entries.append({'id':id,'file':f'sprites/effects/gods/{id}.png','approved':f'approved/{id}.png','candidate':str(p.relative_to(r)),'sha256':digest(p),'source':{'raw':str(raw.relative_to(r)),'raw_sha256':digest(raw),'tool':'OpenAI built-in image_gen','generation_record':f'records/generation_{id}_{v}.json','generation_link':None,'link_note':'Built-in tool provides local output path, no public generation-session URL. Actual prompt and uploaded references retained in record.','references':[str(Path(x).relative_to(r)) if Path(x).is_relative_to(r) else x for x in gen['refs']]},'selected_version':v,'width':a['w']*a['frames'],'height':a['h'],'frame_size':[a['w'],a['h']],'frames':a['frames'],'fps':a['fps'] if a['frames']>1 else None,'anchor':a['anchor'],'alpha_rule':'semi-transparent permitted by task G for scaled areas/strips' if any(s in a['flags'] for s in ['area','stretch']) else '0 or255','measurements':detail,'technical_checks':checks,'visual_review':manual[id],'previews':previews,'rejected_candidates':REJECTS.get(id,{}),'status':'self_check_passed','game_test':'not_performed'})
 if errors:dump(r/'records/final_audit.json',{'status':'failed','errors':errors});raise SystemExit(errors)
 if PUBLISH:
  for e in entries:
   p=r/e['candidate'];approved=r/e['approved'];dest=ASSETS/e['file'];dest.parent.mkdir(parents=True,exist_ok=True)
   if dest.exists() and digest(dest)!=digest(p):
    backup=r/'backups'/dest.name;shutil.copy2(dest,backup)
   shutil.copy2(p,approved);shutil.copy2(p,dest)
   if digest(approved)!=e['sha256'] or digest(dest)!=e['sha256']:raise SystemExit('hash mismatch '+e['id'])
 manifest={'task':group,'date':'2026-10-18','status':'published_after_art_self_check' if PUBLISH else 'art_self_check_complete_not_published','scope':'G4/G5 pixel god effects only','game_test':'not_performed','browser_review':'not_performed; local browser control disabled in Work settings','tile_4x4':'not applicable: no ground tiles in G4/G5; use stretch and ground overlay previews instead','asset_count':len(entries),'files':entries}
 dump(r/'manifest.json',manifest);dump(r/'records/reviews.json',manual);dump(r/'records/rejected_candidates.json',{a['id']:REJECTS[a['id']] for a in plan if a['id'] in REJECTS})
 dump(r/'records/final_audit.json',{'status':'pass','file_count':len(entries),'errors':[],'all_technical_checks':True,'candidate_approved_runtime_sha256_match':PUBLISH,'game_test':'not_performed','browser_review':'not_performed','animation_gifs':[{'id':e['id'],'fps':e['measurements']['gif_average_fps'],'pixel_match':e['technical_checks']['gif_pixels_match_sheet']} for e in entries if e['frames']>1]})
 # Clean overview: every file at native size, no overlapping enlarged copy.
 overview=Image.new('RGBA',(1280,760),BG);d=ImageDraw.Draw(overview)
 for k,e in enumerate(entries):
  x=k%4*320+8;y=k//4*190;d.text((x,y+3),e['id'],fill='white');d.text((x,y+19),f"{e['width']}x{e['height']} / {e['frames']} frame(s)",fill=(150,169,190));im=Image.open(r/e['candidate']).convert('RGBA');overview.alpha_composite(im,(x,y+44))
 overview.save(r/'previews/final_contact.png')
 cards=[]
 for e in entries:
  id=e['id'];w,h=e['frame_size'];n=e['frames'];src=e['candidate'];esc=html.escape
  items=''.join(f'<a href="{p}">{esc(k)}</a> ' for k,p in e['previews'].items())
  gif=f'<p>预览 GIF · {e["fps"]} fps · 4×</p><img class="gif" src="{e["previews"]["gif"]}" alt="{id} GIF">' if n>1 else ''
  extras=''.join(f'<details><summary>{label}</summary><img class="proof" src="{e["previews"][key]}" alt="{id} {key}"></details>' for key,label in [('rotations','0° /90° /180°'),('stretch','4倍长度 /2倍宽度'),('ground','第1关地块叠加：上下层及1倍/1.6倍')] if key in e['previews'])
  cards.append(f'<article data-id="{id}" data-frames="{n}" data-w="{w}" data-h="{h}" data-fps="{e["fps"] or 8}"><h2>{id}</h2><p>{w}×{h} / {n}帧 · 锚点{e["anchor"]} · {e["measurements"]["rgb_colors"]} RGB色</p><p>{esc(NOTES[id])}</p><div class="sprites"><div><label>1×</label><canvas width="{w}" height="{h}" data-scale="1"></canvas></div><div><label>4×</label><canvas width="{w*4}" height="{h*4}" data-scale="4"></canvas></div></div><p class="state">帧 0</p><button class="play">暂停</button> <button class="step">下一帧</button><img hidden class="source" src="{src}" alt="{id} source"><p>{items}</p>{gif}{extras}<details><summary>原帧条、原图和真实提示词</summary><p><a href="{src}">选用帧条</a> · <a href="{e["source"]["raw"]}">生成原图</a> · <a href="{e["source"]["generation_record"]}">Prompt /参考/输出记录</a></p><img class="sheet" src="{src}" alt="{id} sheet"></details></article>')
 page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'''+group+''' 神术像素特效审核</title><style>body{margin:0;background:#121721;color:#e4e9ef;font:15px/1.65 system-ui}header{padding:24px 32px;border-bottom:1px solid #344151}main{padding:24px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,580px),1fr));gap:20px}h1{margin:0}h2{font-size:18px}article{padding:20px;background:#18202d;border:1px solid #344151;overflow:auto}a{color:#91cafb}button{background:#27384d;color:white;border:1px solid #506780;padding:7px 12px;cursor:pointer}.sprites{display:flex;align-items:flex-start;gap:20px;flex-wrap:wrap;min-height:100px}.sprites>div{background:#121721;padding:10px;overflow:auto}label{display:block;color:#9daec1}canvas,img.gif,.sheet{image-rendering:pixelated}canvas{display:block}img.proof{max-width:100%;height:auto}.gif{max-width:100%;background:#121721}summary{cursor:pointer;margin-top:12px}.state{color:#9daec1}input{padding:8px;width:260px;background:#121721;color:white;border:1px solid #506780}.error{color:#ffb3a4}</style><header><h1>'''+group+''' · 13 个神术像素特效</h1><p>美术自检通过；尚未 Godot 实测。半透明仅用于任务书允许的缩放区域和条带。动画帧 GIF 已逐帧及平均帧率核验。此页不代表游戏内验收。</p><p><a href="manifest.json">manifest</a> · <a href="README.md">README</a> · <a href="records/final_audit.json">技术核验</a> · <a href="records/reviews.json">逐图记录</a> · <a href="previews/final_contact.png">1×总览</a></p><input id="filter" placeholder="按文件名筛选"><button id="pause">全部暂停</button><p id="loads">载入中…</p></header><main>'''+''.join(cards)+'''</main><script>
const states=[];let errors=0,loaded=0;const total=document.querySelectorAll('article').length;
for(const card of document.querySelectorAll('article')){const img=card.querySelector('.source'),w=+card.dataset.w,h=+card.dataset.h,n=+card.dataset.frames,fps=+card.dataset.fps;const s={card,img,w,h,n,fps,frame:0,playing:n>1,last:0,ready:false};states.push(s);if(n===1){card.querySelector('.play').disabled=true;card.querySelector('.step').disabled=true}const draw=()=>{if(!s.ready)return;for(const c of card.querySelectorAll('canvas')){const ctx=c.getContext('2d'),sc=+c.dataset.scale;ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,c.width,c.height);ctx.drawImage(img,s.frame*w,0,w,h,0,0,w*sc,h*sc)}card.querySelector('.state').textContent=(n>1?`帧 ${s.frame+1} / ${n} · ${fps}fps`:'静态图')};s.draw=draw;const status=()=>document.querySelector('#loads').textContent=`${loaded}/${total} 文件已载入 · ${errors} 失败`;img.onload=()=>{if(s.ready)return;s.ready=true;loaded++;draw();status()};img.onerror=()=>{errors++;card.classList.add('error');status()};if(img.complete&&img.naturalWidth){s.ready=true;loaded++;draw();status()}card.querySelector('.play').onclick=()=>{s.playing=!s.playing;card.querySelector('.play').textContent=s.playing?'暂停':'播放'};card.querySelector('.step').onclick=()=>{s.playing=false;s.frame=(s.frame+1)%n;draw();card.querySelector('.play').textContent='播放'}}
function tick(t){for(const s of states)if(s.playing&&s.ready&&t-s.last>=1000/s.fps){s.frame=(s.frame+1)%s.n;s.last=t;s.draw()}requestAnimationFrame(tick)}requestAnimationFrame(tick);document.querySelector('#pause').onclick=()=>{for(const s of states){s.playing=false;s.card.querySelector('.play').textContent='播放'}};document.querySelector('#filter').oninput=e=>{for(const s of states)s.card.hidden=!s.card.dataset.id.includes(e.target.value.trim())};
</script></html>'''
 (r/'gallery.html').write_text(page)
 anim=[e for e in entries if e['frames']>1];rawcount=len(list((r/'originals').glob('*_raw.png')))
 table='\n'.join(f"| `{e['id']}.png` | {e['width']}×{e['height']} | {e['frames']} | {e['fps'] or '—'} | {e['anchor']} | {e['measurements']['rgb_colors']} |" for e in entries)
 readme=f'''# {group} 神术像素特效交付（2026-10-18）

13个PNG完成本代理美术自检。{'已复制到 `assets/sprites/effects/gods/`，与 approved 及选用候选 SHA256 一致。' if PUBLISH else '尚未复制到正式目录。'}

只负责{group}；不包含其他子任务。原始生成PNG {rawcount}张，动画{len(anim)}条；真实提示词、输入参考及工具输出路径在 `records/generation_*.json`。内置工具不提供网页生成会话链接，未虚构链接。原图保留在 `originals/`，失败稿保留在 `candidates/`，记录见 `records/rejected_candidates.json`。格式修正版本不代表又调用了一次模型。

## 文件与播放契约

| 文件 | 整图尺寸 | 帧数 | fps | 每帧锚点 | 非透明RGB色数 |
|---|---|---|---|---|---|
{table}

横向帧条，无间隔；渡鸦、幼狼、分身、战猫8fps，野猪12fps。每条GIF为4倍最近邻预览；GIF使用10ms单位，8fps的120/130ms和12fps的80/90ms交替时长令整周期平均帧率准确，并非伪称每帧125/83.333ms。96×96漩涡是单张，整体淡入淡出由代码负责。

## 实际自检

- 已逐图查看 #121721 上1倍轮廓和最近邻4倍细节、全部动画帧的体型/头身/脚底和首尾转换；检查同动画共享色表、朝向、无文字/水印/场景。逐项观察见 `records/reviews.json`。
- 已查看会旋转的锤、两种矛、剑、箭和暴风雪的0/90/180度预览，没有独立投到地面的方向性阴影。
- 已查看光束、余辉、浪、冰面的4倍长度、2倍宽度（双线性缩放）预览；主光束两端4列相同；浪/余辉/冰面保留原图自然端部，去掉排版造成的硬块。
- 已查看符文阵、火、金环、渔网、漩涡、麦田、暴风雪叠在现有Midgard地块上的效果。1倍和1.6倍均合成了角色在特效上方及特效在角色上方两种情况，轮廓可辨。圆环中心的实际全透明半径记在 manifest，未把生成提示词中的目标半径当作实测值。
- 自动核验每图尺寸、PNG/RGBA、32RGB色以内、透明底、透明像素RGB清零、2px留白（拉伸条左右端除外）、枪尖/箭尖和脚底锚点。非缩放图alpha仅0/255；区域/条带按任务G特例允许半透明。RGB色数与含alpha的RGBA取值数分别记录。
- GIF解码逐帧与PNG对应帧在同背景的4倍像素完全相同，平均帧率和无限循环标志通过。技术结果见 `records/final_audit.json`。
- 本批没有地块，4×4平铺不适用；用条带拉伸和Midgard叠加预览代替，未虚构平铺检查。

## 未通过的稿与修正

具体版本、原因在 `records/rejected_candidates.json`。包括幼狼破碎/贴边、渡鸦轮廓与纵向裁切造成跳动、锤头过窄、剑过细、冰箭取样丢失箭杆，以及浪/余辉/冰面端口硬块。已重做或重新裁排；保留全部原稿，没有将不合格稿发布。

## 工具、授权与边界

实际使用用户已批准的OpenAI内置image_gen生成，项目自有特效作风格参考，生成动作时上传参考；提示词仅描述外形，不写人物或作品名。输出商业使用及所有权依据沿用项目已核验 [OpenAI条款](https://openai.com/policies/terms-of-use/)。Pillow沿用MIT-CMU，仅用于裁切排版、最近邻尺寸、alpha、限色、整帧定位和预览/核验，没有用Python重画躯干、武器或特效。G4/G5未实际使用Piskel，没有注册、付款或收费API调用。详见 `assets/LICENSES.md` 的本批追加记录。

当前Work设置禁用本地浏览器控制，未做Chrome图集实测；`gallery.html` 已生成，含1倍/4倍、可暂停逐帧、GIF及旋转/拉伸/叠加证明图。**未做Godot游戏实测**，图层、范围、碰撞、技能节奏、实际渲染过滤由Claude接入并验收。本批只写assets，无代码/场景修改，无git提交或推送。
'''
 (r/'README.md').write_text(readme)
 inventory=[]
 for directory in ['originals','refs','candidates','approved','previews','records']:
  for p in sorted((r/directory).glob('*')):
   if p.is_file() and p.suffix not in ['.pyc']:inventory.append({'path':str(p.relative_to(r)),'bytes':p.stat().st_size,'sha256':digest(p)})
 dump(r/'source_inventory.json',inventory)
 print(group,'technical PASS',len(entries),'files,',len(anim),'animations; published',PUBLISH)
