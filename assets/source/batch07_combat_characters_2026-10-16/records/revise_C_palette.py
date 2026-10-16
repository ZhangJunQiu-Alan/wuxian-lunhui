from pathlib import Path
from PIL import Image
import json,hashlib
r=Path(__file__).resolve().parents[1]
p=r/'records/lanling_palette.json'
colors=json.loads(p.read_text())
if [160,157,154] not in colors:
    (r/'records/lanling_palette_v01_rejected.json').write_text(p.read_text())
    removed=[[8,4,6],[10,5,7],[11,6,8]]
    colors=[c for c in colors if c not in removed]+[[104,102,101],[160,157,154],[222,217,212]]
    p.write_text(json.dumps(colors)+'\n')
    (r/'records/lanling_palette_revision.json').write_text(json.dumps({'reason':'reserve steel shades omitted by small-area palette sampling','removed':removed,'added':colors[-3:]},indent=2)+'\n')
items=json.loads((r/'records/candidates.json').read_text())
for char in ['annie','lanling']:
    raw=Image.open(r/'originals'/f'{char}_v01_raw.png').convert('RGBA')
    raw.putalpha(raw.getchannel('A').point(lambda v:255 if v>=128 else 0))
    crop=raw.crop(raw.getbbox());crop=crop.resize((round(crop.width*48/crop.height),48),Image.Resampling.NEAREST)
    colors=json.loads((r/'records'/f'{char}_palette.json').read_text())
    pal=Image.new('P',(1,1));pal.putpalette([v for c in colors for v in c]+colors[0]*(256-len(colors)))
    q=crop.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(crop.getchannel('A'))
    out=Image.new('RGBA',(64,64));out.paste(q,((64-q.width)//2,12))
    path=f'candidates/{char}_v02.png';out.save(r/path)
    out.resize((512,512),Image.Resampling.NEAREST).save(r/'previews'/f'{char}_static_v02_8x.png')
    j=dict(next(x for x in items if x['candidate']==f'candidates/{char}_v01.png'))
    j.update(candidate=path,version='v02',status='candidate_pending_visual_review',colors=len({p[:3] for p in out.get_flattened_data() if p[3]}),sha256=hashlib.sha256((r/path).read_bytes()).hexdigest(),reference_palette=f'records/{char}_palette.json')
    items=[x for x in items if x['candidate']!=path]+[j]
(r/'records/candidates.json').write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n')
