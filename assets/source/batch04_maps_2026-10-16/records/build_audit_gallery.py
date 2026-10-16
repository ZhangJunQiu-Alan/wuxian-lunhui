from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
import json,random,html,shutil
R=Path(__file__).resolve().parents[1];ASSETS=R.parents[1];rows=json.loads((R/'records/staged_final_checks.json').read_text())
# Snapshot existing characters, because another task may edit their actions concurrently.
refs={}
for name,p in [('swordsman',ASSETS/'sprites/characters/swordsman.png'),('draugr',ASSETS/'source/norse_pixel_2026-10-16/64/mobs/draugr.png'),('wolf',ASSETS/'source/norse_pixel_2026-10-16/64/mobs/wolf.png'),('ice_spirit',ASSETS/'source/norse_pixel_2026-10-16/64/mobs/ice_spirit.png'),('dead',ASSETS/'source/norse_pixel_2026-10-16/64/mobs/dead.png'),('dark_elf',ASSETS/'source/norse_pixel_2026-10-16/64/mobs/dark_elf.png'),('nail_golem',ASSETS/'source/norse_pixel_2026-10-16/64/mobs/nail_golem.png'),('fire_giant',ASSETS/'sprites/enemies/fire_giant.png'),('berserker',ASSETS/'source/norse_pixel_2026-10-16/64/mobs/berserker.png')]:
 q=R/f'references/context_{name}.png'
 if not q.exists():shutil.copy2(p,q)
 refs[name]=Image.open(q).convert('RGBA')
