from pathlib import Path
from PIL import Image, ImageDraw
import hashlib, html, json, shutil, sys
r=Path(__file__).resolve().parents[1]
assets_root=r.parents[1]
publish='--publish' in sys.argv
items=json.loads((r/'records/repair_inventory.json').read_text())
static=json.loads((r/'records/repair_metadata_v01.json').read_text())
rows=[]
for a in static:
 a=dict(a);it=next(i for i in items if i['id']==a['id']);a.update(source=it['source'],expected_final=it['destination'],visual_review='passed_from_prior_recorded_1x_and_4x_review');rows.append(a)
for a in json.loads((r/'records/jormungandr_metadata_v04.json').read_text()):
 a=dict(a);a.update(expected_final='sprites/bosses/'+a['id']+'.png',visual_review='passed_1x_3x_and_repeat');rows.append(a)
surtr_review=r/'records/surtr_approved_metadata.json'
if surtr_review.exists():rows.append(json.loads(surtr_review.read_text()))
source_records={x['id']:x for x in json.loads((r.parent/'norse_2026-10-16/manifest.json').read_text())}
segment_records=json.loads((r/'records/segment_generation_records.json').read_text())
for a in rows:
 name=a['id'];a['frames']=1
 if name.startswith('jormungandr_'):
  a['generation_url']=segment_records[['head','body','tail'].index(name.split('_')[-1])]['url'];a['tools']=['Chrome ChatGPT','Chrome Piskel','Pillow preview and pixel QA'];a['generation_record']='records/segment_generation_records.json'
 else:
  a.setdefault('generation_url',source_records.get(name,{}).get('chat_url'))
  a['tools']=['Chrome ChatGPT source generation','Pillow deterministic normalization']
  if name in ['frost_giant','frost_giant_elite']:a['tools'].insert(1,'Chrome Piskel nearest export')
  a['generation_record']='records/surtr_repair_prompt_v02.txt' if name=='surtr' else '../norse_2026-10-16/manifest.json'
