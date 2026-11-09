"""Author the preview FX with the existing pixel, timing and footprint contracts."""
from pathlib import Path
import hashlib
import json
import math
import random

import numpy as np
from PIL import Image, ImageColor, ImageDraw
from effects import A, B, DIR, M, ALPHAS, ca, strip, xy

ARCHIVE=B/'candidates/vfx-before-polish'
ARCHIVE.mkdir(exist_ok=True)

# Shadow, body, rim, flash, secondary motif.
PAL={
 'steel':('#1e2b41','#607793','#a9c4db','#f2fbff','#779cbf'),
 'ruby':('#231422','#702642','#b75468','#ffe9ef','#e08a98'),
 'swift':('#273849','#6884a6','#c1d9e7','#f6ffff','#8cabd0'),
 'water':('#10333d','#24696d','#63c9c2','#ecfff5','#95ebdc'),
 'oni':('#21101b','#6c2238','#a84253','#ffd5df','#d46a78'),
 'gold':('#382935','#926746','#d4a866','#fff2c2','#e9c689'),
 'ice':('#172743','#3d6190','#82b9e2','#f3f9ff','#a6dafa'),
 'purple':('#221e3d','#564784','#a58dd0','#efe0ff','#c0a8e3'),
 'ink':('#121323','#393a55','#7b8294','#f5f0ef','#bdc1d4'),
 'jade':('#112e32','#266459','#66bf9e','#ecffda','#a0dca9'),
 'lake':('#1b3049','#416c95','#8cc8e8','#fff2d4','#ebcb83'),
 'qi':('#1b3440','#3d7880','#83babb','#effffa','#b9e0ce'),
}
MAIN={
 'katana_slash':('steel','steel'),
 'muramasa_slash':('ruby','ribbon'),
 'monohoshizao_slash':('swift','swallow'),
 'duanshui_slash':('water','water'),
 'duanshui_scar':('water','scar'),
 'higekiri_slash':('steel','fold'),
 'higekiri_oni_slash':('oni','cross'),
 'ganjiang_slash':('gold','split'),
 'moye_slash':('ice','split'),
 'zhuxian_slash_zhu':('gold','flight'),
 'zhuxian_slash_lu':('ruby','flight'),
 'zhuxian_slash_xian':('purple','flight'),
 'zhuxian_slash_jue':('ink','flight'),
 'qinglong_sweep':('jade','scale'),
 'qinglong_sweep_360':('jade','scale'),
 'qinglong_spin':('jade','wheel'),
 'qinglong_heavy':('jade','heavy'),
 'excalibur_slash':('lake','fold'),
 'riyue_sun_sweep':('gold','sun'),
 'riyue_moon_thrust':('ice','needle'),
 'riyue_sun_wheel':('gold','wheel'),
 'chunyang_slash':('qi','brush'),
}
LIMITS={'duanshui_scar':192,'higekiri_oni_aura':160,'higekiri_oni_horns':160,'qinglong_avatar':160,'excalibur_guard':120}

def colors(name):
    return np.array([ImageColor.getrgb(c) for c in PAL[name]])

def alpha_levels(a,cap=255):
    levels=ALPHAS[ALPHAS<=cap]
    return levels[np.abs(a.astype(float)[...,None]-levels).argmin(axis=2)]

