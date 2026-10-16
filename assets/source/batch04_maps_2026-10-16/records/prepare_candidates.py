from pathlib import Path
from PIL import Image,ImageFilter,ImageStat,ImageDraw
import json,math,hashlib
R=Path(__file__).resolve().parents[1]
INV=json.loads((R/'records/asset_inventory.json').read_text())
G={l:[a for a in INV if a['level']==l and a['type']=='ground'] for l in ('midgard','helheim','vigrid')}
P={l:[a for a in INV if a['level']==l and a['type']=='props'] for l in G}
records=[]
def edgefix(im,common=None,band=6):
 p=im.load();w,h=im.size
 if common is None:
  left=[tuple(round((p[0,y][c]+p[w-1,y][c])/2) for c in range(3)) for y in range(h)]
  top=[tuple(round((p[x,0][c]+p[x,h-1][c])/2) for c in range(3)) for x in range(w)]
 else:left,top=common
 corner=tuple(round((left[0][c]+left[-1][c]+top[0][c]+top[-1][c])/4) for c in range(3))
 left[0]=left[-1]=top[0]=top[-1]=corner
 out=im.copy();q=out.load()
 for y in range(h):
  for x in range(w):
   dx=min(x,w-1-x);dy=min(y,h-1-y); ax=max(0,1-dx/band);ay=max(0,1-dy/band)
   if ax or ay:
    tx=left[y];ty=top[x]; weight=max(ax,ay); total=ax+ay
    target=[(tx[c]*ax+ty[c]*ay)/total for c in range(3)]
    q[x,y]=tuple(round(p[x,y][c]*(1-weight)+target[c]*weight) for c in range(3))
 # Exact outer ports after blending; corners shared.
 for y in range(h):q[0,y]=q[w-1,y]=left[y]
 for x in range(w):q[x,0]=q[x,h-1]=top[x]
 return out,(left,top)
