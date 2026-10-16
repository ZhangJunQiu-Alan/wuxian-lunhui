from pathlib import Path
from PIL import Image
import json,hashlib,sys
r=Path(__file__).resolve().parents[1]
def components(im):
 w,h=im.size;a=bytearray(1 if v>=128 else 0 for v in im.getchannel('A').get_flattened_data());out=[]
 for start in range(w*h):
  if not a[start]:continue
  a[start]=0;q=[start];pixels=[];x0=w;y0=h;x1=0;y1=0
  while q:
   k=q.pop();pixels.append(k);y,x=divmod(k,w);x0=min(x0,x);y0=min(y0,y);x1=max(x1,x);y1=max(y1,y)
   for z in ((k-1 if x else -1),(k+1 if x<w-1 else -1),k-w,k+w):
    if 0<=z<w*h and a[z]:a[z]=0;q.append(z)
  if len(pixels)>60:out.append({'count':len(pixels),'bbox':[x0,y0,x1+1,y1+1],'pixels':pixels})
 return sorted(out,key=lambda c:c['count'],reverse=True)
meta=json.loads((r/'records/candidates.json').read_text());jobs=json.loads((r/'records/generation_jobs.json').read_text())
for spec in sys.argv[1:]:
 id,v=spec.rsplit(':',1)
 raw=Image.open(r/'originals'/f'{id}_attack_{v}_raw.png').convert('RGBA');cs=components(raw);print(id,[(c['count'],c['bbox']) for c in cs[:10]]);chosen=cs[:4];assert len(chosen)==4
 if min(c['count'] for c in chosen)<chosen[0]['count']*.4:raise ValueError('merged or missing silhouette')
 chosen=sorted(chosen,key=lambda c:(sum(c['bbox'][1::2])//2>=raw.height//2,(c['bbox'][0]+c['bbox'][2])/2));sources=[]
 for c in chosen:
  box=c['bbox'];z=Image.new('RGBA',(box[2]-box[0],box[3]-box[1]));pix=z.load();rp=raw.load()
  for k in c['pixels']:
   y,x=divmod(k,raw.width);rgba=rp[x,y];pix[x-box[0],y-box[1]]=(*rgba[:3],255)
  sources.append(z)
 ref=Image.open(r/'references'/f'{id}.png').convert('RGBA');n=ref.height;rb=ref.getbbox();base=rb[3]-1;scale=min((n-4)/max(z.width for z in sources),(rb[3]-rb[1])/max(z.height for z in sources));colors=json.loads((r/'records'/f'{id}_reference_palette.json').read_text());pal=Image.new('P',(1,1));pal.putpalette([v for c in colors for v in c]+colors[0]*(256-len(colors)));frames=[]
 for z in sources:
  z=z.resize((round(z.width*scale),round(z.height*scale)),Image.Resampling.NEAREST);q=z.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(z.getchannel('A'));f=Image.new('RGBA',(n,n));f.alpha_composite(q,((n-q.width)//2,base+1-q.height));frames.append(f)
 sheet=Image.new('RGBA',(n*4,n))
 for i,f in enumerate(frames):sheet.alpha_composite(f,(i*n,0))
 png=f'candidates/{id}_attack_{v}.png';sheet.save(r/png);j=next(j for j in jobs if j['id']==id+'_attack_'+v);meta.append({'id':id+'_attack','candidate':png,'status':'candidate_pending_visual_motion_review','source':f'originals/{id}_attack_{v}_raw.png','generation_url':j['conversation_url'],'frames':4,'size':[n*4,n],'frame_size':[n,n],'fps':16,'baseline':base,'bboxes':[f.getbbox() for f in frames],'colors':len({p[:3] for p in sheet.get_flattened_data() if p[3]}),'reference_palette':'records/'+id+'_reference_palette.json','alpha_values':sorted(set(sheet.getchannel('A').get_flattened_data())),'raw_component_bboxes':[c['bbox'] for c in chosen],'scale':scale,'sha256':hashlib.sha256((r/png).read_bytes()).hexdigest()})
(r/'records/candidates.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
