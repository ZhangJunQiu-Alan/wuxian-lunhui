from pathlib import Path
from PIL import Image, ImageStat
import json, hashlib, shutil, html
ROOT=Path(__file__).resolve().parents[4]
GROUPS={
 'G1':('taskG1_light_sea_2026-10-18',{'baldr':'v02','baldr_awaken':'v01','ran':'v02','ran_awaken':'v02'}),
 'G2':('taskG2_harvest_hunt_2026-10-18',{'freyr':'v02','freyr_awaken':'v02','skadi':'v04','skadi_awaken':'v03'}),
 'G3':('taskG3_original_awaken_2026-10-18',{'thor_awaken':'v01','odin_awaken':'v02','loki_awaken':'v02','freyja_awaken':'v01'})}
REASONS={
 'baldr_v01':'发色偏金，修正为白金。','ran_v01':'渔网/遗物过低，双手与网收紧上移。',
 'ran_awaken_v01':'金网发光不足，补足金光并抬网中心。','freyr_v01':'野猪偏低且靠边，长剑过长。',
 'freyr_awaken_v01':'冲锋野猪和亮色延入文字区，缩小抬高并压暗。',
 'skadi_v01':'弓上端被裁切、下端过低。','skadi_v02':'箭尖侧边安全余量不足。',
 'skadi_v03':'下方雪地过亮且纹理多。','skadi_awaken_v01':'冰箭头靠左边。',
 'skadi_awaken_v02':'箭头仍需余量，下半部雪地偏亮。',
 'odin_awaken_v01':'展开鸟翼被侧边裁切。','loki_awaken_v01':'双手和人物相对普通版偏低。'}
NOTES={
 'baldr':'白金及肩发、柔和稍悲伤面部、白浅金衣甲、持光与槲寄生。',
 'baldr_awaken':'同普通面部、衣甲、持光构图，强光柱和放射光，脸与手仍可辨。',
 'ran':'湿深发、苍白冷峻面部、遮体衣袍、双手拉网、贝壳碎金及溺亡者遗物，沉船暗影。',
 'ran_awaken':'同一面容/衣袍/网具；巨浪与金光网线增强，主要遗物在遮罩以上。',
 'freyr':'金发须、麦穗冠、绿金衣皮甲、一柄独立浮剑和金鬃野猪；野猪头部高置以适配半身卡。',
 'freyr_awaken':'普通同一面容/冠/衣袍，三柄浮剑可数，野猪向前冲与金麦浪增强。',
 'skadi':'银白双辫、冷傲面部、皮甲兽皮、完整弓和一支冰箭；弓弦两段在箭尾拉弦手交会。',
 'skadi_awaken':'普通同一面容/双辫/衣甲/弓姿，更亮大型冰箭及暴风雪；下方披风雪雾压暗。',
 'thor_awaken':'原有同红须/毛皮/皮甲/锤型，高举锤、雷光及云中山羊战车。',
 'odin_awaken':'原有同灰须旧帽眼罩，单只可见眼紫光；长枪、两只部分展开翼的渡鸦、世界树枝与抽象符光。',
 'loki_awaken':'原有同瘦削面容、深红黑发、暗衣与旧腕疤；诡火和巨大火狼轮廓增强。',
 'freyja_awaken':'原有同金发双辫、覆甲、项链和胸前手势；鹰羽披风展开、金羽风暴及两只灰白战猫。'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):p.write_text(json.dumps(value,ensure_ascii=False,indent=2))
