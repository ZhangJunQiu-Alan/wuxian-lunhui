from pathlib import Path
from PIL import Image,ImageDraw
import hashlib,json,math,sys
ROOT=Path(__file__).resolve().parents[4]
BATCHES=sorted((ROOT/'assets/source').glob('taskJ*_2026-10-19'))
ALPHA=[0,32,64,96,128,160,208,255]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def process(b,a):
 name=a['name']; version='v02' if (b/'originals'/f'{name}_v02.png').exists() else 'v01'; raw=b/'originals'/f'{name}_{version}.png'
 if not raw.exists():return
 w,h=a['frame_size'];n=a['frames']
 im=Image.open(raw).convert('RGBA');cols=1 if n==1 else 3 if n==6 else 2;rows=math.ceil(n/cols)
 cells=[];boxes=[];rects=[]
 for i in range(n):
  x,y=i%cols,i//cols
  rect=(round(im.width*x/cols),round(im.height*y/rows),round(im.width*(x+1)/cols),round(im.height*(y+1)/rows))
  cell=im.crop(rect);mask=cell.getchannel('A').point(lambda v:255 if v>=16 else 0)
  box=mask.getbbox()
  if box is None:raise ValueError(name+' empty cell'+str(i))
  cells.append(cell);boxes.append(box);rects.append(rect)
 maxw=max(r[2]-r[0] for r in boxes);maxh=max(r[3]-r[1] for r in boxes)
 factor=min(((w//2-4) if name=="blades_slash" else (w-8) if name=="loki_wolf_breath" else (w-4))/maxw,(h-4)/maxh)
 frames=[];placements=[]
 solid=name in ['formation_cavalry','stonehenge_stone','stonehenge_lintel']
 for cell,box in zip(cells,boxes):
  crop=cell.crop(box);size=(max(1,round(crop.width*factor)),max(1,round(crop.height*factor)))
  crop=crop.resize(size,Image.Resampling.NEAREST)
  x=(w//2+2 if name=='blades_slash' else 4 if name=='loki_wolf_breath' else (w-size[0])//2);y=h-2-size[1] if solid else (h-size[1])//2
  frame=Image.new('RGBA',(w,h));frame.paste(crop,(x,y))
  frames.append(frame);placements.append([x,y,*size])
 # One shared RGB palette; alpha handled independently. No repainting.
 sheet=Image.new('RGBA',(w*n,h))
 for i,frame in enumerate(frames):sheet.paste(frame,(i*w,0))
 rgb=sheet.convert('RGB');q=rgb.quantize(colors=32,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGB')
 px=[]
 alpha_cap=160 if name=='west_aura' else 208 if name=='stonehenge_circle' else 255
 for rgbv,old in zip(q.get_flattened_data(),sheet.get_flattened_data()):
  av=(255 if old[3]>=128 else 0) if solid else min(alpha_cap,min(ALPHA,key=lambda k:abs(k-old[3])))
  px.append((*rgbv,av) if av else (0,0,0,0))
 sheet.putdata(px)
 out=b/'candidates'/f'{name}_{version}.png';sheet.save(out)
 frames=[sheet.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
 preview=Image.new('RGB',(max(320,w*4*n),h*4+60),'#121721');d=ImageDraw.Draw(preview)
 for i,f in enumerate(frames):
  preview.paste(f.resize((w*4,h*4),Image.Resampling.NEAREST),(i*w*4,30),f.resize((w*4,h*4),Image.Resampling.NEAREST));d.text((i*w*4+4,8),f'frame {i+1}',fill='white')
 preview.save(b/'previews'/f'{name}_frames_4x.png')
 native=Image.new('RGB',(max(220,w*n),h+35),'#121721');d=ImageDraw.Draw(native);d.text((4,4),'native 1x - dark background',fill='white')
 for i,f in enumerate(frames):native.paste(f,(i*w,25),f)
 native.save(b/'previews'/f'{name}_frames_1x.png')
 # GIF previews are display composites; source RGBA remains canonical.
 if n>1:
  gifs=[]
  for f in frames:
   bg=Image.new('RGBA',(w,h),'#121721');bg.alpha_composite(f);gifs.append(bg.convert('RGB').resize((w*4,h*4),Image.Resampling.NEAREST))
  duration=([120,130]*n)[:n] if a['fps']==8 else [60,70,60,60,60,70][:n]
  kw={'duration':duration,'disposal':2,'optimize':False}
  if a['loop']:kw['loop']=0
  gifs[0].save(b/'previews'/f'{name}_normal.gif',save_all=True,append_images=gifs[1:],**kw)
  kw['duration']=([120,130]*n)[:n]
  gifs[0].save(b/'previews'/f'{name}_slow8.gif',save_all=True,append_images=gifs[1:],**kw)
 record={'name':name,'raw':str(raw.relative_to(b)),'raw_sha256':sha(raw),'raw_size':list(im.size),'grid':[cols,rows],'cell_rects':rects,'alpha_bbox_threshold':16,'cell_content_bboxes':boxes,'uniform_nearest_factor':factor,'placements':placements,'shared_rgb_palette_max':32,'alpha_policy':'binary_0_255' if solid else ALPHA,'alpha_cap':alpha_cap,'target_frame_size':[w,h],'frame_count':n,'candidate':str(out.relative_to(b)),'candidate_sha256':sha(out),'operation_scope':'crop, uniform nearest scaling, register, shared color and alpha specification; no painted pixels or duplicated animation frames'}
 (b/'records'/f'{name}_processing.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
 print(name,list(sheet.size),'RGB',len({p[:3] for p in sheet.get_flattened_data() if p[3]}),'alpha',sorted({p[3] for p in sheet.get_flattened_data()}))
for b in BATCHES:
 plan=json.loads((b/'production_plan.json').read_text())
 for a in plan['assets']:
  if len(sys.argv)==1 or a['name'] in sys.argv[1:]:process(b,a)
