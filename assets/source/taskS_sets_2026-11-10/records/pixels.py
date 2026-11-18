from collections import deque
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageColor, ImageDraw, ImageFilter

BASE = Path(__file__).resolve().parents[1]
SLOTS = ('helm', 'chest', 'legs', 'boots')
INK = '#171821'
BAYS = {
    'xingtian': (0,421,883,1325,1774),
    'nightcount': (0,434,956,1330,1774),
    'nemean': (0,448,921,1332,1774),
    'dragonslayer': (0,398,899,1290,1774),
    'yellowwind': (0,370,918,1274,1774),
    'grail': (0,420,901,1320,1774),
    'valhalla': (0,459,902,1294,1774),
    'bearskin': (0,409,874,1323,1774),
}
PALETTES = {
    'thornoath': '252a34 353b46 4c5461 666d77 9197a0 44403f 5a493b 77624b 503439 7a4d46',
    'xingtian': '272b34 41434b 65656c 3b302c 5d3e31 82553c a57452 c29365 d9b183 4c645c 708477 624049',
    'nightcount': '20202a 2c2937 40394b 585064 767084 39303e 592e40 743a49 717986 a9adba cdd3d7',
    'nemean': '2e2424 44302a 634732 89613e ac794b c69658 dcb779 e7c894 5c5142 928067 b5a083 ded2b6',
    'dragonslayer': '25302e 33423b 465a4e 596c5b 748675 3f3531 574839 766044 9d8259 b8a079 633b43 947b76',
    'yellowwind': '372e29 504333 6b553c 886d44 a88a54 c19e60 dab67a e6c996 5e594b 8c7c5f a79d82',
    'grail': '373743 535664 727986 959da7 aeb7bf c9ccd1 e3e5e1 f1eee0 665a47 9e895e c9b47c e6d6aa',
    'lotus': '432b41 6a344b 8b4054 ac5262 cb7280 dc9398 edb0af f4d1bb 526b64 829086 b7b7a1 dbd1b1 f3e3c5 755038 956b42 bd9251 ddb267 ebd18e',
    'valhalla': '262934 353c49 4e5664 667180 858f9a a7b3bc c7cdd1 e2e1d6 6f5e4b 9c8157 bfa36f d7bd88',
    'bearskin': '2a2525 3d302b 564138 715344 8b6952 a98464 c4a182 68574b 9e8971 c4ad90 e5cdb0 604148',
}
PALETTE = {k: [ImageColor.getrgb(INK), *[ImageColor.getrgb('#'+v) for v in row.split()]]
           for k, row in PALETTES.items()}

STATUS = {
    'thornoath': ('#6d5c4d', '#bf9c70'),
    'xingtian': ('#925140', '#e7ba79'),
    'nightcount': ('#70354d', '#c66d85'),
    'nemean': ('#855a3d', '#d8aa6a'),
    'dragonslayer': ('#4b6656', '#a5b692'),
    'yellowwind': ('#8e754d', '#dec58a'),
    'grail': ('#9b8967', '#f1e1aa'),
    'lotus': ('#8d5068', '#e9a9b5'),
    'valhalla': ('#748391', '#d5dce1'),
    'bearskin': ('#714f3d', '#b58d68'),
}


def largest_mask(mask, keep=1):
    height, width = mask.shape
    seen = np.zeros_like(mask)
    components = []
    for y, x in zip(*np.where(mask)):
        if seen[y, x]:
            continue
        seen[y, x] = True
        todo, points = deque([(y, x)]), [(y, x)]
        while todo:
            j, i = todo.popleft()
            for dj, di in ((-1, 0), (0, 1), (1, 0), (0, -1)):
                a, b = j+dj, i+di
                if 0 <= a < height and 0 <= b < width and mask[a, b] and not seen[a, b]:
                    seen[a, b] = True
                    todo.append((a, b))
                    points.append((a, b))
        components.append(points)
    result = np.zeros_like(mask)
    for points in sorted(components, key=len, reverse=True)[:keep]:
        y, x = zip(*points)
        result[y, x] = True
    return result


