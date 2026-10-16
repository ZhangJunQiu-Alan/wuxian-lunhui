from pathlib import Path
from PIL import Image,ImageDraw
from collections import deque
import json,math
R=Path(__file__).resolve().parents[1];pal=json.loads((R/'references/existing_midgard_palette48.json').read_text());pim=Image.new('P',(1,1));flat=[v for c in pal for v in c];pim.putpalette(flat+flat[:3]*(256-len(pal)))
def norm(im,size):
 im=im.convert('RGBA').resize(size,Image.Resampling.NEAREST);a=im.getchannel('A').point(lambda v:255 if v>=128 else 0);im=im.convert('RGB').quantize(palette=pim,dither=Image.Dither.NONE).convert('RGBA');im.putalpha(a);return im
# Minimum-error connected cut between existing pixel regions, no new painted pixels.
def quilt_right(a,b,overlap=64):
 assert a.height==b.height
 W,H=overlap,a.height;cost=[];A=a.load();B=b.load()
 for y in range(H):
  row=[]
  for x in range(W):
   p=A[a.width-W+x,y];q=B[x,y];row.append(sum((p[c]-q[c])**2 for c in range(4)))
  cost.append(row)
 dp=[cost[0][:]];back=[]
 for y in range(1,H):
  br=[];row=[]
  for x in range(W):
   xs=list(range(max(0,x-1),min(W,x+2)));k=min(xs,key=lambda j:dp[-1][j]);br.append(k);row.append(dp[-1][k]+cost[y][x])
  dp.append(row);back.append(br)
 path=[0]*H;path[-1]=min(range(W),key=lambda x:dp[-1][x])
 for y in range(H-1,0,-1):path[y-1]=back[y-1][path[y]]
 out=a.copy();p=out.load()
 for y in range(H):
  for x in range(path[y],W):p[a.width-W+x,y]=B[x,y]
 return out,path

def periodic(im,axis):
 if axis=='y':im=im.transpose(Image.Transpose.TRANSPOSE)
 # Input320 along repetition axis; copy-overlap then discard first64, resulting256.
 out,path=quilt_right(im,im.crop((0,0,64,im.height)),64);out=out.crop((64,0,out.width,out.height))
 if axis=='y':out=out.transpose(Image.Transpose.TRANSPOSE)
 return out,path

def remove_inner_ground(im,side):
 out=im.copy();p=out.load();w,h=out.size;seen=set();q=deque()
 def allowed(x,y):
  if not (0<=x<w and 0<=y<h):return False
  if side=='s':region=y>=h-64
  elif side=='n':region=y<64
  elif side=='e':region=x>=w-64
  elif side=='w':region=x<64
  else:
   vert='s' if 'n' in side else 'n';horiz='e' if 'w' in side else 'w'
   region=(y>=h-96 if vert=='s' else y<96) and (x>=w-96 if horiz=='e' else x<96)
  r,g,b,a=p[x,y];return region and (a==0 or (b>=r+3 and g>=r and (r+g+b)/3>=55))
 if side in ('n','s'):
  for x in range(w):q.append((x,0 if side=='n' else h-1))
 elif side in ('w','e'):
  for y in range(h):q.append((0 if side=='w' else w-1,y))
 else:
  for y in range(h):q.append((w-1 if 'w' in side else 0,y))
  for x in range(w):q.append((x,h-1 if 'n' in side else 0))
 while q:
  x,y=q.popleft()
  if (x,y) in seen or not allowed(x,y):continue
  seen.add((x,y));p[x,y]=(0,0,0,0);q.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
 return out,len(seen)
raw=Image.open(R/'originals/borders_straight_v01_raw.png');ww,hh=raw.size;records=[];images={}
N=norm(raw.crop((0,30,ww,255)),(1216,192)).crop((210,0,530,192));E=norm(raw.crop((0,294,ww,518)),(1216,192)).crop((510,0,830,192)).transpose(Image.Transpose.ROTATE_270)
W=norm(Image.open(R/'originals/border_west_v02_raw.png'),(192,320));S=norm(Image.open(R/'originals/border_south_v02_raw.png'),(576,192)).crop((100,0,420,192))
for name,im,axis,inner,source in [('cliff_ice',N,'x','s','borders_straight_v01_raw.png'),('frozen_sea',E,'y','w','borders_straight_v01_raw.png'),('dead_forest',W,'y','e','border_west_v02_raw.png'),('rock_wall',S,'x','n','border_south_v02_raw.png')]:
 im,count=remove_inner_ground(im,inner);im,path=periodic(im,axis);images[name]=im;records.append(dict(id=name+'_01',source='originals/'+source,size=list(im.size),repeat_axis=axis,inner_side=inner,background_removed_pixels=count,cut_path=path,status='candidate_pending_visual_review',processing='existing RGB palette; nearest resize; connected inner snow background extraction; minimum-error overlap cut using source pixels only'))
