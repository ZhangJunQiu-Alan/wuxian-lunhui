from pathlib import Path
from PIL import Image,ImageDraw
import json
r=Path(__file__).resolve().parents[1]
base=Image.open(r/'references/skoll_48color.png').convert('RGBA');layout=Image.new('RGBA',(512,128))
for i in range(4):layout.alpha_composite(base,(i*128,0))
layout.save(r/'candidates/skoll_idle_layout_NOT_ANIMATED.png')
patches=[(79,6,97,24),(57,12,79,31),(17,47,31,65),(45,48,61,64)]
motions=[[(0,0)]*4,[(1,0),(0,-1),(1,-1),(0,-1)],[(-1,-1),(1,-1),(-1,-1),(0,-2)],[(1,0),(0,-1),(1,-1),(0,-1)]]
frames=[];plans=[]
for i in range(4):
 out=base.copy()
 for box,(dx,dy) in zip(patches,motions[i]):
  if not dx and not dy:continue
  part=base.crop(box);moved=Image.new('RGBA',part.size);moved.paste(part,(dx,dy));out.paste(moved,box[:2])
 edits=[]
 for y in range(128):
  for x in range(128):
   a=base.getpixel((x,y));b=out.getpixel((x,y))
   if (a[3] or b[3]) and a!=b:edits.append({'x':x,'y':y,'rgba':list(b),'hex':'#%02x%02x%02x'%b[:3]})
 frames.append(out);plans.append({'frame':i,'edits':edits})
(r/'records/skoll_idle_pixel_plan_v01.json').write_text(json.dumps({'source':'references/skoll_48color.png','layout':'candidates/skoll_idle_layout_NOT_ANIMATED.png','method':'Planned localized breathing and flame-tip movement, A-B-C-B; face and feet unchanged. Must be applied in Chrome Piskel and exported before approval.','frames':plans},indent=2)+'\n')
preview=Image.new('RGB',(1024,300),'#121721');d=ImageDraw.Draw(preview);d.text((10,8),'SKOLL IDLE PIXEL PLAN - NOT FINAL / MUST APPLY IN PISKEL',fill='white')
for i,f in enumerate(frames):z=f.resize((256,256),Image.Resampling.NEAREST);preview.paste(z,(i*256,35),z)
preview.save(r/'previews/skoll_idle_plan_NOT_FINAL.png');print([len(p['edits']) for p in plans])
