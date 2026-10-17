from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
R=Path(__file__).resolve().parents[1];jobs=json.loads((R/'records/generation_jobs.json').read_text())
ids=[]
for j in jobs:
 if not j['selected']:continue
 id=j['id'];ids.append(id);p=R/j['source_file'];im=Image.open(p).convert('RGB');im=im.resize((720,1200),Image.Resampling.LANCZOS);im.save(R/'candidates'/f'{id}.png')
 small=im.resize((260,433),Image.Resampling.LANCZOS);small.save(R/'previews'/f'{id}_260.png')
 mask=Image.new('RGB',small.size,'#0F1119');masked=small.copy();y=round(433*.55);masked.paste(Image.blend(small,mask,.9).crop((0,y,260,433)),(0,y));masked.save(R/'previews'/f'{id}_masked.png')
 # Actual 260x450 fill crop: uniform fit-to-cover, crop sides, no nonuniform stretch.
 cover=im.resize((270,450),Image.Resampling.LANCZOS).crop((5,0,265,450));cover.save(R/'previews'/f'{id}_260x450_crop.png')
 safe=im.copy();d=ImageDraw.Draw(safe);d.rectangle((40,0,679,1199),outline='#FFCC66',width=2);d.line((0,660,719,660),fill='#FFCC66',width=2);safe.resize((360,600),Image.Resampling.LANCZOS).save(R/'previews'/f'{id}_safe.png')
for name,selection in [('gods',['thor','odin','loki','freyja']),('weapons',['swordsman','gunslinger','assassin','mage']),('all',ids)]:
 cols=4 if name!='all' else 3;rows=(len(selection)+cols-1)//cols;sheet=Image.new('RGB',(cols*284,rows*489),'#121721');d=ImageDraw.Draw(sheet)
 for i,id in enumerate(selection):
  x=i%cols*284+12;y=i//cols*489+30;sheet.paste(Image.open(R/'previews'/f'{id}_260.png'),(x,y));d.text((x,y-20),id,fill='white')
 sheet.save(R/'previews'/f'{name}_comparison.png')
 sheet2=Image.new('RGB',(cols*284,rows*489),'#121721');d=ImageDraw.Draw(sheet2)
 for i,id in enumerate(selection):
  x=i%cols*284+12;y=i//cols*489+30;sheet2.paste(Image.open(R/'previews'/f'{id}_masked.png'),(x,y));d.text((x,y-20),id,fill='white')
 sheet2.save(R/'previews'/f'{name}_masked_comparison.png')
print('Built',len(ids),'720x1200 RGB candidates and preview sets')
