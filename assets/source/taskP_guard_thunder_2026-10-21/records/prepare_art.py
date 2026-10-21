from pathlib import Path
from PIL import Image
import shutil,json,hashlib
root=Path(__file__).resolve().parents[4]
out=root/'assets/source/taskP_guard_thunder_2026-10-21'
rawdir=Path('/Users/zhangjunqiu/.codex/generated_images/01a14377-c537-7a10-b5df-10043f63fbe0')
sources={'guard_rune':'exec-b2c1fbd7-8815-41d8-bf79-0f03a37cf2ee.png'}
items=[]
for name,file in sources.items():
 original=out/'originals'/f'{name}_v01.png';shutil.copy2(rawdir/file,original)
 im=Image.open(original).convert('RGBA');bbox=im.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
 crop=im.crop(bbox);crop.thumbnail((26,26),Image.Resampling.NEAREST)
 alpha=crop.getchannel('A').point(lambda a:255 if a>=128 else 0)
 rgb=crop.convert('RGB').quantize(colors=32,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGBA');rgb.putalpha(alpha)
 sprite=Image.new('RGBA',(32,32));sprite.paste(rgb,((32-rgb.width)//2,(32-rgb.height)//2))
 path=root/'assets/sprites/pickups'/f'{name}.png';sprite.save(path)
 sprite.resize((256,256),Image.Resampling.NEAREST).save(out/'previews'/f'{name}_8x.png')
 frames=[]
 for i in range(16):
  frame=Image.new('RGB',(64,64),(24,29,38));frame.paste(sprite,(16,16+[0,-1,-2,-1][i//4]),sprite);frames.append(frame.resize((256,256),Image.Resampling.NEAREST))
 frames[0].save(out/'previews'/f'{name}_bob.gif',save_all=True,append_images=frames[1:],duration=100,loop=0)
 tile=Image.new('RGB',(128,128),(32,38,48))
 for y in range(4):
  for x in range(4):tile.paste(sprite,(32*x,32*y),sprite)
 tile.resize((512,512),Image.Resampling.NEAREST).save(out/'previews'/f'{name}_4x4.png')
 colors=len({p for p in sprite.getdata() if p[3]});alphas=sorted(set(sprite.getchannel('A').getdata()));bb=sprite.getbbox()
 items.append({'id':name,'file':str(path.relative_to(root)),'size':[32,32],'source_size':list(im.size),'source':str(original.relative_to(root)),'crop':bbox,'colors':colors,'alpha':alphas,'bbox':bb,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'checks':{'size':sprite.size==(32,32),'binary_alpha':alphas==[0,255],'palette':colors<=32,'margin':bb[0]>=3 and bb[1]>=3 and bb[2]<=29 and bb[3]<=29}})
(out/'manifest.json').write_text(json.dumps({'assets':items,'processing':'Alpha>=128 bounding crop; fit inside26x26 NEAREST; median-cut32 colors; binary alpha; center32x32. Generated originals are not native32px.','license':'OpenAI output Terms of Use; see assets/LICENSES.md','references':{p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in ['assets/sprites/pickups/soul_magnet.png','assets/sprites/pickups/healing_mead.png']}},indent=2,ensure_ascii=False))
print(json.dumps(items,indent=2))
