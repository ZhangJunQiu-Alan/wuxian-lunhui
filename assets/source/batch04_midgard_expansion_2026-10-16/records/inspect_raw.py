from pathlib import Path
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parents[1]
for n in ['crossroads_v01','burial_v01','decals_v01']:
 im=Image.open(R/f'originals/{n}_raw.png').convert('RGBA');print(n,im.size,im.getextrema()[3]);back=Image.new('RGBA',im.size,'#121721');back.alpha_composite(im);d=ImageDraw.Draw(back)
 for x in range(0,im.width,100):d.line((x,0,x,im.height),fill='#808080',width=1);d.text((x+2,5),str(x),fill='white')
 for y in range(0,im.height,100):d.line((0,y,im.width,y),fill='#808080',width=1);d.text((2,y+3),str(y),fill='white')
 back.thumbnail((1100,850));back.save(R/f'previews/{n}_crop_grid.png')
