from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,shutil,html
R=Path(__file__).resolve().parents[1];ROOT=R.parents[2];DEST=ROOT/'assets/sprites/cards';DEST.mkdir(parents=True,exist_ok=True)
IDS=['thor','odin','loki','freyja','general','swordsman','gunslinger','assassin','mage']
NOTES={
 'thor':'红胡子、粗布皮甲毛皮；冰蓝电弧及连续短柄方头锤可辨；握持手无明显多指或融合，次手已隐藏。',
 'odin':'独眼眼罩、灰长须、旧宽檐帽、两只渡鸦和紫色长枪光；v02枪尖完整留白，握持手与枪杆连接合理。',
 'loki':'瘦削面部与微笑、深红黑乱发、橙色诡火、双腕旧疤可见；双手结构无明显多指或断指，未采用角盔或绿金衣。',
 'freyja':'金发、完整覆甲、鹰羽披风、胸前金项链与金色羽毛清楚；手套与胸甲关系合理，非暴露服装。',
 'general':'树根拱下冷白发光几何刻纹石碑，无人物；刻纹作为装饰符号，无标题或连续排版文字。',
 'swordsman':'直接核对项目特写：年轻无须面容、黑发束髻、深蓝开领袍；v03双手和刀柄上移，完整刀尖留边。',
 'gunslinger':'直接核对项目特写：女性、棕色长卷发和宽檐帽、酒红外套、铜纽扣及深色领结；单左轮、握持手和转轮结构连贯。',
 'assassin':'直接核对项目特写：黑发红绳、红围巾、深色层甲和红面具；v02双刃及双手上移收紧，刀尖未被裁切。',
 'mage':'直接核对项目特写：年老长白须、深蓝兜帽袍及弯曲木杖；举手可见五指，无明显融合，手杖连贯。'
}
REJECT={('thor','v01'):'质感偏写实而非厚涂；低处额外手形/锤位置不利卡片遮罩，改v02。',('odin','v01'):'长枪枪尖触及上沿被裁切，改v02。',('swordsman','v01'):'刀尖靠右边且双手/刀柄过低，改v02。',('swordsman','v02'):'下方握持手仍落入文字遮罩区，改v03。',('assassin','v01'):'双刃横向安全余量偏小、刀柄过低，改v02。'}
jobs=json.loads((R/'records/generation_jobs.json').read_text());references=R/'references';references.mkdir(exist_ok=True)
for id in ['swordsman','gunslinger','assassin','mage']:shutil.copy2(ROOT/'assets/sprites/characters'/f'{id}_cutin.png',references/f'{id}_cutin.png')
for j in jobs:
 j['review_status']='selected_after_visual_review' if j['selected'] else 'rejected'
 j['review_note']=NOTES[j['id']] if j['selected'] else REJECT.get((j['id'],j['version']),'superseded')
 # Archive local references and record hashes; original tool path preserved as historical fact.
 j['reference_sha256']=[{'path':p,'sha256':hashlib.sha256(Path(p).read_bytes()).hexdigest()} for p in j['references']]
