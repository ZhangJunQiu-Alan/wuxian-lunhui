from PIL import Image,ImageDraw
from pathlib import Path
from collections import deque
import json
r=Path(__file__).resolve().parents[1];base=Image.open(r/'references/skoll_48color.png').convert('RGBA');sheet=Image.open(r/'candidates/skoll_idle_v01.png').convert('RGBA');boxes=[(79,6,97,24),(57,12,79,31),(17,47,31,65),(45,48,61,64)];motions=[[(0,0)]*4,[(1,0),(0,-1),(1,-1),(0,-1)],[(-1,-1),(1,-1),(-1,-1),(0,-2)],[(1,0),(0,-1),(1,-1),(0,-1)]];plans=[];targets=[]
for i in range(4):
 original=sheet.crop((i*128,0,(i+1)*128,128));out=original.copy()
 for b,(dx,dy) in zip(boxes,motions[i]):
  for y in range(b[1],b[3]):
   for x in range(b[0],b[2]):
    clipped=(dx>0 and x<b[0]+dx)or(dx<0 and x>=b[2]+dx)or(dy>0 and y<b[1]+dy)or(dy<0 and y>=b[3]+dy)
    if clipped and base.getpixel((x,y))[3] and not out.getpixel((x,y))[3]:out.putpixel((x,y),base.getpixel((x,y)))
 alpha=out.getchannel('A');outside=set();q=deque([(0,0)]);outside.add((0,0))
 while q:
  x,y=q.popleft()
  for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
   xx,yy=x+dx,y+dy
   if 0<=xx<128 and 0<=yy<128 and (xx,yy)not in outside and not alpha.getpixel((xx,yy)):outside.add((xx,yy));q.append((xx,yy))
 for y in range(128):
  for x in range(128):
   if not out.getpixel((x,y))[3] and (x,y)not in outside and base.getpixel((x,y))[3]:out.putpixel((x,y),base.getpixel((x,y)))
 edits=[]
 for y in range(128):
  for x in range(128):
   a=original.getpixel((x,y));b=out.getpixel((x,y))
   if (a[3]or b[3])and a!=b:edits.append({'x':x,'y':y,'rgba':list(b),'hex':'#%02x%02x%02x'%b[:3]})
 targets.append(out);plans.append({'frame':i,'edits':edits})
(r/'records/skoll_idle_repair_pixel_plan_v02.json').write_text(json.dumps({'source':'candidates/skoll_idle_v01.png','reason':'Restore accidentally clipped body connection strips and newly enclosed transparent holes; retain intentional flame-tip motion. Must apply via Chrome Piskel.','frames':plans},indent=2)+'\n');contact=Image.new('RGB',(1024,300),'#121721');d=ImageDraw.Draw(contact);d.text((10,8),'SKOLL IDLE REPAIR PLAN v02 - NOT FINAL',fill='white')
for i,im in enumerate(targets):z=im.resize((256,256),Image.Resampling.NEAREST);contact.paste(z,(256*i,35),z)
contact.save(r/'previews/skoll_idle_repair_plan_NOT_FINAL.png');print([len(f['edits'])for f in plans])
(r/'records/skoll_idle_review.json').write_text(json.dumps({'status':'rejected_v01_repair_in_progress','reason':'Motion preview and alpha regression check revealed rectangular transparent cuts at shifted patch edges, including 16/32 chest pixels; no final approval.'},indent=2)+'\n')
