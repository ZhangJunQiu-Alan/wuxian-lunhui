import math
import random
import sys

from PIL import Image, ImageDraw

from pixels import save
from revision_effects import EXTRA, REPLACE, make_effects

FX = {
    'thornoath_burst': dict(kit='thornoath', label='荆棘反刺 · 外圈', size=[248,248], frames=6, fps=16,
        anchor=[124,124], event='受击触发，以玩家为中心', layer='地面和角色之间', play='once', radius=120),
    'thornoath_stab': dict(kit='thornoath', label='荆棘反刺 · 攻击者', size=[24,32], frames=4, fps=16,
        anchor=[12,27], event='反刺命中攻击者，以受击目标的地面投影为锚', layer='敌人前方', play='once'),
    'dragonslayer_scale': dict(kit='dragonslayer', label='龙血 · 龙鳞已备', size=[64,64], frames=4, fps=8,
        anchor=[32,32], event='20 秒冷却结束，等待挡伤期间', layer='身体前方叠加', play='loop'),
    'dragonslayer_shatter': dict(kit='dragonslayer', label='龙血 · 龙鳞碎裂', size=[64,64], frames=6, fps=16,
        anchor=[32,32], event='龙鳞挡下伤害的瞬间', layer='身体前方叠加', play='once'),
    'yellowwind_storm': dict(kit='yellowwind', label='三昧神风 · 循环', size=[96,112], frames=6, fps=12,
        anchor=[48,62], event='沙尘暴持续期间，随伤害中心游走', layer='地面特效层，角色与敌人之下', play='loop', radius=48),
    'yellowwind_storm_start': dict(kit='yellowwind', label='三昧神风 · 卷起', size=[96,112], frames=3, fps=12,
        anchor=[48,62], event='沙尘暴生成时', layer='地面特效层，角色与敌人之下', play='once'),
    'yellowwind_storm_end': dict(kit='yellowwind', label='三昧神风 · 消散', size=[96,112], frames=3, fps=12,
        anchor=[48,62], event='4 秒结束时，伤害停止', layer='地面特效层，角色与敌人之下', play='once'),
    'lotus_proc': dict(kit='lotus', label='三头八臂 · 莲瓣虚影', size=[64,64], frames=4, fps=16,
        anchor=[32,32], event='追加攻击触发瞬间', layer='身体后方叠加', play='once'),
    'valhalla_ring': dict(kit='valhalla', label='英灵分身 · 脚下光环', size=[32,12], frames=4, fps=8,
        anchor=[16,6], event='分身存在期间，以分身脚底为锚', layer='地面和分身之间', play='loop'),
}


for name, fields in REPLACE.items():
    FX[name].update(fields)
FX.update(EXTRA)


def polar(x, y, length, angle):
    return round(x + length*math.cos(angle)), round(y + length*math.sin(angle))


def pixels(draw, coords, color, width=1):
    draw.line(coords, fill=color, width=width)


def branch(draw, points, shade, light, width=4):
    pixels(draw, points, '#211e26', width)
    pixels(draw, points, shade, max(1, width-2))
    pixels(draw, points[:2], light, 1)


def thorns(draw, n):
    rng = random.Random(197)
    reach = (27, 61, 98, 120, 83, 46)[n]
    for k in range(20):
        a = math.tau * k / 20 + rng.uniform(-0.085, 0.085)
        distance = reach - (0 if k == 0 else rng.randint(1, 17))
        if distance < 14:
            continue
        b = rng.choice((-1,1))
        x, y = 124, 124
        p = [polar(x,y,distance*f,a+angle*b) for f,angle in [(0.17,-0.28),(0.44,-0.16),(0.66,0.03),(0.86,0.06),(1,0)]]
        branch(draw,p[:-1],'#59493e','#8d7762',4 if n < 5 else 3)
        pixels(draw,p[-2:],'#9d795e' if n in (2,3) else '#72604e')
        for i in range(1, 4):
            px, py = p[i]
            side = b if i % 2 else -b
            end = polar(px,py,4+i*1.75,a+side*(0.82+i*0.22))
            if math.hypot(end[0]-124,end[1]-124) <= reach:
                pixels(draw,[(px,py),end],'#342a30',2)
                pixels(draw,[(px,py),end],'#78634f')
        for i in range(3):
            rr = rng.uniform(0.35, 0.93)*reach
            u = polar(x,y,rr,a+rng.uniform(-0.13,0.13))
            draw.point(u, fill=rng.choice(['#423743','#665449','#a07a66']))
    if n in (1, 2, 3):
        for k in range(12):
            angle = math.tau*k/12 + n*0.09
            points = [polar(124,124,reach*0.39,angle+j*0.028) for j in range(7)]
            pixels(draw, points, '#453741', 2)
            pixels(draw, points[2:5], '#806554')


