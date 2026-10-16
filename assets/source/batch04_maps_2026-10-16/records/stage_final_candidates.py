from pathlib import Path
from PIL import Image,ImageFilter,ImageStat,ImageDraw
import json,hashlib,random,math
R=Path(__file__).resolve().parents[1]
exec((R/'records/refine_ground_v02.py').read_text().split('allrows=[]')[0])
inv=json.loads((R/'records/asset_inventory.json').read_text());propsrec=json.loads((R/'records/props_processing_v02.json').read_text());groundrec=json.loads((R/'records/candidate_processing_v01.json').read_text());staged={};recs=[]
for a in inv:
 level=a['level'];name=a['id'];key=f'{level}_{name}'
 if a['type']=='props':
  staged[key]=Image.open(R/f'candidates/{key}_v02.png').convert('RGBA');continue
 im=Image.open(R/f'candidates/{key}_v02.png').convert('RGB')
 if level=='midgard' and name.startswith('snow_') and name[-2:].isdigit():
  idx=int(name[-2:])-1;raw=Image.open(R/'originals/midgard_snow_v02_variant2_raw.png').convert('RGB');w,h=raw.size;box=(round(idx%2*w/2)+4,round(idx//2*h/2)+4,round((idx%2+1)*w/2)-4,round((idx//2+1)*h/2)-4);raw=raw.crop(box).resize((64,64),Image.Resampling.NEAREST);mean=ImageStat.Stat(raw).mean
  im=Image.new('RGB',(64,64));im.putdata([tuple(max(0,min(130,round((56,67,80)[c]+(v-mean[c])*.65))) for c,v in enumerate(p)) for p in raw.get_flattened_data()]);per=periodic(im);im.putdata([tuple(max(0,min(150,round(c))) for c in p) for row in per for p in row])
 if level=='vigrid' and name=='scorched_02':
  raw=Image.open(R/'originals/vigrid_ground_v01_raw.png').convert('RGB');w,h=raw.size;raw=raw.crop((round(2*w/4)+3,round(h/2)+3,round(3*w/4)-3,h-3)).resize((64,64),Image.Resampling.NEAREST);bl=raw.filter(ImageFilter.GaussianBlur(5));mean=ImageStat.Stat(raw).mean;im=Image.new('RGB',(64,64));im.putdata([tuple(max(0,min(150,round((40,34,34)[c]+(v-bv)*.42+(bv-mean[c])*.08))) for c,(v,bv) in enumerate(zip(p,b))) for p,b in zip(raw.get_flattened_data(),bl.get_flattened_data())]);per=periodic(im);im.putdata([tuple(max(0,min(150,round(c))) for c in p) for row in per for p in row])
 if name.startswith('nail_deck'):
  mean=ImageStat.Stat(im).mean;im=im.point(lambda v:v);im.putdata([tuple(max(0,round((44,43,40)[c]+(v-mean[c])*.65)) for c,v in enumerate(p)) for p in im.get_flattened_data()])
 staged[key]=im.convert('RGBA')
for level in ['midgard','helheim','vigrid']:
 palettes=[]
 for ty,n in [('ground',18),('props',30)]:
  pixels=[]
  for a in inv:
   if a['level']==level and a['type']==ty:
    pixels.extend(p[:3] for p in staged[f"{level}_{a['id']}"].get_flattened_data() if p[3])
  train=Image.new('RGB',(len(pixels),1));train.putdata(pixels);q=train.quantize(colors=n,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE);pal=q.getpalette();palettes.extend(tuple(pal[i:i+3]) for i in range(0,n*3,3))
 palettes=list(dict.fromkeys(palettes));palettes=palettes+[palettes[0]]*(48-len(palettes));palette=Image.new('P',(1,1));flat=[v for c in palettes for v in c];palette.putpalette(flat+flat[:3]*(256-48));(R/f'records/{level}_palette48.json').write_text(json.dumps(palettes,indent=2))
 for a in inv:
  if a['level']!=level:continue
  name=a['id'];key=f'{level}_{name}';im=staged[key];alpha=im.getchannel('A');rgb=im.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA');rgb.putalpha(alpha);data=list(rgb.get_flattened_data());data=[p if p[3] else (0,0,0,0) for p in data];rgb.putdata(data);path=R/f'candidates/{key}_v03.png';rgb.save(path)
  colors=len(set(p[:3] for p in data if p[3]));bb=rgb.getbbox();stats=ImageStat.Stat(rgb.convert('RGB'));rec=dict(a,candidate=str(path.relative_to(R)),color_count=colors,alpha_values=sorted(set(alpha.get_flattened_data())),bbox=list(bb),palette=f'records/{level}_palette48.json',status='candidate_pending_final_visual_review',sha256=hashlib.sha256(path.read_bytes()).hexdigest())
  rec['checks']={'exact_size':rgb.size==(a['width'],a['height']),'png_rgba':rgb.mode=='RGBA','binary_alpha':set(alpha.get_flattened_data())<={0,255},'palette_limit':colors<=48,'transparent_margin_2px': (bb[0]>=2 and bb[1]>=2 and bb[2]<=rgb.width-2 and bb[3]<=rgb.height-2) if a['type']=='props' else None}
  if a['type']=='ground':
   tile=Image.new('RGBA',(256,256))
   for y in range(4):
    for x in range(4):tile.paste(rgb,(64*x,64*y))
   tile.save(R/f'previews/{key}_v03_4x4.png');p=rgb.load();sx=sum(abs(p[0,y][c]-p[63,y][c]) for y in range(64) for c in range(3))/192;sy=sum(abs(p[x,0][c]-p[x,63][c]) for x in range(64) for c in range(3))/192;ix=sum(abs(p[x,y][c]-p[x-1,y][c]) for y in range(64) for x in range(1,64) for c in range(3))/(64*63*3);iy=sum(abs(p[x,y][c]-p[x,y-1][c]) for y in range(1,64) for x in range(64) for c in range(3))/(64*63*3);rec['seam_metrics']={'x':round(sx,3),'y':round(sy,3),'internal_x':round(ix,3),'internal_y':round(iy,3)};rec['mean_rgb']=[round(v,2) for v in stats.mean[:3]]
  recs.append(rec)
 for ty in ['ground','props']:
  assets=[a for a in inv if a['level']==level and a['type']==ty]
  for page in range((len(assets)+5)//6):
   sheet=Image.new('RGBA',(1560,1040),'#121721');d=ImageDraw.Draw(sheet)
   for i,a in enumerate(assets[page*6:page*6+6]):
    im=Image.open(R/f"candidates/{level}_{a['id']}_v03.png");x=i%3*520;y=i//3*520;d.text((x+5,y+5),a['id'],fill='white');sheet.alpha_composite(im,(x+5,y+28));sheet.alpha_composite(im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST),(x+5,y+130))
   sheet.convert('RGB').save(R/f'previews/{level}_{ty}_v03_review_{page+1}.png')
 # Random mixed basic terrain check.
 base=[a for a in inv if a['level']==level and a['type']=='ground'][:4];mix=Image.new('RGBA',(256,256));rng=random.Random(41)
 for y in range(4):
  for x in range(4):mix.paste(Image.open(R/f"candidates/{level}_{rng.choice(base)['id']}_v03.png"),(x*64,y*64))
 mix.save(R/f'previews/{level}_mixed_base_4x4.png')
mos=Image.new('RGB',(1024,1400),'#121721');d=ImageDraw.Draw(mos)
for i,a in enumerate([a for a in inv if a['type']=='ground']):
 x=i%4*256;y=i//4*280;mos.paste(Image.open(R/f"previews/{a['level']}_{a['id']}_v03_4x4.png"),(x,y+20));d.text((x+3,y+3),a['level']+'/'+a['id'],fill='white')
mos.save(R/'previews/ground_seam_review_v03.png');(R/'records/staged_v03_checks.json').write_text(json.dumps(recs,indent=2));print('Staged',len(recs),'48-color final candidates; pending final visual review');print('Technical failures:',[(a['level'],a['id'],k) for a in recs for k,v in a['checks'].items() if v is False])