assert len(rows) in (9,10)
if publish:assert len(rows)==10,'Surtr has not passed visual review'
cards=[];slides=[]
for a in rows:
 name=a['id'];p=r/a['candidate'];im=Image.open(p).convert('RGBA');size=im.size;a['colors']=len(set(c[:3] for c in im.get_flattened_data() if c[3]));a['alpha']=sorted(set(im.getchannel('A').get_flattened_data()));assert size==tuple(a['size']) and a['alpha']==[0,255] and a['colors']<=48
 box=im.getbbox();a['bbox_exclusive']=list(box);margin=min(box[0],box[1],size[0]-box[2],size[1]-box[3]);assert margin>=2 or name.startswith('jormungandr_')
 approved=r/f'approved/{name}.png';shutil.copy2(p,approved);a.update(approved_copy=f'approved/{name}.png',sha256=hashlib.sha256(p.read_bytes()).hexdigest(),status='self_check_passed_pending_game_review',final_copied=publish,game_test='not_performed')
 a['checks']={'png_rgba':True,'exact_size':True,'alpha_binary':True,'palette_at_most_48':True,'one_x_visual_review':True,'nearest_enlarged_visual_review':True,'consistent_reference_style':True,'no_text_watermark_ground_scene':True,'outline_and_silhouette':'passed','margin':'connection-edge exception documented' if name.startswith('jormungandr_') else 'at least 2 pixels','animation_and_loop':'not_applicable_static_repair','tile_seams':'head-body-tail ports and repeated body visually checked' if name.startswith('jormungandr_') else 'not_applicable'}
 if publish:
  dest=assets_root/a['expected_final'];dest.parent.mkdir(parents=True,exist_ok=True)
  if dest.exists():
   backup=r/'backups'/dest.relative_to(assets_root);backup.parent.mkdir(parents=True,exist_ok=True)
   if not backup.exists():shutil.copy2(dest,backup)
  shutil.copy2(approved,dest);assert hashlib.sha256(dest.read_bytes()).hexdigest()==a['sha256']
 w,h=size;card=f'<article><h2>{html.escape(name)}</h2><p>美术自检通过，等待游戏内复核。{w}×{h} · {a["colors"]} 色。</p><p><a href="{a["source"]}">原图</a> · <a href="{a["approved_copy"]}">透明 PNG</a></p><h3>实际 1 倍</h3><img width="{w}" height="{h}" src="{a["approved_copy"]}"><details><summary>最近邻 4 倍</summary><img width="{w*4}" height="{h*4}" src="{a["approved_copy"]}"></details></article>';cards.append(card)
 slide=Image.new('RGB',(480,480),'#121721');d=ImageDraw.Draw(slide);d.text((12,12),name+' / static asset',fill='white');scale=min(4,416//max(size));z=im.resize((w*scale,h*scale),Image.Resampling.NEAREST);slide.paste(z,((480-z.width)//2,40),z);slides.append(slide)
slides[0].save(r/'previews/static_review_slideshow.gif',save_all=True,append_images=slides[1:],duration=1000,loop=0,disposal=2)
status='complete_self_checked_pending_game_review' if publish else 'in_progress_surtr_review_pending'
manifest={'batch':'batch02_repairs_2026-10-16','date':'2026-10-16','status':status,'self_checked_assets':len(rows),'pending_assets':10-len(rows),'assets':rows,'preview_gif':{'file':'previews/static_review_slideshow.gif','type':'static_asset_slideshow_not_character_animation','duration_per_slide_ms':1000},'snake_assembly':'previews/jormungandr_assembled_v04.png','snake_body_4x4':'previews/jormungandr_body_4x4_v04.png','terrain_4x4':'not_applicable_no_terrain_in_batch_2','game_test':'not_performed','batch_order':{'1':'complete_self_checked_pending_game_review','2':status,'3':'not_started','4':'not_started','5':'not_started','6':'not_started'},'rejected_candidates':[{'id':'jormungandr_v02_v03','reason':'Color selection first-stroke errors; v02 tail coordinate offset; v03 visible vertical bands. Replaced by actual v04 Piskel export with zero pixel differences.'},{'id':'surtr_v01','reason':'Right boot occluded by giant sword; retained as rejected candidate.'}],'chrome_recovery':'Mac unlocked; normal Chrome restart restored automatic connection. Local v03 backups reimported; full v04 plan applied and checked.'}
(r/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
pending='' if len(rows)==10 else '<article class="pending"><h2>苏尔特待完成</h2><p>v01 因右脚被巨剑遮挡退回。v02 已上传现有素材提交补画，尚未通过最终审核。</p></article>'
page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>第 2 批修复 · '+str(len(rows))+' 项自检通过</title><style>body{margin:0;padding:28px;background:#121721;color:#e4eaf3;font:15px/1.65 system-ui}h1{font-size:25px}a,summary{color:#9dccff}article{border-top:1px solid #3c485f;margin:28px 0;padding:12px 0}img{image-rendering:pixelated;max-width:none}details{overflow:auto}summary{cursor:pointer}.pending{color:#ffc08d}</style><h1>第 2 批 · 素材修复</h1><p>'+str(len(rows))+' 项通过单图美术自检。'+('本批 PNG 已放入正式素材目录，等待接入代理游戏内复核。' if publish else '整批尚未完成，尚未替换正式素材。')+'未执行游戏测试。第 3 至第 6 批尚未开始。</p><p><a href="manifest.json">manifest.json</a> · <a href="README.md">README</a> · <a href="../../LICENSES.md">授权台账</a></p>'+''.join(cards)+pending+'<article><h2>耶梦加得实际导出组装 · 1 倍</h2><img width="384" height="128" src="previews/jormungandr_assembled_v04.png"><h3>最近邻 3 倍</h3><img width="1152" height="384" src="previews/jormungandr_assembled_3x_v04.png"><h3>蛇身 4×4 重复检查</h3><img width="768" height="768" src="previews/jormungandr_body_4x4_v04.png"><p>头左侧、身两侧、尾右侧为拼接接口，特意延伸至画布边缘；其余外轮廓留白。4×4 用于蛇身水平重复检查，行间透明间隔不作为地块。</p></article><article><h2>静态轮播 GIF</h2><p>每秒一张，只预览静态资产，不是角色动画。</p><img width="480" height="480" src="previews/static_review_slideshow.gif"></article><article><h2>地块平铺</h2><p>本批无地块，地块 4×4 不适用；第 4 批单独制作和检查。</p></article></html>'
(r/'gallery.html').write_text(page)
print(json.dumps({'status':status,'self_checked':len(rows),'final_copied':publish},ensure_ascii=False))
