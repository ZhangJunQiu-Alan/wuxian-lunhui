from pathlib import Path
from PIL import Image
from collections import Counter
import json,importlib.util
ROOT=Path(__file__).resolve().parent.parent
poses=['single','mid','down','mid'];eyes={'single':(1169,632),'mid':(1169,632),'down':(1159,364)}
frames=[];crops=[]
for pose in poses:
 im=Image.open(ROOT/'originals'/f'raven_{pose}_v04_raw.png').convert('RGBA');im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0))
 ex,ey=eyes[pose];box=(ex-1036,ey-571,ex-1036+1290,ey-571+1198);crops.append(box)
 cut=im.crop(box).resize((28,26),Image.Resampling.NEAREST)
 f=Image.new('RGBA',(32,32));f.paste(cut,(2,3));frames.append(f)
pixels=[p[:3] for f in frames for p in f.getdata() if p[3]];sample=Image.new('RGB',(len(pixels),1));sample.putdata(pixels);pal=sample.quantize(colors=24,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
palette=pal.getpalette()[:72]+[253,253,255];pal.putpalette(palette+[0]*(768-len(palette)))
out=Image.new('RGBA',(128,32))
for i,f in enumerate(frames):
 q=f.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(f.getchannel('A'));q.putdata([p if p[3] else (0,0,0,0) for p in q.getdata()]);out.paste(q,(i*32,0))
out.save(ROOT/'candidates/raven_v04.png')
source=Image.new('RGBA',(1290*4,1198))
for i,(pose,box) in enumerate(zip(poses,crops)):
 im=Image.open(ROOT/'originals'/f'raven_{pose}_v04_raw.png').convert('RGBA');source.paste(im.crop(box),(i*1290,0))
source.save(ROOT/'originals/raven_v04_raw.png')
record={'id':'raven','version':'v04','tool':'builtin image_gen for three single poses; Pillow only common crop, nearest-neighbor scale, shared palette and frame layout','sources':['originals/raven_single_v04_raw.png','originals/raven_mid_v04_raw.png','originals/raven_down_v04_raw.png'],'generation_records':['records/generation_raven_single_v04.json','records/generation_raven_mid_v04.json','records/generation_raven_down_v04.json'],'reference':'originals/raven_single_v04_raw.png','sequence':poses,'note':'Four-phase reversible wingbeat up/mid/down/mid; three unique poses intentionally reused for upward return. Same scaling and fixed eye anchor for every pose; no body painting in Python. Source white eye RGB253,253,255 reserved in shared palette so a one-pixel feature is not averaged into blue-gray.','source_eyes':eyes,'common_crop_size':[1290,1198],'crops':crops,'scaled_cell':[28,26],'placement':[2,3]}
(ROOT/'records/generation_raven_v04.json').write_text(json.dumps(record,indent=2))
sp=importlib.util.spec_from_file_location('refresh',ROOT/'records/refresh_previews.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);print(m.refresh('raven','v04'))
