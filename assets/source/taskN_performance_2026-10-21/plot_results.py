from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json
p=Path(__file__).resolve().parent
fontfile='/System/Library/Fonts/Supplemental/Arial.ttf'
font=lambda size:ImageFont.truetype(fontfile,size)
im=Image.new('RGB',(1280,860),'#111a28');d=ImageDraw.Draw(im)
d.text((40,25),'Odin density test: limited gains, gate still FAILED',font=font(28),fill='#edf4ff')
d.text((40,68),'350 enemies, 1,000,000 HP each; one awakened god, 55 s/stage; Apple M2',font=font(18),fill='#aebcd0')
base=json.loads((p/'results/baseline_seeded/soak.json').read_text())
final=json.loads((p/'results/final_extreme/soak.json').read_text())
scale=3.2
for i,key in enumerate(['p95_ms','p99_ms']):
 y=130+i*225
 d.text((40,y),key+' (ms)',font=font(22),fill='#edf4ff')
 for j,(name,data,color) in enumerate([('baseline',base,'#b8a1f4'),('candidate',final,'#52c8b5')]):
  for k,s in enumerate(data['stages']):
   yy=y+45+j*76+k*30
   d.text((40,yy),name+' / '+s['boss'],font=font(16),fill='#ccd7e8')
   x=245; value=s[key]
   d.rectangle((x,yy,x+value*scale,yy+21),fill=color)
   d.text((max(x+value*scale+10,245+(33.3 if key=="p95_ms" else 50)*scale+12),yy-1),f'{value:.2f}',font=font(17),fill='#edf4ff')
 threshold=33.3 if key=='p95_ms' else 50
 x=245+threshold*scale
 d.line((x,y+37,x,y+178),fill='#f5b46b',width=2)
 d.text((x+6,y+180),f'working budget {threshold} ms',font=font(14),fill='#f5b46b')
d.text((40,610),'12 actual hub returns: nodes / resources / resident memory',font=font(22),fill='#edf4ff')
s=json.loads((p/'results/reachable/soak.json').read_text());rows=s['reentry']
d.text((40,651),f'Nodes: {sorted(set(int(x["nodes"]) for x in rows))}   Resources: {sorted(set(int(x["resources"]) for x in rows))}   Orphans: 0',font=font(20),fill='#52c8b5')
low,high=100,200
for i,row in enumerate(rows):
 x=50+i*95; y=795-(row['rss_mb']-low)/(high-low)*85
 d.rectangle((x,y,x+60,795),fill='#6b97dc')
 d.text((x,y-21),f'{row["rss_mb"]:.1f}',font=font(13),fill='#ccd7e8')
 d.text((x+18,805),str(i+1),font=font(14),fill='#ccd7e8')
d.text((40,833),'RSS in MiB; normal-HP cap-refill prototype. Stable cleanup does not prove frame-rate or release acceptance.',font=font(15),fill='#aebcd0')
im.save(p/'results/performance_trend.png')
print(p/'results/performance_trend.png')
