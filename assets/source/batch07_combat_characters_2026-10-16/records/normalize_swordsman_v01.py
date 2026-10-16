from pathlib import Path
from PIL import Image
import json,hashlib
r=Path(__file__).resolve().parents[1];im=Image.open(r/'originals/swordsman_attack_v01_raw.png').convert('RGBA');colors=json.loads((r.parent/'batch01_swordsman_2026-10-16/records/swordsman_batch_palette.json').read_text())['rgb'];pal=Image.new('P',(1,1));pal.putpalette([v for c in colors for v in c]+colors[0]*(256-len(colors)));fs=[];audit=[];scale=48/420
for i in range(6):
 f=im.crop((i%3*512,i//3*512,(i%3+1)*512,(i//3+1)*512));f.putalpha(f.getchannel('A').point(lambda a:255 if a>=128 else 0));b=f.getbbox();foot=f.getchannel('A').crop((0,b[3]-12,512,b[3])).getbbox();anchor=(foot[0]+foot[2])/2;z=f.crop(b).resize((round((b[2]-b[0])*scale),round((b[3]-b[1])*scale)),Image.Resampling.NEAREST);q=z.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(z.getchannel('A'));canvas=Image.new('RGBA',(72,64));x=round(32+(b[0]-anchor)*scale);y=60-q.height;canvas.alpha_composite(q,(x,y));fs.append(canvas);audit.append({'frame':i+1,'raw_bbox':b,'raw_foot_anchor_x':anchor,'x':x,'y':y,'bbox':canvas.getbbox()})
contact=Image.new('RGB',(72*6*4,64*4),'#121721')
for i,f in enumerate(fs):
 (r/'candidates').mkdir(exist_ok=True);f.save(r/f'candidates/swordsman_attack_frame{i+1:02}_wide_v01.png');bg=Image.new('RGBA',f.size,'#121721');bg.alpha_composite(f);contact.paste(bg.resize((288,256),Image.Resampling.NEAREST).convert('RGB'),(i*288,0))
contact.save(r/'previews/swordsman_attack_wide_v01_contact.png');(r/'records/swordsman_attack_wide_audit.json').write_text(json.dumps({'scale':scale,'frames':audit},indent=2));print(audit)
