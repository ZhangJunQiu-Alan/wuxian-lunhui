from pathlib import Path
from PIL import Image,ImageDraw,ImageStat
import json,hashlib,sys,math,shutil
R=Path(__file__).resolve().parent.parent
PLAN={a['id']:a for a in json.loads((R/'records/production_plan.json').read_text())['assets']}
BG=(18,23,33)
def rgba_palette(im,pal=None):
 alpha=im.getchannel('A');rgb=im.convert('RGB');q=rgb.quantize(colors=32,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE) if pal is None else rgb.quantize(palette=pal,dither=Image.Dither.NONE)
 o=q.convert('RGBA');o.putalpha(alpha);o.putdata([v if v[3] else(0,0,0,0) for v in o.getdata()]);return o,q
def review(id,v='v01'):
 a=PLAN[id];im=Image.open(R/'candidates'/f'{id}_{v}.png').convert('RGBA');w,h,n=a['w'],a['h'],a['frames'];o=Image.new('RGB',(max(640,im.width*4),h*5+80),BG);d=ImageDraw.Draw(o);d.text((4,4),f'{id} {v} | {w}x{h} x{n} | 1x / 4x',fill='white');o.paste(im,(0,25),im);big=im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST);o.paste(big,(0,h+50),big);o.save(R/'previews'/f'{id}_{v}_review.png')
 frames=[im.crop((k*w,0,(k+1)*w,h)) for k in range(n)]
 if n>1:
  gifs=[]
  # GIF centisecond durations alternate to retain exactly8/12 frames persecond on average.
  repeats=3 if a['fps']==12 else 2
  seq=frames*repeats;dur=[round((i+1)*100/a['fps'])*10-round(i*100/a['fps'])*10 for i in range(len(seq))]
  for f in seq:
   z=Image.new('RGBA',f.size,BG+(255,));z.alpha_composite(f);gifs.append(z.convert('RGB').resize((w*4,h*4),Image.Resampling.NEAREST))
  gifs[0].save(R/'previews'/f'{id}_{v}.gif',save_all=True,append_images=gifs[1:],duration=dur,loop=0,disposal=2,optimize=False)
 if 'rotate' in a['flags']:
  o=Image.new('RGBA',(max(w,h)*2+48,max(w,h)*2+60),BG+(255,));d=ImageDraw.Draw(o)
  for k,angle in enumerate([0,90,180]):
   f=frames[0].rotate(angle,expand=True);x=8 if k<2 else max(w,h)+20;y=20 if k!=1 else max(w,h)+35;o.alpha_composite(f,(x,y));d.text((x,y-13),str(angle),fill='white')
  o.save(R/'previews'/f'{id}_{v}_rotations.png')
 if 'stretch' in a['flags']:
  f=frames[0];o=Image.new('RGBA',(w*4+16,h*4+64),BG+(255,));o.alpha_composite(f,(8,18));o.alpha_composite(f.resize((w*4,h*2),Image.Resampling.BILINEAR),(8,h+45));ImageDraw.Draw(o).text((8,2),'native / 4xlength 2xwidth',fill='white');o.save(R/'previews'/f'{id}_{v}_stretch.png')
 if 'area'in a['flags']:
  o=Image.new('RGBA',(384,256));t=Image.open(R/'refs/midgard_ground.png').convert('RGBA')
  for y in range(0,256,t.height):
   for x in range(0,384,t.width):o.alpha_composite(t,(x,y))
  for scale,xy in [(1,(18,25)),(1.6,(172,15))]:
   f=frames[0].resize((round(w*scale),round(h*scale)),Image.Resampling.BILINEAR);o.alpha_composite(f,xy)
  for name,xy in [('swordsman',(45,80)),('enemy',(220,90))]:
   p=R/'refs'/f'{name}.png'
   if p.exists():o.alpha_composite(Image.open(p).convert('RGBA'),xy)
  o.save(R/'previews'/f'{id}_{v}_ground.png')
 return im
def normalize(id,v='v01'):
 a=PLAN[id];src=R/'originals'/f'{id}_{v}_raw.png';raw=Image.open(src).convert('RGBA');w,h,n=a['w'],a['h'],a['frames'];semi='area'in a['flags'] or 'stretch'in a['flags'];raw.putalpha(raw.getchannel('A').point(lambda x:0 if x<12 else x)if semi else raw.getchannel('A').point(lambda x:255 if x>=128 else 0))
 parts=[raw.crop((round(k*raw.width/n),0,round((k+1)*raw.width/n),raw.height)) for k in range(n)];boxes=[f.getbbox() for f in parts];crops=[f.crop(b) for f,b in zip(parts,boxes)];record={'raw_size':raw.size,'source':str(src.relative_to(R)),'frame_boxes':boxes,'target_perframe':[w,h],'frames':n,'alpha':'preserve generatedalpha, quantized8levels/cappedforground' if semi else'binary128threshold','tool':'Pillow formatting only'}
 if 'stretch'in a['flags']:
  f=crops[0].resize((w,h-4),Image.Resampling.NEAREST);f,pal=rgba_palette(f);out=Image.new('RGBA',(w,h));out.paste(f,(0,2));col=out.crop((w//2,0,w//2+1,h));out.paste(col.resize((4,h),Image.Resampling.NEAREST),(0,0));out.paste(col.resize((4,h),Image.Resampling.NEAREST),(w-4,0));record['operation']='Whole strip nearest resize; identical4px sourcecolumn endports, transparent2px top/bottom'
 else:
  maxw=max(f.width for f in crops);maxh=max(f.height for f in crops);max_target_h=a['anchor'][1]-1 if 'feet'in a['flags'] or 'chariot'in a['flags'] else h-4;scale=min(((a['anchor'][0]-1) if 'tip' in a['flags'] else(w-4))/maxw,max_target_h/maxh);record['common_scale']=scale;out=Image.new('RGBA',(w*n,h));pal=None;placements=[]
  # One shared palette sampled across all generatedframes.
  sample=Image.new('RGBA',(sum(f.width for f in crops),maxh));xx=0
  for f in crops:sample.paste(f,(xx,0));xx+=f.width
  _,pal=rgba_palette(sample)
  for k,f in enumerate(crops):
   f=f.resize((max(1,round(f.width*scale)),max(1,round(f.height*scale))),Image.Resampling.NEAREST);f,_=rgba_palette(f,pal);x=(w-f.width)//2;y=(h-f.height)//2
   if 'feet'in a['flags'] or'chariot'in a['flags']:y=a['anchor'][1]+1-f.height
   if 'tip'in a['flags']:x=a['anchor'][0]+1-f.width;y=a['anchor'][1]-f.height//2
   out.paste(f,(k*w+x,y));placements.append([x,y,f.width,f.height])
  record.update(operation='Equalcell cuts, whole silhouette crop, common nearest scale, shared32RGBpalette, anchorplacement; no bodyredrawing',placements=placements)
 if semi:
  cap=72 if 'faint'in a['flags'] else 110 if 'area'in a['flags'] else 150 if 'ice'in a['flags'] else 230
  out.putalpha(out.getchannel('A').point(lambda x:round((x*cap/255)/16)*16 if x else 0));record['alpha_cap']=cap
 out.putdata([q if q[3] else(0,0,0,0) for q in out.getdata()]);out.save(R/'candidates'/f'{id}_{v}.png');(R/'records'/f'normalization_{id}_{v}.json').write_text(json.dumps(record,indent=2));review(id,v);print(id,v,out.size)
if __name__=='__main__':
 for id in sys.argv[1:]:
  if ':'in id:id,v=id.split(':');normalize(id,v)
  else:normalize(id)
