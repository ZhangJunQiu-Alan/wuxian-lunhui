from pathlib import Path
from PIL import Image
import ast,json,hashlib,sys
r=Path(__file__).resolve().parents[1]
t=ast.parse((r/'records/extract_enemy_candidates.py').read_text());fn=next(n for n in t.body if isinstance(n,ast.FunctionDef) and n.name=='components');scope={};exec(compile(ast.Module(body=[fn],type_ignores=[]),'components','exec'),scope)
items=json.loads((r/'records/candidates.json').read_text())
for arg in sys.argv[1:]:
    parts=arg.split(':');ident,ver=parts[:2];outver=parts[2] if len(parts)>2 else ver;method=parts[3] if len(parts)>3 else 'nearest';anchor=parts[4] if len(parts)>4 else 'head';char,action=ident.split('_',1)
    count={'idle':4,'move':6,'hurt':2,'death':6,'attack':6 if char=='assassin' else 4}[action]
    raw=Image.open(r/'originals'/f'{ident}_{ver}_raw.png').convert('RGBA');cs=scope['components'](raw)
    roots=cs[:count];assert len(roots)==count
    roots=sorted(roots,key=lambda c:((c['bbox'][1]+c['bbox'][3])/2>=raw.height/2 if count>=4 else False,(c['bbox'][0]+c['bbox'][2])/2))
    for c in cs[count:]:
        if c['count']<200:continue
        cx=(c['bbox'][0]+c['bbox'][2])/2;cy=(c['bbox'][1]+c['bbox'][3])/2
        z=min(roots,key=lambda z:((z['bbox'][0]+z['bbox'][2])/2-cx)**2+((z['bbox'][1]+z['bbox'][3])/2-cy)**2)
        z['pixels']+=c['pixels'];z['bbox']=[min(z['bbox'][0],c['bbox'][0]),min(z['bbox'][1],c['bbox'][1]),max(z['bbox'][2],c['bbox'][2]),max(z['bbox'][3],c['bbox'][3])]
    ref=Image.open(r/'references'/f'{char}.png').convert('RGBA');colors=json.loads((r/'records'/f'{char}_palette.json').read_text());pal=Image.new('P',(1,1));pal.putpalette([v for c in colors for v in c]+colors[0]*(256-len(colors)))
    hs=[c['bbox'][3]-c['bbox'][1] for c in roots]
    scale=48/(hs[-1] if action=='attack' else hs[0] if action=='death' else max(hs))
    def head_anchor(im):
        b=im.getbbox()
        if char=='mage':
            pts=[(x,y) for y in range(b[1],min(b[3],b[1]+22)) for x in range(im.width) if (p:=im.getpixel((x,y)))[3] and p[2]>p[0]+4 and p[2]>p[1]+1]
            if pts:
                top=min(y for x,y in pts);xs=[x for x,y in pts if y<top+5];return sum(xs)/len(xs)
        xs=[x for y in range(b[1],min(b[3],b[1]+5)) for x in range(im.width) if im.getpixel((x,y))[3]]
        return sum(xs)/len(xs)
    def foot_anchor(im):
        b=im.getbbox();xs=[x for y in range(max(b[1],b[3]-4),b[3]) for x in range(im.width) if im.getpixel((x,y))[3]]
        return (min(xs)+max(xs))/2
    frames=[];offsets=[];failure=[]
    for c in roots:
        b=c['bbox'];z=Image.new('RGBA',(b[2]-b[0],b[3]-b[1]));rp=raw.load();zp=z.load()
        for k in c['pixels']:
            y,x=divmod(k,raw.width);zp[x-b[0],y-b[1]]=(*rp[x,y][:3],255)
        z=z.resize((round(z.width*scale),round(z.height*scale)),Image.Resampling.BOX if method=='box' else Image.Resampling.NEAREST);z.putalpha(z.getchannel('A').point(lambda v:255 if v>=128 else 0));q=z.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(z.getchannel('A'))
        locate=foot_anchor if anchor=='feet' else head_anchor
        x=(64-q.width)//2 if action=='death' else round(locate(ref)-locate(q));y=60-q.height
        f=Image.new('RGBA',(64,64));f.alpha_composite(q,(x,y));frames.append(f);offsets.append([x,y]);failure.append(x<2 or x+q.width>62 or y<2)
    out=Image.new('RGBA',(64*count,64))
    for i,f in enumerate(frames):out.paste(f,(i*64,0))
    path=f'candidates/{ident}_{outver}.png';out.save(r/path)
    j={'id':ident,'candidate':path,'version':ver,'source':f'originals/{ident}_{ver}_raw.png','tool':'built-in image_gen; Pillow format normalization','generation_record':'records/builtin_C_animation_jobs.json','status':'candidate_pending_visual_motion_review','frames':count,'frame_size':[64,64],'size':list(out.size),'fps':16 if action=='attack' else 8,'loop':action in ['idle','move'],'baseline':59,'colors':len({p[:3] for p in out.get_flattened_data() if p[3]}),'alpha_values':sorted(set(out.getchannel('A').get_flattened_data())),'bboxes':[f.getbbox() for f in frames],'normalization_scale':scale,'raw_component_bboxes':[c['bbox'] for c in roots],'offsets':offsets,'margin_or_clipping_failure':failure,'reference_palette':f'records/{char}_palette.json','sha256':hashlib.sha256((r/path).read_bytes()).hexdigest()}
    j['version']=outver;j['downsample_method']=method;j['horizontal_anchor']=anchor
    items=[x for x in items if x['candidate']!=path]+[j];print(json.dumps(j,ensure_ascii=False))
(r/'records/candidates.json').write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n')
