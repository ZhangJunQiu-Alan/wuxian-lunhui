from pathlib import Path
from PIL import Image,ImageFilter,ImageDraw
import json,hashlib
R=Path(__file__).resolve().parents[1];rows=json.loads((R/'records/staged_final_checks.json').read_text());raw=Image.open(R/'originals/pine_weapons_v02_raw.png').convert('RGBA');rec={}
for level,name,box in [('midgard','dead_pine_02',(170,35,835,865)),('vigrid','broken_weapons',(1040,235,1625,855))]:
 a=next(a for a in rows if a['level']==level and a['id']==name);cut=raw.crop(box);mask=Image.new('L',cut.size);cp=cut.load();mp=mask.load()
 for y in range(cut.height):
  for x in range(cut.width):
   r,g,b,_=cp[x,y];mp[x,y]=255 if r>140 and b>140 and r-g>75 and b-g>75 else 0
 near=mask.filter(ImageFilter.MaxFilter(9));np=near.load()
 for y in range(cut.height):
  for x in range(cut.width):
   r,g,b,_=cp[x,y]
   if mp[x,y] or (r-g>10 and b-g>10 and min(r,b)>g*1.2 and np[x,y]):cp[x,y]=(0,0,0,0)
   elif level=='vigrid' and b-r>8 and g-r>3 and (r+g+b)/3>110:
    # Remove the inherited winter-blue color from non-metal powder deposits; remap into ash values.
    # Blade remains readable from its outline, fuller, and neutral metal facets.
    v=round((r+g+b)/3*.5);cp[x,y]=(v,round(v*.94),round(v*.87),255)
 bb=cut.getbbox();cut=cut.crop(bb);w,h=a['width'],a['height'];s=min((w-4)/cut.width,(h-4)/cut.height);nw,nh=round(cut.width*s),round(cut.height*s);out=Image.new('RGBA',(w,h));out.alpha_composite(cut.resize((nw,nh),Image.Resampling.NEAREST),((w-nw)//2,h-2-nh));alpha=out.getchannel('A');pal=json.loads((R/a['palette']).read_text());pim=Image.new('P',(1,1));flat=[v for c in pal for v in c];pim.putpalette(flat+flat[:3]*(256-len(pal)));out=out.convert('RGB').quantize(palette=pim,dither=Image.Dither.NONE).convert('RGBA');out.putalpha(alpha);out.putdata([p if p[3] else (0,0,0,0) for p in out.get_flattened_data()]);p=R/f'candidates/{level}_{name}_v05.png';out.save(p);bb=out.getbbox();a.update(candidate=str(p.relative_to(R)),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),color_count=len(set(p[:3] for p in out.get_flattened_data() if p[3])),bbox=list(bb));a['checks']['transparent_margin_2px']=bb[0]>=2 and bb[1]>=2 and bb[2]<=w-2 and bb[3]<=h-2
 rec[level+'/'+name]={'source':'originals/pine_weapons_v02_raw.png','crop':list(box),'processing':'magenta matte removal/despill; nearest sizing; existing fixed palette; vigrid inherited blue-white powder remapped to charcoal ash tones'}
sheet=Image.new('RGBA',(1040,520),'#121721');d=ImageDraw.Draw(sheet)
for i,key in enumerate(rec):
 level,name=key.split('/');a=next(a for a in rows if a['level']==level and a['id']==name);im=Image.open(R/a['candidate']);x=i*520;d.text((x+8,8),key,fill='white');sheet.alpha_composite(im,(x+8,30));sheet.alpha_composite(im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST),(x+8,135))
sheet.convert('RGB').save(R/'previews/last_props_v05_review.png');(R/'records/last_props_processing.json').write_text(json.dumps(rec,indent=2));(R/'records/staged_final_checks.json').write_text(json.dumps(rows,indent=2));print('Staged last two props, pending visual review')
