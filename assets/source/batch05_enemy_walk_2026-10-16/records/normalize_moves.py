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
plan=json.loads((r/'records/production_plan.json').read_text());items=json.loads((r/'records/candidates.json').read_text())
for arg in sys.argv[1:]:
    parts=arg.split(':');ident,ver=parts[:2];outver=parts[2] if len(parts)>2 else ver;fit=parts[3] if len(parts)>3 else 'height'
    spec=next(p for p in plan if p['id']==ident);char=spec['character'];count=spec['frames'];w,h=spec['frame_size'];baseline=spec['baseline']
    raw=Image.open(r/'originals'/f'{ident}_{ver}_raw.png').convert('RGBA');cs=components(raw);roots=cs[:count];assert len(roots)==count
    roots=sorted(roots,key=lambda c:((c['bbox'][1]+c['bbox'][3])/2>=raw.height/2,(c['bbox'][0]+c['bbox'][2])/2))
    for c in cs[count:]:
        if c['count']<200:continue
        cx=(c['bbox'][0]+c['bbox'][2])/2;cy=(c['bbox'][1]+c['bbox'][3])/2
        z=min(roots,key=lambda z:((z['bbox'][0]+z['bbox'][2])/2-cx)**2+((z['bbox'][1]+z['bbox'][3])/2-cy)**2)
        z['pixels']+=c['pixels'];z['bbox']=[min(z['bbox'][0],c['bbox'][0]),min(z['bbox'][1],c['bbox'][1]),max(z['bbox'][2],c['bbox'][2]),max(z['bbox'][3],c['bbox'][3])]
    ref=Image.open(r/'references'/f'{char}.png').convert('RGBA');rb=ref.getbbox();scale=(rb[3]-rb[1])/max(c['bbox'][3]-c['bbox'][1] for c in roots)
    if fit=='fit':scale=min(scale,(w-4)/max(c['bbox'][2]-c['bbox'][0] for c in roots))
    colors=json.loads((r/'records'/f'{char}_reference_palette.json').read_text());pal=Image.new('P',(1,1));pal.putpalette([v for c in colors for v in c]+colors[0]*(256-len(colors)))
    def head_anchor(im):
        b=im.getbbox();pts=[(x,y) for y in range(b[1],min(b[3],b[1]+max(3,round(h/20)))) for x in range(im.width) if im.getpixel((x,y))[3] and (char!='wolf' or x>=b[0]+(b[2]-b[0])*0.55)]
        xs=[x for x,y in pts];return sum(xs)/len(xs) if xs else (b[0]+b[2]-1)/2
    frames=[];offsets=[];failure=[]
    for c in roots:
        b=c['bbox'];z=Image.new('RGBA',(b[2]-b[0],b[3]-b[1]));rp=raw.load();zp=z.load()
        for k in c['pixels']:
            y,x=divmod(k,raw.width);zp[x-b[0],y-b[1]]=(*rp[x,y][:3],255)
        z=z.resize((round(z.width*scale),round(z.height*scale)),Image.Resampling.NEAREST);q=z.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(z.getchannel('A'))
        x=(w-q.width)//2 if fit=='fit' else round(head_anchor(ref)-head_anchor(q));y=baseline+1-q.height
        f=Image.new('RGBA',(w,h));f.alpha_composite(q,(x,y));frames.append(f);offsets.append([x,y]);failure.append(x<2 or x+q.width>w-2 or y<2 or baseline>h-3)
    out=Image.new('RGBA',(w*count,h))
    for i,f in enumerate(frames):out.paste(f,(i*w,0))
    path=f'candidates/{ident}_{outver}.png';out.save(r/path)
    j={'id':ident,'character':char,'candidate':path,'version':outver,'source':f'originals/{ident}_{ver}_raw.png','tool':'built-in image_gen; Pillow format normalization','generation_record':f'records/generation_{ident}_{ver}.json','status':'candidate_pending_visual_motion_review','frames':count,'frame_size':[w,h],'size':list(out.size),'fps':8,'loop':True,'baseline':baseline,'colors':len({p[:3] for p in out.get_flattened_data() if p[3]}),'alpha_values':sorted(set(out.getchannel('A').get_flattened_data())),'bboxes':[f.getbbox() for f in frames],'normalization_scale':scale,'raw_component_bboxes':[c['bbox'] for c in roots],'offsets':offsets,'margin_or_clipping_failure':failure,'reference_palette':f'records/{char}_reference_palette.json','sha256':hashlib.sha256((r/path).read_bytes()).hexdigest()}
    j['normalization_fit']=fit
    items=[x for x in items if x['candidate']!=path]+[j];print(json.dumps(j,ensure_ascii=False))
(r/'records/candidates.json').write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n')
