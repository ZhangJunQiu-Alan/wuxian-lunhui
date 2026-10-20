from pathlib import Path
from PIL import Image,ImageDraw,ImageSequence,ImageStat
import json,hashlib,math,re,runpy
R=Path(__file__).resolve().parents[4];HOME=Path(__file__).resolve().parent.parent
plan=json.loads((HOME/'records/plan_all_H.json').read_text())
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
records=[]
browser={
'H0':(['thokk_move_v01_native.gif','thokk_attack_v02_slow8.gif'],'H0图库、行走两个时间点和攻击慢放截图实际可见'),
'H1':(['skoll_howl_body_v01_native.gif'],'H1图库和狼体嚎叫GIF截图实际可见'),
'H2':(['hati_split_flash_v01_native.gif'],'H2图库和分裂闪雾GIF截图实际可见'),
'H3':(['hrym_wave_band_v01_native.gif'],'冰浪条带GIF截图实际可见'),
'H4':(['garm_chain_break_v01_native.gif'],'铁链崩断GIF截图实际可见'),
'H5':(['nidhogg_emerge_burst_v02_slow8.gif','nidhogg_poison_breath_v01_native.gif'],'破土慢放和毒息原速GIF截图实际可见'),
'H6':(['hel_board_ship_v01_native.gif'],'登船冥雾GIF截图实际可见')}
for task in [f'H{i}'for i in range(7)]:
 a=next(a for a in plan if a['task']==task);p=R/a['source_root'];mf=p/'manifest.json';m=json.loads(mf.read_text())
 code=[]
 for row in m['files']:
  row['frame_order']='left_to_right_no_spacing';row['generation_records']='records/generation_jobs.json';row['public_generation_url']=None;row['generation_url_note']='内置工具仅返回本地原图路径；真实提示词/参考/结果均归档，不伪造公开URL'
  row['transparent_strategy']='RGBA binary alpha0/255; zero RGB when alpha0'if'body'in row['flags']or'chain'in row['flags']else'Generated alpha quantized to 8 source levels then optional low-alpha cap; RGB count and alpha recorded separately; zero RGB when alpha0'
  if row['task']=='H0'and row['id']=='hel_death_bolt':row['transparent_strategy']='Generated alpha preserved with initial 16-step quantization; RGB/alpha measured separately; zero RGB when alpha0'
  row['loop_mode']='loop only while corresponding state is active'if row['loop']else'single shot / static; single-shot temporary display fades and frees at end'
  row['remaining_issues']=['代码接入未执行','游戏内朝向/锚点/范围/遮挡/帧率/节点清理未测']
  if row['id'].startswith('thokk'):row['remaining_issues'].append('现有loader按radius×2.6算约52px显示高；由集成Agent确认96px显示，不改radius20')
  for s in re.findall(r'scripts/[A-Za-z0-9_/]+\.gd',row['hook']):
   f=R/s
   if f.exists()and not any(x['file']==s for x in code):code.append({'file':s,'sha256_at_handoff':sha(f),'read_only_reference':True})
 save(mf,m);save(p/'records/code_reference_hashes.json',code)
 save(p/'records/browser_review.json',{'date':'2026-10-19','browser':'Chrome alan via cua_repl','files_actually_opened':browser[task][0],'observations':browser[task][1],'scope':'抽样浏览器加载/播放帧截图；其余逐帧深色底/解码时序检查见technical_audit，未声称每条都在浏览器连续看完','game_test':'not_performed'})
 if task in ['H1','H2','H3','H4','H5','H6']:
  note='\n\n## 接入时必须保留的几何边界\n\nPNG的非透明区域是纹理，不是新碰撞／判伤区域。预警几何和判伤边界仍以原代码为准：保留清晰的原边界线或低亮带底，纹理按原有区域裁切、不得越过安全缺口／背后可攻击区／生死分区。单次特效发生与峰值对齐现有技能触发时间，不为追逐动画峰值而延迟判伤；末段按显示寿命淡出并清理。\n'
  if task=='H3':note+='\n冰浪的原BAND26底带建议保留低亮度，以便读出全伤害宽度；新短带作纹理覆盖，按两处±0.42rad缺口同一mask裁切。前盾弧只在±1.3rad正面绘制，不能将完整右半圆未裁切地当作判定。\n'
  if task=='H5':note+='\n毒息原图为96×64的向右扇形纹理，不能简单等比放大到300×200来代表整个判伤扇区。由集成Agent使用原300范围、±0.6rad的扇形mesh／遮罩并以(4,32)为喷口映射UV，按扇区适配横纵尺度，保留完整预警轮廓、巨石阵阻挡和原毒池。破土特效中心对齐实际_crack；原EMERGE_RADIUS100边界保留。\n'
  (p/'integration.md').write_text((p/'integration.md').read_text()+note)
 (p/'README.md').write_text((p/'README.md').read_text()+'\n\n## 浏览器与范围检查边界\n\nChrome实际打开的抽样GIF和观察见 `records/browser_review.json`。所有帧条已逐格看原图与1倍/4倍深色底，GIF已解码核对像素和平均时序；这不等于逐条浏览器长时间播放或Godot游戏验收。范围合成只使用项目地面/角色与脚本参数，不能据此宣称游戏判伤或节点性能已验收。\n')
 records.append((task,p,m))
