from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
from collections import Counter,deque
import json,hashlib,html,math
R=Path(__file__).resolve().parents[1];A=R.parents[1];rows=json.loads((R/'records/review_candidates.json').read_text());lookup={a['id']:a for a in rows}
# Remove isolated alpha specks introduced by sampling from the decorative branch only.
a=lookup['raven_branch'];im=Image.open(R/a['candidate']);px=im.load();seen=set();removed=0
for y in range(im.height):
 for x in range(im.width):
  if (x,y) in seen or px[x,y][3]==0:continue
  q=deque([(x,y)]);part=[];seen.add((x,y))
  while q:
   xx,yy=q.popleft();part.append((xx,yy))
   for nx,ny in [(xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)]:
    if 0<=nx<im.width and 0<=ny<im.height and (nx,ny) not in seen and px[nx,ny][3]:seen.add((nx,ny));q.append((nx,ny))
  if len(part)==1:
   for xy in part:px[xy]=(0,0,0,0);removed+=1
im.save(R/a['candidate']);a['alpha_cleanup_single_pixel_islands']=removed
# Individual true-size and integer 4x previews, full-tile repeats.
for a in rows:
 im=Image.open(R/a['candidate']);assert im.mode=='RGBA' and list(im.size)==a['size'],a['id'];alpha=set(im.getchannel('A').getdata());assert alpha<={0,255};bbox=im.getchannel('A').getbbox();colors=set(v[:3] for v in im.getdata() if v[3]);a['colors']=len(colors);a['alpha_values']=sorted(alpha);a['frames']=1;a['sha256']=hashlib.sha256((R/a['candidate']).read_bytes()).hexdigest();a['opaque_bbox']=list(bbox)
 a['repeat_axis']=a.get('repeat_axis','y' if a['id'].startswith('pier_straight') else None)
 a['technical_checks']={'exact_size':True,'png_rgba':True,'binary_alpha':True,'nonempty':True,'margin_2px':(bbox[0]>=2 and bbox[1]>=2 and bbox[2]<=im.width-2 and bbox[3]<=im.height-2) if a['type'] in ['props','decals'] and not a['repeat_axis'] else 'not_applicable_repeat_or_ground','horizontal_centering':'bbox fitted centrally; terrain not applicable','ground_contact':'bottom 2px margin; not applicable ground/decals/borders','animation_checks':'not_applicable_static_map_asset'}
 assert a['technical_checks']['margin_2px'] is not False,a['id']
 for k in [1,4]:
  out=Image.new('RGBA',(im.width*k,im.height*k),'#121721');out.alpha_composite(im.resize(out.size,Image.Resampling.NEAREST));out.save(R/f"previews/{a['id']}_{k}x.png")
 if a['type']=='ground':
  out=Image.new('RGBA',(256,256),'#121721')
  for y in range(4):
   for x in range(4):out.alpha_composite(im,(x*64,y*64))
  out.save(R/f"previews/{a['id']}_tile4x4.png")
 a['approved_snapshot']=f"approved/{a['type']}/midgard/{a['id']}.png";a['destination']=f"sprites/{a['type']}/midgard/{a['id']}.png"
