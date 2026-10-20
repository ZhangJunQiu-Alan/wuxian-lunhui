from pathlib import Path
from PIL import Image, ImageDraw
import hashlib, json, shutil, re, sys, math
ROOT=Path(__file__).resolve().parents[4]
PLAN=json.loads((Path(__file__).parent/'plan_all_H.json').read_text())
BG=(18,23,33,255)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def asset(id):return next(a for a in PLAN if a['id']==id)
def root(a):return ROOT/a['source_root']
def init(a):
 r=root(a)
 for d in ['records','originals','references','candidates','approved','previews']:(r/d).mkdir(parents=True,exist_ok=True)
 refs=[]
 for rel in a['reference_paths']:
  p=ROOT/rel
  if not p.exists():continue
  dst=r/'references'/p.name
  if dst.exists() and sha(dst)!=sha(p):dst=r/'references'/(p.stem+'_'+sha(p)[:8]+p.suffix)
  if not dst.exists():shutil.copy2(p,dst)
  refs.append({'project_path':rel,'archived_path':str(dst.relative_to(r)),'sha256':sha(dst)})
 a['archived_references']=refs
 return r

def archive(id,v='v01'):
 a=asset(id);r=init(a);j=r/'records'/f'result_{id}_{v}.json'
 if id=='thokk':d=json.loads((r/'records/job_thokk_v01.json').read_text())['tool_result']
 else:d=json.loads(j.read_text())
 match=re.search(r'as (/[^\n]+?\.png) by default',d['output_hint'])
 src=Path(match.group(1));dst=r/'originals'/f'{id}_{v}.png'
 if not dst.exists():shutil.copy2(src,dst)
 return dst

