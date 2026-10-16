from pathlib import Path
from PIL import Image,ImageDraw
import json
R=Path(__file__).resolve().parents[1]
props=json.loads((R/'records/props_decals_normalization_v01.json').read_text());terrain=json.loads((R/'records/transitions_v01.json').read_text())+json.loads((R/'records/ground_extra_normalization_v01.json').read_text());borders=json.loads((R/'records/border_modules_v04.json').read_text());rows=props+terrain+borders
for a in rows:
 a.setdefault('type','borders')
 version='v04' if a in borders else ('v02' if a['id'] in ['pier_straight_01','pier_straight_02'] else 'v01');a.setdefault('candidate',f"candidates/{a['id']}_{version}.png")
for group in sorted(set(a.get('group',a['type']) for a in rows)):
 subset=[a for a in rows if a.get('group',a['type'])==group]
 if group=='ground':subset=[a for a in subset if a['id'] in ['snow_thin','ice_02']]
 for page in range(0,len(subset),8):
  part=subset[page:page+8];cw=max(a['size'][0] for a in part)*4+24;ch=max(a['size'][1] for a in part)*4+36;cols=min(4,len(part));im=Image.new('RGBA',(cw*cols,ch*((len(part)+cols-1)//cols)),'#121721');d=ImageDraw.Draw(im)
  for i,a in enumerate(part):
   x=i%cols*cw;y=i//cols*ch;sp=Image.open(R/a['candidate']);im.alpha_composite(sp.resize((sp.width*4,sp.height*4),Image.Resampling.NEAREST),(x+12,y+24));d.text((x+8,y+5),a['id'],fill='white')
  im.save(R/f'previews/review_{group}_{page//8+1}_4x.png')
# All twelve masks in one assembly including the four distinct concave corners.
for family in ['ice','path']:
 base=Image.open(R/'references/snow_01.png').convert('RGBA');out=Image.new('RGBA',(576,576));tex=Image.open(R/'references'/('ice.png' if family=='ice' else 'snow_trampled.png')).convert('RGBA')
 for y in range(9):
  for x in range(9):out.paste(base,(x*64,y*64))
 for y in range(1,8):
  for x in range(1,8):
   if (x,y)==(4,4):continue
   key=None
   if y==1:key='outer_nw' if x==1 else 'outer_ne' if x==7 else 'n'
   elif y==7:key='outer_sw' if x==1 else 'outer_se' if x==7 else 's'
   elif x==1:key='w'
   elif x==7:key='e'
   special={(3,3):'inner_se',(5,3):'inner_sw',(3,5):'inner_ne',(5,5):'inner_nw',(4,3):'s',(4,5):'n',(3,4):'e',(5,4):'w'}
   key=special.get((x,y),key);im=Image.open(R/f'candidates/{family}_edge_{key}_v01.png') if key else tex;out.alpha_composite(im,(x*64,y*64))
 out.save(R/f'previews/{family}_all12_assembly.png')
(R/'records/review_candidates.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));print(len(rows),'review candidates')
