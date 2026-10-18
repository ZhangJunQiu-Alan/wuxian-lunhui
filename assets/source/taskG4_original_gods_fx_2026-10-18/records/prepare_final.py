from pathlib import Path
from PIL import Image, ImageDraw
import importlib.util, json

BASE=Path(__file__).resolve().parents[2]
ROOTS=[BASE/'taskG4_original_gods_fx_2026-10-18',BASE/'taskG5_new_gods_fx_2026-10-18']
VERSIONS={'thor_hammer':'v02','odin_raven':'v05','loki_wolf':'v04','freyr_sword':'v02','skadi_arrow':'v04','ran_wave':'v02','baldr_glow':'v02','skadi_ice':'v02'}

for r in ROOTS:
 spec=importlib.util.spec_from_file_location(r.name,r/'records/pipeline.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
 plan=json.loads((r/'records/production_plan.json').read_text())['assets']
 for a in plan:
  id=a['id'];v=VERSIONS.get(id,'v01');w,h,n=a['w'],a['h'],a['frames']
  if id in ['ran_wave','baldr_glow','skadi_ice']:
   raw=Image.open(r/'originals'/f'{id}_v01_raw.png').convert('RGBA');raw.putalpha(raw.getchannel('A').point(lambda x:0 if x<12 else x));f=raw.crop(raw.getbbox()).resize((w,h-4),Image.Resampling.NEAREST);f,_=mod.rgba_palette(f);out=Image.new('RGBA',(w,h));out.paste(f,(0,2));cap=72 if id=='baldr_glow' else 150 if id=='skadi_ice' else 230;out.putalpha(out.getchannel('A').point(lambda x:round(x*cap/255/16)*16 if x else 0));out.putdata([p if p[3] else(0,0,0,0) for p in out.getdata()]);out.save(r/'candidates'/f'{id}_{v}.png')
   rec=json.loads((r/'records'/f'generation_{id}_v01.json').read_text());rec.update(version=v,formatting={'source':f'originals/{id}_v01_raw.png','operations':['whole silhouette crop','nearest resize','32 RGB palette','alpha cap','2px vertical padding'],'purpose':'Preserve original natural strip ends; remove artificial endport blocks. No body drawing.'});(r/'records'/f'generation_{id}_{v}.json').write_text(json.dumps(rec,ensure_ascii=False,indent=2))
   (r/'records'/f'normalization_{id}_{v}.json').write_text(json.dumps(rec['formatting'],indent=2))
  mod.review(id,v)
  if 'area' in a['flags']:
   im=Image.open(r/'candidates'/f'{id}_{v}.png').convert('RGBA');t=Image.open(r/'refs/midgard_ground.png').convert('RGBA');o=Image.new('RGBA',(384,512));d=ImageDraw.Draw(o)
   for yy in range(0,512,t.height):
    for xx in range(0,384,t.width):o.alpha_composite(t,(xx,yy))
   for row in [0,1]:
    chars=[(Image.open(r/'refs'/f'{name}.png').convert('RGBA'),(xy[0],xy[1]+row*256)) for name,xy in [('swordsman',(45,80)),('enemy',(220,90))]]
    effects=[(im.resize((round(w*s),round(h*s)),Image.Resampling.BILINEAR),(round(c[0]-w*s/2),round(c[1]-h*s/2)+row*256)) for s,c in [(1,(77,112)),(1.6,(252,122))]]
    for f,xy in (effects+chars if row==0 else chars+effects):o.alpha_composite(f,xy)
    d.text((5,row*256+3),'Effect BELOW characters' if row==0 else 'Effect ABOVE characters (worst case)',fill=(18,23,33,255))
   o.save(r/'previews'/f'{id}_{v}_ground.png')
 (r/'records/final_versions.json').write_text(json.dumps({a['id']:VERSIONS.get(a['id'],'v01') for a in plan},indent=2))
 # All frames, enlarged, with fixed frame-cell borders for manual alignment review.
 anim=[a for a in plan if a['frames']>1];atlas=Image.new('RGBA',(720,max(1,len(anim))*240),(18,23,33,255));d=ImageDraw.Draw(atlas)
 for row,a in enumerate(anim):
  id=a['id'];v=VERSIONS.get(id,'v01');im=Image.open(r/'candidates'/f'{id}_{v}.png').convert('RGBA');d.text((4,row*240+4),f"{id}: {a['fps']} fps",fill='white')
  for k in range(a['frames']):
   f=im.crop((k*a['w'],0,(k+1)*a['w'],a['h'])).resize((a['w']*4,a['h']*4),Image.Resampling.NEAREST);x=8+k*(a['w']*4+24);y=row*240+25;atlas.alpha_composite(f,(x,y));d.rectangle((x,y,x+f.width,y+f.height),outline=(52,66,82));d.text((x,y+f.height+4),f'Frame {k}',fill='white')
 atlas.save(r/'previews/final_animation_frames.png')
