from PIL import Image,ImageDraw
from pathlib import Path
import json,hashlib
R=Path(__file__).resolve().parents[1];checks=json.loads((R/'records/staged_v03_checks.json').read_text());assets=[a for a in checks if a['level']=='vigrid'];palette=[]
for ty,n in [('ground',16),('props',24)]:
 pixels=[]
 for a in assets:
  if a['type']!=ty:continue
  im=Image.open(R/(a['candidate'] if ty=='ground' else f"candidates/vigrid_{a['id']}_v02.png"));pixels.extend(p[:3] for p in im.get_flattened_data() if p[3])
 train=Image.new('RGB',(len(pixels),1));train.putdata(pixels);pal=train.quantize(colors=n,dither=Image.Dither.NONE).getpalette();palette.extend(tuple(pal[i:i+3]) for i in range(0,n*3,3))
palette.extend([(237,175,78),(213,105,38),(130,44,28),(100,142,143),(115,127,156),(152,117,155),(181,135,149),(180,164,105)])
pim=Image.new('P',(1,1));flat=[v for c in palette for v in c];pim.putpalette(flat+flat[:3]*(256-48));(R/'records/vigrid_palette48_v04.json').write_text(json.dumps(palette,indent=2))
for a in assets:
 src=R/(a['candidate'] if a['type']=='ground' else f"candidates/vigrid_{a['id']}_v02.png");im=Image.open(src).convert('RGBA');alpha=im.getchannel('A');out=im.convert('RGB').quantize(palette=pim,dither=Image.Dither.NONE).convert('RGBA');out.putalpha(alpha);out.putdata([p if p[3] else (0,0,0,0) for p in out.get_flattened_data()]);path=R/f"candidates/vigrid_{a['id']}_v04.png";out.save(path);a.update(candidate=str(path.relative_to(R)),palette='records/vigrid_palette48_v04.json',sha256=hashlib.sha256(path.read_bytes()).hexdigest(),color_count=len(set(p[:3] for p in out.get_flattened_data() if p[3])))
for ty in ['props','ground']:
 rows=[a for a in assets if a['type']==ty];sheet=Image.new('RGBA',(1560,1040),'#121721');d=ImageDraw.Draw(sheet)
 for i,a in enumerate(rows):
  im=Image.open(R/a['candidate']);x=i%3*520;y=i//3*520;d.text((x+5,y+5),a['id'],fill='white');sheet.alpha_composite(im,(x+5,y+28));sheet.alpha_composite(im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST),(x+5,y+130))
 sheet.convert('RGB').save(R/f'previews/vigrid_{ty}_v04_review.png')
(R/'records/staged_final_checks.json').write_text(json.dumps(checks,indent=2));print('Vigrid palette v04 staged; other 32 assets unchanged')