def arcs(e, family, motif):
    w,h=e['size']
    ox,oy=e['anchor']
    r=e['radius']; half=math.radians(e['angle']/2)
    yy,xx=np.mgrid[:h,:w]
    rr=np.hypot(xx-ox,yy-oy)
    theta=np.arctan2(yy-oy,xx-ox)
    u=np.clip((theta+half)/(2*half),0,1)
    dr=r-rr
    bounds=(rr<=r+.36)&(abs(theta)<=half+.001)
    rgb=colors(family)
    count=e['frames']
    salt=int(hashlib.sha256(e['id'].encode()).hexdigest()[:8],16)
    depth={'steel':11,'ribbon':14,'swallow':22,'water':20,'scar':14,'fold':15,'cross':9,
           'split':19,'scale':24,'wheel':20,'heavy':28,'sun':24,'needle':19,'brush':14,'flight':8}[motif]
    out=[]
    for n in range(count):
        angle_fraction=(.61,1,1,1)[min(n,3)] if e['play']=='once' else 1
        envelope=bounds&(u<=angle_fraction)
        alpha=np.zeros((h,w),dtype=float)
        c=np.zeros((h,w,3),dtype=np.uint8)
        fade=([.68,1,.79,.42,.29,.17][min(n,5)] if e['play']=='once' else .86+.11*math.sin(n*math.tau/count))
        if motif=='scar':
            fade*=([.44,.78,1,.96,1,.94,.58,.32][n])
        def paint(mask,index,opacity):
            mask=mask&envelope
            c[mask]=rgb[index]
            alpha[mask]=np.maximum(alpha[mask],opacity*fade)
        taper=.14+.86*np.sin(u*np.pi)**.69
        if e['angle']==360:
            taper=.60+.40*(.5+.5*np.cos(theta*3+n*math.tau/count))
        wave=np.sin(theta*(17 if motif in ('water','scar','scale') else 5)-n*1.16)
        span=depth*taper*(.91+.13*wave)
        if motif=='needle':
            span*=.38+.62*np.exp(-(theta/.24)**2)
        if motif=='flight':
            # Small return wave at maximum travel, so the projectile reads as a straight launch.
            paint((dr>=-.36)&(dr<.9),1,72)
            for k in (-1,0,1):
                yy0=k*(7+rr*.14)
                center=(yy-oy)-yy0
                active=(xx-ox>24+n*11)&(xx-ox<r-4)&(abs(center)<(1.1 if k else 2.2))
                paint(active,1,158)
                paint(active&(abs(center)<.65),3 if not k else 4,235)
        else:
            paint((dr>=-.36)&(dr<span+4),0,160)
            paint((dr>=1)&(dr<span*.68),1,201)
            paint((dr>=1)&(dr<2.8+.75*wave),2,244)
            paint((dr>=-.36)&(dr<1.18)&((np.sin(u*math.pi)>.24)|(n==1)),3,255)
            inner=span*.91+3+1.8*np.sin(theta*8+n)
            paint((dr>3)&(abs(dr-inner)<1.35)&(u>.07)&(u<.95),4,177)
            if motif in ('water','scar'):
                foam=np.sin(theta*42-n*1.6)+.65*np.cos(theta*77+n*.7)
                paint((dr>2)&(dr<span*.82)&(foam>1.03),3,214)
                paint((dr>=6)&(abs(dr-9-wave*2)<1.6)&(foam>.02),2,192)
            if motif in ('scale','wheel','sun','heavy'):
                teeth=np.sin(theta*(34 if motif=='scale' else 19)+dr*.39+n*.8)
                paint((dr>2)&(dr<span+3)&(teeth>.77),4,206)
            if motif in ('ribbon','cross','split','swallow','brush'):
                lane=7+17*np.sin(u*np.pi)**2 + 3*np.sin(theta*5+n)
                if motif=='cross':lane=6+35*abs(u-.57)
                paint((dr>3)&(abs(dr-lane)<2.0),1,216)
                paint((dr>3)&(abs(dr-lane)<.7),4,241)
            if motif=='swallow':
                paint((dr>=3)&(dr<9)&(abs(theta)<.21),3,255)
            if motif=='needle':
                spine=(abs(yy-oy)<(1.1+rr*.02))&(rr>r*.37)&(dr>3)
                paint(spine,2,202)
                paint(spine&(abs(yy-oy)<1.3),3,247)
        # Fragment clusters seeded once per blade. Each spark advances along the cut.
        rng=random.Random(salt)
        marks=28 if motif not in ('flight','needle') else 13
        for j in range(marks):
            where=rng.uniform(.05,.95)
            radial=rng.uniform(5,depth*1.75+7)
            reach=rng.randrange(2,8)
            u0=min(.985,where+n*.019)
            if u0>angle_fraction:continue
            angle=(2*u0-1)*half
            radius=r-radial+n*1.05
            if motif=='flight' and abs(angle)>.37:continue
            a=xy(ox,oy,radius,angle)
            b=xy(ox,oy,radius-reach*.46,angle-.016-reach/r*.4)
            mask=Image.new('1',(w,h))
            d=ImageDraw.Draw(mask)
            d.line([a,b],fill=1,width=2 if j%7==0 else 1)
            if j%8==0 and n in (0,1,2):
                d.line((a[0]-2,a[1],a[0]+2,a[1]),fill=1)
                d.line((a[0],a[1]-2,a[0],a[1]+2),fill=1)
            paint(np.asarray(mask),3 if j%6==0 else 4,237 if j%6==0 else 157)
        if motif=='heavy' and n in (1,2,3):
            for k in (-1,-.65,-.29,.25,.65,1):
                pts=[xy(ox,oy,r*d,k+.05*math.sin(d*31+n)) for d in (.10,.21,.38,.54,.62)]
                mask=Image.new('1',(w,h))
                ImageDraw.Draw(mask).line(pts,fill=1,width=2)
                paint(np.asarray(mask),1,155)
        data=np.dstack((c,alpha_levels(alpha,LIMITS.get(e['id'],255))))
        out.append(Image.fromarray(data.astype('uint8'),'RGBA'))
    return strip(out)