def normalize(id,v='v01'):
 a=asset(id);r=init(a);src=archive(id,v);raw=Image.open(src).convert('RGBA');w,h,n=a['w'],a['h'],a['frames'];body='body'in a['flags'];semi=not body and 'chain'not in a['flags']
 raw.putalpha(raw.getchannel('A').point(lambda x:0 if x<18 else min(252,round(x/36)*36)) if semi else raw.getchannel('A').point(lambda x:255 if x>=128 else 0))
 cols,rows=a['columns'],a['rows'];parts=[]
 for k in range(n):
  x=k%cols;y=k//cols
  parts.append(raw.crop((round(x*raw.width/cols),round(y*raw.height/rows),round((x+1)*raw.width/cols),round((y+1)*raw.height/rows))))
 boxes=[f.getbbox() for f in parts];assert all(boxes),(id,boxes)
 # A single scale for every frame; no repeated frames or synthetic body poses.
 crops=[f.crop(b) for f,b in zip(parts,boxes)]
 maxw=max(f.width for f in crops);maxh=max(f.height for f in crops)
 targeth=88 if body and w==96 else 110 if body else h-4
 scale=min((w-4)/maxw,targeth/maxh)
 palette=None
 if id.startswith('thokk_'):
  base=Image.open(ROOT/'assets/source/taskH0_critical_2026-10-19/candidates/thokk_v01.png').convert('RGB')
  palette=base.quantize(colors=48,dither=Image.Dither.NONE)
 elif id=='skoll_howl_body':
  original=Image.open(ROOT/'assets/sprites/bosses/skoll.png').convert('RGBA')
  actual=list({p[:3]for p in original.getdata()if p[3]})
  clustered=original.convert('RGB').quantize(48,dither=Image.Dither.NONE).getpalette()[:144]
  chosen=[]
  for i in range(0,len(clustered),3):
   c=clustered[i:i+3];near=min(actual,key=lambda p:sum((p[j]-c[j])**2 for j in range(3)))
   if near not in chosen:chosen.append(near)
  palette=Image.new('P',(1,1));palette.putpalette([c for p in chosen for c in p]+list(chosen[0])*(256-len(chosen)))
 else:
  sample=Image.new('RGB',(sum(f.width for f in crops),maxh));off=0
  for f in crops:sample.paste(f.convert('RGB'),(off,0));off+=f.width
  palette=sample.quantize(colors=48 if body else 32,dither=Image.Dither.NONE)
 out=Image.new('RGBA',(w*n,h));placements=[]
 # Keep the same cell registration for abstract effects, so expansion is retained.
 union=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
 if not body:scale=min(((w//2-2) if 'front'in a['flags']else w-6 if 'mouth'in a['flags']else w-4)/maxw,(h-4)/maxh)
 for k,(part,crop) in enumerate(zip(parts,crops)):
  if body:
   f=crop.resize((max(1,round(crop.width*scale)),max(1,round(crop.height*scale))),Image.Resampling.NEAREST)
   x=(w-f.width)//2;y=a['anchor'][1]-f.height
   if id.startswith('thokk'):
    feet=f.getchannel('A').crop((0,max(0,f.height-6),f.width,f.height)).getbbox()
    if feet:x=round(a['anchor'][0]-(feet[0]+feet[2])/2)
  else:
   f=crop.resize((max(1,round(crop.width*scale)),max(1,round(crop.height*scale))),Image.Resampling.NEAREST)
   x=(w-f.width)//2;y=(h-f.height)//2
   if 'trail'in a['flags']:x=w-2-f.width
   if 'mouth'in a['flags']:x=4
   if 'front'in a['flags']:x=w//2
  alpha=f.getchannel('A');q=f.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(alpha)
  if 'faint'in a['flags']:q.putalpha(q.getchannel('A').point(lambda x:round(x*0.18)))
  if 'area'in a['flags'] and 'faint'not in a['flags']:q.putalpha(q.getchannel('A').point(lambda x:round(x*0.78)))
  assert x>=0 and y>=0 and x+f.width<=w and y+f.height<=h,(id,k,x,y,f.size)
  out.paste(q,(k*w+x,y));placements.append([x,y,f.width,f.height])
 if 'band'in a['flags'] or 'chain'in a['flags']:
  # Match repeated ports using source-derived pixels, without painting new content.
  for k in range(n):
   f=out.crop((k*w,0,(k+1)*w,h));b=f.getbbox();strip=f.crop((b[0],0,b[2],h)).resize((w,h),Image.Resampling.NEAREST)
   col=strip.crop((w//2,0,w//2+1,h));strip.paste(col,(0,0));strip.paste(col,(w-1,0));out.paste(strip,(k*w,0))
 out.putdata([p if p[3] else (0,0,0,0) for p in out.getdata()]);dst=r/'candidates'/f'{id}_{v}.png';out.save(dst)
 save(r/'records'/f'normalization_{id}_{v}.json',{'input':str(src.relative_to(r)),'input_sha256':sha(src),'raw_size':raw.size,'grid':[cols,rows],'cut_boxes':boxes,'single_common_scale':scale,'placements':placements,'operations':'original alpha threshold/quantization, source frame cuts, single common nearest resize, source-derived shared palette, whole-frame placement; no character/effect drawing','candidate':str(dst.relative_to(r)),'candidate_sha256':sha(dst)})
 preview(id,v)
 return dst

def frames(a,im):return [im.crop((k*a['w'],0,(k+1)*a['w'],a['h'])) for k in range(a['frames'])]
def preview(id,v='v01'):
 a=asset(id);r=root(a);im=Image.open(r/'candidates'/f'{id}_{v}.png').convert('RGBA');w,h=a['w'],a['h'];fs=frames(a,im)
 o=Image.new('RGBA',(max(600,im.width*4),h*5+54),BG);d=ImageDraw.Draw(o);d.text((4,4),f"{id} {v} | {w}x{h} x{a['frames']} | native / 4x",fill='white');o.alpha_composite(im,(0,22));o.alpha_composite(im.resize((im.width*4,h*4),Image.Resampling.NEAREST),(0,h+48));o.convert('RGB').save(r/'previews'/f'{id}_{v}_frames.png')
 if 'body'in a['flags']:
  ImageDraw.Draw(o).line([(0,h+48+a['anchor'][1]*4),(o.width,h+48+a['anchor'][1]*4)],fill='#48d899')
  o.convert('RGB').save(r/'previews'/f'{id}_{v}_baseline.png')
 if len(fs)>1:
  seq=fs*2
  for fps,label in [(a['fps'],'native'),(8,'slow8')]:
   gs=[];dur=[round((k+1)*100/fps)*10-round(k*100/fps)*10 for k in range(len(seq))]
   for f in seq:
    g=Image.new('RGBA',f.size,BG);g.alpha_composite(f);gs.append(g.convert('RGB').resize((w*4,h*4),Image.Resampling.NEAREST))
   gs[0].save(r/'previews'/f'{id}_{v}_{label}.gif',save_all=True,append_images=gs[1:],duration=dur,loop=0,disposal=2,optimize=False)
 if 'rotate'in a['flags']:
  o=Image.new('RGBA',(max(w,h)*12+24,max(w,h)*4+30),BG);d=ImageDraw.Draw(o)
  for k,angle in enumerate([0,90,180]):
   f=fs[0].rotate(angle,expand=True).resize((fs[0].rotate(angle,expand=True).width*4,fs[0].rotate(angle,expand=True).height*4),Image.Resampling.NEAREST);o.alpha_composite(f,(k*max(w,h)*4,24));d.text((k*max(w,h)*4,4),str(angle),fill='white')
  o.convert('RGB').save(r/'previews'/f'{id}_{v}_rotate.png')
 if any(f in a['flags'] for f in ['band','mouth','trail','flow','chain']):
  o=Image.new('RGBA',(w*4+16,h*3+60),BG);o.alpha_composite(fs[0],(8,20));o.alpha_composite(fs[0].resize((w*4,h*2),Image.Resampling.NEAREST),(8,h+40));o.convert('RGB').save(r/'previews'/f'{id}_{v}_stretch.png')
 if 'area'in a['flags'] or 'tile'in a['flags']:
  tiles=list((ROOT/'assets/sprites/ground/helheim').glob('*.png')) if a['task']in ['H0','H4','H5','H6'] else list((ROOT/'assets/sprites/ground/midgard').glob('*.png'))
  t=Image.open(sorted(tiles)[0]).convert('RGBA');o=Image.new('RGBA',(384,256),BG)
  for yy in range(0,256,t.height):
   for xx in range(0,384,t.width):o.alpha_composite(t,(xx,yy))
  f=fs[min(1,len(fs)-1)];o.alpha_composite(f,(12,12));o.alpha_composite(f.resize((w*2,h*2),Image.Resampling.NEAREST),(148,5))
  for p,xy in [('assets/sprites/characters/swordsman.png',(40,65)),('assets/sprites/enemies/dead.png',(220,86))]:
   if (ROOT/p).exists():o.alpha_composite(Image.open(ROOT/p).convert('RGBA'),xy)
  o.convert('RGB').save(r/'previews'/f'{id}_{v}_ground.png')
 if 'tile'in a['flags']:
  o=Image.new('RGBA',(w*4,h*4),BG)
  for yy in range(4):
   for xx in range(4):o.alpha_composite(fs[0],(xx*w,yy*h))
  o.convert('RGB').save(r/'previews'/f'{id}_{v}_tile4x4.png')
 print(id,v,im.size,'frames',len(fs),'palette',len({p[:3] for p in im.getdata()if p[3]}))

if __name__=='__main__':
 for arg in sys.argv[1:]:
  id,_,v=arg.partition(':');normalize(id,v or 'v01')
