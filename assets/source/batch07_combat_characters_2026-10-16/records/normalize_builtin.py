from pathlib import Path
from PIL import Image
from collections import Counter
import ast, json, hashlib, sys

r=Path(__file__).resolve().parents[1]
t=ast.parse((r/'records/extract_enemy_candidates.py').read_text())
fn=next(n for n in t.body if isinstance(n,ast.FunctionDef) and n.name=='components')
scope={}
exec(compile(ast.Module(body=[fn],type_ignores=[]),'components','exec'),scope)
items=json.loads((r/'records/candidates.json').read_text())
for arg in sys.argv[1:]:
    ident,ver=arg.split(':')
    raw=Image.open(r/'originals'/f'{ident}_attack_{ver}_raw.png').convert('RGBA')
    cs=scope['components'](raw)
    roots=sorted(cs[:4],key=lambda c:((c['bbox'][1]+c['bbox'][3])/2>=raw.height/2,(c['bbox'][0]+c['bbox'][2])/2))
    assert len(roots)==4
    for extra in cs[4:]:
        if extra['count']<300:continue
        ex=(extra['bbox'][0]+extra['bbox'][2])/2;ey=(extra['bbox'][1]+extra['bbox'][3])/2
        root=min(roots,key=lambda c:((c['bbox'][0]+c['bbox'][2])/2-ex)**2+((c['bbox'][1]+c['bbox'][3])/2-ey)**2)
        root['pixels']+=extra['pixels'];root['bbox']=[min(root['bbox'][0],extra['bbox'][0]),min(root['bbox'][1],extra['bbox'][1]),max(root['bbox'][2],extra['bbox'][2]),max(root['bbox'][3],extra['bbox'][3])]
    ref=Image.open(r/'references'/f'{ident}.png').convert('RGBA');n=ref.height;rb=ref.getbbox()
    counts=Counter(p[:3] for p in ref.get_flattened_data() if p[3])
    colors=sorted(c for c,count in counts.most_common(48))
    (r/'records'/f'{ident}_attack_palette48.json').write_text(json.dumps(colors)+'\n')
    pal=Image.new('P',(1,1));pal.putpalette([v for c in colors for v in c]+list(colors[0])*(256-len(colors)))
    scale=min((n-4)/max(c['bbox'][2]-c['bbox'][0] for c in roots),(rb[3]-rb[1])/max(c['bbox'][3]-c['bbox'][1] for c in roots))
    out=Image.new('RGBA',(n*4,n));frames=[];offsets=[];clipped=[]
    def top_anchor(im):
        b=im.getbbox();xs=[x for y in range(b[1],min(b[3],b[1]+max(3,round((b[3]-b[1])*.12)))) for x in range(im.width) if im.getpixel((x,y))[3]]
        return sum(xs)/len(xs)
    for i,c in enumerate(roots):
        b=c['bbox'];crop=Image.new('RGBA',(b[2]-b[0],b[3]-b[1]));rp=raw.load();cp=crop.load()
        for k in c['pixels']:
            y,x=divmod(k,raw.width);cp[x-b[0],y-b[1]]=(*rp[x,y][:3],255)
        crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.NEAREST)
        q=crop.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(crop.getchannel('A'))
        x=round(top_anchor(ref)-top_anchor(q)) if 'ice_spirit' in ident else (n-q.width)//2
        y=rb[3]-q.height
        f=Image.new('RGBA',(n,n));f.alpha_composite(q,(x,y));out.alpha_composite(f,(i*n,0));frames.append(f);offsets.append([x,y]);clipped.append(x<2 or x+q.width>n-2 or y<2)
    name=f'candidates/{ident}_attack_{ver}.png';out.save(r/name)
    j={'id':ident+'_attack','candidate':name,'version':ver,'status':'candidate_pending_visual_motion_review','tool':'built-in image_gen; Pillow format normalization','source':f'originals/{ident}_attack_{ver}_raw.png','generation_record':'records/builtin_generation_jobs.json','generation_url':None,'frames':4,'size':list(out.size),'frame_size':[n,n],'fps':16,'baseline':rb[3]-1,'colors':len({p[:3] for p in out.get_flattened_data() if p[3]}),'palette_colors':len(colors),'alpha_values':sorted(set(out.getchannel('A').get_flattened_data())),'bboxes':[f.getbbox() for f in frames],'raw_component_bboxes':[c['bbox'] for c in roots],'normalization_scale':scale,'offsets':offsets,'margin_or_clipping_failure':clipped,'sha256':hashlib.sha256((r/name).read_bytes()).hexdigest()}
    items=[j0 for j0 in items if j0['candidate']!=name]+[j]
    print(json.dumps(j,ensure_ascii=False))
(r/'records/candidates.json').write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n')
