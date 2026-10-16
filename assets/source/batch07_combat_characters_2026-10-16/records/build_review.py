from pathlib import Path
from PIL import Image
import json,html
r=Path(__file__).resolve().parents[1]
items=json.loads((r/'records/candidates.json').read_text())
manifest=json.loads((r/'manifest.json').read_text())
accepted=[];pending=[]
for j in items:
 im=Image.open(r/j['candidate']).convert('RGBA');count=j.get('frames',im.width//im.height)
 fw,fh=j.get('frame_size',[im.width if count==1 else im.height,im.height])
 frames=[im.crop((i*fw,0,(i+1)*fw,fh)) for i in range(count)]
 contact=Image.new('RGB',(fw*count,fh),'#121721');ps=[]
 for i,f in enumerate(frames):
  bg=Image.new('RGBA',(fw,fh),'#121721');bg.alpha_composite(f);contact.paste(bg.convert('RGB'),(i*fw,0));ps.append(bg.resize((fw*4,fh*4),Image.Resampling.NEAREST).convert('RGB'))
 stem=Path(j['candidate']).stem
 contact.save(r/f'previews/{stem}_contact_1x.png');contact.resize((contact.width*4,contact.height*4),Image.Resampling.NEAREST).save(r/f'previews/{stem}_contact_4x.png')
 motion=''
 if count>1:
  slow=[120 if i%2==0 else 130 for i in range(count)]
  ps[0].save(r/f'previews/{stem}_slow8fps.gif',save_all=True,append_images=ps[1:],duration=slow,loop=0,disposal=2)
  fps=j.get('fps',16);timings=[round((i+1)*100/fps)*10-round(i*100/fps)*10 for i in range(count)]
  suffix='attack16fps' if fps==16 else 'action8fps'
  ps[0].save(r/f'previews/{stem}_{suffix}.gif',save_all=True,append_images=ps[1:],duration=timings,disposal=2)
  ps[0].save(r/f'previews/{stem}_{suffix}_QA_loop.gif',save_all=True,append_images=ps[1:],duration=timings,loop=0,disposal=2)
  motion=f'<p>{fps} fps动作反复观察 / 8 fps慢放</p><img loading="lazy" src="previews/{stem}_{suffix}_QA_loop.gif"><img loading="lazy" src="previews/{stem}_slow8fps.gif"><p>GIF受10ms计时量化限制；游戏用PNG按目标帧率播放。非游戏内验收。</p>'
 card=f'<article><h2>{html.escape(j["id"])} / {stem}</h2><p>{html.escape(j.get("status","candidate_pending_review"))}</p><p>1× 全帧</p><img loading="lazy" src="previews/{stem}_contact_1x.png"><p>4× 全帧</p><div class="wide"><img loading="lazy" src="previews/{stem}_contact_4x.png"></div>{motion}</article>'
 (accepted if j['status']=='art_self_check_passed_pending_game_review' else pending).append(card)
state='美术自检完成' if manifest['approved_assets']==29 else '进行中'
(r/'gallery.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>第7批战斗动作·制作审核</title><style>body{background:#121721;color:#e0e7ef;font:16px system-ui;margin:28px}article{border-top:1px solid #49515e;padding:16px 0}img{image-rendering:pixelated;margin-right:18px}.wide{overflow:auto}h1{font-size:24px}</style><h1>第7批战斗动作 · '+state+'</h1><p>'+str(manifest['approved_assets'])+'/29项已通过美术自检，待游戏验收。只把通过的文件放入sprites。人物素材的地块4×4平铺检查不适用。</p><p><a href="manifest.json">manifest</a> · <a href="README.md">README</a> · <a href="records/production_plan.json">完整任务状态</a> · <a href="records/final_audit.json">文件核对</a></p><img src="previews/handoff_overview.png" alt="第7批角色及动作总览">'+''.join(accepted)+'<details><summary>其他候选与中间版本（'+str(len(pending))+'）</summary>'+''.join(pending)+'</details></html>')
print('approved',len(accepted),'other candidates',len(pending))
