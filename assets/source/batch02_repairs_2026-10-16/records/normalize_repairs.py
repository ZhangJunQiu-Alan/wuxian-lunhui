import json
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]
items=json.loads((root/'records/repair_inventory.json').read_text())
images={};methods={}
for it in items:
 if it['id']=='surtr':continue
 name=it['id'];size=it['target_size'][0];p=root/f'candidates/{name}_piskel_92_v01.png'
 if size==96 and p.exists() and p.stat().st_size>0:
  im=Image.open(p).convert('RGBA');assert im.size==(92,92);methods[name]='Chrome Piskel nearest resize export'
 else:
  im=Image.open(root/it['source']).convert('RGBA').resize((size-4,size-4),Image.Resampling.NEAREST);methods[name]='Pillow deterministic nearest resize from archived high-resolution source'
 im.putalpha(im.getchannel('A').point(lambda v:255 if v>=128 else 0));images[name]=im
families={'frost':['frost_giant','frost_giant_elite','frost_veteran','hrym'],'fire':['fire_giant'],'fenrir':['fenrir']};palettes={}
for family,names in families.items():
 colors=[p[:3]for name in names for p in images[name].getdata()if p[3]];samples=Image.new('RGB',(len(colors),1));samples.putdata(colors);palette=samples.quantize(colors=48,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE);palettes[family]=palette
 (root/f'records/{family}_palette_v01.json').write_text(json.dumps([palette.getpalette()[i:i+3]for i in range(0,144,3)]))
report=[];contact=Image.new('RGB',(1536,1160),'#121721');draw=ImageDraw.Draw(contact)
for n,it in enumerate(items):
 name=it['id']
 if name not in images:continue
 family=next(k for k,ns in families.items()if name in ns);im=images[name];rgb=im.convert('RGB').quantize(palette=palettes[family],dither=Image.Dither.NONE).convert('RGBA');rgb.putalpha(im.getchannel('A'));box=rgb.getbbox();crop=rgb.crop(box);size=it['target_size'][0];out=Image.new('RGBA',(size,size));out.alpha_composite(crop,((size-crop.width)//2,size-2-crop.height));out.save(root/f'candidates/{name}_v01.png');box=out.getbbox();entry={'id':name,'candidate':f'candidates/{name}_v01.png','size':list(out.size),'colors':len(set(p[:3]for p in out.getdata()if p[3])),'alpha':sorted(set(out.getchannel('A').getdata())),'bbox_exclusive':box,'baseline':box[3]-1,'min_margin':min(box[0],box[1],size-box[2],size-box[3]),'method':methods[name],'palette':f'records/{family}_palette_v01.json'};report.append(entry)
 preview=Image.new('RGBA',out.size,'#121721');preview.alpha_composite(out);preview.resize((size*4,size*4),Image.Resampling.NEAREST).convert('RGB').save(root/f'previews/{name}_4x_v01.png');x=(n%4)*384;y=(n//4)*512;draw.text((x+8,y+8),f'{name}: {size}x{size}, {entry["colors"]} colors',fill='white');scale=2 if size==192 else 3;z=out.resize((size*scale,size*scale),Image.Resampling.NEAREST);contact.paste(z,(x,y+34),z);contact.paste(out,(x+8,y+424),out)
(root/'records/repair_metadata_v01.json').write_text(json.dumps(report,indent=2));contact.save(root/'previews/repair_contact_v01.png');print(json.dumps(report,indent=2))
