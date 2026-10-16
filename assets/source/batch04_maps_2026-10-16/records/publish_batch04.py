from pathlib import Path
from PIL import Image,ImageStat
import json,shutil,hashlib,datetime,html
R=Path(__file__).resolve().parents[1];ASSETS=R.parents[1]
rows=json.loads((R/'records/staged_final_checks.json').read_text());review=json.loads((R/'records/final_visual_review.json').read_text())
assert len(rows)==43 and len(review['assets'])==43
jobs=[]
for p in sorted((R/'records').glob('generation_jobs_wave*.json')):
 for j in json.loads(p.read_text()):j['record_file']=str(p.relative_to(R));jobs.append(j)
J={j['id']:j for j in jobs};P={(a['level'],a['id']):a for a in json.loads((R/'records/props_processing_v02.json').read_text())}
backup=[]
for a in rows:
 key=f"{a['level']}/{a['id']}";v=review['assets'][key];assert v['passed'],key;src=R/a['candidate'];im=Image.open(src);im.load();data=list(im.get_flattened_data());assert im.mode=='RGBA' and im.size==(a['width'],a['height']);assert set(p[3] for p in data)<={0,255};assert len(set(p[:3] for p in data if p[3]))<=48
 if a['type']=='props':
  bb=im.getbbox();assert bb[0]>=2 and bb[1]>=2 and bb[2]<=im.width-2 and bb[3]<=im.height-2
  source=P[(a['level'],a['id'])]['source'];jobid=Path(source).name.removesuffix('_v01_raw.png');crop=P[(a['level'],a['id'])]['crop']
 else:source=f"originals/{a['level']}_ground_v01_raw.png";jobid=a['level']+'_ground';idx=[b for b in rows if b['level']==a['level'] and b['type']=='ground'].index(a);raw=Image.open(R/source);w,h=raw.size;crop=[round(idx%4*w/4)+3,round(idx//4*h/2)+3,round((idx%4+1)*w/4)-3,round((idx//4+1)*h/2)-3]
 if a['level']=='midgard' and a['type']=='ground' and a['id'].startswith('snow_') and a['id'][-2:].isdigit():
  source='originals/midgard_snow_v02_variant2_raw.png';jobid='midgard_snow_v02';idx=int(a['id'][-2:])-1;w,h=Image.open(R/source).size;crop=[round(idx%2*w/2)+4,round(idx//2*h/2)+4,round((idx%2+1)*w/2)-4,round((idx//2+1)*h/2)-4]
 if a['level']=='vigrid' and a['id']=='scorched_02':
  raw=Image.open(R/source);w,h=raw.size;crop=[round(2*w/4)+3,round(h/2)+3,round(3*w/4)-3,h-3]
 if key in ('midgard/dead_pine_02','vigrid/broken_weapons'):
  replacement=json.loads((R/'records/last_props_processing.json').read_text())[key];source=replacement['source'];jobid='pine_weapons_v02';crop=replacement['crop']
 job=J[jobid];assert job.get('chat_url','').startswith('https://chatgpt.com/c/'),(jobid,job.get('chat_url'))
 approved=R/'approved'/a['type']/a['level']/(a['id']+'.png');approved.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,approved)
 dest=ASSETS/'sprites'/a['type']/a['level']/(a['id']+'.png');dest.parent.mkdir(parents=True,exist_ok=True)
 if dest.exists() and dest.read_bytes()!=src.read_bytes():
  old=R/'backups'/a['type']/a['level']/(a['id']+'_before_batch04.png');old.parent.mkdir(parents=True,exist_ok=True)
  if old.exists():raise RuntimeError('Backup exists; inspect before overwrite '+str(old))
  shutil.copy2(dest,old);backup.append(dict(final=str(dest.relative_to(ASSETS)),backup=str(old.relative_to(R)),sha256=hashlib.sha256(old.read_bytes()).hexdigest()))
 shutil.copy2(approved,dest);assert hashlib.sha256(dest.read_bytes()).hexdigest()==hashlib.sha256(src.read_bytes()).hexdigest()
 a.update(status='self_check_passed_pending_game_review',approved_file=str(approved.relative_to(R)),final_file=str(dest.relative_to(ASSETS)),frame_count=1,fps=None,source={'raw_file':source,'crop':crop,'tool':'Chrome ChatGPT web image generation','chat_url':job['chat_url'],'generation_record':job['record_file'],'prompt_file':job['prompt_file'],'input_references':job.get('references',[job.get('reference','references/style_reference.png')])},processing_tools=['Pillow 12.1.1','project-original deterministic normalization scripts'],visual_review=v,color_count=len(set(p[:3] for p in data if p[3])),sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
 a['checks'].update(style_consistency=True,no_text_watermark_scene=True,dark_background_1x_readable=True,facing_right='not_applicable_static_environment',fixed_feet_baseline='not_applicable_static_environment',animation='not_applicable_single_frame')
 if a['type']=='ground':
  a['checks'].update(opaque_full_ground=set(p[3] for p in data)=={255},seamless_4x4_visual=True,subdued_below_character_visual=True,no_prominent_repeated_landmark=True)
  p=im.load();sx=sum(abs(p[0,y][c]-p[63,y][c]) for y in range(64) for c in range(3))/192;sy=sum(abs(p[x,0][c]-p[x,63][c]) for x in range(64) for c in range(3))/192;ix=sum(abs(p[x,y][c]-p[x-1,y][c]) for y in range(64) for x in range(1,64) for c in range(3))/(64*63*3);iy=sum(abs(p[x,y][c]-p[x,y-1][c]) for y in range(1,64) for x in range(64) for c in range(3))/(64*63*3);a['seam_metrics']={'opposing_edge_mean_x':round(sx,3),'opposing_edge_mean_y':round(sy,3),'interior_neighbor_mean_x':round(ix,3),'interior_neighbor_mean_y':round(iy,3),'edge_jump_outlier_at_1_5x':sx>1.5*ix or sy>1.5*iy};a['mean_rgb']=[round(v,2) for v in ImageStat.Stat(im.convert('RGB')).mean];a['tiling_preview']=f"previews/{a['level']}_{a['id']}_4x4.png"
raws=[]
for p in sorted((R/'originals').glob('*.png')):
 im=Image.open(p);im.load();raws.append({'file':str(p.relative_to(R)),'size':list(im.size),'mode':im.mode,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
manifest={'batch':4,'name':'maps_and_environment_props','date':'2026-10-16','status':'complete_self_checked_pending_game_review','scope':'batch04_only; batch07 handled in another task','ground_count':20,'prop_count':23,'final_count':len(rows),'raw_count':len(raws),'game_tested':False,'commercial_use_record':'../../LICENSES.md','tools_actually_used':['Chrome ChatGPT web','Pillow 12.1.1','Python standard library, original project scripts'],'piskel_used_in_this_batch':False,'tool_choice':'Reuse the commercially verified generation and local normalization route; Piskel compared previously but not needed for this static batch. No new account/API/payment.','palette_policy':'one shared palette per map, at most48 opaque RGB colors across its ground and props','ground_alpha_exception':'Ground is fully opaque RGBA filling64x64; transparency and2px margin apply to props, not terrain','previews':{'contexts':'previews/<level>_context_1x.png (local art composites, not game screenshots)','static_slideshow':'previews/map_preview.gif (3frames at1500ms, not animation)','scroll_qa':'previews/tile_scroll_8fps.gif (16frames alternating120/130ms; static terrain scrolling)','mixed':'previews/<level>_mixed_base_4x4.png'},'backups':backup,'originals':raws,'assets':rows,'generation_jobs':jobs,'failures_and_resolutions':review['failures_and_resolutions']}
(R/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));(R/'records/publish_backup_log.json').write_text(json.dumps(backup,indent=2))
# Gallery uses approved snapshots, stable even if integration changes final assets later.
p=R/'gallery.html';s=p.read_text().replace('第4批地图 · 最终候选审核','第4批地图 · 43项自检通过').replace('最终候选：20张地块 + 23张物件 · 待最终可视检查','自检通过：20张地块 + 23张物件 · 待代码代理游戏验收')
for a in rows:s=s.replace(a['candidate'],a['approved_file'])
p.write_text(s)
readme='''# 第4批：地图与场景物件\n\n状态：美术自检通过，待代码代理接入游戏验收。仅负责第4批；第7批由另一个任务制作。\n\n| 关卡 | 64×64地块 | 透明物件 | 合计 |\n| --- | --- | --- | --- |\n| midgard 芬布尔之冬 | 7 | 13 | 20 |\n| helheim 亡者之船 | 7 | 5 | 12 |\n| vigrid 最后之战 | 6 | 5 | 11 |\n| 合计 | 20 | 23 | 43 |\n\n成品在 `assets/sprites/ground/<level>/` 与 `assets/sprites/props/<level>/`。本目录 `approved/` 保留相同PNG快照；逐文件尺寸、帧数、颜色数、SHA256、原图、裁切区域、提示词、上传参考、会话链接及自检结果见 `manifest.json`。\n\n## 实际制作与工具\n\n生成使用已登录Chrome的ChatGPT网页，第一轮4页并行，第二轮3页并行；后续重做基础雪地与两件物件。全部上传本项目既有像素图作为参考，只使用神话/自然/历史材料，没有引用现代作品角色造型。实际图像处理使用Pillow12.1.1和本项目原创脚本：完整轮廓裁切、洋红底去除与边缘去杂色、最近邻目标尺寸、固定调色板、地块周期边界修正及预览。没有使用Piskel实际修图，没有新注册、付费或调用PixelLabAPI。工具商用依据见 `assets/LICENSES.md`。\n\n## 已执行的自检\n\n- 43张PNG逐文件完整解码，精确尺寸、RGBA、二值透明检查。地块铺满64×64，所以alpha全为255；物件alpha仅0/255且四周至少2px透明留边。\n- 每关地面与物件共用一份不超过48色的色板；无抖动，无半透明边缘。最终固定色板后重新检查。\n- 所有43张在#121721背景的1×及4×对照图检查：轮廓、完整性、居中、材质、光照方向、文字/水印/额外背景。静态环境不适用角色朝右、脚底基线和动画循环门槛。\n- 20张地块分别4×4平铺，三关基础4种变化随机4×4混铺；检查接缝和突出重复地标。另记录跨边界颜色跳变与内部相邻像素跳变，数值只是辅助，不能代替看图。\n- 三关各制作1280×720的1×静态合成预览，叠加现有角色检查地面与角色的对比、物件与角色风格。**这是本地图片合成，不是Godot截图，也没有测试游戏运行。**\n\n## 退回并修正的内容\n\n1. 首轮基础雪地波纹/石粒重复明显，四张基础雪地重做；新一轮两种候选中选用更安静的第二种。第一种亮斑较密，未采用。\n2. 最初6px边缘混合在4×4平铺中形成横向条带，v01退回；v02以周期边界分解替代，保留细节并降低低频反差。\n3. 直接等分物件图集截断长船等宽轮廓，并混入相邻物件碎片；v01退回，按完整主体范围重新裁切。\n4. 洋红底抗锯齿残留导致紫色边缘；重新去底与去杂色，保留硬边和0/255透明度。\n5. 维格利德v03色板使彩虹桥色带丢失、火焰变暗；v04保留火焰与虹色必要颜色，仍共享48色。\n6. 第二棵枯松造型偏阔叶树，断剑断矛过于完整；上传现有素材重新生成，最终采用版本与原图见manifest。\n\n## 预览与适用边界\n\n- `gallery.html`：43项1×/4×、20项4×4平铺、3份基础混铺、三关1×合成、GIF。\n- `previews/map_preview.gif`：三关静态合成轮播，3帧，每帧1500ms；不是角色/物件动画。\n- `previews/tile_scroll_8fps.gif`：静态地块滚动接缝检查，16帧，120/130ms交替，平均8fps。\n- 这批全部为静态素材（每张1帧）；燃烧残骸里的火焰为静态图形。没有把GIF预览当成运行时动画。\n- 同一基础地面4种变化可随机混铺。雪/冰/冻土、冥石/指甲甲板、焦土/熔岩等不同材质未制作过渡边或Godot地形规则；接入时由代码代理选择区域及过渡方式。\n- 尚待代码代理检查运行时导入、最近邻过滤、场景摆放/遮挡、碰撞与实际战斗可读性。本任务未修改代码、场景、docs或project.godot，未执行gitcommit/push。\n'''
(R/'README.md').write_text(readme)
print('Published',len(rows),'PNGs;',len(raws),'originals;',len(backup),'backups')
