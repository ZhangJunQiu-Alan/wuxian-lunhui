from body import B, ROOT, publish, strip
from PIL import Image, ImageDraw, ImageColor
import math, random, json, sys
import numpy as np

A=ROOT/'assets'
DIR=A/'sprites/effects/weapons/swordsman'
UI=A/'sprites/ui/weapons/swordsman'
DIR.mkdir(parents=True,exist_ok=True); UI.mkdir(parents=True,exist_ok=True)
M=DIR/'manifest.json'
C=math.cos; S=math.sin; P=math.pi
STEEL=('#485266','#b0bed1','#e8f0ff')
BLOOD=('#391625','#9e1b32','#e4c6cc')
WATER=('#1b5258','#7fe0d4','#e5fff6')
ONI=('#240f1b','#8a2338','#c4203a')
GOLD=('#604230','#d9a441','#ffe7a0')
BLUE=('#224266','#6b9dc7','#c8d8ff')
JADE=('#1a5450','#3fbf9f','#e0fff0')
LAKE=('#25537c','#8fd0ff','#ffe08a')
INDIGO=('#28243e','#6c60a4','#c1aee7')
INK=('#111019','#464357','#efe9df')
WHITE=('#45646b','#bff3ff','#e6f7ff')
ALPHAS=np.array([0,40,80,120,160,192,224,255])
def ca(col,a):
    return (*ImageColor.getrgb(col),int(ALPHAS[abs(ALPHAS-a).argmin()]))
def new(size): 
    im=Image.new('RGBA',size);return im,ImageDraw.Draw(im)
def xy(cx,cy,r,t):
    return round(cx+C(t)*r),round(cy+S(t)*r)
def spark(d,x,y,light,mid,power=2):
    d.line((x-power,y,x+power,y),fill=mid)
    d.line((x,y-power,x,y+power),fill=mid)
    d.point((x,y),fill=light)
def polyline(d,points,col,width=1):
    d.line([(round(x),round(y)) for x,y in points],fill=col,width=width)

