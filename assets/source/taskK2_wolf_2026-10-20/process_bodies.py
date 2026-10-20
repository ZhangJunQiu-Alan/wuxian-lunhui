from pathlib import Path
import json
import hashlib
from PIL import Image, ImageDraw, ImageFont

BASE=Path(__file__).resolve().parent
REF=Image.open(BASE/'references/fenrir.png').convert('RGBA')
PAL=sorted({p[:3] for p in REF.get_flattened_data() if p[3]})
FONT=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',12)
jobs=[('idle','v01',4,2,8,True),('move','v02',6,3,8,True),('windup','v02',3,2,8,False),('attack','v01',4,2,16,False),('swallow','v01',6,3,16,False)]
report=[]

for action,version,n,cols,fps,loop in jobs:
    raw=Image.open(BASE/f'originals/fenrir_{action}_{version}_raw.png').convert('RGBA')
    mask=raw.getchannel('A').point(lambda v:255 if v>=128 else 0)
    parts=[];boxes=[]
    for i in range(n):
        cx=int((i%cols+.5)*raw.width/cols);cy=int((i//cols+.5)*raw.height/2)
        seed=None
        for reach in [0,16,40,100]:
            for y in range(max(0,cy-reach),min(raw.height,cy+reach+1)):
                for x in range(max(0,cx-reach),min(raw.width,cx+reach+1)):
                    if mask.getpixel((x,y))==255:seed=(x,y);break
                if seed:break
            if seed:break
        if not seed:raise RuntimeError(f'missing foreground seed {action}:{i}')
        ImageDraw.floodfill(mask,seed,128,border=0)
        group=mask.point(lambda v:255 if v==128 else 0);box=group.getbbox()
        if box[2]-box[0]>raw.width/cols*1.5:raise RuntimeError('merged characters')
        mask.paste(0,(0,0),group)
        part=raw.crop(box);part.putalpha(group.crop(box));parts.append(part);boxes.append(box)
    factor=min(186/max(p.width for p in parts),186/max(p.height for p in parts))
    frames=[];placements=[]
    for part in parts:
        target=part.resize((round(part.width*factor),round(part.height*factor)),Image.Resampling.NEAREST)
        colors={};pixels=[]
        for r,g,b,a in target.get_flattened_data():
            if a<128:pixels.append((0,0,0,0));continue
            rgb=(r,g,b)
            if rgb not in colors:colors[rgb]=min(PAL,key=lambda c:sum((c[j]-rgb[j])**2 for j in range(3)))
            pixels.append(colors[rgb]+(255,))
        target.putdata(pixels)
        frame=Image.new('RGBA',(192,192));x=3;y=190-target.height
        frame.paste(target,(x,y));frames.append(frame);placements.append([x,y,target.width,target.height])
    sheet=Image.new('RGBA',(192*n,192))
    for i,f in enumerate(frames):sheet.paste(f,(192*i,0))
    name=f'fenrir_{action}_{version}.png';sheet.save(BASE/'candidates'/name)
    board=Image.new('RGB',(192*(n+1),222),'#121721');d=ImageDraw.Draw(board)
    for i,f in enumerate([REF]+frames):
        board.paste(f,(192*i,0),f);d.text((192*i+5,200),'REF' if i==0 else action+' '+str(i-1),font=FONT,fill='white')
    board.save(BASE/f'previews/fenrir_{action}_{version}_1x.png')
    board.resize((board.width*2,444),Image.Resampling.NEAREST).save(BASE/f'previews/fenrir_{action}_{version}_2x.png')
    for label,rate in [('native',fps),('slow8',8)]:
        imgs=[]
        for f in frames:
            b=Image.new('RGB',(192,192),'#121721');b.paste(f,(0,0),f);imgs.append(b.resize((576,576),Image.Resampling.NEAREST))
        durations=[round((i+1)*100/rate)*10-round(i*100/rate)*10 for i in range(n)]
        if not loop:durations[-1]+=600
        imgs[0].save(BASE/f'previews/fenrir_{action}_{version}_{label}.gif',save_all=True,append_images=imgs[1:],duration=durations,loop=0,optimize=False)
    report.append(dict(action=action,version=version,frames=n,fps=fps,loop=loop,raw_size=list(raw.size),raw_component_boxes=boxes,
                       method='opaque foreground connected components from raw alpha, one uniform scale for all poses, no anisotropic squeezing; original pixels only; original approved48RGB palette',
                       scale=factor,placements=placements,registration='one uniform scale across poses, left3 and lowest contact baseline190; whole-frame placement only, no per-pose resizing',
                       candidate='candidates/'+name,sha256=hashlib.sha256((BASE/'candidates'/name).read_bytes()).hexdigest(),
                       bboxes=[f.getbbox() for f in frames],visual_review='pending'))
(BASE/'records/body_normalization.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps([{'action':r['action'],'raw_size':r['raw_size'],'placements':r['placements']} for r in report],ensure_ascii=False))
