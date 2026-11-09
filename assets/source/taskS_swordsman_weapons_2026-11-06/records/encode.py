from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import sys,json,shutil,subprocess

B=Path(__file__).resolve().parents[1]
raw=Path(sys.argv[1])
stills=Path(sys.argv[2])
rows=json.loads((B/'godot_preview/runtime/timelines.json').read_text())

def encode(r, start):
    id=r['id']
    shutil.copyfile(stills/f'{id}.png',B/'previews'/f'{id}.png')
    if id=='katana':return
    target=B/'previews'/f'{id}.webm'
    temp=target.with_suffix('.partial.webm')
    args=['ffmpeg','-nostdin','-hide_banner','-loglevel','error','-n','-ss',str(start),'-i',str(raw),
        '-t',str(r['seconds']),'-vf','format=yuv420p','-c:v','libvpx-vp9','-threads','3','-deadline','good','-cpu-used','5',
        '-row-mt','1','-crf','23','-b:v','0','-c:a','libopus','-b:a','96k',str(temp)]
    subprocess.run(args,check=True)
    temp.replace(target)
    print(id,flush=True)
with ThreadPoolExecutor(max_workers=2) as pool:
    start=0
    jobs=[]
    for r in rows:
        jobs.append(pool.submit(encode,r,start))
        start+=r['seconds']
    for j in jobs:j.result()
