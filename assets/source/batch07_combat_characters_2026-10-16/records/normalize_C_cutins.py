from pathlib import Path
from PIL import Image
import json,hashlib
r=Path(__file__).resolve().parents[1]
items=json.loads((r/'records/candidates.json').read_text())
for char in ['gunslinger','assassin','mage']:
    raw=Image.open(r/'originals'/f'{char}_cutin_v01_raw.png').convert('RGBA')
    raw.putalpha(raw.getchannel('A').point(lambda v:255 if v>=128 else 0))
    crop=raw.crop(raw.getbbox());scale=min(194/crop.width,154/crop.height)
    crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.NEAREST)
    colors=json.loads((r/'records'/f'{char}_palette.json').read_text());pal=Image.new('P',(1,1));pal.putpalette([v for c in colors for v in c]+colors[0]*(256-len(colors)))
    q=crop.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(crop.getchannel('A'))
    logical=Image.new('RGBA',(200,160));logical.paste(q,((200-q.width)//2,(160-q.height)//2));logical.save(r/'candidates'/f'{char}_cutin_v01_logical.png')
    out=logical.resize((400,320),Image.Resampling.NEAREST);path=f'candidates/{char}_cutin_v01.png';out.save(r/path)
    j={'id':char+'_cutin','candidate':path,'version':'v01','status':'candidate_pending_visual_review','source':f'originals/{char}_cutin_v01_raw.png','tool':'built-in image_gen; Pillow format normalization','generation_record':'records/builtin_C_cutin_walk_jobs.json','frames':1,'frame_size':[400,320],'size':[400,320],'logical_size':[200,160],'logical_candidate':f'candidates/{char}_cutin_v01_logical.png','fps':None,'baseline':None,'bboxes':[out.getbbox()],'colors':len({p[:3] for p in out.get_flattened_data() if p[3]}),'alpha_values':sorted(set(out.getchannel('A').get_flattened_data())),'reference_palette':f'records/{char}_palette.json','sha256':hashlib.sha256((r/path).read_bytes()).hexdigest()}
    items=[x for x in items if x['candidate']!=path]+[j];print(char,j['bboxes'],j['colors'])
(r/'records/candidates.json').write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n')
