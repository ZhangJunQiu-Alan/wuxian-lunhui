from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,shutil,html
r=Path(__file__).resolve().parents[1];assetsroot=r.parents[1];m=json.loads((r/'manifest.json').read_text());assert len(m['assets'])==15 and m['approved_count']==15;target=assetsroot/'sprites/bosses';target.mkdir(parents=True,exist_ok=True);contact=Image.new('RGB',(1024,1152),'#121721');d=ImageDraw.Draw(contact)
for i,a in enumerate(m['assets']):
 review=json.loads((r/f'records/{a["id"]}_review.json').read_text());a.update(review);source=r/a['candidate'];im=Image.open(source).convert('RGBA');im.load();n=a['frame_size'][0];count=im.width//n;assert im.size==(n*count,n);colors={p[:3] for p in im.get_flattened_data() if p[3]};assert len(colors)<=48;palette={tuple(p) for p in json.loads((r/f'records/{a["id"].split("_")[0]}_reference_palette.json').read_text())};assert colors<=palette;assert set(im.getchannel('A').get_flattened_data())=={0,255}
 for k in range(count):
  b=im.crop((k*n,0,(k+1)*n,n)).getbbox();assert b[0]>=2 and b[1]>=2 and b[2]<=n-2 and b[3]<=n-2
 gif=a.get('preview') or a.get('preview_gif');assert gif and (r/gif).exists();g=Image.open(r/gif);g.load();assert g.size==(n*4,n*4)
 out=target/f'{a["id"]}.png'
 if out.exists() and out.read_bytes()!=source.read_bytes():
  backup=r/f'backups/sprites/bosses/{out.name}';backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(out,backup)
 shutil.copy2(source,r/f'approved/{a["id"]}.png');shutil.copy2(source,out);shutil.copy2(r/gif,r/f'previews/{a["id"]}.gif');sha=hashlib.sha256(source.read_bytes()).hexdigest();assert hashlib.sha256(out.read_bytes()).hexdigest()==sha
 a.update(status='self_check_passed_pending_game_review',final_copied=True,final_path=f'sprites/bosses/{a["id"]}.png',approved_file=f'approved/{a["id"]}.png',preview_gif=f'previews/{a["id"]}.gif',size=list(im.size),frames=count,colors=len(colors),sha256=sha,tools=review.get('tools',a.get('tools',[])),source=review.get('source',a.get('source')),license_record='../../LICENSES.md')
 x=i%4*256;y=i//4*288;d.text((x+12,y+10),a['id'],fill='#e4eaf3');f=im.crop((0,0,n,n));contact.paste(f,(x+(256-n)//2,y+46+(192-n)//2),f);d.text((x+12,y+254),f'{n}x{n}  {count} frames  {len(colors)} colors',fill='#a9e7b6')