# Match corner connector ports to the final straight modules by copy-overlap cuts.
def attach(im,port,side):
 if side=='right':return quilt_right(im,port,port.width)[0]
 if side=='left':return quilt_right(im.transpose(Image.Transpose.FLIP_LEFT_RIGHT),port.transpose(Image.Transpose.FLIP_LEFT_RIGHT),port.width)[0].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 if side=='bottom':return quilt_right(im.transpose(Image.Transpose.TRANSPOSE),port.transpose(Image.Transpose.TRANSPOSE),port.height)[0].transpose(Image.Transpose.TRANSPOSE)
 return quilt_right(im.transpose(Image.Transpose.ROTATE_270),port.transpose(Image.Transpose.ROTATE_270),port.height)[0].transpose(Image.Transpose.ROTATE_90)
rawc=Image.open(R/'originals/borders_corners_v01_raw.png')
for name,box in [('nw',(40,20,615,575)),('ne',(670,25,1250,575)),('sw',(38,635,615,1183)),('se',(675,635,1252,1183))]:
 im=norm(rawc.crop(box),(192,192));im,count=remove_inner_ground(im,name)
 if name=='nw':im=attach(im,images['cliff_ice'].crop((128,0,256,192)),'right');im=attach(im,images['dead_forest'].crop((0,128,192,256)),'bottom')
 if name=='ne':im=attach(im,images['cliff_ice'].crop((0,0,128,192)),'left');im=attach(im,images['frozen_sea'].crop((0,128,192,256)),'bottom')
 if name=='sw':im=attach(im,images['rock_wall'].crop((128,0,256,192)),'right');im=attach(im,images['dead_forest'].crop((0,0,192,128)),'top')
 if name=='se':im=attach(im,images['rock_wall'].crop((0,0,128,192)),'left');im=attach(im,images['frozen_sea'].crop((0,0,192,128)),'top')
 images['border_corner_'+name]=im;records.append(dict(id='border_corner_'+name,source='originals/borders_corners_v01_raw.png',crop=list(box),size=[192,192],inner_side=name,background_removed_pixels=count,status='candidate_pending_corner_join_review',processing='nearest resize; existing RGB palette; inner connected snow removal; overlap-copy existing straight connector pixels'))
for key,im in images.items():
 fn=key+'_01' if not key.startswith('border_corner') else key;im.save(R/f'candidates/{fn}_v03.png')
# Actual assembled perimeter, with exact dimensions, no cover-up props across joins.
base=Image.open(R/'references/snow_01.png').convert('RGBA');board=Image.new('RGBA',(1152,1152))
for y in range(0,1152,64):
 for x in range(0,1152,64):board.paste(base,(x,y))
for x in range(192,960,256):board.alpha_composite(images['cliff_ice'],(x,0));board.alpha_composite(images['rock_wall'],(x,960))
for y in range(192,960,256):board.alpha_composite(images['dead_forest'],(0,y));board.alpha_composite(images['frozen_sea'],(960,y))
for n,xy in [('nw',(0,0)),('ne',(960,0)),('sw',(0,960)),('se',(960,960))]:board.alpha_composite(images['border_corner_'+n],xy)
board.save(R/'previews/perimeter_1x_v03.png')
for a in records:
 if 'repeat_axis' not in a:continue
 im=images[a['id'][:-3]];axis=a['repeat_axis'];p=Image.new('RGBA',(im.width*4 if axis=='x' else im.width,im.height*4 if axis=='y' else im.height),'#121721')
 for i in range(4):p.alpha_composite(im,(im.width*i if axis=='x' else 0,im.height*i if axis=='y' else 0))
 p.save(R/f"previews/{a['id']}_repeat_v03.png")
(R/'records/border_modules_v03.json').write_text(json.dumps(records,indent=2));print('8 assembled border candidates, pending visual checks; PNGs not published')
