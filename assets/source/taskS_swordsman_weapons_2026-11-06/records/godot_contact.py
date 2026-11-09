from math import ceil
import json
from pathlib import Path
import sys

from PIL import Image, ImageDraw
from catalog import B

P=B/'previews'
frames_dir=Path(sys.argv[1])
starts={}
start=0
for row in json.loads((B/'godot_preview/runtime/timelines.json').read_text()):
    starts[row['id']]=start
    start+=row['seconds']*24
out=P/'carry_2026-11-09/godot_handoffs.png'
# seconds, frame crop x, observed cue
cases = {
    'excalibur': [(0.79,412,'sheath entry'),(.89,412,'blade feeding'),(1.02,412,'seated'),
                  (5.19,412,'full charge'),(5.76,412,'release'),(5.94,535,'dash')],
    'chunyang': [(.60,412,'belt'),(.72,412,'grasp'),(.87,412,'lift'),
                  (1.0,412,'sip'),(1.17,412,'lower'),(1.31,412,'belt again')],
    'ganjiang_moye': [(.78,412,'both hands'),(.88,412,'wind-up'),(1.17,412,'flight'),
                      (2.15,412,'point planted'),(4.18,412,'return flight'),(4.72,412,'off-hand catch')],
    'riyue': [(.66,412,'moon main'),(.94,412,'sun main'),(1.64,412,'sun wheel'),
              (2.85,412,'sun ready'),(3.08,412,'moon main'),(4.52,515,'moon recovery')],
}
width,height=272,96
plate=Image.new('RGB',(width*3,30+len(cases)*(height*2+28)),'#202b37')
draw=ImageDraw.Draw(plate)
draw.text((8,7),'GODOT 1x   /   S-SW CARRY AND SKILL HANDOFFS',fill='#c5dedb')
for row,(id,frames) in enumerate(cases.items()):
    y=30+row*(height*2+28)
    draw.text((8,y+4),id.upper(),fill='#c5dedb')
    for i,(time,x,label) in enumerate(frames):
        number=starts[id]+ceil(time*24)
        pic=Image.open(frames_dir/f'{number:05d}.png').convert('RGB').crop((x,322,x+width,398))
        left,top=(i%3)*width,y+24+(i//3)*height
        plate.paste(pic,(left,top))
        draw.text((left+4,top+77),f'{time:.2f}  {label}',fill='#e1e9ef')
plate.save(out)
path=B/'records/carry-visual.json'
data=json.loads(path.read_text())
data['godot']=str(out.relative_to(B))
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
