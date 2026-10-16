from pathlib import Path
import json
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]
raw={k:Image.open(root/f'originals/jormungandr_{k}_v01.png').convert('RGBA')for k in ['head','body','tail']}
head_small=raw['head'].resize((112,112),Image.Resampling.NEAREST);head=Image.new('RGBA',(128,128));head.alpha_composite(head_small,(8,-1))
body=raw['body'].crop((0,290,840,1130)).resize((64,64),Image.Resampling.NEAREST)
tail=raw['tail'].crop((-20,-24,1240,1236)).resize((64,64),Image.Resampling.NEAREST)
images={'head':head,'body':body,'tail':tail}
for im in images.values():im.putalpha(im.getchannel('A').point(lambda v:255 if v>=128 else 0))
colors=[p[:3]for im in images.values()for p in im.getdata()if p[3]];sample=Image.new('RGB',(len(colors),1));sample.putdata(colors);palette=sample.quantize(colors=48,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE);(root/'records/jormungandr_palette_v01.json').write_text(json.dumps([palette.getpalette()[i:i+3]for i in range(0,144,3)]))
contact=Image.new('RGB',(1024,560),'#121721');d=ImageDraw.Draw(contact)
for k,im in images.items():
 q=im.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(im.getchannel('A'));q.save(root/f'candidates/jormungandr_{k}_v01.png');x={'head':0,'body':520,'tail':780}[k];d.text((x+8,8),f'{k}: provisional ports not joined',fill='white');scale=4;z=q.resize((q.width*scale,q.height*scale),Image.Resampling.NEAREST);contact.paste(z,(x,32),z)
contact.save(root/'previews/jormungandr_ports_before_fix.png')