def stab(draw, n):
    high = (19,8,2,14)[n]
    branch(draw, [(11,27),(9,22),(12,16+n),(14,high)], '#635144','#95745d', 5)
    if n in (1,2):
        pixels(draw,[(14,high+3),(14,high)],'#ad826b')
    for points in [((10,23),(3,25)),((11,20),(17,19),(20,13)),((12,16),(8,12))]:
        if min(p[1] for p in points) > high:
            branch(draw,list(points),'#685243','#8b6a54',3)
    for i in range(5):
        draw.point((4+3*i,26+(i+n)%3), fill=('#553e40','#7b5b49')[i%2])


def shard(draw, x, y, r, color, highlight):
    form = [(x,y-r),(x+r,y-1),(x+r-1,y+1),(x,y+r+1),(x-r,y+1),(x-r,y-1)]
    draw.polygon(form, fill=color, outline='#202e2b')
    pixels(draw,[(x,y-r+1),(x-1,y),(x,y+1)],highlight)
    draw.point((x+r-1,y), fill='#536859')


def dragon_ready(draw, n):
    locs = [(26,20),(36,23),(23,29),(39,31),(27,37),(34,35),(34,18)]
    for i,(x,y) in enumerate(locs):
        bright = i % 4 == n or (i+1) % 4 == n
        shard(draw,x,y,3 if i < 6 else 2,'#6a805f' if bright else '#435747','#c6c49a' if bright else '#7f9478')
    x,y = locs[n]
    draw.point((x-2,y-4), fill='#ccc19b')
    draw.point((x+2,y-5), fill='#9b9374')


