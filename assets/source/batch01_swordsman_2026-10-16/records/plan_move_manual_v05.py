import json
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]
old=Image.open(root/'candidates/swordsman_move_v04.png').convert('RGBA')
src=Image.open(root/'candidates/swordsman_move_v03.png').convert('RGBA')
cloth=['#151011','#1b181c','#232229','#2b2c38','#3d404f','#565561','#616375']
skin=['#5e453e','#855946','#ad7e63','#e1a377']
def rgba(h):return tuple(bytes.fromhex(h[1:]))+(255,)
cloth=list(map(rgba,cloth));skin=list(map(rgba,skin))
def shade(p,shift):
 ramp=skin if p in skin else cloth if p in cloth else None
 return ramp[max(0,min(len(ramp)-1,ramp.index(p)+shift))] if ramp else p
arm_shapes=[
 ([(30,25),(32,25),(34,28),(37,31),(36,34),(33,33),(31,30),(29,28)],[(31,26),(32,26),(33,29),(36,31),(35,33),(33,32),(31,29),(30,28)],[(36,31),(39,29),(41,27),(43,27),(44,28),(44,30),(42,31),(39,33),(36,35),(35,34)],[(36,32),(39,30),(42,28),(43,28),(43,29),(41,30),(38,33),(36,34)]),
 ([(30,25),(32,25),(34,28),(37,33),(36,36),(33,35),(31,30),(29,28)],[(31,26),(32,26),(33,29),(36,33),(35,35),(33,34),(31,29),(30,28)],[(36,33),(40,31),(43,31),(45,33),(44,35),(40,35),(36,37),(35,36)],[(36,34),(40,32),(43,32),(44,33),(43,34),(40,34),(36,36)]),
 ([(30,25),(32,25),(34,27),(36,30),(35,33),(32,32),(30,29),(29,27)],[(31,26),(32,26),(33,28),(35,30),(34,32),(32,31),(31,28),(30,27)],[(35,30),(37,27),(39,25),(41,25),(42,27),(41,29),(38,32),(35,34),(34,32)],[(35,31),(38,27),(40,26),(41,27),(40,28),(37,32),(35,33)])
]
plan={'source':'candidates/swordsman_move_v04.png','reference':'candidates/swordsman_move_v03.png','method':'Piskel UI redraw near forward arm silhouette; contralateral near/far leg shading; fixed profile','frames':[]}
for i in range(6):
 actual=old.crop((64*i,0,64*(i+1),64));target=actual.copy();pose=src.crop((64*(i%3),0,64*(i%3+1),64))
 for y in range(43,64):
  for x in range(64):
   p=pose.getpixel((x,y));target.putpixel((x,y),shade(p,(0 if x<32 else -1) if i>=3 else(-1 if x<32 else 1)))
 if i>=3:
  draw=ImageDraw.Draw(target);draw.rectangle((38,27,51,35),fill=(0,0,0,0));sleeve,inside,forearm,skin_inside=arm_shapes[i-3]
  draw.polygon(sleeve,fill='#151011');draw.polygon(inside,fill='#565561');draw.line([(31,26),(32,28),(34,31 if i!=4 else 33)],fill='#616375',width=1)
  draw.polygon(forearm,fill='#1b181c');draw.polygon(skin_inside,fill='#ad7e63');draw.line([skin_inside[1],skin_inside[2]],fill='#e1a377',width=1)
 edits=[]
 for y in range(64):
  for x in range(64):
   p=target.getpixel((x,y));q=actual.getpixel((x,y))
   if (p if p[3] else(0,0,0,0))!=(q if q[3] else(0,0,0,0)):
    edits.append({'x':x,'y':y,'rgba':list(p),'hex':'#'+''.join(f'{v:02x}' for v in p[:3]) if p[3] else None})
 plan['frames'].append({'index':i,'edits':edits})
(root/'records/move_manual_pixel_plan_v05.json').write_text(json.dumps(plan,indent=2))
print([len(f['edits']) for f in plan['frames']])
