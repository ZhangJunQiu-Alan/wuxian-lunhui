import json
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]
s=Image.open(root/'candidates/swordsman_move_v05.png').convert('RGBA');old=Image.open(root/'candidates/swordsman_move_v04.png').convert('RGBA');plan={'source':'candidates/swordsman_move_v05.png','method':'Piskel UI add central arm passing poses in frames 3 and 6 to avoid abrupt swing reversal','frames':[]}
for i in range(6):
 a=s.crop((64*i,0,64*(i+1),64));t=a.copy();d=ImageDraw.Draw(t)
 if i==2:
  d.rectangle((17,29,28,39),fill=(0,0,0,0));d.polygon([(29,25),(32,25),(33,28),(32,32),(34,35),(34,38),(31,39),(29,36),(28,32),(27,29)],fill='#151011');d.polygon([(30,26),(31,26),(32,28),(31,32),(29,32),(28,29)],fill='#565561');d.line([(30,26),(31,28),(30,30)],fill='#616375');d.polygon([(30,32),(32,32),(33,35),(33,37),(31,38),(30,36)],fill='#ad7e63');d.line([(31,33),(32,35)],fill='#e1a377');d.point((32,37),fill='#855946')
 if i==5:
  t.paste(old.crop((64*i,24,64*(i+1),43)),(0,24));d=ImageDraw.Draw(t);d.rectangle((38,27,51,35),fill=(0,0,0,0));d.polygon([(30,25),(32,25),(34,28),(33,32),(30,33),(28,30),(28,27)],fill='#151011');d.polygon([(30,26),(31,26),(33,28),(32,31),(30,32),(29,29)],fill='#565561');d.line([(30,26),(31,28),(31,30)],fill='#616375');d.polygon([(30,31),(32,32),(31,35),(31,38),(28,39),(27,37),(28,34)],fill='#1b181c');d.polygon([(30,32),(31,33),(30,35),(30,37),(28,38),(28,36),(29,34)],fill='#ad7e63');d.line([(30,33),(29,35)],fill='#e1a377');d.point((29,38),fill='#855946')
 edits=[]
 for y in range(64):
  for x in range(64):
   p=t.getpixel((x,y));q=a.getpixel((x,y))
   if (p if p[3]else(0,0,0,0))!=(q if q[3]else(0,0,0,0)):edits.append({'x':x,'y':y,'rgba':list(p),'hex':'#'+''.join(f'{v:02x}'for v in p[:3])if p[3]else None})
 plan['frames'].append({'index':i,'edits':edits})
(root/'records/move_manual_pixel_plan_v06.json').write_text(json.dumps(plan,indent=2));print([len(f['edits'])for f in plan['frames']])
