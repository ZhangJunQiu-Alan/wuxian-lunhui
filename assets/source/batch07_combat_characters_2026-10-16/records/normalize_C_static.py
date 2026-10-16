from pathlib import Path
from PIL import Image
import json,hashlib
r=Path(__file__).resolve().parents[1]
items=json.loads((r/'records/candidates.json').read_text())
for ident in ['gunslinger','assassin','mage']:
    raw=Image.open(r/'originals'/f'{ident}_v01_raw.png').convert('RGBA')
    raw.putalpha(raw.getchannel('A').point(lambda v:255 if v>=128 else 0))
    b=raw.getbbox();crop=raw.crop(b);scale=48/crop.height
    crop=crop.resize((round(crop.width*scale),48),Image.Resampling.NEAREST)
    opaque=[p[:3] for p in crop.get_flattened_data() if p[3]]
    sample=Image.new('RGB',(len(opaque),1));sample.putdata(opaque)
    q=sample.quantize(colors=48,dither=Image.Dither.NONE)
    colors=sorted(set(q.convert('RGB').get_flattened_data()))
    palette=Image.new('P',(1,1));palette.putpalette([v for c in colors for v in c]+list(colors[0])*(256-len(colors)))
    out=crop.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA');out.putalpha(crop.getchannel('A'))
    f=Image.new('RGBA',(64,64));f.paste(out,((64-out.width)//2,12))
    p=f'candidates/{ident}_v01.png';f.save(r/p);f.save(r/'references'/f'{ident}.png');f.resize((512,512),Image.Resampling.NEAREST).save(r/'references'/f'{ident}_8x.png')
    (r/'records'/f'{ident}_palette.json').write_text(json.dumps(colors)+'\n')
    j={'id':ident,'candidate':p,'version':'v01','status':'candidate_pending_visual_review','source':f'originals/{ident}_v01_raw.png','tool':'built-in image_gen; Pillow format normalization','generation_record':'records/builtin_C_static_jobs.json','frames':1,'frame_size':[64,64],'size':[64,64],'fps':None,'baseline':59,'bboxes':[f.getbbox()],'colors':len({p[:3] for p in f.get_flattened_data() if p[3]}),'reference_palette':f'records/{ident}_palette.json','alpha_values':sorted(set(f.getchannel('A').get_flattened_data())),'sha256':hashlib.sha256((r/p).read_bytes()).hexdigest()}
    items=[x for x in items if x['candidate']!=p]+[j];print(ident,j['bboxes'],j['colors'])
(r/'records/candidates.json').write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n')
