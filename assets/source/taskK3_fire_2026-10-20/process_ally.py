from pathlib import Path
import json
from PIL import Image,ImageDraw

BASE=Path(__file__).resolve().parent
ref=Image.open(BASE/'candidates/freyr_v01.png').convert('RGBA');pal=json.loads((BASE/'references/freyr_palette.json').read_text())
solepts=[x for y in range(58,62) for x in range(64) if ref.getpixel((x,y))[3]];sole_ref=sum(solepts)/len(solepts);rows=[]
for action,fps,loop in [('idle',8,True),('heal',16,False)]:
    version='v02' if action=='heal' else 'v01'
    raw=Image.open(BASE/f'originals/freyr_{action}_{version}_raw.png').convert('RGBA');mask=raw.getchannel('A').point(lambda a:255 if a>=128 else 0);parts=[]
    for i in range(4):
        cx=int((i%2+.5)*raw.width/2);cy=int((i//2+.5)*raw.height/2);pts=[(x,y) for y in range(max(0,cy-100),min(raw.height,cy+101)) for x in range(max(0,cx-100),min(raw.width,cx+101)) if mask.getpixel((x,y))==255];seed=min(pts,key=lambda q:(q[0]-cx)**2+(q[1]-cy)**2);ImageDraw.floodfill(mask,seed,128,border=0);group=mask.point(lambda a:255 if a==128 else 0);box=group.getbbox();part=raw.crop(box);part.putalpha(group.crop(box));parts.append(part);mask.paste(0,(0,0),group)
    scale=58/max(p.height for p in parts);frames=[];placements=[]
    for part in parts:
        im=part.resize((round(part.width*scale),round(part.height*scale)),Image.Resampling.NEAREST);pts=[x for y in range(max(0,im.height-4),im.height) for x in range(im.width) if im.getpixel((x,y))[3]>=128];x=round(sole_ref-sum(pts)/len(pts));y=62-im.height
        if x<2 or x+im.width>62:raise RuntimeError(f'ally {action} x{x} width{im.width} exceeds64, regenerate')
        cache={};data=[]
        for r,g,b,a in im.get_flattened_data():
            if a<128:data.append((0,0,0,0));continue
            rgb=(r,g,b)
            if rgb not in cache:cache[rgb]=min(pal,key=lambda c:sum((c[i]-rgb[i])**2 for i in range(3)))
            data.append(tuple(cache[rgb])+(255,))
        im.putdata(data);f=Image.new('RGBA',(64,64));f.paste(im,(x,y));frames.append(f);placements.append([x,y,im.width,im.height])
    sheet=Image.new('RGBA',(256,64))
    for i,f in enumerate(frames):sheet.paste(f,(64*i,0))
    sheet.save(BASE/f'candidates/freyr_{action}_{version}.png');board=Image.new('RGB',(320,88),'#121721');d=ImageDraw.Draw(board)
    for i,f in enumerate([ref]+frames):board.paste(f,(64*i,0),f);d.line((64*i,62,64*(i+1)-1,62),fill='#7bb3aa');d.text((64*i+2,68),'REF' if i==0 else str(i-1),fill='white')
    board.save(BASE/f'previews/freyr_{action}_{version}_1x.png');board.resize((1280,352),Image.Resampling.NEAREST).save(BASE/f'previews/freyr_{action}_{version}_4x.png')
    for kind,rate in [('native',fps),('slow8',8)]:
        pics=[]
        for f in frames:
            b=Image.new('RGB',(64,64),'#121721');b.paste(f,(0,0),f);pics.append(b.resize((256,256),Image.Resampling.NEAREST))
        ms=[round((i+1)*100/rate)*10-round(i*100/rate)*10 for i in range(4)]
        if not loop:ms[-1]+=600
        pics[0].save(BASE/f'previews/freyr_{action}_{version}_{kind}.gif',save_all=True,append_images=pics[1:],duration=ms,loop=0,optimize=False)
    rows.append(dict(id='freyr_'+action,version=version,frame_size=[64,64],frames=4,fps=fps,loop=loop,scale=scale,placements=placements,method='one scale peraction, fixed sole centroid and baseline62; approved master48RGB; no painting'))
(BASE/'records/ally_normalization.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(rows))
