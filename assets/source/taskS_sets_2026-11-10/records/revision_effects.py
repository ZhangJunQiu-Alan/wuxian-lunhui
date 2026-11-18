import math
import random

from PIL import Image, ImageDraw

from pixels import save
from revision_pixels import EFFECTS

EXTRA = {
    'xingtian_mengzhi': dict(kit='xingtian', label='猛志 · 受击叠层',
        size=[64,64], frames=6, fps=16, anchor=[32,32], play='once',
        event='刑天套装受击叠加或刷新猛志', layer='身体后方叠加'),
}
REPLACE = {
    'dragonslayer_scale': dict(event='龙鳞充能完毕，鳞片闪在胸腰与身侧，头部留空'),
    'yellowwind_storm': dict(event='持续期间随判定中心移动。独立龙卷，无可见地环'),
    'yellowwind_storm_start': dict(event='风柱由下向上卷起，无可见地环'),
    'yellowwind_storm_end': dict(event='风柱被拉散成沙尘，无可见地环'),
    'lotus_proc': dict(event='追加攻击触发，角色背后绽放莲花'),
    'valhalla_ring': dict(size=[64,32], frames=8, fps=12, anchor=[32,19],
        event='独立英灵脚下的符文光环', layer='地面和分身之间'),
}


def path(d, points, color, width=1):
    d.line(points, fill=color, width=width)


def star(d,x,y,r,light,shade):
    if r>1:
        path(d,[(x-r,y),(x+r,y)],shade)
        path(d,[(x,y-r),(x,y+r)],shade)
    d.point((x,y),fill=light)


def dragon(d,n):
    positions=[(22,35),(27,40),(36,37),(41,34),(19,43),(43,43)]
    for i,(x,y) in enumerate(positions):
        lit=(i-n)%4 in (0,1)
        edge='#819481' if lit else '#586a5d'
        fill='#537259' if lit else '#394a43'
        d.polygon([(x,y-3),(x+3,y-1),(x+2,y+2),(x,y+4),(x-2,y+2),(x-3,y-1)],
                  fill=fill,outline='#253632')
        path(d,[(x-2,y-1),(x,y-2),(x+2,y-1)],edge)
        d.point((x,y),fill='#c8c29e' if lit else '#758c73')
    x,y=positions[n]
    star(d,x+3,y-4,1,'#ded2ae','#7b917b')
    d.point((x-3,y+3),fill='#9eab8b')


def wind(d,n,mode):
    power={'loop':1.0,'start':(0.33,0.60,0.88),'end':(0.80,0.51,0.27)}[mode]
    power=power if mode=='loop' else power[n]
    phase=(n+(5 if mode=='end' else 0))*math.tau/6
    back='#5c554c'
    dark='#75664f'
    sand='#a58a5f'
    lit='#d1b685'
    bright='#e5cc9c'
    drift=(0 if mode!='end' else n*5)
    # Each turn follows one continuous ascending spiral, widening toward the top.
    for turn in range(7):
        t=(turn+0.2)/7
        cy=73-57*power*t
        cx=47.5+drift+math.sin(3.5*t+phase*.23)*6*t
        r=(3.5+31*t**.78)*power
        for side in (0,1):
            coords=[]
            for i in range(23):
                a=phase+turn*1.63+i*.118+side*math.pi
                px=round(cx+math.cos(a)*r)
                py=round(cy+math.sin(a)*min(r*.23,5.2)-i*.37*power)
                coords.append((px,py))
            if side==0:
                path(d,coords,back,3 if power>.5 else 2)
                path(d,coords[1:21],dark)
                path(d,coords[3:8],sand)
            else:
                path(d,coords,dark,4 if power>.66 else 2)
                path(d,coords[2:21],sand,2)
                path(d,coords[6:15],lit)
                path(d,coords[9:12],bright)
    rng=random.Random(701+17*n)
    for i in range(round(112*power)+12):
        t=rng.random()
        x=47+drift+rng.uniform(-1,1)*(13+24*t)*power
        y=76-60*t*power+rng.uniform(-5,7)
        if mode=='end':
            x+=rng.uniform(0,15)*n
            y+=rng.uniform(-4,5)*n
        x,y=round(x),round(y)
        if 1<=x<=94 and 2<=y<=103:
            color=rng.choice([back,dark,dark,sand,lit])
            d.point((x,y),fill=color)
            if i%9==0:
                path(d,[(x,y),(x+2,y-1)],color)
    # A few broken sand streaks at the contact point give depth without forming a ring.
    for i in range(7):
        side=-1 if i%2==0 else 1
        a=round(48+drift+side*(5+i*2)*power)
        y=74+(i+n)%5
        path(d,[(a,y),(a+side*(1+i%3),y-1)],back if i%2 else dark)


