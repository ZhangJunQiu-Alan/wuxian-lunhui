from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

BASE=Path(__file__).resolve().parent
rows=[]
FONT=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',12)


def palette(frames, count=48):
    pixels=[p[:3] for f in frames for p in f.get_flattened_data() if p[3]>=128]
    pool=Image.new('RGB',(len(pixels),1));pool.putdata(pixels);pool=pool.quantize(colors=count,method=Image.Quantize.MEDIANCUT).convert('RGB')
    return sorted(set(pool.get_flattened_data()))


for name,version,size,count,soft in [('fenrir_maw','v03',256,4,False),('fenrir_bind','v03',192,4,True),('gleipnir_fragment','v01',24,1,False),('vidar','v01',96,1,False)]:
    raw=Image.open(BASE/f'originals/{name}_{version}_raw.png').convert('RGBA')
    cells=[];boxes=[]
    for i in range(count):
        cell=raw if count==1 else raw.crop(((i%2)*raw.width//2,(i//2)*raw.height//2,(i%2+1)*raw.width//2,(i//2+1)*raw.height//2))
        m=cell.getchannel('A').point(lambda a:255 if a>=(32 if soft else 128) else 0);box=m.getbbox()
        if box is None:raise RuntimeError('empty '+name)
        cells.append(cell);boxes.append(box)
    union=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
    pieces=[cell.crop(union) for cell in cells]
    margin=8 if name=='fenrir_maw' else 2
    factor=min((size-2*margin)/max(p.width for p in pieces),(size-2*margin)/max(p.height for p in pieces))
    frames=[];places=[]
    pal=palette(pieces)
    for part in pieces:
        part=part.resize((round(part.width*factor),round(part.height*factor)),Image.Resampling.NEAREST)
        out=Image.new('RGBA',part.size);cache={};data=[]
        for r,g,b,a in part.get_flattened_data():
            a=round(a/255*7)*255//7 if soft else (255 if a>=128 else 0)
            if not a:data.append((0,0,0,0));continue
            rgb=(r,g,b)
            if rgb not in cache:cache[rgb]=min(pal,key=lambda c:sum((c[j]-rgb[j])**2 for j in range(3)))
            data.append(cache[rgb]+(a,))
        out.putdata(data)
        canvas=Image.new('RGBA',(size,size));x=round((size-part.width)/2);y=size-2-part.height if name=='vidar' else round((size-part.height)/2)
        canvas.paste(out,(x,y));frames.append(canvas);places.append([x,y,part.width,part.height])
    strip=Image.new('RGBA',(size*count,size))
    for i,f in enumerate(frames):strip.paste(f,(i*size,0))
    strip.save(BASE/f'candidates/{name}_{version}.png')
    board=Image.new('RGB',(size*count,size+28),'#121721');d=ImageDraw.Draw(board)
    for i,f in enumerate(frames):board.paste(f,(i*size,0),f);d.text((i*size+3,size+5),str(i),font=FONT,fill='white')
    board.save(BASE/f'previews/{name}_{version}_1x.png')
    board.resize((board.width*4,board.height*4),Image.Resampling.NEAREST).save(BASE/f'previews/{name}_{version}_4x.png')
    if count>1:
        imgs=[]
        for f in frames:
            bg=Image.new('RGB',(size,size),'#121721');bg.paste(f,(0,0),f);imgs.append(bg.resize((size*2,size*2),Image.Resampling.NEAREST))
        imgs[0].save(BASE/f'previews/{name}_{version}_8fps.gif',save_all=True,append_images=imgs[1:],duration=[120,130,120,130],loop=0,optimize=False)
    if name=='vidar':(BASE/'references/vidar_palette.json').write_text(json.dumps(pal)+'\n')
    interior=[]
    if name in ['fenrir_maw','fenrir_bind']:
        box=(96,112,208,176) if name=='fenrir_maw' else (56,54,136,138)
        interior=[sum(p[3]>0 for p in f.crop(box).get_flattened_data()) for f in frames]
    rows.append(dict(id=name,version=version,size=size,frames=count,fps=8 if count>1 else 0,alpha='soft8' if soft else 'binary',palette=pal,
                     normalization='one uniform scale across original cells; nearest fit; no painted pixels; median48RGB; alpha formatting only',
                     placements=places,interior_occupied_pixels=interior,visual_review='pending'))
(BASE/'records/extras_normalization.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(json.dumps([{k:r[k] for k in ['id','placements','interior_occupied_pixels']} for r in rows],ensure_ascii=False))