# Supplement the initially hand-normalized static source recipe.
static=Image.open(HOME/'candidates/thokk_v01.png').convert('RGBA')
save(HOME/'records/normalization_thokk_v01.json',{'source':'originals/thokk_v01.png','alpha_threshold':128,'source_crop_bbox':[291,93,978,1185],'nearest_fit_box':[84,88],'palette_operation':'Pillow MEDIANCUT 48RGB, NONE dither','paste_ground_baseline':92,'final_bbox':static.getbbox(),'candidate_sha256':sha(HOME/'candidates/thokk_v01.png'),'scope':'formatting only; no repaint'})
# Dark-terrain ship/sail overlay for the new transition VFX.
p=next(p for t,p,m in records if t=='H6');ship=Image.open(R/'assets/sprites/props/helheim/naglfar_sail.png').convert('RGBA');body=Image.open(R/'assets/sprites/bosses/hel.png').convert('RGBA');bolt=Image.open(R/'assets/sprites/effects/nail_bolt.png').convert('RGBA');fx=Image.open(R/'assets/sprites/effects/bosses/hel_board_ship.png').crop((128,0,256,128)).convert('RGBA')
o=Image.new('RGBA',(1024,650),'#121721');sx=(1024-ship.width)//2;sy=570-ship.height;o.alpha_composite(ship,(sx,sy));o.alpha_composite(fx,(448,340));o.alpha_composite(body,(512-body.width//2,430-body.height))
for x,y in[(360,410),(650,390),(740,440)]:o.alpha_composite(bolt,(x,y))
ImageDraw.Draw(o).text((12,10),'OFFLINE SHIP / SAIL / BODY / BARRAGE COMPOSITE - NOT GAME ACCEPTANCE',fill='white');o.convert('RGB').save(p/'previews/hel_board_ship_v01_ship_overlay.png')
# Common-size giant comparison; preview only.
o=Image.new('RGBA',(1152,460),'#121721');d=ImageDraw.Draw(o)
for k,(path,label)in enumerate([('assets/sprites/enemies/frost_giant.png','existing giant'),('assets/sprites/enemies/frost_veteran.png','existing veteran'),('assets/sprites/enemies/thokk.png','new elderly female giant')]):
 f=Image.open(R/path).convert('RGBA');o.alpha_composite(f.resize((384,384),Image.Resampling.NEAREST),(k*384,40));d.text((k*384+8,10),label,fill='white')
o.convert('RGB').save(HOME/'previews/thokk_style_comparison.png')
# Collect rotation/stretch previews into readable review boards.
visuals=[]
for task,p,m in records:
 for row in m['files']:
  for suffix in ['rotate','stretch']:
   f=p/'previews'/f'{row["id"]}_{row["version"]}_{suffix}.png'
   if f.exists():visuals.append(f)