positions={'midgard':[(70,100),(1120,90),(330,170),(790,140),(580,620),(1080,300),(80,420),(1030,570),(870,400),(300,400),(430,90),(680,260),(200,600)],'helheim':[(100,100),(1050,170),(850,470),(100,470),(550,100)],'vigrid':[(110,200),(1080,170),(180,550),(900,400),(550,80)]}
scene_frames=[];scroll_bases=[]
for level in ['midgard','helheim','vigrid']:
 grounds=[a for a in rows if a['level']==level and a['type']=='ground'];props=[a for a in rows if a['level']==level and a['type']=='props'];base=[Image.open(R/a['candidate']).convert('RGBA') for a in grounds[:4]];scene=Image.new('RGBA',(1280,720));rng=random.Random(714)
 for y in range(0,720,64):
  for x in range(0,1280,64):scene.paste(rng.choice(base),(x,y))
 layers=[]
 for a,(x,y) in zip(props,positions[level]):
  im=Image.open(R/a['candidate']);layers.append((y+im.height,x,y,im))
 enemies={'midgard':['draugr','wolf','ice_spirit'],'helheim':['dead','dark_elf','nail_golem'],'vigrid':['fire_giant','berserker','draugr']}[level]
 for i in range(24):
  x=230+(i%6)*145+(i%3)*8;y=170+(i//6)*118
  if 540<x<710 and 270<y<410:continue
  im=refs[enemies[i%len(enemies)]];layers.append((y+im.height,x,y,im))
 im=refs['swordsman'];layers.append((360+im.height,610,360,im))
 for z,x,y,im in sorted(layers,key=lambda a:a[0]):scene.alpha_composite(im,(x,y))
 ImageDraw.Draw(scene).text((12,8),level+' | LOCAL ART COMPOSITE - NOT A GODOT SCREENSHOT',fill='white');scene.convert('RGB').save(R/f'previews/{level}_context_1x.png');scene_frames.append(scene.convert('RGB'))
 # Final exact tile previews, recomputed after palette changes.
 for a in grounds:
  im=Image.open(R/a['candidate']);tile=Image.new('RGBA',(256,256))
  for y in range(4):
   for x in range(4):tile.paste(im,(64*x,64*y))
  tile.save(R/f"previews/{level}_{a['id']}_4x4.png")
 mix=Image.new('RGBA',(256,256));rng=random.Random(41)
 for y in range(4):
  for x in range(4):mix.paste(rng.choice(base),(x*64,y*64))
 mix.save(R/f'previews/{level}_mixed_base_4x4.png');scroll_bases.append(mix)
scene_frames[0].save(R/'previews/map_preview.gif',save_all=True,append_images=scene_frames[1:],duration=[1500]*3,loop=0,optimize=False)
frames=[]
for phase in range(16):
 frame=Image.new('RGB',(768,280),'#121721');d=ImageDraw.Draw(frame)
 for i,(level,im) in enumerate(zip(['midgard','helheim','vigrid'],scroll_bases)):
  frame.paste(ImageChops.offset(im,-phase*4,-phase*4),(i*256,24));d.text((i*256+5,5),level+' seamless scroll QA',fill='white')
 frames.append(frame)
frames[0].save(R/'previews/tile_scroll_8fps.gif',save_all=True,append_images=frames[1:],duration=[120,130]*8,loop=0,optimize=False)
css='''body{margin:0;background:#121721;color:#e9ecf2;font:15px system-ui;line-height:1.6}main{max-width:1300px;margin:auto;padding:28px}h1{font-size:28px;margin:0}h2{margin-top:40px}a{color:#a8d5ff}nav{display:flex;gap:24px;margin:18px 0}article{border-top:1px solid #34404e;padding:20px 0}.spec{color:#afb8c8}.compare{display:flex;gap:32px;align-items:flex-start;flex-wrap:wrap}.pixel{image-rendering:pixelated;max-width:none}.tile{image-rendering:pixelated;width:256px;height:256px}.scene{image-rendering:pixelated;width:1280px;max-width:none}.scroll{overflow-x:auto}.note{background:#1f2b39;padding:12px 16px;border-left:3px solid #87abc7}.views{display:flex;gap:28px;flex-wrap:wrap}details{margin:12px 0}.badge{color:#e9cd82}button,select{font:inherit;background:#263344;color:white;padding:8px;border:1px solid #45596f}'''
p=['<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>第4批地图 · 最终候选审核</title><style>'+css+'</style><main><h1>第4批地图与场景物件</h1><p class="badge">最终候选：20张地块 + 23张物件 · 待最终可视检查</p><p>所有地块64×64；物件保持规定尺寸。每关同一48色调色板。下方为本地美术合成预览，不是游戏截图。</p><nav><a href="#midgard">米德加尔特</a><a href="#helheim">赫尔海姆</a><a href="#vigrid">维格利德</a><a href="manifest.json">manifest</a><a href="README.md">README</a></nav><p class="note">地面完整填充，不透明RGBA；场景物件真正透明、alpha仅0/255。静态素材：无动作帧，朝右/脚底基线/动画循环不适用。图像严格1×与4×整数展示。</p><details><summary>GIF预览：三关合成轮播与8fps平铺滚动检查</summary><div class="scroll"><img src="previews/map_preview.gif" width="1280" height="720" alt="三关静态合成轮播"></div><img src="previews/tile_scroll_8fps.gif" width="768" height="280" alt="平铺滚动检查，素材本身为静态"></details>']
for level,label in [('midgard','米德加尔特 · 芬布尔之冬'),('helheim','赫尔海姆 · 亡者之船'),('vigrid','维格利德 · 最后之战')]:
 p.append(f'<section id="{level}"><h2>{label}</h2><div class="scroll"><img class="scene" src="previews/{level}_context_1x.png" alt="{level}本地1倍美术合成"></div><details><summary>基础地块4种变化随机混铺4×4</summary><img class="tile" src="previews/{level}_mixed_base_4x4.png" alt="{level}基础混铺"></details>')
 for a in [a for a in rows if a['level']==level]:
  path=html.escape(a['candidate']);name=html.escape(a['id']);w,h=a['width'],a['height'];p.append(f'<article id="{level}_{name}" data-kind="{a["type"]}"><h3>{name}</h3><p class="spec">{a["type"]} · {w}×{h} RGBA · {a["color_count"]}色 · 静态1帧</p><div class="compare"><div>1×<br><img class="pixel" src="{path}" width="{w}" height="{h}" alt="{level}/{name} 1倍"></div><div>4×<br><img class="pixel" src="{path}" width="{w*4}" height="{h*4}" alt="{level}/{name} 4倍"></div>')
  if a['type']=='ground':p.append(f'<div>4×4平铺（1×像素）<br><img class="tile" src="previews/{level}_{name}_4x4.png" alt="{level}/{name}平铺"></div>')
  p.append('</div></article>')
 p.append('</section>')
p.append('</main></html>');(R/'gallery.html').write_text(''.join(p))
print('Audit gallery built: 43 candidate rows,20 tilings,3 mixed tilings,3 context composites,2GIFs')