contact.save(r/'previews/batch03_4x4_contact.png');m.update(status='complete_self_checked_pending_game_review',approved_count=15,final_copied_count=15,required_count=15,generation_records=[f'records/generation_jobs_{v}.json' for v in ['v01','v02','wave03','wave04','wave05','wave06']],original_png_count=len(list((r/'originals').glob('*.png'))),terrain_4x4='not_applicable_no_terrain_in_batch_3',sprite_4x4_overview='previews/batch03_4x4_contact.png',game_test='not_performed',notes=['15条PNG全部复制到sprites/bosses，逐项哈希已复核。','移动为快速追击节奏；斯库尔包围框顶部17/9/8/16，未声称达到生成提示词慢走1像素起伏目标，游戏速度与帧速由代码代理审核。','单次技能阶段保持不循环；QA连续预览另作循环仅检查阶段衔接。','三帧GIF受10毫秒计时精度限制，120/130/120毫秒，名义8FPS，平均8.108FPS；PNG动作速度由游戏侧设置。','Piskel失败候选保留，只有approved及final_path是自检通过稿。'])
(r/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>第 3 批 Boss 动作 · 15 项自检通过</title><style>body{background:#121721;color:#e4eaf3;padding:24px;font:15px/1.65 system-ui}a{color:#9dccff}img{image-rendering:pixelated}article{border-top:1px solid #455066;margin-top:24px;padding-top:12px}details{overflow:auto}.row{display:flex;align-items:end;gap:20px}.passed{color:#a9e7b6}</style><h1>第 3 批 Boss 动作 · 15 / 15 自检通过</h1><p>PNG 已复制到 assets/sprites/bosses/，尚待代码代理接入与游戏验收；本代理未进行游戏实测。</p><p><a href="manifest.json">manifest.json</a> · <a href="README.md">README</a> · <a href="../../LICENSES.md">授权台账</a></p><p>狼移动采用快速追击步态；并非提示词中仅起伏1像素的慢走。单次技能的GIF不循环，游戏播放速度需接入审核。</p><h2>4×4 精灵总览</h2><p>这是精灵联系表；本批不含地块，无缝地块4×4平铺不适用。</p><img width="768" src="previews/batch03_4x4_contact.png">'''
for a in m['assets']:
 n=a['frame_size'][0];page+=f'<article><h2 class="passed">{a["id"]} · 自检通过</h2><div class="row"><div>原角色 1×<br><img width="{n}" height="{n}" src="references/{a["id"].split("_")[0]}_48color.png"></div><div>实际帧条 1×<br><img width="{a["size"][0]}" height="{n}" src="{a["approved_file"]}"></div></div><details><summary>实际 PNG 最近邻 4×</summary><img width="{a["size"][0]*4}" height="{n*4}" src="{a["approved_file"]}"></details><p>实际帧预览 GIF · 4×，名义8FPS</p><img width="{n*4}" height="{n*4}" src="{a["preview_gif"]}"><p><a href="records/{a["id"]}_review.json">逐项审核记录</a> · <a href="../../{a["final_path"]}">最终 PNG</a></p></article>'
page+='</html>';(r/'gallery.html').write_text(page)
(r/'README.md').write_text(f'''# 第 3 批：第 1 关 Boss 动作

15 / 15 条美术自检通过，PNG 已复制到 assets/sprites/bosses/；状态为 complete_self_checked_pending_game_review。尚待代码代理接入与游戏审核，本代理未运行游戏。

- 斯库尔：待机4帧、移动4帧、蓄力3帧、咬击3帧；每帧128×128，脚底y117。
- 哈提：待机4帧、移动4帧、蓄力3帧、咬击3帧、嚎叫3帧；每帧128×128，脚底y118。
- 赫列姆：待机4帧、移动4帧、蓄力3帧、出招3帧、举盾2帧、举锤砸地3帧；每帧192×192，脚底y189。

所有PNG为RGBA、二值透明、每角色共用参考48色板、横向无间隙帧条；尺寸、边距、基线、颜色与最终文件哈希均复核。每条实际观察记录见 records/*_review.json，浏览器相位截图、1×/4×联系表见 records/ 与 previews/。manifest.json逐条记录原图、工具、会话、提示词记录、尺寸、帧数、颜色、预览、哈希和最终路径。

原图共 {m['original_png_count']} 张，保存在 originals/。所有新动作均上传本项目现有角色作为参考，未引用第三方作品角色。完整提示词与会话见 records/generation_jobs_*.json。沿用 assets/LICENSES.md 已核验的 OpenAI、Piskel、Pillow 商用依据，无新账号、付款或API调用。

## 实际人工修正

斯库尔待机、哈提待机、赫列姆待机、哈提嚎叫与哈提抬爪均经Chrome Piskel界面修正。哈提移动最终为v08：第1与第4帧爪部复制自同一角色其他帧，移除生成时的环形爪；实际PNG导出与验证结果0像素差异，限定区域外不变。可编辑.piskel保存在candidates/，其余动作由上传参考后的生成原图作确定性切帧与规范化。

## 播放与审核边界

狼移动采用快速追击节奏。斯库尔各帧包围框顶部17、9、8、16像素，是低伏/伸展步态；未达到提示词中慢走最多1像素起伏的目标，不把该目标写成通过。最终移动速度与动画节奏交代码代理游戏审核。

GIF为实际PNG帧的4倍最近邻预览，名义8FPS。四帧120/130/120/130毫秒，平均8FPS；三帧120/130/120毫秒，受GIF时间粒度限制平均8.108FPS。PNG动画可在Godot设置精确8FPS。蓄力/出招/嚎叫/举盾/砸地预览为单次播放；带sequence_QA命名的循环GIF只用于查看连续动作，不代表游戏中的循环方式。

本批没有地块，无缝地块4×4平铺不适用；previews/batch03_4x4_contact.png是15项精灵的4×4总览。

## 失败候选

第一轮狼动作体型与相机偏离；第二轮49色（色板补零引入额外黑色）退回；旧横砸的等宽切格混入相邻武器/尾部，后改为完整相连轮廓提取。哈提移动v05实际导出出现目标外竖线，v07复制未保留完整爪部，均退回；只有approved/及manifest中final_path列出的文件为成品。candidates/包含失败和过渡文件，不可整目录接入。

仅运行 records/package_current.py 会生成早期制作中状态；不要对已完成批次运行它或旧 records/package_progress.py。最终封装脚本为 records/publish_batch03.py。未执行git commit或git push；未修改scripts/、scenes/、docs/或project.godot。
''')
print(json.dumps({'status':m['status'],'approved':15,'copied':15,'original_pngs':m['original_png_count']},ensure_ascii=False))
