from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]
source=Image.open(root/'candidates/jormungandr_body_v01.png').convert('RGBA');actual={n:Image.open(root/f'candidates/jormungandr_{n}_v03.png').convert('RGBA')for n in['head','body','tail']}
body=Image.new('RGBA',(64,64))
for x in range(64):
 for y in range(64):body.putpixel((x,y),source.getpixel((24+x%21,y)))
head=actual['head'].copy();tail=actual['tail'].copy()
for x in range(16):
 for y in range(64):head.putpixel((x,y+32),body.getpixel((x,y)))
for x in range(56,64):
 for y in range(64):tail.putpixel((x,y),body.getpixel((x,y)))
targets={'head':head,'body':body,'tail':tail};plan={'source_version':'v03','texture_reference':'candidates/jormungandr_body_v01.png','method':'Piskel manual transfer of 21-pixel repeating scale pattern, source columns 24 to 44, with matching head and tail ports','assets':[]}
for name,a in actual.items():
 t=targets[name];edits=[]
 for y in range(a.height):
  for x in range(a.width):
   p=t.getpixel((x,y));q=a.getpixel((x,y))
   if(p if p[3]else(0,0,0,0))!=(q if q[3]else(0,0,0,0)):edits.append({'x':x,'y':y,'rgba':list(p),'hex':'#'+''.join(f'{v:02x}'for v in p[:3])if p[3]else None})
 plan['assets'].append({'id':name,'source':f'candidates/jormungandr_{name}_v03.png','edits':edits})
(root/'records/jormungandr_texture_pixel_plan_v04.json').write_text(json.dumps(plan,indent=2));print([(x['id'],len(x['edits']))for x in plan['assets']]);preview=Image.new('RGBA',(384,128),'#121721');preview.alpha_composite(tail,(0,32))
for x in[64,128,192]:preview.alpha_composite(body,(x,32))
preview.alpha_composite(head,(256,0));preview.resize((1152,384),Image.Resampling.NEAREST).convert('RGB').save(root/'previews/jormungandr_v04_plan_preview_NOT_FINAL.png')
