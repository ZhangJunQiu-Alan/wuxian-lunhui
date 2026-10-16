from pathlib import Path
from PIL import Image,ImageDraw
import json
R=Path(__file__).resolve().parents[1];pal=json.loads((R/'references/existing_midgard_palette48.json').read_text());p=Image.new('P',(1,1));flat=sum(pal,[]);p.putpalette(flat+flat[:3]*(256-len(pal)))
def cut(a,b,o):
 w,h=o,a.height;pa=a.load();pb=b.load();dp=[];back=[]
 for y in range(h):
  vals=[sum((pa[a.width-o+x,y][c]-pb[x,y][c])**2 for c in range(4)) for x in range(w)]
  if y==0:dp.append(vals);continue
  bs=[];row=[]
  for x in range(w):
   k=min(range(max(0,x-1),min(w,x+2)),key=lambda j:dp[-1][j]);bs.append(k);row.append(vals[x]+dp[-1][k])
  back.append(bs);dp.append(row)
 path=[0]*h;path[-1]=min(range(w),key=lambda x:dp[-1][x])
 for y in range(h-1,0,-1):path[y-1]=back[y-1][path[y]]
 out=a.copy();px=out.load()
 for y in range(h):
  for x in range(path[y],o):px[a.width-o+x,y]=pb[x,y]
 return out.crop((o,0,out.width,out.height))
def repeat2(im,o):
 im=cut(im,im.crop((0,0,o,im.height)),o);im=im.transpose(Image.Transpose.TRANSPOSE);im=cut(im,im.crop((0,0,o,im.height)),o);return im.transpose(Image.Transpose.TRANSPOSE)
raw=Image.open(R/'originals/ground_extra_v01_raw.png');w,h=raw.size;records=[]
for ident,box in [('snow_thin',(0,0,w//2,h//2)),('ice_02',(w//2,0,w,h//2))]:
 palette=p
 if ident=='snow_thin':
  colors=[c for c in pal if 38<=sum(c)/3<=82];palette=Image.new('P',(1,1));palette.putpalette(sum(colors,[])+colors[0]*(256-len(colors)))
 src='snow_thin_v02_raw.png' if ident=='snow_thin' else 'ground_extra_v01_raw.png';version='v02' if ident=='snow_thin' else 'v01';source=Image.open(R/'originals'/src);box=(0,0,source.width,source.height) if ident=='snow_thin' else box
 im=source.crop(box).convert('RGB').resize((96,96),Image.Resampling.NEAREST).quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA');im=repeat2(im,32);im.save(R/f'candidates/{ident}_{version}.png');records.append(dict(id=ident,type='ground',size=[64,64],source='originals/'+src,candidate=f'candidates/{ident}_{version}.png',crop=list(box),processing='Nearest resize; shared palette; minimum error source-pixel overlap and crop on both axes',status='candidate_pending_visual_review'))
 board=Image.new('RGBA',(256,256))
 for y in range(4):
  for x in range(4):board.paste(im,(x*64,y*64))
 board.save(R/f'previews/{ident}_tile4x4_{version}.png')
# Joinable dock strips extend through repeat-axis edges; side padding remains transparent.
for ident in ['pier_straight_01','pier_straight_02']:
 im=Image.open(R/f'candidates/{ident}_v01.png');im=im.crop((0,8,64,56)).resize((64,80),Image.Resampling.NEAREST).transpose(Image.Transpose.TRANSPOSE);im=cut(im,im.crop((0,0,16,im.height)),16).transpose(Image.Transpose.TRANSPOSE);im.save(R/f'candidates/{ident}_v02.png')
 out=Image.new('RGBA',(64,256),'#121721')
 for y in range(4):out.alpha_composite(im,(0,y*64))
 out.save(R/f'previews/{ident}_join_v02.png')
(R/'records/ground_extra_normalization_v01.json').write_text(json.dumps(records,indent=2));print('2 ground candidates + 2 connected pier revisions')
