from pathlib import Path
from PIL import Image,ImageSequence,ImageDraw
import runpy,json,hashlib,shutil,re,html,sys
P=runpy.run_path(str(Path(__file__).with_name('pipeline.py')))
ROOT=P['ROOT'];PLAN=P['PLAN'];BG=P['BG'];save=P['save'];sha=P['sha']

def deliver(task,versions,visual_notes):
 assets=[a for a in PLAN if a['task']==task];r=P['init'](assets[0]);rows=[];errors=[];gif_count=0
 for a in assets:
  id=a['id'];v=versions.get(id,'v01');P['init'](a);candidate=r/'candidates'/f'{id}_{v}.png'
  if id=='thokk':P['preview'](id,v)
  im=Image.open(candidate).convert('RGBA');fs=P['frames'](a,im);w,h=a['w'],a['h'];colors={q[:3]for q in im.getdata()if q[3]};alphas=sorted(set(im.getchannel('A').getdata()));boxes=[f.getbbox()for f in fs]
  edge='band'in a['flags'] or 'chain'in a['flags'] or 'tile'in a['flags']
  checks={'PNG_RGBA':Image.open(candidate).format=='PNG'and Image.open(candidate).mode=='RGBA','exact_strip_dimensions':im.size==(w*a['frames'],h),'RGB_within_48':len(colors)<=48,'transparent_background':alphas[0]==0,'every_frame_nonempty':all(boxes),'distinct_original_frames':len({hashlib.sha256(f.tobytes()).hexdigest()for f in fs})==len(fs),'2px_margin_or_tiling_exception':edge or all(b[0]>=2 and b[1]>=2 and b[2]<=w-2 and b[3]<=h-2 for b in boxes)}
  if 'body'in a['flags'] or 'chain'in a['flags']:checks['binary_alpha']=set(alphas)<={0,255}
  if 'body'in a['flags']:checks['same_foot_baseline']=all(b[3]==a['anchor'][1]for b in boxes)
  if id.startswith('thokk_'):
   base=Image.open(r/'candidates/thokk_v01.png');pal={q[:3]for q in base.getdata()if q[3]};checks['same_static_palette']=colors<=pal
  if id=='skoll_howl_body':
   base=Image.open(ROOT/'assets/sprites/bosses/skoll.png').convert('RGBA');checks['same_static_palette']=colors<={q[:3]for q in base.getdata()if q[3]}
  if 'hole'in a['flags']:
   checks['transparent_center']=all(f.getchannel('A').crop((round(w*.45),round(h*.45),round(w*.55),round(h*.55))).getextrema()==(0,0)for f in fs)
  if 'front'in a['flags']:checks['rear_half_transparent']=all(f.getchannel('A').crop((0,0,w//2,h)).getextrema()==(0,0)for f in fs)
  if 'band'in a['flags']or'chain'in a['flags']:checks['identical_repeat_ports']=all(f.crop((0,0,1,h)).tobytes()==f.crop((w-1,0,w,h)).tobytes()for f in fs)
  previews=[str(p.relative_to(r))for p in sorted((r/'previews').glob(f'{id}_{v}_*'))]
  for label,fps in [('native',a['fps']),('slow8',8)]:
   if len(fs)<2:continue
   gp=r/'previews'/f'{id}_{v}_{label}.gif';g=Image.open(gp);decoded=[];duration=0;match=True
   for k,f in enumerate(ImageSequence.Iterator(g)):
    duration+=f.info.get('duration',0);expected=Image.new('RGBA',fs[k%len(fs)].size,BG);expected.alpha_composite(fs[k%len(fs)]);expected=expected.convert('RGB').resize((w*4,h*4),Image.Resampling.NEAREST)
    match=match and f.convert('RGB').tobytes()==expected.tobytes();decoded.append(k)
   checks['GIF_'+label+'_decoded_pixel_match']=match
   checks['GIF_'+label+'_average_fps']=abs(len(decoded)*1000/duration-fps)<0.001
   gif_count+=1
  problems=[k for k,val in checks.items()if not val]
  if problems:errors.append({'id':id,'failed':problems})
  row=dict(a,version=v,final_path=a['target'],candidate=str(candidate.relative_to(r)),sha256=sha(candidate),actual_RGB_colors=len(colors),actual_alpha_values=alphas,frame_bboxes=boxes,technical_checks=checks,visual_review={'status':'passed'if not problems else'pending_technical_correction','observations':visual_notes.get(id,'')},code_integration='not_performed',game_acceptance='not_performed',source_license={'tool':'OpenAI built-in image_gen','commercial_basis':'existing approved OpenAI output terms; project-owned input references','terms_url':'https://openai.com/policies/terms-of-use/','processing':'Pillow MIT-CMU, source cuts/alpha/palette/nearest resize/placement and preview only'},previews=previews)
  assert visual_notes.get(id),('Missing actual visual review',id)
  rows.append(row)
 save(r/'records/technical_audit.json',{'task':task,'status':'pass'if not errors else'fail','files_checked':len(rows),'GIFs_decoded_checked':gif_count,'errors':errors,'game_test':'not_performed'})
 if errors:print(json.dumps(errors,ensure_ascii=False,indent=2));return False
 for row in rows:
  src=r/row['candidate'];dst=ROOT/row['target'];dst.parent.mkdir(parents=True,exist_ok=True)
  if dst.exists()and sha(dst)!=sha(src):
   b=r/'records/replaced_runtime';b.mkdir(exist_ok=True);shutil.copy2(dst,b/(dst.stem+'_'+sha(dst)[:12]+dst.suffix))
  approved=r/'approved'/(row['id']+'.png')
  shutil.copy2(src,approved);shutil.copy2(src,dst)
  row['approved']=str(approved.relative_to(r))
  assert sha(src)==sha(dst)==sha(approved)
 for row in rows:
  assert sha(r/row['candidate'])==sha(ROOT/row['target'])==sha(r/row['approved'])
 jobs=[]
 for f in sorted((r/'records').glob('prompt_*.json')):jobs.append(json.loads(f.read_text()))
 for f in sorted((r/'records').glob('job_*.json')):jobs.append(json.loads(f.read_text()))
 save(r/'records/generation_jobs.json',jobs)
 save(r/'manifest.json',{'task_id':task,'date':'2026-10-19','production':'delivered','self_review':'pass','code_integration':'not_performed','game_acceptance':'not_performed','files':rows,'originals':[{'file':str(p.relative_to(r)),'sha256':sha(p)}for p in sorted((r/'originals').glob('*.png'))],'generation_records':'records/generation_jobs.json','limitations':['Technical measurements and local previews do not prove Godot gameplay acceptance.']})
 save(r/'records/production_plan.json',assets)
 intro=f'# {task} 制作交付\n\n{len(rows)} 个 PNG 已复制到正式目录。逐帧静态检查已做，原速和8fps慢放GIF已生成并解码核对；浏览器播放检查另记，不冒充游戏实测。\n\n制作：完成；文件与美术自检：通过；代码接入：未执行；游戏验收：未执行。\n\n## 逐文件实际观察\n\n'
 for row in rows:intro+=f"- `{row['target']}`：{visual_notes[row['id']]}\n"
 intro+='\n## 来源与限制\n\n使用已批准的内置 image_gen，只上传本项目参考图。原图、失败稿、实际提示词和输入路径存 originals/ 与 records/。商用依据沿用项目已核验的 OpenAI 输出条款：https://openai.com/policies/terms-of-use/ 。Pillow MIT-CMU 仅用于原像素裁排、统一尺度、色表与透明、预览和检查，未用 Python 重画角色或特效。\n\n原图工具未提供公开生成会话链接，保留实际返回路径和工具记录，不伪造URL。\n\n所有新特效仍需代码接入；见 integration.md。没有执行 Godot 测试、修改代码/场景/项目设置或 Git 提交推送。\n'
 if task=='H0':intro+='\n## 退回稿与接入问题\n\n`thokk_attack_v01` 伸臂过长，固定脚底中心后越界；已保留原图，最终使用 v02 近身短挥击。女巨人脚底落在第91行，地面基线为y92。现有敌人加载器按radius×2.6计算52px显示高，精英倍率在height计算中抵消；若需要96px画布按1倍显示，应由集成Agent单独确认并配置显示高度，不修改碰撞半径。\n'
 (r/'README.md').write_text(intro)
 integ=f'# {task} 代码接入交接（未执行）\n\n素材放入目录不等于接入；此文件是逐项交接，未改任何游戏代码。坐标从单帧左上角起算，+X向右、+Y向下；默认旋转0指向右，正角为顺时针。中心锚点与脚底点请用源像素坐标减去后再旋转/缩放。\n\n'
 for row in rows:
  integ+=f"## {Path(row['target']).name}\n\n- 正式路径：`{row['target']}`；SHA256 `{row['sha256']}`。\n- 单帧：{row['w']}×{row['h']}；横向{row['frames']}帧，无间隔；{row['fps']}fps；{'循环（状态结束立即停止）'if row['loop']else'单次（播完释放临时节点；单张除外）'}。\n- 锚点：{row['anchor']}，源像素；方向和透明要求按 manifest，避免使用整张帧条尺寸计算锚点。\n- 目标脚本／函数：{row['hook']}。\n- 替换与保持：{row['keep']}。\n- 层级／缩放／遮罩：区域效果放人物下方，接触闪光短播放人物附近；按实际判定范围裁切，不能扩大伤害暗示。曲线与圆弧条段用独立网格/节段排布，禁止整个帧条直接当单图。保留原预警几何和伤害逻辑；替换对应旧重复视觉，资源缺失保留回退。\n- 后续验收：真实视角逐帧核对朝向/锚点/遮挡/范围、状态结束释放、多人同屏节点数。代码接入未执行；游戏验收未执行。\n\n"
 if task=='H0':integ+='## 显示尺度待确认\n\n`Enemy._ready()` 的height=radius×2.6/(精英倍率)使该类型显示约52px高。thokk文件按96px制作，若希望1倍巨人尺度请做类型专用显示高度；碰撞radius20、血量、速度、精英逻辑、逃跑与攻击判伤不改。`SpriteVisual` 现有move/attack自动加载可用；攻击逻辑实际函数名为 `_update_attack()`。\n'
 if task=='H3':integ+='## 必须在游戏中核对\n\n`Shockwave._in_gap()` 的两处±0.42rad缺口必须同步用于美术裁切，整片宽度BAND26；不能用静态完整环覆盖缺口。盾弧随_facing旋转并限制±1.3rad，背后透明。预览合成只证明制作方法，不证明游戏判伤一致。\n'
 if task=='H6':integ+='## 分区与安全边界\n\n两侧纹理以_anchor.x严格分区裁切，再受安全圈遮罩；安全圈与原圈外压暗保留，领域边缘不能充当新的判伤来源。地面低alpha纹理不得盖住预警。船转阶段特效保持中心通透，船帆与指甲弹幕应在其上方可辨。\n'
 (r/'integration.md').write_text(integ)
 parts=['<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>'+task+' 素材交付</title><style>body{background:#121721;color:#dde4ef;font:15px/1.6 system-ui;margin:24px}a{color:#91cdfb}section{border-top:1px solid #46505e;padding:20px 0}img{image-rendering:pixelated;max-width:100%;vertical-align:top}.strip{overflow:auto}p{max-width:1100px}</style><h1>'+task+' 素材交付</h1><p>制作与文件自检完成；代码接入／游戏验收未执行。GIF循环仅供观察，正式单次／循环约定见清单。</p><p><a href="manifest.json">manifest</a> · <a href="README.md">README</a> · <a href="integration.md">integration</a> · <a href="records/technical_audit.json">文件审计</a></p>']
 for row in rows:
  parts+=['<section><h2>'+row['id']+'</h2><p>'+html.escape(visual_notes[row['id']])+'</p><p>'+f"{row['w']}×{row['h']} ×{row['frames']}帧 / {row['fps']}fps / anchor{row['anchor']}"+'</p><a href="'+row['approved']+'">正式快照</a>']
  for rel in row['previews']:parts+=['<div class="strip"><p>'+Path(rel).name+'</p><img src="'+rel+'"></div>']
  parts+=['</section>']
 parts+=['</html>'];(r/'gallery.html').write_text(''.join(parts))
 broken=[u for u in re.findall(r'(?:src|href)="([^"]+)"',(r/'gallery.html').read_text())if ':'not in u and not(r/u).exists()];assert not broken,broken
 save(r/'records/final_audit.json',{'task':task,'status':'pass','published_files':len(rows),'candidate_approved_runtime_hash_match':True,'technical_audit':'records/technical_audit.json','gallery_local_links_checked':len(re.findall(r'(?:src|href)="([^"]+)"',(r/'gallery.html').read_text())),'broken_links':broken,'code_integration':'not_performed','game_test':'not_performed'})
 print(task,'DELIVERED',len(rows));return True

if __name__=='__main__':
 task=sys.argv[1];r=ROOT/next(a['source_root']for a in PLAN if a['task']==task);review=json.loads((r/'records/visual_reviews.json').read_text());deliver(task,review['versions'],review['observations'])