def extract(source, index, key):
    w, h = source.size
    edges = BAYS.get(key)
    left, right = ((round(w*edges[i]/1774) for i in (index,index+1))
                   if edges else (round(w*index/4),round(w*(index+1)/4)))
    bounds = (left, 0, right, h)
    bay = source.crop(bounds)
    h = bay.height
    a = np.asarray(bay, dtype=np.float32)
    border = h//28 if key == 'grail' else h//9
    top = np.median(a[:border], axis=0)
    bottom = np.median(a[-border:], axis=0)
    factor = np.linspace(0, 1, h)[:, None, None]
    background = top * (1-factor) + bottom * factor
    distance = np.linalg.norm(a - background, axis=2)
    core = Image.fromarray(((distance > 19) * 255).astype('uint8'))
    shape = largest_mask(np.asarray(core.resize((112, 224), Image.Resampling.BOX)) > 110, 2)
    seed = Image.fromarray(shape.astype('uint8')*255).resize(bay.size, Image.Resampling.NEAREST)
    seed = seed.filter(ImageFilter.MaxFilter(15))
    alpha = Image.fromarray(((distance > 13.8) & (np.asarray(seed) > 0)).astype('uint8')*255)
    mask = alpha.getbbox()
    if mask is None:
        raise ValueError(f'No object in {key} bay {index}')
    bay.putalpha(alpha)
    bay = bay.crop(mask)
    limit = 23 if key == 'nemean' and index == 2 else (26 if index == 0 else 28)
    scale = min(limit/bay.width, limit/bay.height)
    size = tuple(max(1, round(v*scale)) for v in bay.size)
    small = np.asarray(bay.resize(size, Image.Resampling.BOX))
    rgb = small[:, :, :3].astype(float)
    alpha = small[:, :, 3] >= 110
    # Material accents use the small set palette. Perceptual weights keep shaded metal neutral.
    palette = np.asarray(PALETTE[key][1:], dtype=float)
    rgb = rgb * 1.06 + 1.0
    delta = rgb[:, :, None, :] - palette[None, None, :, :]
    nearest = np.argmin(np.sum(delta**2 * [0.90, 1.25, 0.82], axis=3), axis=2)
    rgba = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    rgba[:, :, :3] = palette[nearest]
    rgba[:, :, 3] = alpha * 255
    cutout = Image.fromarray(rgba)
    center = ((32-size[0])//2, (32-size[1])//2)
    sprite = Image.new('RGBA', (32, 32))
    sprite.paste(cutout,center)
    shape = sprite.getchannel('A')
    bordered = Image.new('RGBA', sprite.size, INK)
    bordered.putalpha(shape.filter(ImageFilter.MaxFilter(3)))
    bordered.alpha_composite(sprite)
    return bordered


def sandals():
    image = Image.new('RGBA',(32,32))
    draw = ImageDraw.Draw(image)
    def sandal(x,y,bright):
        def path(points):
            return [(a+x,b+y) for a,b in points]
        ink = '#2e2424'
        dark = '#634732' if bright else '#44302a'
        light = '#ac794b' if bright else '#89613e'
        gold = '#c69658' if bright else '#ac794b'
        for coords in [[(0,17),(1,8),(2,0),(6,0),(6,3),(5,7),(7,11),(10,15)],
                       [(3,3),(6,6),(3,9),(7,12),(6,15)],[(11,16),(12,12),(14,12),(16,16)]]:
            draw.line(path(coords),fill=ink,width=4)
            draw.line(path(coords),fill=dark,width=2)
            draw.line(path(coords[1:3]),fill=light,width=1)
        draw.polygon(path([(0,16),(5,16),(7,17),(16,16),(20,17),(20,19),(18,20),(2,20),(0,19)]),fill=dark,outline=ink)
        draw.line(path([(1,17),(6,18),(12,18),(17,17),(19,18)]),fill=light)
        draw.point((x+16,y+17),fill=gold)
    sandal(4,3,False)
    sandal(9,9,True)
    return image


def finish(sprite, key, slot):
    if key == 'nemean' and slot == 'boots':
        return sandals()
    draw = ImageDraw.Draw(sprite)
    if key == 'xingtian' and slot == 'chest':
        for side in (-1,1):
            x = 15+side*5
            draw.line([(x-side*3,15),(x,12),(x+side*3,12)],fill='#a57452',width=2)
            draw.polygon([(x-side*2,15),(x,14),(x+side*2,14),(x+side,16),(x,17)],fill='#272b34')
            draw.point((x,15),fill='#d9b183')
        draw.line([(12,24),(13,22),(18,22),(20,24)],fill='#a57452')
        draw.line([(13,24),(19,24)],fill='#272b34')
    if key == 'nightcount':
        silhouette = sprite.getchannel('A')
        edge = '#767084' if slot in ('helm','chest') else '#585064'
        for y in [5,6,7,10,11,12,15,16,19,20,21,24,25]:
            at = [x for x in range(32) if silhouette.getpixel((x,y))]
            if len(at) > 6:
                draw.point((at[0]+1,y),fill=edge)
        if slot == 'chest':
            for x,y in [(7,22),(8,23),(11,25),(12,25),(20,24),(21,24),(25,21)]:
                draw.point((x,y),fill=(0,0,0,0))
        lines = {
            'helm': [([(6,9),(10,11),(13,15)],'#743a49'), ([(19,14),(24,10)],'#592e40'), ([(15,16),(16,16)],'#a9adba')],
            'chest': [([(11,7),(14,9),(17,9),(20,7)],'#767084'), ([(13,8),(14,9)],'#a9adba'), ([(12,23),(14,20)],'#592e40'), ([(19,23),(22,20)],'#592e40')],
            'legs': [([(19,10),(20,15),(20,19),(18,24)],'#767084')],
            'boots': [([(10,10),(12,10)],'#a9adba'), ([(16,13),(18,13)],'#a9adba')],
        }
        for path, color in lines[slot]:
            before = sprite.copy()
            mark = Image.new('RGBA',sprite.size)
            ImageDraw.Draw(mark).line(path,fill=color)
            sprite.paste(mark,mask=Image.fromarray((np.asarray(mark.getchannel('A')) & np.asarray(before.getchannel('A')))))
    if key == 'dragonslayer':
        if slot == 'helm':
            draw.line([(15,4),(15,6),(18,8)],fill='#9d8259')
            draw.line([(18,15),(19,20),(19,24)],fill='#b8a079')
            draw.line([(12,10),(10,12),(12,14),(14,12)],fill='#748675')
        elif slot == 'chest':
            for y in (13,18,23):
                for x in (11,15,19):
                    draw.line([(x-1,y),(x,y+1),(x+1,y)],fill='#748675')
            draw.polygon([(19,8),(22,7),(24,9),(23,12),(20,11)],fill='#9d8259',outline='#574839')
        elif slot == 'legs':
            for x in (7,18):
                for y in (8,14,20,25):
                    draw.line([(x,y),(x+6,y)],fill='#596c5b',width=2)
                    draw.line([(x+1,y-1),(x+4,y-1)],fill='#748675')
    if key == 'yellowwind' and slot == 'boots':
        draw.line([(4,21),(2,20),(2,18),(4,17),(6,18),(5,19)],fill='#a88a54')
        draw.point((2,22),fill='#c19e60')
    if key == 'grail':
        if slot == 'helm':
            draw.line([(17,16),(17,24)],fill='#373743')
            draw.line([(12,19),(20,19)],fill='#373743')
        elif slot == 'chest':
            draw.line([(15,8),(15,17)],fill='#959da7')
            draw.line([(12,11),(18,11)],fill='#959da7')
            draw.line([(15,9),(15,10)],fill='#c9ccd1')
        elif slot == 'legs':
            for x in (10,21):
                draw.line([(x-3,9),(x,6),(x+3,9),(x,12),(x-3,9)],fill='#727986')
                draw.line([(x-1,8),(x,7),(x+1,8)],fill='#e3e5e1')
    if key == 'valhalla' and slot == 'chest':
        draw.rectangle((12,8,18,12),fill='#6f5e4b',outline='#262934')
        draw.line([(14,11),(14,9),(16,9),(16,11),(18,10)],fill='#d7bd88')
    if key == 'valhalla' and slot == 'legs':
        for x in (8,19):
            draw.line([(x,13),(x+5,18),(x+1,23)],fill='#9c8157')
            draw.line([(x+5,13),(x+2,16)],fill='#a7b3bc')
    if key == 'bearskin' and slot == 'helm':
        draw.point((14,13),fill='#604148')
        draw.line([(22,17),(22,19)],fill='#e5cdb0')
    if key == 'bearskin' and slot == 'boots':
        for x,y in [(24,21),(26,23),(28,25)]:
            draw.line([(x-1,y-1),(x,y),(x+1,y+1)],fill='#2a2525')
            draw.point((x+1,y+1),fill='#e5cdb0')
    if key == 'nemean' and slot == 'chest':
        draw.line([(13,13),(18,17),(22,22)],fill='#89613e',width=3)
        draw.line([(18,13),(14,17),(9,21)],fill='#c69658',width=3)
        for x,y in [(9,21),(11,22),(13,22),(20,20),(22,21),(23,23)]:
            draw.line([(x,y),(x,y+1)],fill='#ded2b6')
    if slot == 'legs' and key in ('dragonslayer','grail','valhalla','bearskin'):
        limits = {'dragonslayer':(15,15),'grail':(15,16),'valhalla':(15,16),'bearskin':(15,16)}
        left,right = limits[key]
        draw.rectangle((left,1,right,30),fill=(0,0,0,0))
        if key == 'dragonslayer':
            for y in (9,15,21,26):
                draw.point((5,y),fill='#465a4e')
                draw.point((25,y),fill='#465a4e')
        if key == 'grail':
            draw.line([(7,7),(6,9),(7,11)],fill='#535664')
            draw.line([(24,7),(25,9),(24,11)],fill='#535664')
        if key == 'bearskin':
            for points in [[(6,4),(3,4),(6,7)],[(24,5),(28,4),(26,7)],[(4,24),(2,27),(5,27)],[(26,24),(29,27),(26,28)]]:
                draw.polygon(points,fill='#564138',outline=INK)
    if key != 'thornoath':
        return sprite
    branch = '#77624b'
    lit = '#9197a0'
    mid = '#666d77'
    dark = '#252a34'
    def trace(points, color, width=1):
        draw.line(points,fill=color,width=width)
    if slot == 'helm':
        trace([(7,12),(9,10),(13,11),(16,10),(19,12),(23,11)], dark, 3)
        trace([(6,12),(9,10),(13,11),(16,10),(19,12),(23,11)], branch)
        for p in [[(9,10),(8,7)],[(13,11),(13,8),(15,5)],[(19,12),(20,8)],[(22,11),(25,9)]]:
            trace(p,branch)
        trace([(14,18),(18,17),(24,17)], INK,2)
        trace([(16,16),(20,16),(23,16)], mid)
        trace([(19,16),(20,16)],lit)
    elif slot == 'chest':
        trace([(5,10),(9,7),(11,8)],mid)
        trace([(19,8),(23,7),(27,10)],mid)
        trace([(8,8),(10,11),(8,16),(10,20),(9,25)],dark,3)
        trace([(8,8),(10,11),(8,16),(10,20),(9,25)],branch)
        trace([(23,9),(21,13),(24,17),(21,22),(23,26)],branch)
        for p in [[(9,15),(6,13),(5,13)],[(10,21),(13,18)],[(24,17),(27,14)],[(22,23),(25,25)]]:
            trace(p,branch)
        trace([(15,8),(16,8)],lit)
    elif slot == 'legs':
        for dx in (0,9):
            trace([(8+dx,5),(11+dx,8),(13+dx,12),(10+dx,16),(9+dx,20),(13+dx,23),(12+dx,27)],dark,2)
            trace([(8+dx,5),(11+dx,8),(13+dx,12),(10+dx,16),(9+dx,20),(13+dx,23),(12+dx,27)],branch)
            trace([(13+dx,12),(15+dx,10)],branch)
            trace([(9+dx,20),(7+dx,18)],branch)
            trace([(11+dx,4),(12+dx,4)],mid)
    elif slot == 'boots':
        trace([(6,22),(10,21),(12,19),(12,16)],branch)
        trace([(12,22),(9,25),(5,26),(3,28)],branch)
        trace([(11,23),(9,27),(7,29)],branch)
        trace([(9,24),(6,24),(4,25)],branch)
        trace([(11,6),(15,6),(16,7)],mid)
        trace([(20,23),(25,23),(27,24)],mid)
    return sprite


def status_icon(key):
    image = Image.new('RGBA', (12, 12))
    draw = ImageDraw.Draw(image)
    dark, light = STATUS[key]
    def poly(coords, fill=dark):
        draw.polygon(coords, fill=fill, outline=INK)
    def line(coords, fill=light):
        draw.line(coords, fill=fill)
    if key == 'thornoath':
        draw.ellipse((1, 3, 10, 9), outline=INK, width=3)
        draw.ellipse((2, 4, 9, 8), outline=dark)
        for x, y in [(2,4),(4,3),(7,3),(9,5),(8,8),(4,8)]:
            line((x,y,x-1,y-1))
    elif key == 'xingtian':
        poly([(1,6),(3,3),(8,3),(10,6),(8,8),(3,8)])
        line((2,6,4,4,7,4,9,6))
        draw.ellipse((4,4,7,7), fill=light, outline=INK)
        draw.point((5,6), fill=INK)
    elif key == 'nightcount':
        poly([(6,1),(7,4),(9,7),(8,9),(6,10),(3,9),(2,7),(4,4)])
        line((5,5,4,7,5,8))
    elif key in ('nemean', 'bearskin'):
        poly([(3,8),(4,6),(7,6),(9,8),(8,10),(3,10)])
        toes = [(1,4),(4,2),(7,2),(9,4)]
        for x,y in toes:
            draw.ellipse((x,y,x+1,y+2), fill=light)
        if key == 'nemean':
            line((3,2,3,4)); line((8,2,8,4))
        else:
            line((4,8,7,8))
    elif key == 'dragonslayer':
        poly([(6,1),(9,3),(10,5),(8,8),(6,10),(3,8),(2,5),(3,3)])
        line((6,2,4,4,4,6)); line((6,4,6,8), '#344b43'); line((7,6,8,5))
    elif key == 'yellowwind':
        line((1,3,3,1,8,1,10,3,8,5,4,5,2,7,4,9,8,9,10,8), dark)
        line((2,3,4,2,8,2,9,3,7,4,4,4,3,6,5,7,8,7))
        draw.point((2,9), fill=light)
    elif key == 'grail':
        poly([(2,2),(9,2),(9,5),(7,7),(7,8),(9,9),(9,10),(2,10),(2,9),(5,8),(5,7),(3,6)])
        line((3,3,8,3)); line((4,4,4,5,5,6)); line((3,9,8,9))
    elif key == 'lotus':
        poly([(1,5),(3,5),(3,3),(5,5),(6,1),(8,5),(10,3),(10,6),(9,8),(6,10),(3,9)])
        line((2,6,5,8,6,5,7,8,9,5)); draw.point((6,8), fill='#e9c387')
    elif key == 'valhalla':
        poly([(1,2),(4,3),(5,7),(5,9),(2,7)])
        poly([(10,2),(7,3),(6,7),(6,9),(9,7)])
        line((2,3,4,5,4,7)); line((9,3,7,5,7,7))
    return image


def save(image, group, file):
    for directory in ('candidates', 'approved'):
        path = BASE / directory / group / file
        path.parent.mkdir(exist_ok=True)
        image.save(path, optimize=True)


def make(key):
    source = Image.open(BASE / 'originals' / (key + '.png')).convert('RGB')
    for i, slot in enumerate(SLOTS):
        save(finish(extract(source, i, key), key, slot), 'armor', f'{key}_{slot}.png')
    save(status_icon(key), 'status', key + '.png')


if __name__ == '__main__':
    for key in sys.argv[1:]:
        make(key)
