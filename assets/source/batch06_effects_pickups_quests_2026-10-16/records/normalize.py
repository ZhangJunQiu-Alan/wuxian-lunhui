from PIL import Image, ImageDraw
from pathlib import Path
from collections import Counter
import json, hashlib, argparse, math

ROOT = Path(__file__).resolve().parent.parent
PLAN = {a['id']: a for a in json.loads((ROOT/'records/production_plan.json').read_text())['assets']}
BG = (18, 23, 33)

def normalize(asset_id, version='v01', palette_from=None):
    a = PLAN[asset_id]
    source_path=ROOT/'originals'/f'{asset_id}_{version}_raw.png'
    if asset_id=='lightning' and version=='v02':source_path=ROOT/'refs/lightning_extracted_v02.png'
    raw = Image.open(source_path).convert('RGBA')
    w,h,n = a['w'],a['h'],a['frames']
    horizontal = asset_id in ('lightning','quest_beacon')
    cols,rows = (1,1) if n==1 else ((4,1) if horizontal else (2,2))
    cw,ch = raw.width//cols,raw.height//rows
    cells=[]
    for i in range(n):
        im=raw.crop(((i%cols)*cw,(i//cols)*ch,(i%cols+1)*cw,(i//cols+1)*ch))
        im.putalpha(im.getchannel('A').point(lambda v:255 if v>=128 else 0))
        cells.append(im)
    boxes=[im.getbbox() for im in cells]
    if any(b is None for b in boxes): raise ValueError('Empty cell')
    union=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
    if asset_id=='lightning' and version=='v02':union=(0,0,cw,ch)
    scale=min((w-4)/(union[2]-union[0]),(h-4)/(union[3]-union[1]))
    sw,sh=max(1,round((union[2]-union[0])*scale)),max(1,round((union[3]-union[1])*scale))
    if asset_id=='lightning' and version=='v02':sw,sh=w-4,h-4
    ox=(w-sw)//2
    oy=h-2-sh if a['anchor']=='bottom' else (h-sh)//2
    frames=[]
    for im in cells:
        cut=im.crop(union).resize((sw,sh),Image.Resampling.NEAREST)
        frame=Image.new('RGBA',(w,h))
        frame.paste(cut,(ox,oy))
        frames.append(frame)
    translations=[]
    for index,f in enumerate(frames):
        b=f.getbbox();dx=dy=0
        if n>1 and a['anchor']=='bottom':
            dx=round(w/2-(b[0]+b[2])/2);dy=h-2-b[3]
            if asset_id=='lightning':dx=0
        elif asset_id in ('will_o_wisp_aura','frost_shockwave','ice_vortex'):
            dx=round(w/2-(b[0]+b[2])/2);dy=round(h/2-(b[1]+b[3])/2)
        elif asset_id=='rune_missile':
            points=[(x,y) for y in range(h) for x in range(w) if (p:=f.getpixel((x,y)))[3] and min(p[:3])>150 and p[0]>220]
            if points:
                dx=round(21-sum(x for x,y in points)/len(points));dy=round(15-sum(y for x,y in points)/len(points))
        if dx or dy:
            if b[0]+dx<2 or b[2]+dx>w-2 or b[1]+dy<2 or b[3]+dy>h-2: raise ValueError(f'Alignment would clip frame {index}: {(dx,dy)}')
            shifted=Image.new('RGBA',(w,h));shifted.paste(f,(dx,dy));frames[index]=shifted
        translations.append([dx,dy])
    colors=Counter(p[:3] for f in frames for p in f.getdata() if p[3])
    if palette_from:
        other=Image.open(palette_from).convert('RGBA')
        palette=list(dict.fromkeys(p[:3] for p in other.getdata() if p[3]))
        if len(palette)>48: raise ValueError('Reference palette >48 colors')
        pal=Image.new('P',(1,1));flat=[c for p in palette for c in p]
        pal.putpalette(flat+[0]*(768-len(flat)))
    else:
        pixels=list(colors.elements())
        sample=Image.new('RGB',(len(pixels),1));sample.putdata(pixels)
        quant=sample.quantize(colors=min(32,len(colors)),method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
        pal=quant
    normalized=[]
    for f in frames:
        q=f.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(f.getchannel('A'))
        q.putdata([p if p[3] else (0,0,0,0) for p in q.getdata()])
        normalized.append(q)
    sheet=Image.new('RGBA',(w*n,h))
    for i,f in enumerate(normalized):sheet.paste(f,(i*w,0))
    name=f'{asset_id}_{version}'
    path=ROOT/'candidates'/f'{name}.png';sheet.save(path)
    panels=Image.new('RGB',(max(w*n*4,640),h*5+64),BG);d=ImageDraw.Draw(panels)
    d.text((4,4),f'{asset_id} {w}x{h} x {n} | native 1x then nearest 4x',fill='white')
    for i,f in enumerate(normalized):
        c=Image.new('RGB',(w,h),BG);c.paste(f,mask=f.getchannel('A'))
        panels.paste(c,(i*w,24));panels.paste(c.resize((w*4,h*4),Image.Resampling.NEAREST),(i*w*4,h+40))
    panels.save(ROOT/'previews'/f'{name}_review.png')
    gif=[]
    for f in normalized:
        c=Image.new('RGB',(w,h),BG);c.paste(f,mask=f.getchannel('A'));gif.append(c.resize((w*4,h*4),Image.Resampling.NEAREST))
    if n>1:gif[0].save(ROOT/'previews'/f'{name}.gif',save_all=True,append_images=gif[1:],duration=[120,130,120,130],loop=0,disposal=2,optimize=False)
    report={'id':asset_id,'version':version,'original_size':raw.size,'grid':[cols,rows],'source_cell':[cw,ch],'union_crop':union,'scale':scale,'placement':[ox,oy,sw,sh], 'size':sheet.size,'colors':len(set(p[:3] for p in sheet.getdata() if p[3])),'alpha':sorted(set(sheet.getchannel('A').getdata())),'frame_boxes':[f.getbbox() for f in normalized], 'unique_frames':len(set(f.tobytes() for f in normalized)), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'palette_reference':str(palette_from) if palette_from else '32 colors extracted from this generated original','status':'candidate_not_reviewed'}
    report['whole_frame_translations']=translations
    report['formatted_source']=str(source_path.relative_to(ROOT))
    report['fit_mode']='common independent x/y scale for vertical effect' if asset_id=='lightning' and version=='v02' else 'uniform nearest-neighbor'
    (ROOT/'records'/f'normalization_{name}.json').write_text(json.dumps(report,indent=2))
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('ids',nargs='+');p.add_argument('--version',default='v01');p.add_argument('--palette-from');args=p.parse_args()
    for asset_id in args.ids: print(json.dumps(normalize(asset_id,args.version,args.palette_from)))
