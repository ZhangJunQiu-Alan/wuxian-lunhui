from pathlib import Path
import json
from PIL import Image,ImageDraw

BASE=Path(__file__).resolve().parent
spec=json.loads((BASE/'records/specification.json').read_text())
rows=[]
for r in spec:
    if r.get('decision')!='new_proposed':continue
    name=r['id'];rawpath=BASE/f'originals/{name}_v01_raw.png'
    if not rawpath.exists():continue
    size=r['frame_size'][0];n=r['frames'];raw=Image.open(rawpath).convert('RGBA');soft=name=='fire_giant_explosion'
    if soft:
        cells=[raw.crop((i%2*raw.width//2,i//2*raw.height//2,(i%2+1)*raw.width//2,(i//2+1)*raw.height//2)) for i in range(n)]
        parts=cells;boxes=[(0,0,c.width,c.height) for c in cells]
    else:
        cols=3 if n==6 else 2;mask=raw.getchannel('A').point(lambda a:255 if a>=128 else 0);parts=[];boxes=[]
        for i in range(n):
            cx=int((i%cols+.5)*raw.width/cols) if n>1 else raw.width//2;cy=int((i//cols+.5)*raw.height/2) if n>1 else raw.height//2
            pts=[(x,y) for y in range(max(0,cy-140),min(raw.height,cy+141)) for x in range(max(0,cx-140),min(raw.width,cx+141)) if mask.getpixel((x,y))==255]
            seed=min(pts,key=lambda q:(q[0]-cx)**2+(q[1]-cy)**2);ImageDraw.floodfill(mask,seed,128,border=0);group=mask.point(lambda a:255 if a==128 else 0);box=group.getbbox()
            if n>1 and (box[2]-box[0]>raw.width/cols*1.6 or box[3]-box[1]>raw.height/2*1.5):raise RuntimeError(name+' raw opaque masks merged; cannot extract')
            part=raw.crop(box);part.putalpha(group.crop(box));parts.append(part);boxes.append(box);mask.paste(0,(0,0),group)
    refname='fire_giant' if name.startswith('fire_giant') else 'frost_veteran' if name.startswith('frost_veteran') else 'wolf_berserker'
    if refname=='wolf_berserker' and n==1:
        pix=[p[:3] for p in parts[0].get_flattened_data() if p[3]>=128];pool=Image.new('RGB',(len(pix),1));pool.putdata(pix);pal=sorted(set(pool.quantize(colors=48,method=Image.Quantize.MEDIANCUT).convert('RGB').get_flattened_data()));(BASE/'references/wolf_berserker_palette.json').write_text(json.dumps(pal)+'\n')
    elif refname=='wolf_berserker':pal=json.loads((BASE/'references/wolf_berserker_palette.json').read_text())
    else:pal=sorted({p[:3] for p in Image.open(BASE/f'references/{refname}.png').convert('RGBA').get_flattened_data() if p[3]})
    factor=min((size-4)/max(p.width for p in parts),((58 if n==1 and size==64 else size-4))/max(p.height for p in parts))
    if soft:factor=min((size-8)/parts[0].width,(size-8)/parts[0].height)
    frames=[];placements=[]
    for i,part in enumerate(parts):
        im=part.resize((round(part.width*factor),round(part.height*factor)),Image.Resampling.NEAREST);cache={};data=[]
        for rr,g,b,a in im.get_flattened_data():
            a=round(a/255*7)*255//7 if soft else (255 if a>=128 else 0)
            if not a:data.append((0,0,0,0));continue
            rgb=(rr,g,b)
            if rgb not in cache:cache[rgb]=min(pal,key=lambda c:sum((c[j]-rgb[j])**2 for j in range(3)))
            data.append(tuple(cache[rgb])+(a,))
        im.putdata(data);x=round((size-im.width)/2);y=round((size-im.height)/2) if soft else size-2-im.height
        frame=Image.new('RGBA',(size,size));frame.paste(im,(x,y));frames.append(frame);placements.append([x,y,im.width,im.height])
    sheet=Image.new('RGBA',(size*n,size))
    for i,f in enumerate(frames):sheet.paste(f,(size*i,0))
    sheet.save(BASE/f'candidates/{name}_v01.png')
    if name=='wolf_berserker':sheet.resize((768,768),Image.Resampling.NEAREST).save(BASE/'references/wolf_berserker_master_12x.png')
    ref=Image.open(BASE/f'references/{refname}.png').convert('RGBA') if (BASE/f'references/{refname}.png').exists() else frames[0]
    board=Image.new('RGB',(size*(n+1),size+24),'#121721');d=ImageDraw.Draw(board)
    for i,f in enumerate([ref]+frames):board.paste(f,(size*i,0),f);d.line((size*i,size-2,size*(i+1)-1,size-2),fill='#7bb3aa');d.text((size*i+2,size+4),'REF' if i==0 else str(i-1),fill='white')
    board.save(BASE/f'previews/{name}_v01_1x.png');board.resize((board.width*4,board.height*4),Image.Resampling.NEAREST).save(BASE/f'previews/{name}_v01_4x.png')
    if n>1:
        for kind,rate in [('native',r['fps']),('slow8',8)]:
            pictures=[]
            for f in frames:
                bg=Image.new('RGB',(size,size),'#121721');bg.paste(f,(0,0),f);pictures.append(bg.resize((size*4,size*4),Image.Resampling.NEAREST))
            ms=[round((i+1)*100/rate)*10-round(i*100/rate)*10 for i in range(n)]
            if not r['loop']:ms[-1]+=600
            pictures[0].save(BASE/f'previews/{name}_v01_{kind}.gif',save_all=True,append_images=pictures[1:],duration=ms,loop=0,optimize=False)
    rows.append(dict(id=name,version='v01',frame_size=[size,size],frames=n,fps=r['fps'],loop=r['loop'],scale=factor,raw_boxes=boxes,placements=placements,bboxes=[f.getbbox() for f in frames],method='whole raw opaque connected components, shared uniform scale peraction, nearest, originalpalette/binaryalpha or8level effect alpha; no painted pixels',visual_review='pending'))
(BASE/'records/normalization.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(json.dumps([dict(id=r['id'],placements=r['placements']) for r in rows]))