for block in range(math.ceil(len(visuals)/6)):
 o=Image.new('RGB',(1200,1000),'#121721');d=ImageDraw.Draw(o)
 for k,f in enumerate(visuals[block*6:block*6+6]):
  im=Image.open(f).convert('RGB');im.thumbnail((580,285),Image.Resampling.NEAREST);x=k%2*600;y=k//2*330;d.text((x+5,y+3),f.stem,fill='white');o.paste(im,(x+5,y+25))
 o.save(HOME/'previews'/f'rotation_stretch_board_{block+1}.png')
# Link extra preview artifacts without modifying delivered pixels.
for task,p,m in records:
 page=p/'gallery.html';s=page.read_text();extras=['previews/thokk_style_comparison.png']if task=='H0'else['previews/hel_board_ship_v01_ship_overlay.png']if task=='H6'else[]
 if extras:s=s.replace('</html>',''.join('<p>'+Path(x).name+'</p><img src="'+x+'">'for x in extras)+'</html>');page.write_text(s)
# Top-level handoff remains inside H0's own source directory.
head='# H0～H6 交付总表（2026-10-19）\n\n文件交付与素材自检完成；代码接入未执行；游戏验收未执行。只制作H0～H6，未接管G6，未执行I/J/K/L，未改代码、场景、设置、导入，未提交或推送。\n\n|任务|PNG|制作|文件自检|接入|游戏验收|交接|\n|---|---:|---|---|---|---|---|\n'
parts=['<!doctype html><meta charset="utf-8"><title>H0–H6 交付总览</title><style>body{background:#121721;color:#e0e7ef;font:16px/1.7 system-ui;margin:28px}a{color:#9ed5ff}img{image-rendering:pixelated;max-width:100%}table{border-collapse:collapse}td,th{padding:10px;border-bottom:1px solid #354054}</style><h1>H0～H6 交付总览</h1><p>33张PNG；制作/文件自检完成；代码接入与游戏验收未执行。</p><p><a href="handoff.md">总交接表</a> · <a href="records/final_delivery_audit.json">最终审计</a></p><table><tr><th>任务</th><th>文件数</th><th>图库</th><th>接入说明</th></tr>']
for task,p,m in records:
 rel='.'if task=='H0'else'../'+p.name;head+=f'|{task}|{len(m["files"])}|完成|通过|未执行|未执行|[{task} integration]({rel}/integration.md)|\n';parts.append(f'<tr><td>{task}</td><td>{len(m["files"])}</td><td><a href="{rel}/gallery.html">gallery</a></td><td><a href="{rel}/integration.md">integration</a></td></tr>')
head+='\n## 所需代码接入与剩余问题\n\n- thokk现有动作命名可被加载，但现有高度公式将96px画布显示约52px；由集成Agent确认显示尺度，碰撞半径不改。\n- 海拉第一阶段冥界弹需替换 `_fan()` 空纹理，不能改第二阶段指甲弹。\n- 其余新Boss特效逐项显式接入，按各integration.md保留预警、伤害、AI、冷却、控制、召唤和转阶段。\n- 赫列姆两处动态缺口/盾背、加姆本体与锁桩、尼德霍格扇形/潜地/啃根、海拉分区/安全圈/船帆弹幕必须实际游戏验收。\n- 仍未测真实游戏视角、技能判伤对齐、密集战斗遮挡、节点清理和帧率；不能标记游戏验收通过。\n\n## 修正与来源\n\n女巨人攻击v01伸臂越界退回，v02近身短挥击通过；破土v01末帧留石堆退回，只采用新v02末帧淡尘且前3格保持原像素。首次声波GIF量化色差导出已保留，限色/透明阶梯修正后解码核验通过。同名狼体/声波的approved快照采用不同ID避免冲突，最终逐文件哈希核验。全部原图和失败候选保留，没有虚构公开生成URL。\n'
(HOME/'handoff.md').write_text(head);parts.append('</table><p>详细尺寸、帧率、锚点、透明策略、色数、SHA256、来源与实际自检见各manifest。</p><img src="previews/thokk_style_comparison.png">');(HOME/'handoff.html').write_text(''.join(parts))
print('Metadata, handoff and review boards finalized:',len(visuals),'rotation/stretch previews')
