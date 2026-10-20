from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

BASE=Path(__file__).resolve().parent
rows=[]
for action,n,cols in [('idle',4,2),('move',6,3),('windup',3,2),('attack',4,2),('plant',4,2),('summon',4,2)]:
    version='v02' if action in ['windup','attack'] else 'v01'
    raw=Image.open(BASE/f'originals/surtr_{action}_{version}_raw.png').convert('RGBA')
    mask=raw.getchannel('A').point(lambda a:255 if a>=128 else 0);poses=[]
    board=Image.new('RGB',(256*min(n,3),280*((n+2)//3)),'#121721');draw=ImageDraw.Draw(board)
    for i in range(n):
        cx=int((i%cols+.5)*raw.width/cols);cy=int((i//cols+.5)*raw.height/2)
        pts=[(x,y) for y in range(max(0,cy-120),min(raw.height,cy+121)) for x in range(max(0,cx-120),min(raw.width,cx+121)) if mask.getpixel((x,y))==255]
        seed=min(pts,key=lambda q:(q[0]-cx)**2+(q[1]-cy)**2)
        ImageDraw.floodfill(mask,seed,128,border=0);group=mask.point(lambda a:255 if a==128 else 0);box=group.getbbox()
        if box is None or box[2]-box[0]>raw.width/cols*1.8:raise RuntimeError('merged or missing pose '+action+str(i))
        part=raw.crop(box);part.putalpha(group.crop(box));mask.paste(0,(0,0),group)
        part.save(BASE/f'references/raw_component_{action}_{version}_{i:02d}.png')
        factor=240/max(part.size);w=round(part.width*factor);h=round(part.height*factor);x=(256-w)//2;y=256-h
        tiny=part.resize((w,h),Image.Resampling.NEAREST);ox=(i%3)*256;oy=(i//3)*280;board.paste(tiny,(ox+x,oy+y),tiny)
        for yy in range(32,256,32):draw.line((ox,oy+yy,ox+255,oy+yy),fill='#526565');draw.text((ox+2,oy+yy),str(yy),fill='white')
        draw.text((ox+6,oy+259),f'{action} {i} raw {part.width}x{part.height}',fill='white')
        poses.append(dict(index=i,raw_box=box,raw_component=f'references/raw_component_{action}_{version}_{i:02d}.png',preview_fit=factor,preview_place=[x,y,w,h]))
    board.save(BASE/f'previews/landmark_{action}_{version}.png');rows.append(dict(action=action,version=version,poses=poses))
(BASE/'records/body_components.json').write_text(json.dumps(rows,indent=2)+'\n')
ref=Image.open(BASE/'references/surtr.png').convert('RGBA');bg=Image.new('RGB',(192,208),'#121721');bg.paste(ref,(0,0),ref);d=ImageDraw.Draw(bg)
for y in range(16,192,16):d.line((0,y,191,y),fill='#526565');d.text((0,y),str(y),fill='white')
bg.resize((768,832),Image.Resampling.NEAREST).save(BASE/'previews/landmark_original.png')
print('body components and landmark boards saved')