# A handmade arrangement using only the actual PNG assets: not a Godot screenshot.
def get(ident):return Image.open(R/lookup[ident]['candidate'])
W,H=896,640;village=Image.new('RGBA',(W,H));grounds=[Image.open(A/f'sprites/ground/midgard/snow_0{i}.png').convert('RGBA') for i in range(1,5)]
for y in range(0,H,64):
 for x in range(0,W,64):village.paste(grounds[(x//64*3+y//64)%4],(x,y))
# A compacted-snow lane through the middle with matching transition borders.
road=Image.open(R/'references/snow_trampled.png').convert('RGBA')
for x in range(0,W,64):
 village.alpha_composite(get('path_edge_n'),(x,256));village.alpha_composite(road,(x,320));village.alpha_composite(get('path_edge_s'),(x,384))
placements=[('longhouse_snow',90,72),('longhouse_frame',530,72),('longhouse_ridge',330,118),('sheep_pen',710,420),('frozen_well',422,221),('fish_rack',655,215),('chopping_block',220,215),('fence_broken_01',70,242),('fence_broken_02',750,235),('fence_gate',335,208),('cart_overturned',130,420),('barrel_01',505,230),('barrel_02',275,235),('sack_01',470,227),('campfire_unlit',430,442),('dead_pine_03',25,30),('bush_01',285,452),('rock_04',620,480),('fallen_log',30,542),('raven_branch',805,65),('broken_shield_01',550,440),('snowdrift_03',330,470)]
for ident,x,y in [('human_tracks_01',395,325),('cart_ruts_02',165,320),('blood_01',535,364),('snow_shadow_01',315,418),('wolf_tracks_02',670,365),('drag_mark_01',245,360)]:village.alpha_composite(get(ident),(x,y))
for ident,x,y in sorted(placements,key=lambda a:a[2]+get(a[0]).height):village.alpha_composite(get(ident),(x,y))
hero=Image.open(R/'references/swordsman.png').convert('RGBA');village.alpha_composite(hero,(415,325));village.save(R/'previews/village_assembly_1x.png')
# All decals on their actual snow/ice receiving surfaces.
board=Image.new('RGBA',(512,256));ds=[a for a in rows if a['type']=='decals']
for i,a in enumerate(ds):
 x=i%8*64;y=i//8*128;board.paste(grounds[0],(x,y));board.paste(Image.open(R/'references/ice.png'),(x,y+64));board.alpha_composite(get(a['id']),(x,y));board.alpha_composite(get(a['id']),(x,y+64))
board.save(R/'previews/decals_on_snow_and_ice_1x.png')
ice=Image.new('RGBA',(384,192));tx=Image.open(R/'references/ice.png')
for y in range(0,192,64):
 for x in range(0,384,64):ice.paste(tx,(x,y))
for ident,x,y in [('fishing_boat_frozen',15,22),('underice_fish_01',110,95),('underice_fish_02',235,35),('underice_weeds_01',180,95),('underice_weeds_02',300,105)]:ice.alpha_composite(get(ident),(x,y))
ice.alpha_composite(hero,(220,105));ice.save(R/'previews/lake_assembly_1x.png')
# Static artwork review loops: pans show placement/repetition; no game animation is implied.
frames=[]
for step in range(8):
 x=round((village.width-512)*step/7);frame=village.crop((x,96,x+512,480)).resize((1024,768),Image.Resampling.NEAREST).convert('RGB');frames.append(frame)
frames[0].save(R/'previews/village_pan.gif',save_all=True,append_images=frames[1:]+frames[-2:0:-1],duration=125,loop=0)
for ident in ['snow_thin','ice_02']:
 im=get(ident);frames=[]
 for shift in range(0,64,8):
  out=Image.new('RGBA',(256,256))
  for y in range(-64,256,64):
   for x in range(-64,256,64):out.paste(im,(x+shift,y+shift))
  frames.append(out.resize((512,512),Image.Resampling.NEAREST).convert('RGB'))
 frames[0].save(R/f'previews/{ident}_scroll.gif',save_all=True,append_images=frames[1:],duration=125,loop=0)
# Reviewable HTML, filtering, true 1x/4x sizes, and all audit inputs.
parts=['<!doctype html><meta charset="utf-8"><title>第4批第1关地图补做</title><style>body{background:#121721;color:#d4dce5;font:15px system-ui;margin:24px}a{color:#a6ccec}nav{position:sticky;top:0;background:#121721;padding:12px;z-index:2}button,input{font:inherit;padding:8px;margin:4px}article{border-top:1px solid #34414f;padding:20px 0}figure{display:inline-block;vertical-align:top;margin:8px 24px 8px 0}img{image-rendering:pixelated;max-width:none}summary{cursor:pointer}.scroll{overflow:auto;max-width:100%}small{color:#8b9bab}h1{font-size:26px}</style><h1>第4批 · 第1关地图补做</h1><p>112 张候选的实际预览；美术自检与 Godot 游戏验收分开。全部为静态地图资产。下方 GIF 是素材检查平移。</p><nav><input id="q" placeholder="按文件名筛选"><button onclick="filter(\'all\')">全部</button><button onclick="filter(\'borders\')">边界</button><button onclick="filter(\'ground\')">地块/过渡</button><button onclick="filter(\'props\')">物件</button><button onclick="filter(\'decals\')">贴花</button><span id="count"></span></nav>']
for label,file in [('村庄本地拼装（非游戏截图）','village_assembly_1x.png'),('边界整圈拼装','perimeter_1x_v04.png'),('冰面12种过渡连接','ice_all12_assembly.png'),('雪路12种过渡连接','path_all12_assembly.png'),('贴花：每组上雪地/下冰面','decals_on_snow_and_ice_1x.png'),('冰下暗影','lake_assembly_1x.png'),('村庄平移检查 GIF','village_pan.gif')]:parts.append(f'<details><summary>{label}</summary><div class="scroll"><img src="previews/{file}"></div></details>')
for a in rows:
 ident=a['id'];w,h=a['size'];parts.append(f'<article data-type="{a["type"]}" data-id="{ident}"><h3>{ident} · {w}×{h} · {a["colors"]} 色</h3><a href="{a["candidate"]}">PNG</a> <a href="{a["source"]}">来源原图</a><div class="scroll"><figure><figcaption>1× · #121721</figcaption><img src="previews/{ident}_1x.png" width="{w}" height="{h}"></figure><figure><figcaption>4× · 最近邻</figcaption><img src="previews/{ident}_4x.png" width="{w*4}" height="{h*4}"></figure></div>')
 if a['type']=='ground':parts.append(f'<details><summary>4×4 平铺（边缘块以连接预览为准）</summary><img src="previews/{ident}_tile4x4.png"></details>')
 if ident in ['snow_thin','ice_02']:parts.append(f'<details><summary>滚动接缝检查 GIF</summary><img src="previews/{ident}_scroll.gif"></details>')
 parts.append('</article>')
parts.append('<script>let type="all";function filter(t){type=t;apply()}function apply(){let n=0;document.querySelectorAll("article").forEach(a=>{let on=(type==="all"||a.dataset.type===type)&&a.dataset.id.includes(document.getElementById("q").value.toLowerCase());a.hidden=!on;if(on)n++});document.getElementById("count").textContent=n+" / 112"}document.getElementById("q").addEventListener("input",apply);apply()</script>')
(R/'gallery.html').write_text('\n'.join(parts));(R/'records/final_candidates_audit.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));print(json.dumps({'assets':len(rows),'groups':dict(Counter(a['type'] for a in rows)),'max_colors':max(a['colors'] for a in rows),'isolated_branch_pixels_removed':removed},ensure_ascii=False))
