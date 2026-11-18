"""Build the Round 08 paint guide and runtime layers in the game's camera projection."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
SRC = HERE.parent
DST = SRC.parents[2] / 'models/midgard/courtyard/v5_painted'
OUT = DST / 'round08'
DATA = json.loads((HERE / 'layout.json').read_text())
OLD = json.loads((SRC / '引导/projection.json').read_text())
B = np.array([OLD['basis_x'][::2], -np.array(OLD['basis_y'])[::2]])
BI = np.linalg.inv(B)
CENTER = np.array([3.9, -.1])
OLD_CENTER = np.array([2.25, .25])
S = 96
SIZE = (27*S, 18*S)


def project(points):
    return ((np.asarray(points) - CENTER) @ B.T) * S + np.array(SIZE) / 2


def smooth(t):
    t = np.clip(t, 0., 1.)
    return t*t*(3-2*t)


def expand(x, z, ramp=None):
    east = np.clip((x+5.9)/13.7, 0, 1)
    west, inner_west, inner_east, east_end = np.asarray(DATA["depth_ramp"] if ramp is None else ramp)/100
    depth = smooth((x-west)/(inner_west-west))*(1-smooth((x-inner_east)/(east_end-inner_east)))
    return x + DATA['east_shift']/100*east, z*(1+.30*depth)


def old_ground(x,z):
    shift = DATA['east_shift']/100
    ox = np.where(x < -5.9, x, np.where(x > 7.8+shift, x-shift, (x-shift*5.9/13.7)/(1+shift/13.7)))
    return ox, z/expand(ox,1.)[1]


def floor_polygon():
    a = np.array([v['world'][::2] for v in OLD['collision_anchors']])
    def side(row):
        end = 8.08
        y = np.interp([-6.42, end],row[:,0],row[:,1])
        return np.vstack(([-6.42,y[0]],row[(row[:,0]>-6.42)&(row[:,0]<end)],[end,y[1]]))
    return np.vstack((side(a[:55]),side(a[55:112])[::-1]))


def guide():
    ground = Image.open(DST/'room-ground.png').convert('RGB')
    # Inverse-project the new camera plane to the accepted full-room plate.
    def sample(px,py):
        x,z = np.array([px-SIZE[0]/2,py-SIZE[1]/2]) @ BI.T / S + CENTER
        p = (np.array(old_ground(x,z))-OLD_CENTER) @ B.T * 64 + [2688,912]
        return tuple(p)
    mesh=[]
    for y in range(0,SIZE[1],32):
        for x in range(0,SIZE[0],32):
            r,b=min(x+32,SIZE[0]),min(y+32,SIZE[1])
            mesh.append(((x,y,r,b),sum((sample(*p) for p in [(x,y),(x,b),(r,b),(r,y)]),())))
    im=ground.transform(SIZE,Image.Transform.MESH,mesh,Image.Resampling.BICUBIC)
    # The ring is exported by Godot. Use the same measured footprint on the paint guide.
    ring=project(np.array(DATA['ring'][:2])/100 + DATA['ring'][2]/100*np.array([(np.cos(t),np.sin(t)) for t in np.linspace(0,2*np.pi,361)]))
    d=ImageDraw.Draw(im)
    d.line(list(map(tuple,ring)), fill='#626478',width=9)
    im.resize((1536,1024),Image.Resampling.LANCZOS).save(HERE/'registered-guide.png')


if __name__=='__main__' and '--guide' in sys.argv:
    guide()


def engraved_ring(paint):
    chars = 'ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛟᛞ'
    font = ImageFont.truetype('/System/Library/Fonts/Apple Symbols.ttf', 102)
    if len({bytes(font.getmask(c)) for c in chars}) != len(chars):
        raise ValueError('A complete Elder Futhark font is required')
    disk = Image.new('L',(1200,1200))
    for i,c in enumerate(chars):
        angle = 2*np.pi*i/len(chars)
        letter = Image.new('L',(152,152))
        ImageDraw.Draw(letter).text((76,76),c,anchor='mm',font=font,fill=255,stroke_width=1)
        letter = letter.rotate(-360*i/len(chars),Image.Resampling.BICUBIC)
        disk.paste(letter,(round(524+480*np.sin(angle)),round(524-480*np.cos(angle))))
    carved = Image.new('L', paint.size)
    carved.paste(disk.resize((294,216),Image.Resampling.LANCZOS),(581,370))
    # Warm upper lip and recessed blue-gray inner groove retain the stone texture.
    rgb=np.asarray(paint,dtype=float)
    ink=np.asarray(carved)/255.
    snow=np.clip((180-rgb[:,:,0])/45,0,1)
    relief=(np.roll(ink,(1,1),axis=(0,1))*.21-ink*.58)*snow
    return Image.fromarray(np.clip(rgb*(1+relief[:,:,None]),0,255).astype('uint8'))


def hall_layers():
    atlas=Image.open(DST/'longhouse.png').convert('RGBA')
    alpha=atlas.getchannel('A')
    box=alpha.getbbox()
    box=(box[0]-24,box[1]-24,box[2]+24,box[3]+24)
    local=alpha.crop(box)
    color=Image.open(SRC/'court-paint.png').convert('RGB').crop(tuple(v-o for v,o in zip(box,(384,256,384,256))))
    # A backing strip from the same painting spans both sides of every cut.
    # It also restores the natural dark room through the gaps between the rafters.
    backing=color.copy()
    backing.putalpha(local.filter(ImageFilter.MaxFilter(27)).filter(ImageFilter.GaussianBlur(3)))
    plate=Image.new('RGBA',atlas.size)
    plate.paste(backing,box[:2])
    plate.save(OUT/'hall-backing.png')
    core=local.filter(ImageFilter.MinFilter(7))
    colors=np.asarray(color).copy()
    known=np.asarray(core)>200
    for _ in range(8):
        sums=np.zeros_like(colors,dtype=float)
        counts=np.zeros(known.shape,dtype=float)
        for dy,dx in [(-1,0),(0,1),(1,0),(0,-1)]:
            live=np.roll(known,(dy,dx),(0,1))
            sums+=np.roll(colors,(dy,dx),(0,1))*live[:,:,None]
            counts+=live
        fill=(~known)&(counts>0)
        colors[fill]=(sums[fill]/counts[fill,None]).round().astype('uint8')
        known|=fill
    cut=Image.fromarray(colors)
    cut.putalpha(local.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(.55)))
    layer=Image.new('RGBA',atlas.size)
    layer.paste(cut,box[:2])
    layer.save(OUT/'longhouse.png')


def build_layers():
    OUT.mkdir(exist_ok=True)
    hall_layers()
    original=Image.open(HERE/'court-paint.png').convert('RGB')
    detail=Image.open(HERE/'court-ground-detail.png').convert('RGB')
    ring_mask=Image.new('L',original.size)
    ImageDraw.Draw(ring_mask).ellipse((531,338,923,620),fill=255)
    paint=Image.composite(engraved_ring(original),detail,ring_mask.filter(ImageFilter.GaussianBlur(3)))
    mask=Image.new('L',paint.size)
    # Follow the inner snow banks. The original gate, cliff and hall stay on their own plates.
    contour=[(144,552),(170,425),(238,342),(349,259),(490,193),(510,146),
             (620,110),(756,108),(885,137),(1038,164),(1152,218),
             (1270,292),(1300,355),(1320,414),(1278,562),(1224,685),
             (1149,757),(1000,844),(878,896),(713,929),(538,921),
             (446,867),(358,828),(328,777),(337,677),(286,627),(196,586)]
    ImageDraw.Draw(mask).polygon(contour,fill=255)
    # Keep the hall's existing masonry behind its rafters. The fallen rack has its own foot depth.
    ImageDraw.Draw(mask).polygon([(487,134),(521,73),(745,46),(794,157),(687,181),(501,220)],fill=0)
    mask=mask.filter(ImageFilter.GaussianBlur(16))
    shade=Image.new('L',paint.size)
    for _,x,z,r,w,h in DATA['covers']:
        cx,cy=project([x/100,z/100])*np.array(paint.size)/SIZE
        a=w*paint.width/27
        ImageDraw.Draw(shade).polygon([(cx-.44*a,cy-.08*a),(cx-.25*a,cy-.25*a),
            (cx+.77*a,cy-.17*a),(cx+1.12*a,cy+.06*a),(cx+.59*a,cy+.14*a),
            (cx+.06*a,cy+.10*a)],fill=62)
    paint=Image.composite(Image.new('RGB',paint.size,'#29314d'),paint,shade.filter(ImageFilter.GaussianBlur(4)))
    paint.putalpha(mask)
    # Register the painted northern and southern shoulders to the final net-area adjustment.
    size=np.array(paint.size)
    def ref_sample(px,py):
        x,z = (np.array([px,py])-size/2) @ BI.T * (27/size[0]) + CENTER
        ox,oz=old_ground(x,z)
        original=expand(ox,oz,[-620,-290,500,805])
        return tuple((np.array(original)-CENTER) @ B.T * size[0]/27 + size/2)
    quads=[]
    for y in range(0,paint.height,32):
        for x in range(0,paint.width,32):
            r,b=min(x+32,paint.width),min(y+32,paint.height)
            quads.append(((x,y,r,b), sum((ref_sample(*p) for p in [(x,y),(x,b),(r,b),(r,y)]),())))
    paint.transform(paint.size,Image.Transform.MESH,quads,Image.Resampling.BICUBIC).save(OUT/'court-floor.png')
    old=Image.open(DST/'parapets.png').convert('RGBA')
    for box in [(448,482,537,544),(642,383,693,442)]:
        ImageDraw.Draw(old).rectangle(tuple(x*2 for x in box),fill=(0,0,0,0))
    old.save(OUT/'parapets.png')
    rack=Image.open(HERE/'broken-rack.png').convert('RGBA')
    rack=rack.crop(rack.getchannel('A').point(lambda a:255 if a>28 else 0).getbbox())
    rack.thumbnail((720,400),Image.Resampling.LANCZOS)
    rack.save(OUT/'broken-rack.png')
    sheet=Image.open(SRC/'court-cover-r08.png').convert('RGBA')
    for cover,limits in zip(DATA['covers'],[(0,720),(720,1448),(1448,2172)]):
        tile=sheet.crop((limits[0],0,limits[1],sheet.height))
        alpha=tile.getchannel('A')
        tile.crop(alpha.point(lambda a:255 if a>20 else 0).getbbox()).save(OUT/(cover[0]+'.png'))


if __name__=='__main__' and '--guide' not in sys.argv:
    build_layers()
