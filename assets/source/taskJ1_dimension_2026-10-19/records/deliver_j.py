from pathlib import Path
from PIL import Image,ImageDraw,ImageSequence
from html.parser import HTMLParser
import hashlib,html,json,math,shutil
ROOT=Path(__file__).resolve().parents[4]
BATCHES=sorted((ROOT/'assets/source').glob('taskJ*_2026-10-19'))
OBS={
'dimension_cut':'四帧由薄裂痕到亮核爆发再碎裂衰减，冷蓝紫配色与现有刀光相容，无人物或全屏底色。',
'west_star':'小尺寸警星形点缀清楚，峰值帧与末尾零散金粒不同；不含文字或完整纸牌。',
'west_aura':'复审固定薄环，中心透明，四个方位的亮段依次循环；首轮不均匀版本退回。',
'formation_cavalry':'六个不同的右向奔驰姿势；同一骑手、盔甲、红披布、马和长枪。伸展、收腿和落蹄可辨，实体没有半透明白边。',
'formation_slash':'短起笔、红白峰值、破碎拖痕与低亮残粒清楚；不包含身体。',
'stonehenge_stone':'灰紫粗砺立石，左上高光、平整落地端；没有地面底板或外部投影。',
'stonehenge_lintel':'同色系横石，长度与厚度可独立缩放用于两立石连接，无支架或底色。',
'stonehenge_circle':'灰紫符文阵留透明中心，细环和稀疏装饰不形成满屏底色；外缘另由原程序保持精确。',
'blades_slash':'红白相邻双弧，主体在中心右侧，左半透明；四帧强弱变化清楚。按原判伤扇形裁切的预览另存。',
'arcane_nova':'复审无长尖刺的薄环，固定外缘由代码扩张，中心透明；首轮长尖刺版本退回。',
'hit_claw':'三道并列爪痕，无爪掌或敌人身体，峰值与碎裂尾帧清楚。',
'hit_bite':'上下对合的抽象牙弧及接触闪痕，无嘴部实体或血肉；中心留白。',
'death_shards':'抽象中性碎片由近到远扩散，末帧稀疏；无肢体、血液或烟幕。',
'loki_wolf_breath':'固定左侧喷口、右向火舌、峰值和余烬衰减可辨；透明间隙充足，无狼身体或满扇形实色。'}
CONTRACT={
'dimension_cut':('scripts/ultimates/dimension_slash.gd','_draw','替代_cuts的黑/蓝/白draw_line裂痕；保留全屏压暗、白闪、冻结、_burst判伤和END_AT清理。每条cut首次appear时显示第0帧，BURST_AT=0.75起16fps单次，0.25秒后末帧随原END_AT=1.3淡出；不得提前爆伤。以from/to中点定位，朝向(to-from).angle()，按现有180～440长度沿x拉伸；不加固定投影。'),
'west_star':('scripts/ultimates/wild_west_show.gd','_draw','替代五颗绕身draw_colored_polygon星形；以原p=from_angle(_time*4+TAU*i/5)*34定位。每颗从大招开始播16fps单次0.25秒，播完消失；剩余狂热时间由光环表现。保持frenzy_time=8、射速/换弹/穿透/移速/击杀治疗和尘土；不把单次条改成循环。星形以画布中心锚定，世界内约12像素宽，按有效图形宽度缩放。'),
'west_aura':('scripts/ultimates/wild_west_show.gd','_draw','替代半径34的淡draw_arc，中心跟玩家，8fps循环，show_behind_parent=true；以实际外环有效半径缩放至34，保持中央透明，最后0.5秒沿原fade淡出。保持8秒狂热和五颗星的轨道，不追加伤害或节点。'),
'formation_cavalry':('scripts/ultimates/enter_formation.gd','_draw','只替代14行×3列的马身/骑手多边形和长枪draw_line；复用原p(x+jitter-k*70,y)及alpha=0.55-k*0.15，同一节点集中绘制，不创建42个节点。脚底锚点(48,62)放在p+(0,6)，默认朝右，1倍尺度，8fps循环；可用行列相位避免整队同姿。保留_cavalry_x、CAVALRY_WIDTH=90、CAVALRY_TIME=1.1、判伤、击退和原范围淡红提示。'),
'formation_slash':('scripts/ultimates/enter_formation.gd','_draw','替代_trails的红黑draw_line；以from/to中点定位，旋转(to-from).angle()并沿x拉伸至原距离。以0.35-trail.life作为动画年龄，16fps单次0.25秒后最后一帧在剩余0.1秒淡出；保留瞬移、_strike判伤、15刀上限、无敌与_trails回收。'),
'stonehenge_stone':('scripts/ultimates/stonehenge.gd','_draw','替代立石的两个draw_rect；脚底锚点(24,62)定位base+drop+(0,14)，对应原矩形落地端。有效宽24/高60像素，建议0.75倍接近旧18×44外观，依据实景复核；保留原落地影子、drop轨迹、十根石、DROP_TIME=0.45、阻挡、弹幕拦截和吸血防护。'),
'stonehenge_lintel':('scripts/ultimates/stonehenge.gd','_draw','替代偶数立石到下一根的横石draw_line；绘制中心为(base+next)/2+(0,-32)，旋转(next-base).angle()，沿x拉伸使有效石体两端接到立石。有效图形60×14，横轴中点锚点(32,15)，高度缩放至原约9单位。仅_landed时显示，保持原最后1秒fade与阻挡逻辑。'),
'stonehenge_circle':('scripts/ultimates/stonehenge.gd','_draw','替代_landed后的低alpha填充底色，锚点中心，外缘按有效最大半径缩放至RADIUS=140；保留精确半径140的原程序细边界，装饰不能代表更大阻挡区。保持pulse和最后1秒fade，禁止用贴图alpha代替shields或碰撞，中心透明。'),
'blades_slash':('scripts/weapons/twin_blades.gd','_draw','替代红弧与白线；中心锚点(32,32)放在武器局部原点，旋转a=_aim.angle()±0.25，按有效最远前端缩放到reach*0.9。必须以实际_aim为轴、HALF_ARC=0.7、半径reach裁切视觉；不能按偏移a扩大判伤。按16fps单次播放4帧，纯视觉寿命0.25秒。原SLASH_DURATION=0.1只用于_slash_time显示计时，判伤在_process出手时即时执行；集成时可将纯视觉计时改为0.25秒，或另设0.25秒贴图年龄，不改_timer、即时判伤、连刺、左右手和冷却。新出手重置视觉帧，不能用0.25秒作为攻击判伤窗口。'),
'arcane_nova':('scripts/weapons/arcane_nova.gd','_draw','替代扩散环纹理表现及低亮填充，锚点(64,64)，不旋转投影；以现有r=radius*min(1,wave.t/0.35)驱动实际外环半径，素材帧只改变光强和缺口，不叠加二次扩张。16fps单次0.25秒，余下阶段末帧按原0.15秒alpha淡出；精确范围细弧可保留用于边界校验。保留wave.hit、echo负时间、击退、判伤与波清理。'),
'hit_claw':('scripts/effects/fx_layer.gd','_draw_mark','仅kind=claw改为现有FxLayer节点内draw_texture_region，保持MAX_MARKS=120。以m.pos中心、m.angle旋转，沿x按m.length缩放。为贴图claw/bite单独记录0.25秒视觉duration，按16fps单次播放4帧；原通用slash仍用MARK_LIFE=0.22。此寿命只影响痕迹绘制与回收，不是攻击判伤窗口；保留粒子/数字集中绘制。'),
'hit_bite':('scripts/effects/fx_layer.gd','_draw_mark','仅kind=bite替代上下draw_arc；m.pos中心、m.angle旋转，按m.length缩放，支持m.color染色。保留上下合拢的反馈和MAX_MARKS=120；与hit_claw共用独立0.25秒贴图duration，16fps单次4帧，原通用slash的0.22秒不变。新贴图不定义咬击判伤，也不新增节点。'),
'death_shards':('scripts/effects/fx_layer.gd','_draw / burst','提供可选一次性抽象死亡碎片条，不把现有800粒子逐个换为完整爆炸或新增节点。实际触发点是scripts/entities/enemy.gd::_die()中的FxLayer.burst；应只在该处切换为一个集中绘制的death标记（复用MAX_MARKS=120上限，视觉寿命0.25秒），沿用敌人color染色、普通/精英尺度区分；只播一组16fps4帧，结束回收。保留MAX_PARTICLES=800及所有非死亡burst，不能全局替换。性能未实测前可继续保留现有程序碎片；记录取舍后才启用此文件。'),
'loki_wolf_breath':('scripts/gods/loki.gd','_draw_wolf','只替代_breath_flash下的draw_colored_polygon(cone)，喷口(4,32)定位to_local(_wolf_pos)，沿_breath_dir.angle()旋转。按有效最远距离缩放至BREATH_LENGTH=220，并按喷口为圆心、半角0.45、半径220的扇形裁切。4帧16fps单次0.25秒，剩余原0.4秒窗口淡出末帧；狼身体、_tick_wolf判伤、_breath_flash、冷却和回收不改。')}

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pixels(im):return im.get_flattened_data()
def verify(b,a,version):
 p=b/'candidates'/f"{a['name']}_{version}.png";im=Image.open(p);w,h=a['frame_size'];n=a['frames'];checks={'png_rgba':im.format=='PNG' and im.mode=='RGBA','exact_strip_dimensions':im.size==(w*n,h),'rgb_le48':len({v[:3] for v in pixels(im) if v[3]})<=48,'unique_frames':len({hashlib.sha256(im.crop((i*w,0,(i+1)*w,h)).tobytes()).hexdigest() for i in range(n)})==n}
 frames=[im.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
 boxes=[f.getbbox() for f in frames]
 checks['margin_ge2']=all(r and r[0]>=2 and r[1]>=2 and r[2]<=w-2 and r[3]<=h-2 for r in boxes)
 solid=a['name'] in ['formation_cavalry','stonehenge_stone','stonehenge_lintel']
 checks['alpha_policy']=set(v[3] for v in pixels(im))<={0,255} if solid else len({v[3] for v in pixels(im)})<=8
 if a['name']=='formation_cavalry':checks['fixed_hoof_baseline']=len({r[3] for r in boxes})==1
 if a['name']=='blades_slash':checks['left_half_clear']=all(f.crop((0,0,w//2,h)).getbbox() is None for f in frames)
 if a['name'] in ['west_aura','arcane_nova','stonehenge_circle']:
  checks['center_clear']=all(f.crop((w//2-16,h//2-16,w//2+16,h//2+16)).getbbox() is None for f in frames)
 gif_results=[]
 if n>1:
  for kind,fps in [('normal',a['fps']),('slow8',8)]:
   gp=b/'previews'/f"{a['name']}_{kind}.gif";g=Image.open(gp);loop=g.info.get('loop');durations=[];exact=True
   for i,gf in enumerate(ImageSequence.Iterator(g)):
    durations.append(gf.info['duration']);bg=Image.new('RGBA',(w,h),'#121721');bg.alpha_composite(frames[i]);target=bg.convert('RGB').resize((w*4,h*4),Image.Resampling.NEAREST)
    exact=exact and gf.convert('RGB').tobytes()==target.tobytes()
   gif_results.append({'path':str(gp.relative_to(b)),'frames':len(durations),'durations_ms':durations,'average_fps':1000*n/sum(durations),'decoded_pixels_match_source_composite':exact,'loop':loop})
  checks['gif_frame_counts']=all(g['frames']==n for g in gif_results)
  checks['gif_exact_pixels']=all(g['decoded_pixels_match_source_composite'] for g in gif_results)
  checks['gif_average_fps']=all(abs(g['average_fps']-(a['fps'] if i==0 else 8))<.001 for i,g in enumerate(gif_results))
  checks['gif_loop_contract']=all(g['loop']==0 if a['loop'] else g['loop'] is None for g in gif_results)
 if not all(checks.values()):raise ValueError(a['name']+str(checks))
 return im,frames,{'checks':checks,'frame_bboxes':boxes,'rgb_colors':len({v[:3] for v in pixels(im) if v[3]}),'alpha_levels':sorted({v[3] for v in pixels(im)}),'gifs':gif_results,'visual_frame_review':OBS[a['name']],'visual_review_scope':'actual native1x overview and each4x frame-strip image, offline only; not browser playback or game','browser_playback':'not_performed_Work_browser_disabled','game_test':'not_performed'}

def geometry_preview(b,a,frames):
 name=a['name'];w,h=a['frame_size'];f=frames[1 if len(frames)>1 else 0];out=Image.new('RGB',(480,360),'#121721');d=ImageDraw.Draw(out);d.text((10,8),'OFFLINE SCALE / RANGE - NOT GAME CAPTURE',fill='white');cx,cy=240,185
 if name in ['blades_slash','loki_wolf_breath']:
  anchor=(32,32) if name=='blades_slash' else (4,32);half=.7 if name=='blades_slash' else .45;target_r=140 if name=='blades_slash' else 200
  pts=[(x,y) for y in range(h) for x in range(w) if f.getpixel((x,y))[3]];art_r=max(math.hypot(x-anchor[0],y-anchor[1]) for x,y in pts);scale=target_r/art_r
  # Preview-only crop to the real cone contract. Canonical PNG is untouched.
  cropped=f.copy();removed=0
  for y in range(h):
   for x in range(w):
    v=cropped.getpixel((x,y));angle=abs(math.atan2(y-anchor[1],x-anchor[0]))
    if v[3] and (x<anchor[0] or angle>half):cropped.putpixel((x,y),(0,0,0,0));removed+=1
  size=(round(w*scale),round(h*scale));c=cropped.resize(size,Image.Resampling.NEAREST);origin=(cx-round(anchor[0]*scale),cy-round(anchor[1]*scale));out.paste(c,origin,c)
  d=ImageDraw.Draw(out);d.arc((cx-target_r,cy-target_r,cx+target_r,cy+target_r),-math.degrees(half),math.degrees(half),fill='#60bfa0',width=1)
  for sign in [-1,1]:d.line((cx,cy,cx+target_r*math.cos(half),cy+sign*target_r*math.sin(half)),fill='#60bfa0')
  d.text((10,335),f'preview cone clip; removed {removed} source pixels; scale illustrative',fill='white')
 elif name in ['west_aura','arcane_nova','stonehenge_circle']:
  rad=140;scale=rad/max(w,h)*2;c=f.resize((round(w*scale),round(h*scale)),Image.Resampling.NEAREST);out.paste(c,(cx-c.width//2,cy-c.height//2),c);d=ImageDraw.Draw(out);d.ellipse((cx-rad,cy-rad,cx+rad,cy+rad),outline='#60bfa0',width=1);d.text((10,335),'green=code boundary; retain/crop boundary as integration specifies',fill='white')
 else:
  c=f.resize((w*3,h*3),Image.Resampling.NEAREST);out.paste(c,(cx-c.width//2,cy-c.height//2),c);d=ImageDraw.Draw(out);d.line((cx-8,cy,cx+8,cy),fill='#60bfa0');d.line((cx,cy-8,cx,cy+8),fill='#60bfa0');d.text((10,335),'center / orientation illustration; actual scale in integration.md',fill='white')
 out.save(b/'previews'/f'{name}_range.png')
 # Rotation/stretch preview uses existing pixels only.
 rot=Image.new('RGB',(480,180),'#121721');d=ImageDraw.Draw(rot);d.text((8,5),'OFFLINE ROTATE / STRETCH - NOT GAME',fill='white')
 for i,angle in enumerate([0,45,90,180]):
  c=f.resize((w*2,h),Image.Resampling.NEAREST) if i==0 else f.rotate(angle,Image.Resampling.NEAREST,expand=True)
  rot.paste(c,(i*120+(120-c.width)//2,35+(130-c.height)//2),c)
 rot.save(b/'previews'/f'{name}_transforms.png')

for b in BATCHES:
 plan=json.loads((b/'production_plan.json').read_text());entries=[];audit=[];contracts=[];cards=[]
 for a in plan['assets']:
  name=a['name'];v='v02' if name in ['west_aura','arcane_nova'] else 'v01'
  im,frames,result=verify(b,a,v);geometry_preview(b,a,frames)
  src=b/'candidates'/f'{name}_{v}.png';approved=b/'approved'/f'{name}.png';formal=ROOT/a['formal_path']
  if formal.exists() and sha(formal)!=sha(src):raise ValueError('Refuse unexpected target overwrite: '+str(formal))
  shutil.copy2(src,approved);formal.parent.mkdir(parents=True,exist_ok=True)
  if not formal.exists():shutil.copy2(src,formal)
  w,h=a['frame_size'];anchor=[w/2,h/2]
  if name in ['formation_cavalry','stonehenge_stone']:anchor=[w/2,h-2]
  if name=='stonehenge_lintel':anchor=[32,15]
  if name=='loki_wolf_breath':anchor=[4,32]
  script,func,contract=CONTRACT[name]
  refs=a['references'];refs=[{**r,'sha256':sha(b/r['copy'])} for r in refs]
  raw=b/'originals'/f'{name}_{v}.png';prompt=b/'records'/f'{name}_{v}_prompt.txt'
  entry={'task':a['task'],'name':name,'formal_path':a['formal_path'],'version':v,'frame_size':[w,h],'frames':a['frames'],'fps':a['fps'],'loop':a['loop'],'anchor':anchor,'orientation':'right' if name not in ['west_aura','arcane_nova','stonehenge_circle'] else 'top_down_center','alpha_policy':'binary' if name in ['formation_cavalry','stonehenge_stone','stonehenge_lintel'] else '8_level_source_alpha_or_lower_cap','rgb_colors':result['rgb_colors'],'alpha_levels':result['alpha_levels'],'sha256':sha(formal),'raw':str(raw.relative_to(b)),'raw_sha256':sha(raw),'prompt':str(prompt.relative_to(b)),'prompt_sha256':sha(prompt),'reference_library':refs,'generation_inputs':([{'path':f'candidates/{name}_v01.png','role':'edit target','sha256':sha(b/'candidates'/f'{name}_v01.png')}] if v=='v02' else [{'path':'references/style_board.png','role':'style reference collage made from reference_library','sha256':sha(b/'references/style_board.png')}]),'tool':'OpenAI built-in image_gen; model identity not exposed','license_url':'https://openai.com/policies/terms-of-use/','license':'OpenAI output rights per applicable terms; project-owned input references; not exclusive copyright guarantee','processing_record':'records/'+name+'_processing.json','self_checks':result,'source_reference_role':'style only; revised v02 also uses retained v01 candidate as edit target','integration':{'document':'integration.md','target_script':script,'function':func,'status':'requires_explicit_code_integration','runtime_test':'not_performed'}}
  entries.append(entry);audit.append({'name':name,**result});contracts += [f'### `{a["formal_path"]}`','',f'- 单帧 {w}×{h}，{a["frames"]}帧，{a["fps"]}fps，'+('循环。' if a['loop'] else '单次。' if a['frames']>1 else '静态。'),f'- 锚点 `{anchor}`；正式SHA256：`{entry["sha256"]}`。',f'- 接入点：`{script}::{func}()`。',f'- {contract}','- 最近邻采样；保持透明，不把画布矩形视为碰撞。坐标/尺度预览为离线示意，实际范围与遮挡需游戏确认。','']
  links=[('1倍逐帧',f'previews/{name}_frames_1x.png'),('4倍逐帧',f'previews/{name}_frames_4x.png'),('范围',f'previews/{name}_range.png'),('旋转与拉伸',f'previews/{name}_transforms.png'),('原图',str(raw.relative_to(b))),('实际Prompt',str(prompt.relative_to(b)))]
  if a['frames']>1:links += [('原速GIF',f'previews/{name}_normal.gif'),('8fps慢放GIF',f'previews/{name}_slow8.gif')]
  cards.append('<article><h2>'+name+'</h2><p>'+html.escape(OBS[name])+'</p><p>'+' · '.join(f'<a href="{href}">{title}</a>' for title,href in links)+'</p><img class="strip" src="previews/'+name+'_frames_4x.png" alt="'+name+'逐帧"><canvas aria-label="'+name+'播放" data-src="approved/'+name+'.png" data-w="'+str(w)+'" data-h="'+str(h)+'" data-n="'+str(a['frames'])+'" data-fps="'+str(a['fps'])+'" data-loop="'+str(a['loop']).lower()+'"></canvas></article>')
 manifest={'task':plan['task'],'date':'2026-10-19','status':'art_files_published_offline_self_checks_pass_runtime_pending','files':entries,'sources':'Each file records actual raw image, prompt, project reference copies, SHA256 and OpenAI commercial-use basis; assets/LICENSES.md contains task license entry.','rejected_candidates':[str(p.relative_to(b)) for p in (b/'records').glob('*rejected.json')],'code_integration':'not_performed','game_test':'not_performed','browser_playback':'not_performed_Work_browser_disabled','four_by_four_tiling':'not_applicable_no_ground_tiles_in_J'}
 (b/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 (b/'records/self_audit.json').write_text(json.dumps({'task':plan['task'],'status':'pass_offline_asset_checks','files':audit,'browser':'in-app bootstrap missing browser-client.mjs; Chrome control returned Local browser use is disabled in Work settings; no setting changed or bypass','code_integration':'not_performed','game_test':'not_performed'},ensure_ascii=False,indent=2)+'\n')
 existing=(b/'integration.md').read_text() if plan['task']=='J8' else '# '+plan['task']+' 逐文件接入交接\n\n'
 if '## 最终文件合同' not in existing:(b/'integration.md').write_text(existing+'\n## 最终文件合同\n\n'+'\n'.join(contracts)+'\n## 游戏验收待办\n\n逐技能比较新旧表现、检查目标与预警可读、正确播放方式、真实范围裁切、场景切换清理和密集战斗性能。本轮未运行游戏，全部运行项未测。不得因正式文件存在标记接入或游戏通过。\n')
 extra='\nJ8其余三类保留程序反馈，方案见effect_proposals.md；未制作未定义融合技套装。\n' if plan['task']=='J8' else ''
 (b/'README.md').write_text('# '+plan['task']+' 素材交付\n\n正式交付 '+str(len(entries))+' PNG。实际原图、Prompt、参考图、候选、退回记录、approved与逐项自检均保留。本轮只制作assets，未修改代码、场景、docs、项目配置或导入设置，未提交或推送Git。\n\n本轮实际检查：1倍总览、所有4倍逐帧、RGBA/精确尺寸/共享色表/alpha/2像素边距/独立帧、GIF逐帧像素往返与平均帧率。实体基线与特效中心留白另测。原速16fps的GIF用60/70ms组合表示平均16fps，8fps用120/130ms组合表示平均8fps；PNG及manifest为运行合同，GIF为预览。\n\n浏览器播放因组件缺失及Work禁用未测，未更改权限。未运行Godot或游戏；遮挡、同屏性能、真实判伤边界与资源生命周期未测。静态素材无播放要求；本任务无地块，4×4平铺不适用。\n\n[integration.md](integration.md)列逐文件函数、坐标、缩放、旋转、遮罩、替换内容与保留逻辑。[manifest.json](manifest.json)列来源/授权/输入与正式哈希。[gallery.html](gallery.html)提供逐帧、原速与慢放播放。[自检](records/self_audit.json)只代表离线资产检查。\n\n生成工具为OpenAI内置image_gen（模型身份未暴露），许可依据[OpenAI条款](https://openai.com/policies/terms-of-use/)，详细记入项目assets/LICENSES.md。Pillow仅裁排、最近邻尺度、颜色/alpha规格处理和预览，没有用程序重画角色。\n'+extra)
 page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+plan['task']+'素材交付</title><style>body{background:#121721;color:#dce2ea;font:15px/1.6 system-ui;margin:24px}a{color:#a6d9ff}article{border-top:1px solid #435268;padding:20px 0}img.strip{display:block;max-width:100%;height:auto;image-rendering:pixelated}canvas{display:block;background:#121721;image-rendering:pixelated;margin:16px 0}button{padding:8px;margin:8px;background:#29384c;color:white;border:1px solid #7390ad}</style><h1>'+plan['task']+'素材交付</h1><p>离线资产自检通过；代码未接入、游戏未验收。点击“重播”后单次动画只播一遍，循环动画持续播放。</p><p><a href="manifest.json">清单与来源</a> · <a href="integration.md">接入合同</a> · <a href="README.md">说明与未测项</a> · <a href="records/self_audit.json">实际自检</a></p>'+''.join(cards)+'''<script>
for(const c of document.querySelectorAll('canvas')){const w=+c.dataset.w,h=+c.dataset.h,n=+c.dataset.n,fps=+c.dataset.fps,loop=c.dataset.loop==='true',im=new Image();c.width=w*4;c.height=h*4;const ctx=c.getContext('2d');ctx.imageSmoothingEnabled=false;let start=0,playing=false;const b=document.createElement('button');b.textContent='重播 '+c.dataset.src.split('/').pop();c.before(b);function draw(t){let frame=fps?Math.floor((t-start)*fps/1000):0;if(loop)frame%=n;else if(frame>=n){frame=n-1;playing=false;}ctx.clearRect(0,0,c.width,c.height);ctx.drawImage(im,frame*w,0,w,h,0,0,c.width,c.height);if(playing)requestAnimationFrame(draw);}b.onclick=()=>{if(!im.complete||!im.naturalWidth)return;start=performance.now();if(!playing){playing=true;requestAnimationFrame(draw);}};im.onload=()=>{start=performance.now();playing=n>1;draw(start);};im.src=c.dataset.src;}
</script></html>'''
 (b/'gallery.html').write_text(page)
 print(plan['task'],len(entries),'offline asset checks pass; published; code/runtime pending')
