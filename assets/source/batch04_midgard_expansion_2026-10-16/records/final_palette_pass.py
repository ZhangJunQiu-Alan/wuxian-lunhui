from pathlib import Path
from PIL import Image
import json,hashlib,re
R=Path(__file__).resolve().parents[1];A=R.parents[1];old={(38,20,25),(48,23,29),(57,27,33)};new=(48,23,29)
def recolor(im):
 im=im.convert('RGBA');im.putdata([(*new,p[3]) if p[:3] in old and p[3] else p for p in im.get_flattened_data()]);return im
m=json.loads((R/'manifest.json').read_text())
for a in m['assets']:
 if not a['id'].startswith('blood'):continue
 im=recolor(Image.open(R/a['candidate']));im.save(R/a['candidate']);a['colors']=1;a['sha256']=hashlib.sha256((R/a['candidate']).read_bytes()).hexdigest();a['processing']+='; final single muted dark-red hue for48-color environment union'
 for p in [R/a['approved_snapshot'],A/a['destination']]:p.write_bytes((R/a['candidate']).read_bytes())
 for k in [1,4]:
  out=Image.new('RGBA',(64*k,64*k),'#121721');out.alpha_composite(im.resize(out.size,Image.Resampling.NEAREST));out.save(R/f"previews/{a['id']}_{k}x.png")
# Recolor the composite preview's previous blood-only shades, without changing any geometry.
for name in ['village_assembly_1x.png','decals_on_snow_and_ice_1x.png','props_decals_v01.png','review_decals_2_4x.png']:
 p=R/'previews'/name;recolor(Image.open(p)).save(p)
village=Image.open(R/'previews/village_assembly_1x.png');frames=[]
for step in range(8):
 x=round((village.width-512)*step/7);frames.append(village.crop((x,96,x+512,480)).resize((1024,768),Image.Resampling.NEAREST).convert('RGB'))
frames=frames+frames[-2:0:-1];frames[0].save(R/'previews/village_pan.gif',save_all=True,append_images=frames[1:],duration=[120 if i%2==0 else 130 for i in range(len(frames))],loop=0)
allcolors=set()
for a in m['assets']:allcolors.update(p[:3] for p in Image.open(R/a['candidate']).get_flattened_data() if p[3])
assert len(allcolors)==48
m['palette']['blood_muted_red']=[list(new)];m['palette']['total_rgb_union']=48;m['palette']['note']='47 existing Midgard colors plus one muted blood-red hue; same three decal silhouettes; environment total48 RGB colors.'
(R/'records/midgard_expansion_palette48.json').write_text(json.dumps(sorted(allcolors),indent=2));(R/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
for fn in ['final_candidates_audit.json','props_decals_normalization_v01.json']:
 p=R/'records'/fn;j=json.loads(p.read_text())
 for a in j:
  if a['id'].startswith('blood'):
   a['colors']=1;a['processing']=a['processing'].replace('blood retains three muted dark red source-family shades','blood uses one muted dark red hue across three shape variations');a['sha256']=hashlib.sha256((R/a['candidate'] if 'candidate' in a else R/f"candidates/{a['id']}_v01.png").read_bytes()).hexdigest()
 p.write_text(json.dumps(j,ensure_ascii=False,indent=2))
p=R/'gallery.html';s=p.read_text();s=re.sub(r'(blood_0[123] · 64×64 · )3 色',r'\g<1>1 色',s);p.write_text(s)
p=R/'README.md';s=p.read_text().replace('血迹保留3种必要的低饱和暗红，单张最多47种不透明RGB，本批并集50种','三张血迹统一使用一种低饱和暗红，单张最多47种不透明RGB；本批环境素材并集48种（47种既有颜色+1种暗红）').replace('硬映射成灰棕色','映射成灰棕色');p.write_text(s)
p=R/'records/normalize_props.py';s=p.read_text().replace('bloodpal=[[38,20,25],[48,23,29],[57,27,33]]','bloodpal=[[48,23,29]]').replace('blood retains three muted dark red source-family shades','blood uses one muted dark red hue across three shape variations');p.write_text(s)
# Update the publication helper's corresponding palette policy for repeatability.
p=R/'records/publish_delivery.py';s=p.read_text().replace("[[38,20,25],[48,23,29],[57,27,33]]","[[48,23,29]]").replace('only blood keeps three required dark red shades','blood keeps one muted red hue across three silhouettes');p.write_text(s)
p=A/'LICENSES.md';s=p.read_text().replace('血迹另保留3种低饱和暗红，单图最多47色','三张血迹统一1种低饱和暗红，单图最多47色，本批环境合计48色');p.write_text(s)
print('48 RGB colors total;3 blood silhouettes retain1 muted dark-red hue;PNG SHA256 records refreshed')