def arc(radius,angle,n,pal,style='steel'):
    r=radius
    ang=math.radians(angle/2)
    cx=cy=r+2
    w=2*r+5 if angle>180 else r+5
    if angle<=180:cx=2
    h=2*r+5
    yy,xx=np.mgrid[:h,:w]
    X=xx-cx;Y=yy-cy
    R=np.hypot(X,Y);T=np.arctan2(Y,X)
    u=(T+ang)/(2*ang);u=np.clip(u,0,1)
    cols=[ImageColor.getrgb(x) for x in pal]
    frames=[]
    for i in range(n):
        t=i/(n-1)
        extent=min(1,.58+i*.42) if style not in ('spin','scar','wheel') else 1
        inangle=(abs(T)<=ang+.0001)&(u<=extent)
        wave=np.sin(T*(12 if style in ('water','scar') else 5)+i*.9)
        dr=r-R
        taper=np.maximum(.24,np.sin(u*np.pi)**.65)
        thick={'gold':17,'jade':18,'spin':16,'heavy':19,'water':10,'scar':14,'tip':12,'oni':3,'red':3,'ink':15,'wheel':10}.get(style,8)
        if style=='scar': thick=14
        if style=='tip': thick=22
        decay=(.65,.99,.76,.46,.24,.12)[min(i,5)]
        if style in ('spin','scar'):decay=(.70+.20*math.sin(t*P*2))
        if style=='scar':decay*=([.45,.75,1,1,1,1,.55,.25][i])
        if style=='wheel':decay=(.55,1,.95,.75,.5,.22)[i]
        profile=thick*taper
        rind=1.65+.6*wave
        if style in ('water','scar'):rind+=.8*np.sin(T*30+i)
        if style=='tip':
            profile=19*taper
            core_tip=(dr>10)&(dr<r*.32)&(np.abs((dr+wave*2)%11-2)<1.4)
        else:core_tip=np.zeros_like(R,dtype=bool)
        alpha=np.zeros(R.shape)
        rgb=np.zeros((h,w,3),np.uint8)
        def coat(mask,col,a):
            mask=mask&inangle&(R<=r+.4)
            alpha[mask]=a;rgb[mask]=cols[col]
        coat((dr>=-.35)&(dr<profile+2),0,160*decay)
        coat((dr>=1)&(dr<profile*(.68+.14*wave)),1,224*decay)
        if style=='scar':
            coat((dr>4)&(dr<8),0,0)
            coat((dr>8+wave)&(dr<10+wave),1,192*decay)
        coat((dr>=-.45)&(dr<rind),2,255*decay)
        coat(core_tip,1,64*decay)
        if style=='oni':
            # Two crossing curves kept inside the attack envelope.
            coat((dr>1)&(np.abs(dr-(3+26*abs(u-.55)))<2.2),0,192*decay)
            coat((dr>2)&(np.abs(dr-(3+26*abs(u-.55)))<.85),2,255*decay)
        if style in ('heavy','wheel'):
            for j in range(1,22):
                q=-ang+j*ang/11+(i*.025 if style=='wheel' else 0)
                tooth=abs(T-q)<(.006+j%3*.002)
                coat(tooth&(dr>1)&(dr<18+j%5*3),1,224*decay)
        rgba=np.zeros((h,w,4),np.uint8);rgba[:,:,:3]=rgb
        rgba[:,:,3]=ALPHAS[np.abs(alpha[:,:,None]-ALPHAS).argmin(axis=2)]
        im=Image.fromarray(rgba)
        d=ImageDraw.Draw(im);rng=random.Random(619+i)
        for j in range(12 if style not in ('steel','red','oni') else 5):
            theta=-ang+2*ang*rng.uniform(.025,max(.026,extent-.025))
            rr=r-rng.uniform(3,thick*1.9)
            x,y=xy(cx,cy,rr,theta)
            color=ca(pal[1],max(40,180*decay))
            d.point((x,y),fill=color)
            if j%4==0:d.point((x-1,y+1),fill=ca(pal[2],max(40,180*decay)))
        if style=='heavy':
            for j in range(8):
                q=-1.4+j*.4
                points=[xy(cx,cy,k*(i+2),q+S(k)*.13) for k in [1,4,8,12,16]]
                d.line(points,fill=ca(pal[0],192*decay),width=2)
                d.line(points[2:],fill=ca(pal[1],160*decay))
        frames.append(im)
    return frames,[cx,cy]

