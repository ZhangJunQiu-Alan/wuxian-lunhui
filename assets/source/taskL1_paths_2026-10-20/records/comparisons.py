from pathlib import Path
from PIL import Image, ImageDraw
import json

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'assets/source/taskL1_paths_2026-10-20'
jobs = json.loads((BASE/'records/plan_all_L.json').read_text())

def sheet(paths, labels, cols, out):
    image = Image.new('RGB', (260*cols, 465*((len(paths)+cols-1)//cols)), '#121721')
    draw = ImageDraw.Draw(image)
    for i, (path, label) in enumerate(zip(paths, labels)):
        x, y = i%cols*260, i//cols*465
        draw.text((x+4,y+4), label, fill='white')
        if path.exists():
            with Image.open(path) as im:
                image.paste(im.convert('RGB').resize((260,433),Image.Resampling.LANCZOS),(x,y+24))
        else:
            draw.text((x+15,y+100),'PENDING',fill='orange')
    image.save(out)

for god in ['thor','odin','loki','freyja','baldr','ran','freyr','skadi']:
    ids=[j['id'] for j in jobs if j.get('god')==god and j['variant']=='path']
    names=[god]+ids+[god+'_awaken']+[id+'_awaken' for id in ids]
    sheet([ROOT/'assets/sprites/cards'/f'{id}.png' for id in names],names,4,BASE/'previews'/f'comparison_{god}.png')
for j in [j for j in jobs if j['task']=='L2']:
    root=ROOT/j['root'];a=root/'records'/f'approved_{j["id"]}.json'
    if not a.exists():continue
    approved=json.loads(a.read_text());v=approved['selected_version'];id=j['id']
    paths=[ROOT/ref for ref in j['references']]+[ROOT/j['target'],root/'previews'/f'{id}_{v}_masked.png']
    sheet(paths,j['gods']+[id,'bottom45 mask'],4,root/'previews'/f'comparison_{id}.png')
print('comparison sheets refreshed')