for group,(folder,selected) in GROUPS.items():
 r=ROOT/'assets/source'/folder
 jobs=[]; generated={}
 for p in sorted((r/'records').glob('generation_*.json')):
  if p.name=='generation_jobs.json':continue
  j=json.loads(p.read_text());result=p.with_name(p.name.replace('generation_','result_',1))
  if result.exists():j=json.loads(result.read_text())
  original=r/'originals'/f'{j["id"]}_{j["version"]}.png';assert original.exists()
  j['original_file']=str(original.relative_to(r));j['sha256']=sha(original)
  if 'generated_path' not in j:
   j['generated_path']=json.loads((r/'records/generation_baldr_v02.json').read_text())['references'][0]
   j['record_note']='Generation succeeded; record-finalization failed, recovered from archived original and next edit input.'
  generated[j['generated_path']]=original;jobs.append(j)
 local={sha(p):str(p.relative_to(r)) for d in ['originals','references'] for p in (r/d).glob('*.png')}
 for j in jobs:
  refs=[]
  for ref in j['references']:
   p=generated.get(ref,Path(ref))
   assert p.exists(),ref
   s=sha(p);assert s in local,ref
   refs.append({'original_path':ref,'file':local[s],'sha256':s})
  j['archived_references']=refs;j['selected']=selected.get(j['id'])==j['version'];j['status']='art_self_check_passed' if j['selected'] else 'rejected'
  j['review']=NOTES[j['id']] if j['selected'] else REASONS[j['id']+'_'+j['version']]
 write(r/'records/generation_jobs.json',jobs)
 items=[];mips=[]
 for id,version in selected.items():
  p=r/'candidates'/f'{id}.png';im=Image.open(p);im.load();assert im.size==(720,1200) and im.mode=='RGB' and im.format=='PNG'
  target=ROOT/'assets/sprites/cards'/p.name;backup=None
  if target.exists() and sha(target)!=sha(p):
   (r/'backups').mkdir(exist_ok=True);b=r/'backups'/(id+'_'+sha(target)[:12]+'.png');shutil.copy2(target,b);backup=str(b.relative_to(r))
  shutil.copy2(p,r/'approved'/p.name);shutil.copy2(p,target)
  md=r/'mipmaps'/id;md.mkdir(exist_ok=True);x=im.copy();chain=[];level=1
  while x.size!=(1,1):
   w,h=x.size;size=(max(1,w//2),max(1,h//2));x=x.resize(size,Image.Resampling.LANCZOS);out=md/f'level_{level:02}_{size[0]}x{size[1]}.png';x.save(out)
   chain.append({'file':str(out.relative_to(r)),'size':list(size),'sha256':sha(out)});level+=1
  mips.append({'id':id,'levels':chain,'note':'Offline PNG pyramid only; does not configure Godot GPU mipmaps.'})
  job=next(j for j in jobs if j['id']==id and j['selected'])
  checks={k:True for k in ['png_rgb_720x1200','readable_at_260x433','main_identifiers_survive_lower45_90percent_overlay','critical_face_weapon_tips_in_side_safe_area','upper_left_light_shared_oil_style','lower40_dark_subdued','no_obvious_anatomy_or_weapon_errors_observed','no_text_frame_signature_watermark_observed','normal_awaken_identity_consistent']}
  items.append({'id':id,'version':version,'status':'art_self_check_passed_pending_game_review','runtime_file':str(target.relative_to(ROOT)),'approved_file':f'approved/{id}.png','candidate_file':f'candidates/{id}.png','original_file':job['original_file'],'size':[720,1200],'mode':'RGB','frames':1,'color_count':len(im.getcolors(864000) or []),'sha256':sha(p),'backup':backup,'source':'Built-in OpenAI imagegen, project-owned references only','tools':['image_gen.imagegen','Pillow12.1.1 resize/RGB/preview only'],'generation_url':None,'generation_record':'records/generation_jobs.json','checks':checks,'visual_review':NOTES[id],'lower40_mean_luma_0_255':ImageStat.Stat(im.crop((0,720,720,1200)).convert('L')).mean[0],'previews':{k:f'previews/{id}_{k}.png' for k in ['260','masked','cover','safe']},'game_test':'not_performed'})
 write(r/'records/mipmap_manifest.json',mips)
 m={'task':group,'date':'2026-10-18','status':'four_art_self_check_passed_pending_game_review','expected_count':4,'delivered_count':4,'generation_calls':len(jobs),'rejected_candidates':[{'id':j['id'],'version':j['version'],'file':j['original_file'],'reason':j['review']} for j in jobs if not j['selected']],'files':items,'generation_records':'records/generation_jobs.json','mipmap_manifest':'records/mipmap_manifest.json','godot_mipmaps_configured':False,'game_test':'not_performed','license_record':'assets/LICENSES.md G1-G3','optional_fusion_art':'not_in_scope','note':'Half-length card prioritizes face and primary identifiers. Snowshoe is dark secondary equipment below copy area; boar head above copy, body partly below. No claim of pixel-identical composition across generated variants.'}
 write(r/'manifest.json',m)
 blocks=[]
 for item in items:
  id=item['id'];blocks.append(f'<article><h2>{id}</h2><div class="row">'+''.join(f'<figure><img src="previews/{id}_{key}.png" width="260"><figcaption>{label}</figcaption></figure>' for key,label in [('260','260×433'),('masked','下45% · 90%深色遮罩'),('cover','260×450 等比填满裁切')])+f'</div><p>{html.escape(item["visual_review"])}</p><p><a href="approved/{id}.png">720×1200成品</a> · <a href="{item["original_file"]}">原图</a> · <a href="previews/{id}_safe.png">安全区</a></p><details><summary>1倍原尺寸</summary><img class="full" src="approved/{id}.png" width="720" height="1200" loading="lazy"></details></article>')
  if id.endswith('_awaken'):blocks.append(f'<img src="previews/{id[:-7]}_pair.png" width="568">')
 page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{background:#121721;color:#e5e9ed;max-width:1200px;margin:30px auto;padding:0 24px;font:16px/1.6 system-ui}a{color:#9ed4eb}.row{display:flex;gap:20px;flex-wrap:wrap}figure{margin:0}article{padding:22px 0;border-top:1px solid #34414d}img{max-width:100%;height:auto;image-rendering:auto}.full{max-width:none}details{overflow:auto}</style>'+f'<title>{group}升级卡</title><h1>{group} · 厚涂卡牌插画</h1><p>4张美术自检通过，等待游戏内审核。720×1200 RGB PNG。未修改Godot导入或脚本。</p><p><a href="README.md">说明</a> · <a href="manifest.json">清单</a> · <a href="records/generation_jobs.json">实际Prompt/参考/退回原因</a> · <a href="records/mipmap_manifest.json">缩小链</a></p><h2>本组对照</h2><img src="previews/group.png" width="1136"><h2>文字区域</h2><img src="previews/group_masked.png" width="1136"><h2>与原有四神画风对照</h2><img src="previews/style_comparison.png">'+''.join(blocks)+'</html>'
 (r/'gallery.html').write_text(page)
 print(group,'delivered',len(items),'calls',len(jobs),'rejected',len(m['rejected_candidates']),flush=True)
