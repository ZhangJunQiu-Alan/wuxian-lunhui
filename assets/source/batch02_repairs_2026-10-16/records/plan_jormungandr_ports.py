from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]
images={k:Image.open(root/f'candidates/jormungandr_{k}_v01.png').convert('RGBA')for k in['head','body','tail']}
profile=[images['body'].getpixel((32,y))for y in range(17,47)];profile[-1]=profile[-2]
plan={'profile_body_y':[17,47],'profile_head_y':[49,79],'head_pivot':[64,64],'body_pivot':[32,32],'tail_pivot':[32,32],'profile_rgba':[list(p)for p in profile],'assets':[]}
body=images['body'].copy()
for x in [0,1,62,63]:
 for y in range(64):body.putpixel((x,y),profile[y-17]if 17<=y<47 else(0,0,0,0))
for x in list(range(8))+list(range(56,64)):
 for y in range(17):body.putpixel((x,y),(0,0,0,0))
for name,im in images.items():
 target=im.copy()
 if name=='body':target=body
 elif name=='head':
  for x in range(8):
   for y in range(17,47):target.putpixel((x,y+32),body.getpixel((x,y)))
  for x in [0,1]:
   for y in range(128):target.putpixel((x,y),profile[y-49]if 49<=y<79 else(0,0,0,0))
 else:
  for x in [62,63]:
   for y in range(64):target.putpixel((x,y),profile[y-17]if 17<=y<47 else(0,0,0,0))
 edits=[]
 for y in range(im.height):
  for x in range(im.width):
   p=target.getpixel((x,y));q=im.getpixel((x,y))
   if(p if p[3]else(0,0,0,0))!=(q if q[3]else(0,0,0,0)):edits.append({'x':x,'y':y,'rgba':list(p),'hex':'#'+''.join(f'{v:02x}'for v in p[:3])if p[3]else None})
 plan['assets'].append({'id':name,'source':f'candidates/jormungandr_{name}_v01.png','edits':edits})
(root/'records/jormungandr_port_pixel_plan_v02.json').write_text(json.dumps(plan,indent=2));print([(i['id'],len(i['edits']))for i in plan['assets']])