def ground():
 for level,assets in G.items():
  src=R/f'originals/{level}_ground_v01_raw.png'
  if not src.exists():continue
  raw=Image.open(src).convert('RGB');w,h=raw.size; common=None
  for idx,a in enumerate(assets):
   box=(round(idx%4*w/4)+3,round(idx//4*h/2)+3,round((idx%4+1)*w/4)-3,round((idx//4+1)*h/2)-3)
   tile=raw.crop(box).resize((64,64),Image.Resampling.NEAREST)
   tile.save(R/f"candidates/{level}_{a['id']}_unfixed.png")
   blur=tile.filter(ImageFilter.GaussianBlur(7));mean=ImageStat.Stat(tile).mean
   target={'midgard':(56,67,80),'helheim':(37,47,52),'vigrid':(40,34,34)}[level]
   if a['id']=='frozen_dirt':target=(48,44,44)
   if a['id'].startswith('nail_deck'):target=(59,57,52)
   if a['id']=='ice':target=(43,60,75)
   macro=.15 if idx<4 else .38; micro=.65
   out=Image.new('RGB',(64,64));op=out.load();tp=tile.load();bp=blur.load()
   for y in range(64):
    for x in range(64):
     op[x,y]=tuple(max(0,min(150,round(target[c]+(tp[x,y][c]-bp[x,y][c])*micro+(bp[x,y][c]-mean[c])*macro))) for c in range(3))
   out,ports=edgefix(out,common if idx<4 else None)
   if idx==0:common=ports
   out.convert('RGBA').save(R/f"candidates/{level}_{a['id']}_v01.png")
   records.append(dict(id=a['id'],level=level,type='ground',source=str(src.relative_to(R)),crop=box,processing='nearest64; subdued micro/macro contrast; 6px opposing-edge port blend; shared base ports',status='candidate_pending_visual_review'))
def matte(im):
 im=im.convert('RGBA');px=im.load()
 for y in range(im.height):
  for x in range(im.width):
   r,g,b,al=px[x,y]
   if r>150 and b>140 and r-g>75 and b-g>75:px[x,y]=(0,0,0,0)
   # Magenta anti-alias fringe: reject strongly chromatic edge contamination.
   elif r>g*1.65 and b>g*1.65 and min(r,b)>110:px[x,y]=(0,0,0,0)
 return im
PROPMAPS=[('midgard_props_a','midgard',3,2,list(range(6))),('midgard_props_b','midgard',4,2,list(range(6,13))),('helheim_props','helheim',3,2,list(range(5))),('vigrid_props','vigrid',3,2,list(range(5)))]
def props():
 for name,level,cols,rows,ids in PROPMAPS:
  src=R/f'originals/{name}_v01_raw.png'
  if not src.exists():continue
  raw=Image.open(src);w,h=raw.size
  for i,asset_idx in enumerate(ids):
   a=P[level][asset_idx];box=(round(i%cols*w/cols),round(i//cols*h/rows),round((i%cols+1)*w/cols),round((i//cols+1)*h/rows))
   if name=='midgard_props_b':
    box=[(80,80,345,430),(410,140,900,425),(900,80,1385,445),(1405,215,1765,435),(10,490,660,835),(680,625,1005,800),(1040,630,1400,800)][i]
   elif name=='midgard_props_a' and i<2:
    box=[(110,10,470,525),(585,20,1000,535)][i]
   cut=matte(raw.crop(box));bb=cut.getbbox()
   if not bb:raise ValueError((name,a['id'],'empty'))
   cut=cut.crop(bb);tw,th=a['width'],a['height'];s=min((tw-4)/cut.width,(th-4)/cut.height);nw,nh=max(1,round(cut.width*s)),max(1,round(cut.height*s))
   small=cut.resize((nw,nh),Image.Resampling.NEAREST);out=Image.new('RGBA',(tw,th));out.alpha_composite(small,((tw-nw)//2,th-2-nh));out.save(R/f"candidates/{level}_{a['id']}_v01.png")
   records.append(dict(id=a['id'],level=level,type='props',source=str(src.relative_to(R)),cell_crop=box,content_bbox=list(bb),processing='magenta matte removal; nearest scale preserving aspect; centered x and bottom2px',status='candidate_pending_visual_review'))
def preview():
 for level in G:
  files=[(a,R/f"candidates/{level}_{a['id']}_v01.png") for a in INV if a['level']==level];files=[(a,p) for a,p in files if p.exists()]
  if not files:continue
  sheet=Image.new('RGB',(1000,math.ceil(len(files)/4)*350),'#121721');d=ImageDraw.Draw(sheet)
  for i,(a,p) in enumerate(files):
   im=Image.open(p);x=i%4*250;y=i//4*350;d.text((x+8,y+8),a['id'],fill='white');sheet.paste(im,(x+8,y+30),im)
   scale=2 if a['width']>96 else 3;big=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST);sheet.paste(big,(x+8,y+140),big)
   if a['type']=='ground':
    tiled=Image.new('RGBA',(256,256))
    for iy in range(4):
     for ix in range(4):tiled.paste(im,(ix*64,iy*64))
    tiled.save(R/f"previews/{level}_{a['id']}_4x4.png")
  sheet.save(R/f'previews/{level}_candidate_contact.png')
 ground_files=[a for a in INV if a['type']=='ground' and (R/f"candidates/{a['level']}_{a['id']}_v01.png").exists()]
 mosaic=Image.new('RGB',(1024,math.ceil(len(ground_files)/4)*280),'#121721');d=ImageDraw.Draw(mosaic)
 for i,a in enumerate(ground_files):
  im=Image.open(R/f"previews/{a['level']}_{a['id']}_4x4.png");x=i%4*256;y=i//4*280;mosaic.paste(im,(x,y+20));d.text((x+3,y+3),a['level']+'/'+a['id'],fill='white')
 mosaic.save(R/'previews/ground_seam_review_v01.png')
ground();props();preview();(R/'records/candidate_processing_v01.json').write_text(json.dumps(records,indent=2));print('Prepared',len(records),'unapproved candidates')
