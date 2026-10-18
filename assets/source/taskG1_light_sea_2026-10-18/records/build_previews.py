from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[4]
GROUPS={'G1':('taskG1_light_sea_2026-10-18',{'baldr':'v02','baldr_awaken':'v01','ran':'v02','ran_awaken':'v02'}),'G2':('taskG2_harvest_hunt_2026-10-18',{'freyr':'v02','freyr_awaken':'v02','skadi':'v04','skadi_awaken':'v03'}),'G3':('taskG3_original_awaken_2026-10-18',{'thor_awaken':'v01','odin_awaken':'v02','loki_awaken':'v02','freyja_awaken':'v01'})}
def sheet(items,p):
 im=Image.new('RGB',(284*len(items),489),'#121721');d=ImageDraw.Draw(im)
 for i,(name,image)in enumerate(items):im.paste(image,(i*284+12,30));d.text((i*284+12,8),name,fill='white')
 im.save(p)
for group,(folder,selected)in GROUPS.items():
 r=ROOT/'assets/source'/folder
 for id,v in selected.items():
  im=Image.open(r/'originals'/f'{id}_{v}.png').convert('RGB').resize((720,1200),Image.Resampling.LANCZOS);im.save(r/'candidates'/f'{id}.png')
  small=im.resize((260,433),Image.Resampling.LANCZOS);small.save(r/'previews'/f'{id}_260.png');overlay=Image.blend(small,Image.new('RGB',small.size,'#0F1119'),.9);masked=small.copy();y=round(.55*433);masked.paste(overlay.crop((0,y,260,433)),(0,y));masked.save(r/'previews'/f'{id}_masked.png')
  cover=im.resize((270,450),Image.Resampling.LANCZOS).crop((5,0,265,450));cover.save(r/'previews'/f'{id}_cover.png')
  safe=im.copy();d=ImageDraw.Draw(safe);d.line((40,0,40,1199),fill='#FFCC66',width=2);d.line((679,0,679,1199),fill='#FFCC66',width=2);d.line((0,660,719,660),fill='#FFCC66',width=2);safe.resize((360,600),Image.Resampling.LANCZOS).save(r/'previews'/f'{id}_safe.png')
 sheet([(id,Image.open(r/'previews'/f'{id}_260.png'))for id in selected],r/'previews/group.png')
 sheet([(id,Image.open(r/'previews'/f'{id}_masked.png'))for id in selected],r/'previews/group_masked.png')
 ordinary=[]
 for id in selected:
  if id.endswith('_awaken'):continue
  ordinary.append((id,Image.open(r/'previews'/f'{id}_260.png')))
 old=[(id,Image.open(r/'references'/f'{id}.png').resize((260,433),Image.Resampling.LANCZOS))for id in ['thor','odin','loki','freyja']]
 sheet(old+ordinary,r/'previews/style_comparison.png')
 for id in selected:
  if not id.endswith('_awaken'):continue
  base=id[:-7]
  normal=r/'candidates'/f'{base}.png'
  if not normal.exists():normal=r/'references'/f'{base}.png'
  n=Image.open(normal).resize((260,433),Image.Resampling.LANCZOS)
  sheet([(base,n),(id,Image.open(r/'previews'/f'{id}_260.png'))],r/'previews'/f'{base}_pair.png')
 print(group,'prepared',len(selected),'candidate/preview sets')
