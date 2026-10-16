from pathlib import Path
from PIL import Image
import hashlib,html,json
r=Path(__file__).resolve().parents[1]
meta_path=r/'records/skoll_idle_review.json'
review=json.loads(meta_path.read_text()) if meta_path.exists() else {'status':'technical_pass_pending_motion_review'}
assets=[]
for char,size in [('skoll',128),('hati',128),('hrym',192)]:
 for action,count in [('idle',4),('move','4-6'),('windup','2-3'),('attack','2-3')]:
  a={'id':char+'_'+action,'frame_size':[size,size],'expected_frames':count,'status':'not_started','final_copied':False}
  if char in ['skoll','hati'] and action in ['move','windup','attack']:a['status']='v01_rejected_v02_generated_pending_review'
  if a['id']=='skoll_idle':
   im=Image.open(r/'candidates/skoll_idle_v02.png').convert('RGBA');a.update(generation_url=review.get('generation_url'),status=review['status'],candidate='candidates/skoll_idle_v02.png',frames=4,size=list(im.size),colors=len(set(p[:3] for p in im.get_flattened_data() if p[3])),source='references/skoll.png',tools=['Chrome Piskel actual UI pixel edits, frame duplicate and reorder','Pillow deterministic 48-color reference normalization and QA previews'],generation_record='records/skoll_idle_repair_pixel_plan_v02.json',preview_gif='previews/skoll_idle_v02.gif',editable='candidates/skoll_idle_v02.piskel',review=review)
  assets.append(a)
for name,count in [('hati_howl',3),('hrym_shield',2),('hrym_stomp',3)]:assets.append({'id':name,'frame_size':[128,128] if name.startswith('hati') else [192,192],'expected_frames':count,'status':'not_started','final_copied':False})
manifest={'batch':'batch03_stage01_boss_actions_2026-10-16','status':'in_progress','assets':assets,'generation_jobs_v01':'records/generation_jobs_v01.json','generation_jobs_v02':'records/generation_jobs_v02.json','rejected_candidates':'records/wolf_candidates_metadata_v01.json','game_test':'not_performed','terrain_4x4':'not_applicable_no_terrain_in_batch_3','approved_count':sum(a['status'].startswith('self_check_passed') for a in assets),'final_copied_count':0}
(r/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>第 3 批 Boss 动作 · 制作中</title><style>body{margin:0;padding:28px;background:#121721;color:#e4eaf3;font:15px/1.65 system-ui}h1{font-size:25px}a{color:#9dccff}article{border-top:1px solid #3c485f;padding-top:12px;margin:28px 0}img{image-rendering:pixelated}details{overflow:auto}.pending{color:#ffc08d}.row{display:flex;align-items:end;gap:32px}</style><h1>第 3 批 · 第 1 关 Boss 动作（制作中）</h1><p>尚未完成整批验收，尚未新增正式动作文件。斯库尔待机完成实际 Piskel 导出，当前状态：'''+html.escape(review['status'])+'''。</p><p><a href="manifest.json">manifest.json</a> · <a href="README.md">README</a> · <a href="../../LICENSES.md">授权台账</a></p><article><h2>斯库尔待机 · 实际 1 倍</h2><div class="row"><div>原角色参考<br><img width="128" height="128" src="references/skoll.png"></div><div>实际导出四帧<br><img width="512" height="128" src="candidates/skoll_idle_v02.png"></div></div><details><summary>横向帧条最近邻 4 倍</summary><img width="2048" height="512" src="candidates/skoll_idle_v02.png"></details><h3>实际导出帧的 GIF · 4 倍、平均 8 FPS</h3><img width="512" height="512" src="previews/skoll_idle_v02.gif"><p>只在身体局部和火焰尖端变化；A→B→C→B，脸部与脚底保持原图。GIF 为实际 Piskel PNG 导出后的预览，不是生成方案示意。</p></article><article class="pending"><h2>第一轮移动／攻击候选 · 退回</h2><p>躯干与镜头比例偏离原图；扑咬时身体过长，统一缩放后变小；移动存在近似重复姿态。不作为成品。</p><img width="800" height="1080" src="previews/wolf_candidates_contact_1x_v01.png"></article><article><h2>第二轮重做</h2><p>Chrome 四标签上传原角色与排版定位模板重新生成。正在下载、审核，尚未通过。</p></article><article><h2>其余待做</h2><p>哈提待机／嚎叫、赫列姆全部动作与举盾／举锤砸地。第 4 至第 6 批尚未开始。本批不含地块，地块 4×4 不适用。未进行游戏实测。</p></article></html>'''
v02_path=r/'records/wolf_candidates_metadata_v02.json'
if v02_path.exists():
 clips=''
 for entry in json.loads(v02_path.read_text()):
  clips+='<article class="pending"><h2>'+html.escape(entry['id'])+' v02 · 待动作审核</h2><p>固定角色色板、透明边缘与脚底基线已规范化；未批准。</p><img width="'+str(entry['frames']*128)+'" height="128" src="'+entry['candidate']+'"><h3>4 倍、名义 8 FPS</h3><img width="512" height="512" src="'+entry['preview']+'"><p>'+('循环移动预览' if entry['loop'] else '单次技能阶段预览；GIF 不循环，刷新页面可重新播放。')+'</p></article>'
 
 for char in ['skoll','hati']:
  clips+='<article><h2>'+char+' 蓄力→出招→收回 · 连续 6 帧检查</h2><p>由同一次生成的实际规范化帧组成，4 倍、8 FPS 循环，仅用于检查阶段衔接。</p><img width="512" height="512" src="previews/'+char+'_skill_sequence_v02.gif"></article>'
 page=page.replace('</html>',clips+'</html>')
(r/'gallery.html').write_text(page)
print({'status':'in_progress','idle_review':review['status']})
