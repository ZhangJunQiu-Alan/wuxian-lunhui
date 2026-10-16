from pathlib import Path
from PIL import Image,ImageFilter,ImageDraw
import json
R=Path(__file__).resolve().parents[1];inv=json.loads((R/'records/asset_inventory.json').read_text());rec=[]
boxes={
'midgard_props_a':[(110,10,480,525),(590,20,1005,535),(1140,280,1410,510),(80,600,455,975),(545,570,1050,995),(1140,570,1420,990)],
'midgard_props_b':[(80,80,345,430),(410,140,900,425),(900,80,1385,445),(1405,215,1765,435),(10,490,660,835),(680,625,1005,800),(1040,630,1400,800)],
'helheim_props':[(30,130,485,455),(575,40,975,465),(1145,0,1495,510),(10,510,490,1020),(525,570,1020,930)],
'vigrid_props':[(95,10,455,465),(540,100,920,455),(950,30,1520,480),(20,485,565,1010),(570,525,1120,1005)]}
for raw_id,bbxs in boxes.items():
 level=raw_id.split('_')[0];assets=[a for a in inv if a['level']==level and a['type']=='props'];offset=6 if raw_id=='midgard_props_b' else 0
 src=R/f'originals/{raw_id}_v01_raw.png';raw=Image.open(src).convert('RGBA')
 for i,box in enumerate(bbxs):
  a=assets[i+offset];cut=raw.crop(box);mask=Image.new('L',cut.size);mp=mask.load();cp=cut.load()
  for y in range(cut.height):
   for x in range(cut.width):
    r,g,b,_=cp[x,y];mp[x,y]=255 if r>140 and b>140 and r-g>75 and b-g>75 else 0
  near=mask.filter(ImageFilter.MaxFilter(9));np=near.load()
  for y in range(cut.height):
   for x in range(cut.width):
    r,g,b,_=cp[x,y]
    if mp[x,y] or (r-g>10 and b-g>10 and min(r,b)>g*1.2 and (np[x,y] or level!='vigrid')):cp[x,y]=(0,0,0,0)
  bb=cut.getbbox();cut=cut.crop(bb);tw,th=a['width'],a['height'];s=min((tw-4)/cut.width,(th-4)/cut.height);nw,nh=round(cut.width*s),round(cut.height*s);small=cut.resize((nw,nh),Image.Resampling.NEAREST)
  out=Image.new('RGBA',(tw,th));out.alpha_composite(small,((tw-nw)//2,th-2-nh));out.save(R/f"candidates/{level}_{a['id']}_v02.png")
  rec.append(dict(level=level,id=a['id'],source=str(src.relative_to(R)),crop=box,bbox=list(bb),processing='full object crop reviewed against raw; magenta matte removal plus 9px neighborhood despill; nearest target preserving aspect; 2px bottom margin',status='candidate_pending_visual_review'))
for level in ['midgard','helheim','vigrid']:
 items=[a for a in inv if a['level']==level and a['type']=='props']
 for page in range((len(items)+5)//6):
  sheet=Image.new('RGBA',(1560,1040),'#121721');d=ImageDraw.Draw(sheet)
  for i,a in enumerate(items[page*6:page*6+6]):
   im=Image.open(R/f"candidates/{level}_{a['id']}_v02.png");x=i%3*520;y=i//3*520;d.text((x+5,y+5),a['id'],fill='white');sheet.alpha_composite(im,(x+5,y+28));sheet.alpha_composite(im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST),(x+5,y+130))
  sheet.convert('RGB').save(R/f'previews/{level}_props_v02_review_{page+1}.png')
(R/'records/props_processing_v02.json').write_text(json.dumps(rec,indent=2));print('23 props v02 pending review')
