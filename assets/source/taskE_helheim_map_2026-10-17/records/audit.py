from pathlib import Path
from PIL import Image,ImageStat
import json,hashlib
import pipeline as p
R=p.ROOT
versions=json.loads((R/'records/static_versions.json').read_text())
rows=[]
for a in p.PLAN.values():
 id=a['id'];v=versions.get(id,'v01');path=R/'candidates'/f'{id}_{v}.png';im=Image.open(path);pixels=list(im.getdata());colors={q[:3] for q in pixels if q[3]};alpha=set(q[3] for q in pixels);box=im.getbbox();checks={'size_exact':im.size==(a['w'],a['h']),'png':im.format=='PNG','rgba':im.mode=='RGBA','binary_alpha':alpha<={0,255},'palette48':colors<={tuple(c) for c in p.COLORS},'nonempty':bool(box),'generation_record':(R/'records'/f'generation_{id}_{v}.json').exists(),'preview':(R/'previews'/f'{id}_{v}_review.png').exists()}
 if a['type'] in ['props','decals']:checks['two_pixel_margin']=box[0]>=2 and box[1]>=2 and box[2]<=a['w']-2 and box[3]<=a['h']-2
 if a.get('tile'):checks['opaque_fulltile']=alpha=={255};checks['four_by_four_preview']=(R/'previews'/f'{id}_{v}_tile4x4.png').exists()
 if a.get('transition'):
  rec=json.loads((R/'records'/f'generation_{id}_{v}.json').read_text());src=Image.open(R/rec['source']);checks['exact_source_rgb']=all(not q[3] or q[:3]==s[:3] for q,s in zip(pixels,src.getdata()))
 if a.get('axis'):checks['repeat_preview']=(R/'previews'/f'{id}_{v}_repeat4.png').exists()
 if id=='dark_sea_01':checks['outer_flush']=all(im.getpixel((x,0))[3]==255 for x in range(im.width));checks['inner_clear']=all(im.getpixel((x,im.height-1))[3]==0 for x in range(im.width))
 if id=='ice_cliff_01' or id=='gnipa_cave':checks['outer_flush']=all(im.getpixel((x,im.height-1))[3]==255 for x in range(im.width));checks['inner_clear']=all(im.getpixel((x,0))[3]==0 for x in range(im.width))
 if id=='hel_wall_01':checks['outer_flush']=all(im.getpixel((im.width-1,y))[3]==255 for y in range(im.height));checks['inner_clear']=all(im.getpixel((0,y))[3]==0 for y in range(im.height))
 if id=='fog_abyss_01':checks['outer_flush']=all(im.getpixel((0,y))[3]==255 for y in range(im.height));checks['inner_clear']=all(im.getpixel((im.width-1,y))[3]==0 for y in range(im.height))
 row={'id':id,'version':v,'checks':checks,'passed':all(checks.values()),'size':list(im.size),'colors':len(colors),'alpha':sorted(alpha),'bbox':box,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 if a.get('tile'):
  w,h=im.size;px=im.load();metric={}
  for axis in ['x','y']:
   edge=[sum(abs(px[w-1,z][c]-px[0,z][c]) for c in range(3))/3 for z in range(h)] if axis=='x' else[sum(abs(px[z,h-1][c]-px[z,0][c]) for c in range(3))/3 for z in range(w)]
   inside=[sum(abs(px[x,y][c]-px[x-1 if axis=='x' else x,y if axis=='x' else y-1][c]) for c in range(3))/3 for y in range(1,h) for x in range(1,w)]
   metric[axis]={'boundary_mean_abs':sum(edge)/len(edge),'interior_mean_abs':sum(inside)/len(inside)}
  row['seam_diagnostic']=metric;row['rgb_mean']=ImageStat.Stat(im).mean[:3]
 rows.append(row)
lamp=Image.open(R/'candidates/soul_lamp_v01.png');lit=Image.open(R/'candidates/soul_lamp_lit_v04.png');changes=[(n%32,n//32) for n,(a,b)in enumerate(zip(lamp.getdata(),lit.getdata())) if a!=b]
special={'lamp_body_exact_outside_head':all(12<=x<20 and 0<=y<10 for x,y in changes),'lamp_changed_pixels':len(changes),'root_clear_140x70':Image.open(R/'candidates/world_root_arch_v03.png').getchannel('A').crop((120,75,260,145)).getbbox()is None,'hoof_01_manually_counted':8,'hoof_02_manually_counted':8,'in_game_tested':False}
for id,other in [('river_02','river_01'),('river_ice','river_ice')]:
 a=Image.open(R/'candidates'/f'{id}_{versions[id]}.png');b=Image.open(R/'candidates'/f'{other}_{"v05" if id=="river_ice" else "v01"}.png');special[id+'_edgeports_preserved']=all(list(a.crop(box).getdata())==list(b.crop(box).getdata()) for box in[(0,0,4,64),(60,0,64,64),(0,0,64,4),(0,60,64,64)])
result={'task':'E','total':len(rows),'passed':sum(r['passed'] for r in rows),'special':special,'rows':rows,'game_tested':False};(R/'records/audit.json').write_text(json.dumps(result,indent=2));print(json.dumps({'total':len(rows),'passed':result['passed'],'failures':[{r['id']:[k for k,v in r['checks'].items() if not v]} for r in rows if not r['passed']],'special':special},indent=2))