def accents(size,n,pal,kind):
    w,h=size;cx=w//2;cy=h//2;frames=[]
    for i in range(n):
        t=i/max(1,n-1);im,d=new(size)
        rng=random.Random(3303)
        fade=max(.16,1-t*.86)
        dark,mid,light=[ca(c,160 if j==0 else 192 if j==1 else 255) for j,c in enumerate(pal)]
        if kind in ('tip','full','swap'):
            if kind=='tip':
                dx=int(t*11)-5
                d.polygon([(cx-12+dx,cy-6),(cx-4+dx,cy-4),(cx+dx,cy),(cx+8+dx,cy-4),(cx+13+dx,cy-5),(cx+7+dx,cy+1),(cx+2+dx,cy+3),(cx-2+dx,cy+7),(cx-4+dx,cy+2),(cx-8+dx,cy)],fill=ca(pal[1],200*fade))
                polyline(d,[(cx-10+dx,cy-5),(cx-4+dx,cy-4),(cx+dx,cy+1),(cx+9+dx,cy-3)],ca(pal[2],255*fade))
            elif kind=='full':
                rr=4+i*4
                d.polygon([(cx,cy-rr),(cx+2,cy-2),(cx+rr,cy),(cx+2,cy+2),(cx,cy+rr),(cx-2,cy+2),(cx-rr,cy),(cx-2,cy-2)],fill=ca(pal[1],184*fade))
                spark(d,cx,cy,light,ca(pal[2],245*fade),max(2,rr//2))
            else:
                r=7+i;dx=5-i*3
                d.arc((cx-r+dx,cy-r,cx+r+dx,cy+r),0,360,fill=ca(pal[2],255*fade),width=2)
                for j in range(8):
                    q=j*P/4
                    d.line([xy(cx+dx,cy,r+2,q),xy(cx+dx,cy,r+4,q)],fill=ca(pal[1],195*fade))
                d.arc((cx-r-dx,cy-r,cx+r-dx,cy+r),55,285,fill=ca('#c8d8ff',255*fade),width=3)
        elif kind in ('thirst','aura','guard','exhaust','avatar'):
            if kind=='avatar':
                p=[]
                for j in range(52):
                    q=j/52*P*1.65+i*P/3
                    rr=44-j*.33
                    p.append((cx+rr*C(q),cy+rr*.82*S(q)))
                for j in range(len(p)-1):
                    width=1+int(7*(1-j/(len(p)-1))**.9)
                    polyline(d,p[j:j+2],ca(pal[0],160),width)
                    if j%3!=2:polyline(d,[(x,y-1) for x,y in p[j:j+2]],ca(pal[1],160),max(1,width//3))
                    if j%5==0:d.point((int(p[j][0])+1,int(p[j][1])-1),fill=ca(pal[2],120))
                x,y=map(round,p[0]);q=i*P/3
                dx,dy=-S(q),C(q)
                polyline(d,[(x-dx*4,y-dy*4),(x+dx*10,y+dy*10)],ca(pal[1],160),4)
                for s in (-1,1):
                    a=(x+int(C(q)*6*s),y+int(S(q)*6*s))
                    polyline(d,[(x,y),a,(a[0]-int(dx*3),a[1]-int(dy*3))],ca(pal[1],160))
                d.point((x+int(dx*4),y+int(dy*4)),fill=ca('#c5e69d',160))
            elif kind=='guard':
                for j in range(6):
                    k=(j+i)%6
                    box=(13+k%2,12+k%2,51-k%2,59-k%2)
                    d.arc(box,j*60+i*11,j*60+i*11+38,fill=ca(pal[1 if j%2 else 2],80 if j%2 else 120),width=1)
                d.arc((17,48,47,60),2+i*5,173,fill=ca(pal[1],80),width=2)
            else:
                center={'thirst':(37,34),'aura':(32,38),'exhaust':(32,24)}[kind]
                for j in range(9 if kind=='aura' else 6):
                    theta=j*2.4+i*.37
                    r=6+j*.8
                    x,y=xy(*center,r,theta)
                    points=[(x+S(k*.9+theta)*2,y-k*(1 if kind=='thirst' else 2)) for k in range(5+j%3)]
                    polyline(d,points,ca(pal[0],120 if kind=='aura' else 80),2)
                    polyline(d,points[1:-1],ca(pal[1],160 if kind=='aura' else 120))
        elif kind=='horns':
            a=1+i
            for s in (-1,1):
                d.polygon([(cx+s*1,h-2),(cx+s*4,h-3),(cx+s*6,a),(cx+s*5,h-5),(cx+s*2,h-4)],fill=ca(pal[0],160))
                d.line([(cx+s*3,h-3),(cx+s*5,h-5),(cx+s*6,a)],fill=ca(pal[2],160))
        elif kind=='tipsy':
            for x in (cx-3,cx+3):d.line((x-1,cy+3,x+1,cy+3),fill=ca('#db8e92',160))
            for x,y in [(3,3-i),(10,1+i),(13,4-i)]:
                d.ellipse((x,y,x+2,y+2),outline=ca('#dab06e',160))
        elif kind=='ring':
            for j in range(8):
                d.arc((2,4,w-3,h-4),j*45+i*10,j*45+i*10+27,fill=ca(pal[1 if j%2 else 2],120+j%2*40),width=1+j%2)
            d.arc((8,8,w-9,h-8),i*38,130+i*38,fill=ca(pal[1],80),width=1)
        elif kind in ('link','dash','burst','cap','trail','qi','lunge'):
            if kind=='lunge':
                for j in range(3):
                    x=38+j*48+min(i,3)*3;y=cy+(j%2*2-1)*4
                    d.arc((x-21,y-13,x+8,y+13),-75,75,fill=ca(pal[2],240*fade),width=2)
                    d.line((max(0,x-38),y,x+9,y),fill=ca(pal[1],185*fade),width=2)
            elif kind=='cap':
                r=2+i*2
                for j in range(8):
                    q=(j-4)*.33
                    d.line([xy(5,cy,max(1,r-3),q),xy(5,cy,r+j%3*2,q)],fill=ca(pal[2 if j%2 else 1],220*fade))
            else:
                for j in range(2 if kind=='link' else 3):
                    if kind=='link':col=('#d9a441','#a8d8f0')[j]
                    elif kind in ('dash','burst'):col=pal[1+j%2]
                    else:col=pal[1+j%2]
                    points=[]
                    for x in range(w):
                        q=x/(w-1)*P*2+i*.9+j*P
                        scale=(1 if kind in ('dash','burst','link') else x/(w-1))
                        span=(1+i*2.5 if kind=='burst' else 3+j)
                        y=cy+S(q)*span*scale+(j-1)*1.0
                        if kind in ('qi','trail'):y=cy+S(q)*span*scale
                        points.append((x,y))
                    polyline(d,points,ca(col, (190 if j==0 else 230)*fade if kind=='burst' else 160+j*30),1+(j==1))
                    if kind=='link':
                        for x,y in points[3::6]:
                            polyline(d,[(x-1,y-1),(x+1,y),(x-1,y+1)],ca(col,120))
                if kind=='qi':
                    d.polygon([(w-1,cy),(w-8,cy-4),(w-14,cy),(w-8,cy+4)],fill=ca(pal[1],192))
                    d.line((w-16,cy,w-1,cy),fill=light)
                if kind=='burst':
                    for x in range(3,w,6):
                        q=x/(w-1)*P*2
                        yy=cy+int(S(q)*i*2)
                        d.line((x,yy-int(3+i*2),x+3,yy+int(3+i*2)),fill=ca(pal[1+x%2],160*fade))
        elif kind=='talisman':
            x=cx-4+(i==0)*2;y=cy-8+(i==0)*4
            d.polygon([(x,y),(x+8,y-2),(x+9,y+13),(x+1,y+15)],fill=ca('#604832',192))
            d.polygon([(x+1,y+1),(x+7,y),(x+8,y+12),(x+2,y+14)],fill=ca('#e8d27a',255))
            d.line([(x+4,y+2),(x+4,y+11),(x+2,y+8),(x+6,y+6),(x+3,y+5),(x+6,y+3)],fill=ca('#9d3940',255))
            d.point((x+5,y+12),fill=ca('#9d3940',255))
        elif kind=='execute':
            for j in range(10):
                rad=9+t*38+j%3*2
                q=j*.59-.8
                x,y=xy(cx,cy,rad,q)
                polyline(d,[(cx-7+j,cy+j//3),(x,y),(x+2,y-1)],ca(pal[j%3],255*fade),max(1,4-j%4))
            d.polygon([(cx-35,cy+15),(cx-13,cy+3),(cx+28,cy-17),(cx+38,cy-20),(cx+20,cy-8),(cx-10,cy+9)],fill=ca(pal[0],255*fade))
            d.line((cx-34,cy+15,cx+34,cy-17),fill=ca(pal[2],255*fade))
        elif kind=='bleed':
            for j in range(6):
                x=5+rng.randrange(w-10); y=3+(j*6+i*4)%(h-6)
                d.polygon([(x,y-2),(x-1,y),(x,y+1),(x+1,y)],fill=ca(pal[1 if j%2 else 0],192))
        else:  # water/whisky splashes and low dissipating whisky mist
            for j in range(14 if kind=='mist' else 10):
                q=rng.uniform(-3.1,-.02)
                radius=(3+i*1.5)*rng.uniform(.35,1.35)
                x,y=xy(cx,cy+(6 if kind=='mist' else 3),radius,q)
                y+=int(i*i*.17)
                col=ca(pal[(j%2)+1],(105 if kind=='mist' else 245)*fade)
                d.line((x,y,x+(j%3)-1,y+(1 if j%2 else 0)),fill=col,width=2 if kind=='mist' else 1)
        frames.append(im)
    return frames,[cx,cy]

def make(id,weapon,label,frames,anchor,palette=None,angle=None,radius=None,
         play='once',fps=16,layer=0,tile=False,timeline=None,anchor_type=None):
    file=f'sprites/effects/weapons/swordsman/{id}.png'
    publish(strip(frames),A/file)
    o=dict(id=id,weapon=weapon,label=label,file=file,size=list(frames[0].size),frames=len(frames),fps=fps,
           play=play,anchor=anchor,anchor_type=anchor_type or ('head' if layer==6 else 'body_frame' if layer==7 else 'player' if radius else 'effect_origin'),base_deg=0,layer=layer)
    if radius:o.update(radius=radius,angle=angle)
    if tile:o['tile']=True
    if timeline:o['timeline']=timeline
    return o
def arcfx(id,weapon,label,r,a,n,p,style='steel',**props):
    frames,anchor=arc(r,a,n,p,style);return make(id,weapon,label,frames,anchor,angle=a,radius=r,**props)
def fx(id,weapon,label,w,h,n,p,style,**props):
    frames,anchor=accents((w,h),n,p,style)
    if style=='cap':anchor=[5,h//2]
    if style in ('trail','dash','burst','link'):anchor=[0,h//2]
    if style=='horns':anchor=[w//2,h-2]
    if style=='lunge':anchor=[16,h//2]
    if style=='tipsy':anchor=[w//2,h//2-2]
    return make(id,weapon,label,frames,anchor,**props)

def qinglong():
    k='qinglong'
    return [
      arcfx(k+'_sweep',k,'普攻横扫',138,180,4,JADE,'jade'),
      arcfx(k+'_sweep_360',k,'青龙附体横扫',138,360,4,JADE,'jade'),
      arcfx(k+'_spin',k,'偃月风暴',138,360,4,JADE,'spin',play='loop'),
      arcfx(k+'_heavy',k,'松手重劈与地裂',150,180,6,JADE,'heavy'),
      fx(k+'_avatar',k,'青龙附体外圈',128,128,6,JADE,'avatar',layer=7,play='loop',fps=12),
    ]
def excalibur():
    k='excalibur'
    return [
      arcfx(k+'_slash',k,'手动挥砍',110,120,4,('#4e5567','#e4c584','#f4f5ef')),
      fx(k+'_guard',k,'收鞘护体',64,64,4,LAKE,'guard',layer=7,play='loop',fps=8),
      fx(k+'_charge_full',k,'四秒蓄满闪光',48,48,4,GOLD,'full',anchor_type='scabbard_mouth'),
      fx(k+'_dash_trail',k,'拔剑冲刺尾迹',32,24,4,LAKE,'dash',tile=True),
      fx(k+'_line_burst',k,'延迟刀痕爆开',32,48,6,LAKE,'burst',tile=True),
      fx(k+'_line_cap',k,'爆开线段端帽',32,48,6,LAKE,'cap'),
    ]
def katana():
    file='sprites/effects/katana_slash.png'
    im=Image.open(A/file)
    n=4;w=im.width//n
    return [dict(id='katana_slash',weapon='katana',label='沿用初始太刀刀光',file=file,size=[w,im.height],frames=n,
                 fps=16,play='once',anchor=[w//2,im.height//2],anchor_type='legacy',base_deg=0,layer=0,reused=True)]
def muramasa():
    k='muramasa'
    return [arcfx(k+'_slash',k,'普攻细红刃线',110,120,4,BLOOD,'red'),
            fx(k+'_thirst',k,'断连 · 渴',64,64,4,('#3b111b','#5a0f1c','#9a3a4c'),'thirst',layer=7,play='loop',fps=8)]
def monohoshizao():
    k='monohoshizao'
    return [arcfx(k+'_slash',k,'刀尖伤害区',165,90,4,STEEL,'tip'),
            fx(k+'_tip',k,'刀尖命中 · 燕形闪光',32,32,4,STEEL,'tip',anchor_type='hit')]
def duanshui():
    k='duanshui'
    return [arcfx(k+'_slash',k,'分水横斩',110,120,4,WATER,'water'),
            arcfx(k+'_scar',k,'水壁斩痕',110,120,8,WATER,'scar',play='phased',timeline={'appear':[0,1],'loop':[2,3,4,5],'fade':[6,7]}),
            fx(k+'_splash',k,'斩痕命中水花',24,24,4,WATER,'splash',anchor_type='hit')]
def higekiri():
    k='higekiri'
    return [arcfx(k+'_slash',k,'普通刀光',110,120,4,STEEL),
            arcfx(k+'_oni_slash',k,'鬼化交叉双刀线',110,120,4,ONI,'oni'),
            fx(k+'_oni_aura',k,'鬼气绕身',64,64,4,ONI,'aura',layer=7,play='loop',fps=8),
            fx(k+'_oni_horns',k,'鬼角',14,10,2,ONI,'horns',layer=6,play='loop',fps=6),
            fx(k+'_exhaust',k,'脱力白气',64,64,4,STEEL,'exhaust',layer=7,play='loop',fps=8)]
def ganjiang_moye():
    k='ganjiang_moye'
    return [arcfx('ganjiang_slash',k,'雄剑普攻',110,120,4,GOLD,'gold'),
            fx('moye_trail',k,'莫邪飞行拖尾',48,16,4,BLUE,'trail',play='loop'),
            fx('moye_planted_ring',k,'莫邪插地',48,24,4,BLUE,'ring',play='loop',fps=8),
            fx('ganjiang_link',k,'金蓝剑气连线',32,16,4,BLUE,'link',tile=True,play='loop',fps=12)]
def zhuxian():
    k='zhuxian'; entries=[]
    for name,label,p,style in [('zhu','诛 · 厚金',GOLD,'gold'),('lu','戮 · 绯红',ONI,'red'),('xian','陷 · 靛紫',INDIGO,'steel'),('jue','绝 · 墨痕',INK,'ink')]:
        entries.append(arcfx(k+'_slash_'+name,k,label,110,120,4,p,style))
    return entries+[fx(k+'_bleed',k,'戮 · 流血',24,24,4,ONI,'bleed',play='loop',anchor_type='target'),
        fx(k+'_talisman',k,'陷 · 贴符定身',24,32,4,GOLD,'talisman',fps=8,timeline={'appear':[0,1],'hold':[2,3]},anchor_type='target'),
        fx(k+'_execute',k,'绝 · 墨斩处决',96,96,6,INK,'execute',anchor_type='target')]
def riyue():
    k='riyue'
    return [arcfx(k+'_sun_sweep',k,'日刀横扫',110,180,4,GOLD,'gold'),
            arcfx(k+'_moon_thrust',k,'月刀窄刺',143,60,4,BLUE),
            arcfx(k+'_sun_wheel',k,'日轮环斩',110,360,6,GOLD,'wheel'),
            fx(k+'_moon_lunge',k,'月牙突进与三连刺',160,48,6,BLUE,'lunge'),
            fx(k+'_swap',k,'日月交错换手',48,48,4,GOLD,'swap',anchor_type='hand')]
def chunyang():
    k='chunyang'
    return [arcfx(k+'_slash',k,'清白剑光',110,120,4,WHITE),
            fx(k+'_qi',k,'一醉脱手剑气',48,24,4,WHITE,'qi',play='loop'),
            fx(k+'_drink',k,'饮酒酒花',24,24,6,GOLD,'splash',fps=12,anchor_type='mouth'),
            fx(k+'_tipsy',k,'醉红与酒泡',16,12,2,GOLD,'tipsy',layer=6,play='loop',fps=6),
            fx(k+'_dodge',k,'三醉脚下酒雾',32,32,4,GOLD,'mist',anchor_type='feet')]

def ui(weapon):
    icons=[]
    def save(id,im,label):
        publish(im,UI/f'{id}.png');icons.append(dict(id=id,weapon=weapon,label=label))
    if weapon=='excalibur':
        im,d=new((12,12));d.line([(2,9),(9,2)],fill='#141722',width=5);d.line([(2,9),(9,2)],fill='#42789f',width=3)
        d.point((8,2),fill='#f7d78c');d.line((2,6,5,9),fill='#d2ae66',width=2)
        save('excalibur_charge',im,'蓄力表 · 剑鞘')
    if weapon=='higekiri':
        im,d=new((12,12));d.polygon([(1,1),(4,3),(7,3),(10,1),(10,7),(8,10),(3,10),(1,7)],fill='#211421')
        d.polygon([(2,3),(5,4),(8,4),(9,3),(9,7),(7,9),(4,9),(2,7)],fill='#962c41')
        d.line((3,5,4,6),fill='#efd0a8');d.line((8,5,7,6),fill='#efd0a8');d.line((4,8,7,8),fill='#2c1226')
        save('higekiri_oni_gauge',im,'鬼气表 · 鬼面')
    if weapon=='zhuxian':
        designs={'zhu':[(3,3,3,8),(4,4,7,4),(6,3,6,8),(5,6,8,6)],
                 'lu':[(3,7,7,3),(3,4,7,8),(6,2,8,3),(5,8,8,8)],
                 'xian':[(3,3,3,8),(4,3,5,5),(5,4,8,4),(8,4,8,8),(5,8,8,8)],
                 'jue':[(3,3,4,5),(4,4,3,7),(3,8,5,8),(6,3,8,3),(8,3,8,6),(6,6,8,6),(6,6,6,8)]}
        for (k,lines),pal in zip(designs.items(),[GOLD,ONI,INDIGO,INK]):
            im,d=new((12,12));d.rounded_rectangle((1,1,10,10),radius=1,fill=pal[0],outline=pal[1])
            for p in lines:d.line(p,fill=pal[2])
            save('zhuxian_next_'+k,im,'下一剑 · '+k)
    if weapon=='chunyang':
        for i in range(4):
            im,d=new((12,12));d.polygon([(5,1),(7,1),(7,3),(8,4),(8,6),(10,8),(9,10),(3,10),(2,8),(4,6),(4,4),(5,3)],fill='#1c1922')
            d.ellipse((4,7,8,9),fill='#543437' if i==0 else '#a76242')
            d.ellipse((5,4,7,6),fill='#563539' if i<2 else '#c38950')
            if i>=1:d.line((4,8,8,8),fill='#d9a441')
            if i==3:d.line((5,5,7,5),fill='#f2c875');d.point((6,2),fill='#d9a441')
            save(f'chunyang_gourd_{i}',im,'醉意 '+str(i))
    return icons

if __name__=='__main__':
    entries=json.loads(M.read_text()) if M.exists() else []
    ui_path=B/'records/ui.json'
    ui_list=json.loads(ui_path.read_text()) if ui_path.exists() else []
    for k in sys.argv[1:]:
        if any(v['weapon']==k for v in entries):raise ValueError(k)
        entries+=globals()[k]()
        ui_list+=ui(k)
        M.write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')
        ui_path.write_text(json.dumps(ui_list,ensure_ascii=False,indent=2)+'\n')
