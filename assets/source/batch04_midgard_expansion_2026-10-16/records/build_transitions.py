from pathlib import Path
from PIL import Image,ImageDraw
import math,json
R=Path(__file__).resolve().parents[1]
def turn(im,k):return im.rotate(k*90,expand=False)
def mask(kind):
 m=Image.new('L',(64,64));p=m.load()
 for y in range(64):
  for x in range(64):
   if kind=='edge':inside=y>=32+round(1.5*math.sin(x*math.pi/16))
   elif kind=='outer':inside=math.hypot(63.5-x,63.5-y)<=32+round(math.sin((x+y)*math.pi/12))
   else:inside=math.hypot(x+.5,y+.5)>=32+round(math.sin((x+y)*math.pi/12))
   p[x,y]=255 if inside else 0
 return m
rows=[]
for name,src in [('ice','ice.png'),('path','snow_trampled.png')]:
 tex=Image.open(R/'references'/src).convert('RGBA')
 for kind,dirs in [('edge',['n','w','s','e']),('outer',['nw','sw','se','ne']),('inner',['nw','sw','se','ne'])]:
  for k,d in enumerate(dirs):
   im=tex.copy();im.putalpha(turn(mask(kind),k));ident=f'{name}_edge_{d}' if kind=='edge' else f'{name}_edge_{kind}_{d}';im.save(R/f'candidates/{ident}_v01.png')
   rows.append(dict(id=ident,type='ground',size=[64,64],source='references/'+src,processing='Original tile RGB unchanged; binary alpha crop only; circular corner cutouts with 1-2px irregular edges',status='candidate_pending_visual_review'))
# Assemblies show all four outer corners, concave cutouts, and straight connectors.
base=Image.open(R/'references/snow_01.png').convert('RGBA')
for family in ['ice','path']:
 board=Image.new('RGBA',(640,448))
 for y in range(0,448,64):
  for x in range(0,640,64):board.paste(base,(x,y))
 pattern=[['outer_nw','n','n','n','outer_ne'],['w','full','full','full','e'],['w','full','inner_se','s','outer_se'],['outer_sw','s','outer_se',None,None]]
 for y,row in enumerate(pattern):
  for x,key in enumerate(row):
   if key is None:continue
   im=Image.open(R/'references'/('ice.png' if family=='ice' else 'snow_trampled.png')).convert('RGBA') if key=='full' else Image.open(R/f'candidates/{family}_edge_{key}_v01.png')
   board.alpha_composite(im,(128+x*64,64+y*64))
 board.save(R/f'previews/{family}_transition_assembly_v01.png')
(R/'records/transitions_v01.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
print('24 alpha-only transition candidates; road uses existing snow_trampled')
