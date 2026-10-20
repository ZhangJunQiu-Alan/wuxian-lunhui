from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

BASE=Path(__file__).resolve().parent
REF=Image.open(BASE/'candidates/vidar_v01.png').convert('RGBA')
PAL=json.loads((BASE/'references/vidar_palette.json').read_text())
FONT=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',11)
ref_pts=[x for y in range(90,94) for x in range(96) if REF.getpixel((x,y))[3]]
ref_foot=sum(ref_pts)/len(ref_pts)
result=[]
for action,n,cols,fps,loop in [('idle',4,2,8,True),('pry',6,3,16,False)]:
    raw=Image.open(BASE/f'originals/vidar_{action}_v01_raw.png').convert('RGBA')
    mask=raw.getchannel('A').point(lambda a:255 if a>=128 else 0);parts=[];boxes=[]
    for i in range(n):
        left=int(i%cols*raw.width/cols);right=int((i%cols+1)*raw.width/cols);top=int(i//cols*raw.height/2);bottom=int((i//cols+1)*raw.height/2)
        cx=(left+right)//2;cy=(top+bottom)//2;seed=None
        for reach in [0,20,50,100]:
            for y in range(max(top,cy-reach),min(bottom,cy+reach+1)):
                for x in range(max(left,cx-reach),min(right,cx+reach+1)):
                    if mask.getpixel((x,y))==255:seed=(x,y);break
                if seed:break
            if seed:break
        if not seed:raise RuntimeError('missing ally')
        ImageDraw.floodfill(mask,seed,128,border=0);group=mask.point(lambda a:255 if a==128 else 0);box=group.getbbox();boxes.append(box)
        part=raw.crop(box);part.putalpha(group.crop(box));parts.append(part);mask.paste(0,(0,0),group)
    factor=92/max(p.height for p in parts);frames=[];positions=[]
    for part in parts:
        part=part.resize((round(part.width*factor),round(part.height*factor)),Image.Resampling.NEAREST)
        pts=[x for y in range(max(0,part.height-4),part.height) for x in range(part.width) if part.getpixel((x,y))[3]]
        foot=sum(pts)/len(pts);x=round(ref_foot-foot);y=94-part.height
        if x<2 or x+part.width>94:raise RuntimeError(f'ally pose exceeds96 canvas at x{x},w{part.width}; regenerate, do not squeeze')
        data=[];cache={}
        for r,g,b,a in part.get_flattened_data():
            if a<128:data.append((0,0,0,0));continue
            rgb=(r,g,b)
            if rgb not in cache:cache[rgb]=min(PAL,key=lambda c:sum((c[j]-rgb[j])**2 for j in range(3)))
            data.append(tuple(cache[rgb])+(255,))
        part.putdata(data);frame=Image.new('RGBA',(96,96));frame.paste(part,(x,y));frames.append(frame);positions.append([x,y,part.width,part.height])
    strip=Image.new('RGBA',(96*n,96))
    for i,f in enumerate(frames):strip.paste(f,(96*i,0))
    strip.save(BASE/f'candidates/vidar_{action}_v01.png')
    board=Image.new('RGB',(96*(n+1),122),'#121721');d=ImageDraw.Draw(board)
    for i,f in enumerate([REF]+frames):board.paste(f,(i*96,0),f);d.text((i*96+3,103),'REF' if i==0 else str(i-1),font=FONT,fill='white')
    board.save(BASE/f'previews/vidar_{action}_v01_1x.png');board.resize((board.width*4,488),Image.Resampling.NEAREST).save(BASE/f'previews/vidar_{action}_v01_4x.png')
    for label,rate in [('native',fps),('slow8',8)]:
        pictures=[]
        for f in frames:
            b=Image.new('RGB',(96,96),'#121721');b.paste(f,(0,0),f);pictures.append(b.resize((384,384),Image.Resampling.NEAREST))
        ms=[round((i+1)*100/rate)*10-round(i*100/rate)*10 for i in range(n)]
        if not loop:ms[-1]+=600
        pictures[0].save(BASE/f'previews/vidar_{action}_v01_{label}.gif',save_all=True,append_images=pictures[1:],duration=ms,loop=0,optimize=False)
    result.append(dict(action=action,frames=n,fps=fps,loop=loop,scale=factor,raw_boxes=boxes,placements=positions,
                       registration='one scale per action; same master-ground-foot centroid and foot baseline94; whole-frame placement only',visual_review='pending'))
(BASE/'records/ally_normalization.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