def lotus(d,n):
    spread=(.67,.90,1.0,.94)[n]
    dark=('#5b3b54','#633e58','#603c57','#524052')[n]
    rose=('#94637f','#b6698c','#c97f9e','#86556f')[n]
    blush=('#c994a7','#e1a2b5','#edb6c3','#b47c95')[n]
    glint=('#dfb6ab','#f7d1be','#ffe5cc','#d5a3a3')[n]
    ox,oy=32,48
    def petal(points,fill):
        shape=[(round(ox+(x-ox)*spread),round(oy+(y-oy)*spread)) for x,y in points]
        d.polygon(shape,fill=fill,outline=dark)
        path(d,shape[:3],blush)
        d.point(shape[1],fill=glint)
    petal([(27,47),(31,13),(36,24),(39,37),(36,49)],rose)
    petal([(22,48),(14,20),(23,24),(29,35),(30,49)],rose)
    petal([(41,48),(50,20),(42,24),(35,35),(34,49)],rose)
    petal([(19,48),(5,29),(13,30),(22,37),(27,49)],rose)
    petal([(44,48),(59,29),(51,30),(42,37),(37,49)],rose)
    petal([(22,51),(3,42),(12,40),(21,43),(31,51)],blush)
    petal([(42,51),(61,42),(52,40),(43,43),(33,51)],blush)
    d.polygon([(11,51),(17,47),(27,50),(32,54),(37,50),(47,47),(53,51),
               (45,55),(33,58),(20,55)],fill=dark,outline='#422e42')
    path(d,[(17,51),(25,53),(32,55),(40,53),(47,51)],rose,2)
    for i,(x,y) in enumerate([(8,23),(18,15),(46,15),(55,23),(8,48),(55,48)]):
        if n!=3 or i%2==0:
            y-=n
            d.polygon([(x,y-2),(x+2,y),(x+1,y+3),(x-1,y+2)],fill=rose)
            d.point((x,y),fill=glint)
    for x,y in [(19,53),(27,55),(37,55),(45,53)]:
        star(d,x,y,1,'#efcf92',blush)


def mengzhi(d,n):
    progress=(.43,.62,.81,1,.9,.75)[n]
    shades=('#463641','#75503c','#b58258','#efd197')
    for side in (-1,1):
        def shape(points):
            return [(32+side*round(x*progress),y) for x,y in points]
        ribbon=shape([(4,36),(10,34),(16,29),(21,27),(25,24),(23,32),(19,38),(15,43),(8,44)])
        d.polygon(ribbon,fill=shades[0],outline='#252735')
        path(d,shape([(8,39),(15,36),(21,32),(24,26)]),shades[1],3)
        path(d,shape([(12,38),(16,35),(21,32)]),shades[2],2)
        if n in (1,2,3,4):
            path(d,shape([(17,34),(22,31)]),shades[3])
        for j,(x,y) in enumerate([(21,39),(26,34),(25,45),(17,47)]):
            if j<=5-n or j%2==0:
                a,b=shape([(x,y+n)])[0]
                star(d,a,b,1+n%2,shades[3] if n<4 else shades[2],shades[1])
    if n<5:
        path(d,[(21+n,48),(27,51+n),(32,52+n),(38,51+n),(43-n,48)],shades[2])


def runes(d,n):
    gold='#b79a65'
    pale='#fff0c3'
    muted='#705f56'
    blue='#8aa8bd'
    for k in range(12):
        a=k*math.tau/12
        outer=[(round(32+27*math.cos(a+i*.031)),round(19+8*math.sin(a+i*.031))) for i in range(14)]
        inner=[(round(32+20*math.cos(a+i*.039)),round(19+5*math.sin(a+i*.039))) for i in range(10)]
        path(d,outer,muted,2)
        path(d,outer[1:13],pale if (k-n)%5==0 else gold)
        path(d,inner,blue if (k+n)%3==0 else muted)
        x=round(32+24*math.cos(a+.24))
        y=round(19+6.5*math.sin(a+.24))
        if k%2==0:
            path(d,[(x-1,y-2),(x-1,y+1),(x,y-1),(x+1,y+1)],gold)
        else:
            star(d,x,y,2,pale,blue)
    for j,(x,y) in enumerate([(9,19),(16,14),(49,14),(54,22),(21,21),(43,21)]):
        a=(n+j*3)%8
        if a<6:
            path(d,[(x,y-a),(x,y-a-2-a//3)],gold if a<4 else blue)
            d.point((x,y-a-3-a//3),fill=pale)
    for x in (5,59):
        star(d,x,19,2,pale,blue)


DRAW = {
    'dragonslayer_scale': dragon, 'yellowwind_storm': lambda d,n:wind(d,n,'loop'),
    'yellowwind_storm_start': lambda d,n:wind(d,n,'start'),
    'yellowwind_storm_end': lambda d,n:wind(d,n,'end'),
    'lotus_proc': lotus, 'xingtian_mengzhi': mengzhi, 'valhalla_ring': runes,
}


def make_effects(meta):
    for key,paint in DRAW.items():
        info=meta[key]
        w,h=info['size']
        sheet=Image.new('RGBA',(w*info['frames'],h))
        for n in range(info['frames']):
            frame=Image.new('RGBA',(w,h))
            paint(ImageDraw.Draw(frame),n)
            sheet.paste(frame,(n*w,0))
        file=key+('_r2' if key in EFFECTS else '')+'.png'
        save(sheet,'effects',file)
