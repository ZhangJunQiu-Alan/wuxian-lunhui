from pathlib import Path
from PIL import Image, ImageDraw
import json,sys
import pipeline as p

ids=sys.argv[2:];out=Image.new('RGB',(260*len(ids),906),(18,23,33));draw=ImageDraw.Draw(out)
for i,id in enumerate(ids):
 j=p.job(id);d=p.ROOT/j['root'];g=json.loads(sorted((d/'records').glob(f'generation_{id}_v*.json'))[-1].read_text());v=g['version']
 out.paste(Image.open(d/'previews'/f'{id}_{v}_safe.png'),(i*260,20));out.paste(Image.open(d/'previews'/f'{id}_{v}_masked.png'),(i*260,473));draw.text((i*260+3,3),id+' '+v,fill='white')
 stats=json.loads((d/'records'/f'normalization_{id}_{v}.json').read_text())['bottom40_luminance'];draw.text((i*260+3,456),str(stats['mean'])+' mean bottom40',fill='white')
out.save(p.ROOT/'assets/source/taskL1_paths_2026-10-20/previews'/sys.argv[1])
