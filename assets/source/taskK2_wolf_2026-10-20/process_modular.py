from pathlib import Path
import json, math
from PIL import Image, ImageDraw

BASE=Path(__file__).resolve().parent
PAL=sorted({p[:3] for p in Image.open(BASE/'references/fenrir.png').convert('RGBA').get_flattened_data() if p[3]})
rows=[]
for name in ['fenrir_maw_upper','fenrir_maw_lower','fenrir_bind_link']:
    raw=Image.open(BASE/f'originals/{name}_v01_raw.png').convert('RGBA')
    n=1 if name.endswith('link') else 4
    size=(16,8) if n==1 else (256,128)
    cells=[raw] if n==1 else [raw.crop((i%2*raw.width//2-32,i//2*raw.height//2-32,(i%2+1)*raw.width//2+32,(i//2+1)*raw.height//2+32)) for i in range(n)]
    discarded=[]
    if n>1:
        clean=[]
        for c in cells:
            mask=c.getchannel('A').point(lambda a:255 if a>=128 else 0)
            points=[(x,y) for y in range(c.height) for x in range(c.width) if mask.getpixel((x,y))]
            seed=min(points,key=lambda q:(q[0]-c.width/2)**2+(q[1]-c.height/2)**2)
            ImageDraw.floodfill(mask,seed,128,border=0)
            component=mask.point(lambda a:255 if a==128 else 0)
            discarded.append(sum(a==255 for a in mask.get_flattened_data()))
            c.putalpha(component);clean.append(c)
        cells=clean
    boxes=[c.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox() for c in cells]
    union=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
    if n==1:
        span=min(union[2]-union[0],4*(union[3]-union[1]))
        left=(union[0]+union[2]-span)//2
        union=(left,union[1],left+span,union[3])
    parts=[c.crop(union) for c in cells]
    if n==1:
        factor=min(16/parts[0].width,4/parts[0].height)
        pix=[p[:3] for p in parts[0].get_flattened_data() if p[3]>=128]
        pool=Image.new('RGB',(len(pix),1));pool.putdata(pix)
        pal=sorted(set(pool.quantize(colors=16,method=Image.Quantize.MEDIANCUT).convert('RGB').get_flattened_data()))
    else:
        factor=min(240/parts[0].width,112/parts[0].height);pal=PAL
    frames=[];placements=[]
    for part in parts:
        part=part.resize((round(part.width*factor),round(part.height*factor)),Image.Resampling.NEAREST)
        cache={};data=[]
        for r,g,b,a in part.get_flattened_data():
            if a<128:data.append((0,0,0,0));continue
            c=(r,g,b)
            if c not in cache:cache[c]=min(pal,key=lambda p:sum((p[i]-c[i])**2 for i in range(3)))
            data.append(cache[c]+(255,))
        part.putdata(data)
        canvas=Image.new('RGBA',size);x=(size[0]-part.width)//2;y=(size[1]-part.height)//2
        canvas.paste(part,(x,y));frames.append(canvas);placements.append([x,y,part.width,part.height])
    sheet=Image.new('RGBA',(size[0]*n,size[1]))
    for i,f in enumerate(frames):sheet.paste(f,(i*size[0],0))
    sheet.save(BASE/f'candidates/{name}_v01.png')
    sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST).save(BASE/f'previews/{name}_v01_2x.png')
    if n>1:
        views=[]
        for f in frames:
            bg=Image.new('RGB',size,'#121721');bg.paste(f,(0,0),f);views.append(bg.resize((512,256),Image.Resampling.NEAREST))
        views[0].save(BASE/f'previews/{name}_v01_native.gif',save_all=True,append_images=views[1:],duration=[120,130,120,130],loop=0,optimize=False)
    rows.append(dict(id=name,frame_size=size,frames=n,scale=factor,source_crop=union,placements=placements,palette=pal,discarded_disconnected_raw_pixels=discarded,method='fixed cells with32px overflow guard, principal opaque component extraction preserves whole jaw beyond raw grid; shared union bbox and uniform scale; link crops one central material span; nearest; palette and binary alpha normalization only'))
upper=Image.open(BASE/'candidates/fenrir_maw_upper_v01.png').convert('RGBA')
lower=Image.open(BASE/'candidates/fenrir_maw_lower_v01.png').convert('RGBA')
combined=[];clear=[]
for i in range(4):
    c=Image.new('RGBA',(288,352));c.alpha_composite(upper.crop((i*256,0,(i+1)*256,128)),(0,16));c.alpha_composite(lower.crop((i*256,0,(i+1)*256,128)),(0,208))
    clear.append(sum(p[3]>0 for p in c.crop((96,144,208,208)).get_flattened_data()));combined.append(c)
    c.save(BASE/f'previews/maw_pair_{i}.png')
combined[0].save(BASE/'previews/maw_pair_native.gif',save_all=True,append_images=combined[1:],duration=[120,130,120,130],loop=0,disposal=2)
rows.append(dict(id='paired_jaw_clearance',protected_rect=[96,144,208,208],occupied=clear,geometry_gap=64))
(BASE/'records/modular_normalization.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(json.dumps([{k:r[k] for k in r if k!='palette'} for r in rows]))