def dragon_break(draw,n):
    rng = random.Random(253)
    for i in range(23):
        a = rng.uniform(0,math.tau)
        r = rng.uniform(3,15) + n*rng.uniform(2,5)
        x,y = polar(32,29,r,a)
        if not 2 < x < 61 or not 2 < y < 61 or i % 7 < n-1:
            continue
        color = ('#607e65','#8a986a','#afa67d','#496257')[i%4]
        if i < 9 and n < 4:
            shard(draw,x,y,max(2,4-n//2),color,'#d9c394')
        else:
            pixels(draw,[(x,y),polar(x,y,1+(i+n)%3,a)],color)
    if n in (0,1):
        for i in range(8):
            a = i*math.tau/8
            pixels(draw,[polar(32,29,8+n*4,a),polar(32,29,18+n*4,a)],'#b4bb8f')


def wind(draw,n,mode):
    rng = random.Random(834)
    power = 1.0 if mode == 'loop' else ((0.31,0.64,0.89) if mode == 'start' else (0.86,0.65,0.38))[n]
    phase = n * math.tau/6
    dark, medium, light = '#615644','#8c7955','#c0a46e'
    highlights = ('#a48b5e','#c0a46e','#d4bc83')
    for k in range(10):
        a = k*math.tau/10 + phase/3
        radius = (47.5-rng.randint(0,5))*power
        coords = [(round(47.5+radius*math.cos(a+i*0.032)),round(62+radius*math.sin(a+i*0.032))) for i in range(14)]
        pixels(draw,coords,dark,3)
        pixels(draw,coords[2:12],medium)
        pixels(draw,coords[5:9],light)
    if mode == 'loop':
        for i in range(4):
            a = i*math.pi/2
            path = [polar(47.5,62,47.5,a+j*0.026) for j in range(-3,4)]
            pixels(draw,path,medium)
            draw.point(path[3],fill=light)
    for k in range(9):
        t = (k + 0.6)/10
        y = 72-t*57*power
        cx = 48+math.sin(t*6.2+phase*0.75)*12*power*t
        half = (23 - 11*t + t*t*15)*power
        for j in range(2):
            pts = []
            shift = j*math.pi + phase + t*6
            for i in range(17):
                a = shift+i*0.145
                pts.append((round(cx+half*math.cos(a)),round(y+math.sin(a)*3.7*power-i*0.3*power)))
            pixels(draw,pts,dark,3)
            pixels(draw,pts[1:15],medium,2)
            pixels(draw,pts[4:11],highlights[(k+j)%3])
    for k in range(round(115*power)):
        y = rng.uniform(12,97)
        t = max(0,min(1,(72-y)/57))
        half = (27 if y < 78 else 44)*power
        cx = 48+math.sin(t*6+phase*0.75)*11*power*t
        x = round(cx+rng.uniform(-half,half))
        y = round(62+(y-62)*power)
        if math.hypot(x-48,y-62)>47:
            continue
        draw.point((x,y),fill=rng.choice([dark,dark,medium,medium,light]))
        if k%11 == 0 and 0 < x < 95:
            draw.point((x+1,y),fill=medium)


def lotus(draw,n):
    arms = [
        [(28,30),(20,28),(14,19),(10,16)], [(27,33),(17,33),(10,27),(7,25)],
        [(28,37),(19,43),(13,43),(9,48)], [(36,30),(44,28),(50,19),(54,16)],
        [(37,33),(47,33),(54,27),(57,25)], [(36,37),(45,43),(51,43),(55,48)]
    ]
    ink = ('#674354','#71485b','#644357','#433642')[n]
    base = ('#ac727b','#cd8e93','#c98a93','#88606f')[n]
    light = ('#c78c97','#f0c0a6','#e6ab9e','#aa7581')[n]
    for k,arm in enumerate(arms):
        if n == 3 and k not in (0,2,3,5):
            continue
        pts = [(x+(1 if k<3 else -1)*(2-n), y+(1-n)*(k%3-1)) for x,y in arm]
        pixels(draw,pts,ink,5 if n in (1,2) else 3)
        pixels(draw,pts,base,3)
        pixels(draw,pts[1:],light)
        x,y = pts[-1]
        sign = -1 if k<3 else 1
        for j in range(3):
            pixels(draw,[(x,y),(x+sign*(3-j%2),y-2+j)],base)
        draw.point((x+sign*3,y-2), fill=light)
    for i in range(11):
        rng = random.Random(170+i)
        x,y = polar(32,31,rng.uniform(12,23)+n*2,rng.uniform(0,math.tau))
        draw.polygon([(x-2,y+1),(x,y-2),(x+2,y-1),(x+1,y+2)],fill=base)
        draw.point((x,y-1),fill=light)


def valhalla(draw,n):
    for k in range(16):
        a = k*math.tau/16
        pts = [(round(15.5+14.5*math.cos(a+j*0.06)),round(5.5+4.7*math.sin(a+j*0.06))) for j in range(5)]
        pixels(draw,pts,'#72634f')
        pixels(draw,pts[:3],'#c6af77' if (k+n)%4 else '#efdcaa')
    for k in range(5):
        x = 5+k*5
        y = 5+(k+n)%2
        pixels(draw,[(x,y-1),(x,y+1)],'#a18b67')
        draw.point((x+1,y),fill='#d9c794')


DRAW = {
    'thornoath_burst': thorns, 'thornoath_stab': stab,
    'dragonslayer_scale': dragon_ready, 'dragonslayer_shatter': dragon_break,
    'yellowwind_storm': lambda d,n:wind(d,n,'loop'),
    'yellowwind_storm_start': lambda d,n:wind(d,n,'start'),
    'yellowwind_storm_end': lambda d,n:wind(d,n,'end'),
    'lotus_proc': lotus, 'valhalla_ring': valhalla,
}


def make(kits):
    for key, meta in FX.items():
        if meta['kit'] not in kits or key in REPLACE or key in EXTRA:
            continue
        w,h = meta['size']
        sheet = Image.new('RGBA',(w*meta['frames'],h))
        for n in range(meta['frames']):
            frame = Image.new('RGBA',(w,h))
            DRAW[key](ImageDraw.Draw(frame),n)
            sheet.paste(frame,(n*w,0))
        save(sheet, 'effects', key+'.png')


if __name__ == '__main__':
    if sys.argv[1:] == ['--revision']:
        make_effects(FX)
    else:
        make(sys.argv[1:])
