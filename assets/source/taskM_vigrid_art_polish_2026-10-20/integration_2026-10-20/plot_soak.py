from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont

B=Path(__file__).parent
data=json.loads((B/'results/soak_final/soak.json').read_text())
im=Image.new('RGB',(1280,880),'#14191d');d=ImageDraw.Draw(im)
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',18)
small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',14)
title=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',25)
d.text((36,22),'M integration: 350-enemy soak and 12 hub returns',font=title,fill='#eef4f0')
d.text((36,58),'Apple M2 / Godot4.7.2 / real renderer / controlled invincible load / 4 x90s',font=font,fill='#b6c4cb')
palette=['#80d3c6','#efc36f','#94b7ef','#d9a2dd']
for panel,(field,label) in enumerate([('static_mb','Static memory (MiB)'),('nodes','Nodes'),('rss_mb','RSS (MiB)'),('resources','Resources')]):
    left=70+panel%2*630;top=140+panel//2*290;w=535;h=190
    values=[s[field] for st in data['stages'] for s in st['samples']]
    lo=min(values);hi=max(values);gap=max((hi-lo)*.1,1);lo-=gap;hi+=gap
    d.text((left,top-35),label,font=font,fill='#eef4f0')
    for j in range(5):
        y=top+h-j*h/4;v=lo+(hi-lo)*j/4
        d.line((left,y,left+w,y),fill='#384249');d.text((left-55,y-8),f'{v:.0f}',font=small,fill='#b6c4cb')
    for k,st in enumerate(data['stages']):
        points=[(left+(k*90+s['t'])/360*w,top+h-(s[field]-lo)/(hi-lo)*h) for s in st['samples']]
        if len(points)>1:d.line(points,fill=palette[k],width=3)
    for k,label2 in enumerate(['No boss','Serpent','Fenrir','Surtr']):
        x=left+k*w/4;d.text((x,top+h+10),label2,font=small,fill=palette[k])
hub=data['reentry'];ranges=[]
for field in ['nodes','resources','orphans','rss_mb']:
    vals=[x[field] for x in hub];ranges.append(f'{field}: {min(vals):.1f} - {max(vals):.1f}')
d.text((36,752),'After each real return to hub (12 rounds):',font=font,fill='#eef4f0')
d.text((36,788),'  /  '.join(ranges),font=font,fill='#b6c4cb')
residue=sum(x['enemies_left']+x['hazards_left']+x['fragments_left'] for x in hub)
d.text((36,824),f'Enemy / hazard / fragment residue total: {residue}. Cold-start peaks retained in source JSON.',font=font,fill='#80d3c6')
im.save(B/'results/soak_memory_trend.png')