def ornament(e,path):
    """Add directional glints to the existing small effects without changing their anchors."""
    source=Image.open(path).convert('RGBA')
    w,h=e['size']
    cap=LIMITS.get(e['id'],255)
    family=next((value[0] for key,value in MAIN.items() if key.startswith(e['weapon']+'_')),'ice' if e['id'].startswith('moye') else 'gold')
    pal=PAL[family]
    frames=[]
    for n in range(e['frames']):
        frame=source.crop((n*w,0,(n+1)*w,h))
        d=ImageDraw.Draw(frame)
        solid=np.asarray(frame)[:,:,3]
        ys,xs=np.where(solid>=min(cap,80))
        if len(xs):
            rng=random.Random(f"{e['id']}-{n}")
            for j in range(min(13,max(3,len(xs)//26))):
                k=rng.randrange(len(xs))
                x,y=int(xs[k]),int(ys[k])
                # Leave the outer columns of repeatable textures intact.
                if e.get('tile') and (x<4 or x>w-5):continue
                direction=-1 if j%2 else 1
                d.line((x,y,x+direction*(j%4+1),y-1),fill=ca(pal[4],min(cap,120)))
                if j%4==0:
                    d.point((x,y),fill=ca(pal[3],min(cap,224)))
        frames.append(frame)
    return strip(frames)

def save(e,im):
    file=A/e['file']
    backup=ARCHIVE/file.name
    if file.is_file() and not backup.is_file():backup.write_bytes(file.read_bytes())
    im.save(file)
    im.save(B/'approved'/file.name)

def main():
    entries=json.loads(M.read_text())
    kat=next(e for e in entries if e['id']=='katana_slash')
    kat.pop('reused',None)
    kat.update(file='sprites/effects/weapons/swordsman/katana_slash.png',size=[115,225],anchor=[2,112],
               label='太刀 · 银白回锋',radius=110,angle=120,anchor_type='player')
    if not any(e['id']=='moye_slash' for e in entries):
        i=next(i for i,e in enumerate(entries) if e['id']=='ganjiang_slash')
        entries.insert(i+1,entries[i]|dict(id='moye_slash',label='莫邪 · 霜蓝反切',file='sprites/effects/weapons/swordsman/moye_slash.png'))
    for e in entries:
        original=ARCHIVE/Path(e['file']).name
        if e['id'] in MAIN:
            im=arcs(e,*MAIN[e['id']])
        else:
            im=ornament(e,original if original.exists() else A/e['file'])
        save(e,im)
    M.write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':
    main()
