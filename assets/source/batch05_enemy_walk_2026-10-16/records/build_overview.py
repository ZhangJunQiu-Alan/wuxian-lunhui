from pathlib import Path
from PIL import Image,ImageDraw
import json
r=Path(__file__).resolve().parents[1]
m=json.loads((r/'manifest.json').read_text());assert m['approved_assets']==7
canvas=Image.new('RGBA',(1200,800),'#121721');d=ImageDraw.Draw(canvas);d.text((20,12),'BATCH05 - STAGE01 - 7 move animations - art check complete / game review pending',fill='#e0e7ef')
order=['draugr_move','draugr_elite_move','wolf_move','ice_spirit_move','ice_spirit_elite_move','frost_giant_move','frost_giant_elite_move']
for i,k in enumerate(order):
    a=next(a for a in m['assets'] if a['id']==k);w,h=a['frame_size'];im=Image.open(r/a['candidate']).convert('RGBA');index=2 if a['frames']==4 else 3;f=im.crop((index*w,0,(index+1)*w,h));x=(i%4)*300+10;y=(i//4)*380+55
    d.text((x,y),k,fill='#e0e7ef');d.text((x,y+18),str(w)+'x'+str(h)+' / '+str(a['frames'])+' frames / 8fps',fill='#a4b9c8')
    ref=Image.open(r/'references'/f'{a["character"]}.png').convert('RGBA');canvas.alpha_composite(ref,(x,y+42));canvas.alpha_composite(f,(x+110,y+42));d.text((x,y+146),'reference   /   move frame',fill='#a4b9c8')
    big=f.resize((w*2,h*2),Image.Resampling.NEAREST);canvas.alpha_composite(big,(x,y+170))
canvas.convert('RGB').save(r/'previews/handoff_overview.png')
print('overview saved')
