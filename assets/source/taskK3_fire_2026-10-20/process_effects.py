from pathlib import Path
import json
from PIL import Image,ImageDraw

BASE=Path(__file__).resolve().parent
surtr=Image.open(BASE/'references/surtr.png').convert('RGBA')
fire_palette=sorted({p[:3] for p in surtr.get_flattened_data() if p[3]})
results=[]
for name,version,size,n,fps,loop in [('surtr_sword_arc','v02',128,4,16,False),('surtr_gate','v03',128,4,8,True),('surtr_firewall_band','v01',64,4,8,True),('surtr_final_fire','v01',64,4,16,False),('surtr_safe_rune','v01',64,1,0,False)]:
    raw=Image.open(BASE/f'originals/{name}_{version}_raw.png').convert('RGBA')
    cells=[raw] if n==1 else [raw.crop((i%2*raw.width//2,i//2*raw.height//2,(i%2+1)*raw.width//2,(i//2+1)*raw.height//2)) for i in range(n)]
    crop=None
    if name=='surtr_gate':
        boxes=[c.getchannel('A').point(lambda a:255 if a>=32 else 0).getbbox() for c in cells]
        crop=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
        cells=[c.crop(crop) for c in cells]
    if name=='surtr_firewall_band':
        boxes=[c.getchannel('A').point(lambda a:255 if a>=32 else 0).getbbox() for c in cells]
        top=min(b[1] for b in boxes);bottom=max(b[3] for b in boxes);height=bottom-top;width=round(height*64/30)
        left=(min(c.width for c in cells)-width)//2;crop=(left,top,left+width,bottom);cells=[c.crop(crop) for c in cells]
    pal=fire_palette
    if name=='surtr_safe_rune':
        pixels=[p[:3] for p in raw.get_flattened_data() if p[3]>=32];pool=Image.new('RGB',(len(pixels),1));pool.putdata(pixels)
        pal=sorted(set(pool.quantize(colors=24,method=Image.Quantize.MEDIANCUT).convert('RGB').get_flattened_data()))
    frames=[]
    for c in cells:
        if name=='surtr_firewall_band':target=(64,30);offset=(0,2)
        else:target=(size-8,size-8) if size==128 else (size-4,size-4);offset=(4,6) if name=='surtr_gate' else ((4,4) if size==128 else (2,2))
        c=c.resize(target,Image.Resampling.NEAREST);cache={};data=[]
        for r,g,b,a in c.get_flattened_data():
            a=round(a/255*7)*255//7
            if not a:data.append((0,0,0,0));continue
            rgb=(r,g,b)
            if rgb not in cache:cache[rgb]=min(pal,key=lambda q:sum((q[i]-rgb[i])**2 for i in range(3)))
            data.append(cache[rgb]+(a,))
        c.putdata(data);f=Image.new('RGBA',(size,size));f.paste(c,offset);frames.append(f)
    registration=[]
    if name in ['surtr_gate','surtr_sword_arc']:
        if name=='surtr_sword_arc':
            peak=Image.open(BASE/'originals/surtr_sword_arc_peak_v03_raw.png').convert('RGBA').resize((120,120),Image.Resampling.NEAREST)
            cache={};pixels=[]
            for r,g,b,a in peak.get_flattened_data():
                a=round(a/255*7)*255//7
                if not a:pixels.append((0,0,0,0));continue
                rgb=(r,g,b)
                if rgb not in cache:cache[rgb]=min(pal,key=lambda q:sum((q[k]-rgb[k])**2 for k in range(3)))
                pixels.append(cache[rgb]+(a,))
            peak.putdata(pixels);replacement=Image.new('RGBA',(128,128));replacement.paste(peak,(4,4));frames[2]=replacement
        shifted=[]
        for i,f in enumerate(frames):
            points=[(x,y) for y in range(size) for x in range(size) if f.getpixel((x,y))[3]];fits=[]
            for dx in range(-8,9):
                for dy in range(-8,9):
                    if not all(2<=x+dx<126 and 2<=y+dy<126 for x,y in points):continue
                    bad=any((x+dx-64)**2+(y+dy-64)**2<32**2 for x,y in points) if name=='surtr_sword_arc' else any(40<=x+dx<88 and 46<=y+dy<116 for x,y in points)
                    if not bad:fits.append((dx,dy))
            if not fits:raise RuntimeError(f'{name}:{i} cannot register whole frame without protected-area intrusion; regenerate')
            dx,dy=min(fits,key=lambda d:(d[0]**2+d[1]**2,abs(d[1]),abs(d[0])))
            canvas=Image.new('RGBA',(size,size));canvas.paste(f,(dx,dy));shifted.append(canvas);registration.append([dx,dy])
        frames=shifted
    sheet=Image.new('RGBA',(size*n,size))
    for i,f in enumerate(frames):sheet.paste(f,(i*size,0))
    sheet.save(BASE/f'candidates/{name}_{version}.png')
    board=Image.new('RGB',(size*n,size),'#121721')
    for i,f in enumerate(frames):board.paste(f,(size*i,0),f)
    board.save(BASE/f'previews/{name}_{version}_1x.png');board.resize((board.width*4,size*4),Image.Resampling.NEAREST).save(BASE/f'previews/{name}_{version}_4x.png')
    if n>1:
        for label,rate in [('native',fps),('slow8',8)]:
            pictures=[]
            for f in frames:
                bg=Image.new('RGB',(size,size),'#121721');bg.paste(f,(0,0),f);pictures.append(bg.resize((size*4,size*4),Image.Resampling.NEAREST))
            timings=[round((i+1)*100/rate)*10-round(i*100/rate)*10 for i in range(n)]
            if not loop:timings[-1]+=600
            pictures[0].save(BASE/f'previews/{name}_{version}_{label}.gif',save_all=True,append_images=pictures[1:],duration=timings,loop=0,optimize=False)
    protected=[]
    if name=='surtr_gate':protected=[sum(p[3]>0 for p in f.crop((40,46,88,116)).get_flattened_data()) for f in frames]
    if name=='surtr_safe_rune':protected=[sum(p[3]>0 for p in f.crop((14,14,50,50)).get_flattened_data()) for f in frames]
    if name=='surtr_firewall_band':protected=[sum(p[3]>0 for p in f.crop((0,32,64,64)).get_flattened_data()) for f in frames]
    if name=='surtr_sword_arc':protected=[sum(f.getpixel((x,y))[3]>0 for y in range(size) for x in range(size) if (x-64)**2+(y-64)**2<32**2) for f in frames]
    results.append(dict(id=name,version=version,frame_size=[size,size],frames=n,fps=fps,loop=loop,alpha='8levels',rgb_count=len({p[:3] for p in sheet.get_flattened_data() if p[3]}),protected_occupied=protected,crop=crop,whole_frame_registration=registration,peak_override='originals/surtr_sword_arc_peak_v03_raw.png' if name=='surtr_sword_arc' else None,method='fixed cell nearest resize, palette and8level alpha normalization; whole-frame registration preserves all visible pixels; fire band material span cropped then padded below, no painted pixels'))
(BASE/'records/effects_normalization.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(results,ensure_ascii=False))