(R/'records/generation_jobs.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2))
items=[];mips=[]
for id in IDS:
 p=R/'candidates'/f'{id}.png';im=Image.open(p);assert im.size==(720,1200) and im.mode=='RGB' and im.format=='PNG';im.load()
 if (DEST/p.name).exists():
  b=R/'backups';b.mkdir(exist_ok=True);shutil.copy2(DEST/p.name,b/p.name)
 shutil.copy2(p,R/'approved'/p.name);shutil.copy2(p,DEST/p.name)
 md=R/'mipmaps'/id;md.mkdir(parents=True,exist_ok=True);current=im.copy();level=1;chain=[]
 while current.size!=(1,1):
  w,h=current.size;size=(max(1,w//2),max(1,h//2));current=current.resize(size,Image.Resampling.LANCZOS);mp=md/f'level_{level:02}_{size[0]}x{size[1]}.png';current.save(mp)
  chain.append({'level':level,'size':list(size),'file':str(mp.relative_to(R)),'sha256':hashlib.sha256(mp.read_bytes()).hexdigest()});level+=1
 mips.append({'id':id,'base':f'approved/{id}.png','levels':chain,'note':'Offline RGB PNG resolution pyramid for inspection. PNG contains no embedded GPU mip levels; does not configure Godot import.'})
 # Quantitative tone values supplement, never replace the visual checks.
 def tone(image):
  from PIL import ImageStat
  st=ImageStat.Stat(image.convert('L'));return {'mean_luma_0_255':st.mean[0],'stddev_luma':st.stddev[0]}
 small=Image.open(R/'previews'/f'{id}_260.png');mask=Image.open(R/'previews'/f'{id}_masked.png')
 selected=next(j for j in jobs if j['id']==id and j['selected'])
 check={'png_720x1200_rgb':True,'face_and_identifiers_readable_at_260x433':True,'important_content_survives_lower45_percent_90_percent_mask':True,'important_content_inside_40px_side_safe_area':True,'upper_left_light_and_thick_oil_medium':True,'lower40_percent_dark_subdued':True,'no_text_frame_signature_watermark_observed':True,'no_obvious_anatomy_or_weapon_errors_observed':True,'character_identity_matches_cutin':True if id in ['swordsman','gunslinger','assassin','mage'] else 'not_applicable','gods_set_consistent':True if id in ['thor','odin','loki','freyja'] else 'not_applicable'}
 items.append({'id':id,'runtime_file':str((DEST/p.name).relative_to(ROOT)),'approved_file':f'approved/{id}.png','candidate_file':str(p.relative_to(R)),'original_file':selected['source_file'],'selected_version':selected['version'],'source':'Built-in OpenAI image generation; original project references only','license_record':'assets/LICENSES.md task F','tool':'image_gen.imagegen; Pillow12.1.1 for RGB/resize/preview/pyramid only','generation_record':'records/generation_jobs.json','generation_url':None,'size':[720,1200],'mode':'RGB','frames':1,'color_count':len(im.getcolors(720*1200) or []),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'checks':check,'visual_review_note':NOTES[id],'bottom40_percent_tone':tone(im.crop((0,720,720,1200))),'masked_bottom45_percent_tone':tone(mask.crop((0,round(433*.55),260,433))),'previews':{'small':f'previews/{id}_260.png','masked':f'previews/{id}_masked.png','cover_crop':f'previews/{id}_260x450_crop.png','safe':f'previews/{id}_safe.png'},'status':'art_self_check_passed_pending_user_integration','game_test':'not_performed'})
(R/'records/mipmap_manifest.json').write_text(json.dumps(mips,ensure_ascii=False,indent=2))
m={'task':'F upgrade-card nonpixel illustrations','date':'2026-10-17','status':'required_nine_art_self_check_passed_pending_user_integration','required_count':9,'delivered_count':len(items),'generation_calls':len(jobs),'rejected_candidates':[{'id':j['id'],'version':j['version'],'file':j['source_file'],'reason':j['review_note']}for j in jobs if not j['selected']],'optional_awaken_cards':'not_produced; optional third priority','user_integration_note':'User handles Godot import mipmap generation and smooth downscale filtering. Offline PNG pyramid and260px previews supplied; no import/scenes/scripts/project settings changed.','checks_performed':'Individual generated originals inspected; 260px set, 90% dark lower45% masks, gods side-by-side and character references visually inspected; exact dimensions/mode/hashes verified. No Godot runtime test.','files':items,'mipmap_manifest':'records/mipmap_manifest.json','generation_records':'records/generation_jobs.json','comparisons':['previews/gods_comparison.png','previews/gods_masked_comparison.png','previews/weapons_comparison.png','previews/weapons_masked_comparison.png','previews/all_comparison.png']}
(R/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
cards=[]
for row in items:
 id=row['id'];cards.append(f'<article><h2>{html.escape(id)}</h2><div class="pair"><figure><img src="previews/{id}_260.png" width="260" height="433"><figcaption>260×433 抗锯齿缩小</figcaption></figure><figure><img src="previews/{id}_masked.png" width="260" height="433"><figcaption>下45%：90%深色遮罩</figcaption></figure><figure><img src="previews/{id}_260x450_crop.png" width="260" height="450"><figcaption>260×450等比填满及左右裁切</figcaption></figure></div><p>{html.escape(row["visual_review_note"])}</p><p><a href="approved/{id}.png">720×1200原尺寸成品</a> · <a href="previews/{id}_safe.png">安全区检查</a> · <a href="{row["original_file"]}">生成原图</a></p><details><summary>1倍原尺寸检查</summary><img src="approved/{id}.png" width="720" height="1200" loading="lazy"></details></article>')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>无限轮回 · 升级卡插画</title><style>body{max-width:1150px;margin:32px auto;padding:0 22px;background:#121721;color:#e4e8ed;font:16px/1.65 system-ui}a{color:#9bcddd}h1{font-size:30px}article{border-top:1px solid #39434e;padding:28px 0}.pair{display:flex;gap:20px;flex-wrap:wrap}figure{margin:0}figcaption{font-size:13px;color:#adb5c0}img{max-width:100%;height:auto;image-rendering:auto}details img{max-width:none}details{overflow:auto}.notice{background:#212a35;padding:16px}</style><h1>升级卡插画 · 非像素厚涂</h1><p class="notice">9张必做插画美术自检通过，尚未游戏实测。PNG RGB720×1200。260px缩小预览及离线mipmap尺寸链已生成；Godot导入生成mipmap和过滤设置由用户接入时处理。</p><p><a href="README.md">交付说明</a> · <a href="manifest.json">逐项清单与自检</a> · <a href="records/generation_jobs.json">实际提示词与生成记录</a> · <a href="records/mipmap_manifest.json">缩小尺寸链</a></p><h2>四位神明：同套对照</h2><img src="previews/gods_comparison.png" width="1136"><h2>文字区域遮罩检查</h2><img src="previews/gods_masked_comparison.png" width="1136">'''+''.join(cards)+'''</html>'''
(R/'gallery.html').write_text(page)
print(json.dumps({'delivered':len(items),'generation_calls':len(jobs),'rejected':len(m['rejected_candidates']),'mipmap_levels':sum(len(x['levels'])for x in mips)},ensure_ascii=False))
