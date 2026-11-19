from functools import lru_cache
from pathlib import Path
import re

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent.parent
CANVAS = (1920, 1080)
SOURCE = (1672, 941)
SONG = '/System/Library/Fonts/Supplemental/Songti.ttc'
HEI = '/System/Library/Fonts/STHeiti Medium.ttc'
RESAMPLE = Image.Resampling.LANCZOS
GODS = [
    ('托尔', '雷神', '落雷', '每 2 秒向附近的敌人劈下一道雷，被劈中的敌人感电', 'thor', '#a7dbff'),
    ('奥丁', '众神之父', '符文飞弹', '向最近的敌人发射符文。符文印记叠到 3 层时引爆', 'odin', '#dcc5ff'),
    ('斯卡蒂', '冬与狩猎女神', '霜猎之箭', '每 1.8 秒向最远的敌人射出穿透的冰箭。霜冻叠到 5 层时冻结', 'skadi', '#e1f5ff'),
]
DIRS = ['A_立石神谕', 'B_星穹罗盘', 'C_神殿挂幡', 'D_神谕法典']
NEW_GOD = '新的神明（一局最多 4 位）'
PUNCTUATION = '，。！？：；、）'

STONE_OUTLINES = (
    [(148,724),(162,695),(193,682),(206,652),(217,567),(223,423),(234,291),(241,205),
     (254,157),(272,138),(312,116),(344,105),(371,94),(396,79),(420,69),(440,75),
     (470,94),(504,108),(545,119),(572,138),(591,167),(601,199),(608,361),(613,497),
     (616,637),(617,683),(603,708),(608,727),(554,736),(260,737),(175,731)],
    [(605,722),(616,699),(624,660),(632,567),(638,418),(644,234),(651,169),(674,143),
     (710,121),(748,102),(779,90),(806,71),(833,59),(865,70),(892,89),(934,104),
     (972,126),(999,151),(1018,184),(1025,241),(1030,426),(1031,549),(1035,625),
     (1048,665),(1048,697),(1040,719),(964,737),(704,736),(658,730)],
    [(1043,715),(1053,688),(1058,613),(1060,460),(1061,312),(1067,213),(1077,174),
     (1102,147),(1133,132),(1167,115),(1191,106),(1223,84),(1248,75),(1274,85),
     (1300,100),(1337,106),(1372,118),(1407,141),(1424,174),(1434,218),(1439,337),
     (1445,480),(1455,591),(1462,651),(1473,680),(1504,704),(1516,726),(1446,735),
     (1124,736),(1073,730)],
)
STONE_WINDOWS = (
    [(279,432),(283,216),(295,190),(320,165),(351,147),(385,135),(418,128),(449,130),
     (483,141),(516,158),(542,180),(558,208),(567,250),(561,432),(444,434),(424,415),(403,434)],
    [(684,434),(681,236),(696,199),(719,169),(752,149),(788,133),(825,122),(851,122),
     (884,134),(922,150),(949,171),(973,204),(990,245),(994,432),(861,434),(838,415),(812,434)],
    [(1105,433),(1106,228),(1120,198),(1143,173),(1177,152),(1210,137),(1249,130),(1283,137),
     (1318,150),(1350,170),(1378,193),(1394,227),(1400,432),(1282,433),(1256,414),(1232,433)],
)
BEAM = [(171,65),(177,44),(207,32),(235,28),(251,18),(275,20),(330,8),(319,23),(345,22),
        (333,30),(372,27),(362,38),(416,45),(544,45),(627,44),(671,49),(752,46),(786,49),
        (819,35),(854,32),(890,45),(939,42),(1012,48),(1090,44),(1195,46),(1272,42),
        (1307,29),(1347,29),(1330,12),(1387,25),(1382,8),(1430,25),(1453,32),(1480,36),
        (1496,47),(1503,64),(1494,77),(1482,59),(1463,69),(1476,91),(1480,106),(1465,116),
        (1434,113),(1384,121),(1226,119),(1103,116),(991,119),(866,116),(738,119),(619,119),
        (496,120),(367,120),(277,121),(239,114),(204,116),(193,107),(194,89),(208,95),
        (223,78),(205,65),(188,66),(181,79)]
FIRST_BANNER = [(337,108),(360,108),(364,137),(590,137),(596,108),(613,108),(618,137),
                (633,138),(639,147),(634,161),(618,162),(622,226),(628,257),(634,280),
                (615,287),(610,268),(610,653),(615,724),(607,726),(606,715),(585,734),
                (576,752),(570,745),(552,760),(546,771),(538,765),(513,786),(508,779),
                (487,798),(476,816),(469,799),(455,797),(451,783),(431,782),(425,767),
                (410,767),(398,749),(381,748),(375,737),(354,731),(347,745),(342,731),
                (326,724),(323,711),(327,692),(330,276),(324,285),(309,280),(314,252),
                (318,234),(319,164),(311,162),(306,151),(309,140),(334,137)]
BOOK = [(40,843),(49,763),(56,675),(62,568),(70,498),(74,463),(86,347),(95,248),(99,216),
        (113,201),(132,189),(175,191),(189,180),(202,173),(239,176),(278,185),(321,179),
        (360,181),(407,178),(457,172),(530,171),(591,177),(657,185),(717,191),
        (773,205),(798,214),(814,222),(828,231),(846,220),(882,210),(939,198),(1001,180),(1073,168),
        (1134,165),(1162,161),(1184,167),(1244,168),(1304,175),(1374,187),(1422,183),
        (1468,174),(1496,172),(1512,178),(1528,194),(1551,195),(1568,204),(1576,225),
        (1580,275),(1592,416),(1602,544),(1615,671),(1631,796),(1641,839),(1633,859),
        (1616,872),(1583,878),(1413,878),(1195,878),(996,877),(910,880),(883,893),
        (840,897),(780,896),(754,886),(697,882),(529,886),(276,882),(86,883),(56,873),(43,859)]


@lru_cache(maxsize=None)
def font(size, title=False):
    return ImageFont.truetype(SONG if title else HEI, size, index=0 if title else 1)


@lru_cache(maxsize=None)
def art(letter):
    with Image.open(ROOT / '生成底图' / f'{letter}.png') as source:
        if source.size != SOURCE:
            raise ValueError(f'{letter}.png 的蒙版对应 {SOURCE}，实际底图尺寸为 {source.size}')
        return source.convert('RGBA')


@lru_cache(maxsize=None)
def card(god_id):
    with Image.open(PROJECT / 'assets/sprites/cards' / f'{god_id}.png') as source:
        return source.convert('RGB')


def text(draw, xy, value, size, color='#f3eee5', title=False, align='left'):
    f = font(size, title)
    left, top, right, bottom = draw.textbbox((0, 0), value, font=f)
    x, y = xy
    if align == 'center':
        x -= (left + right) / 2
    elif align == 'right':
        x -= right
    draw.text((round(x), round(y - top)), value, font=f, fill=color,
              stroke_width=1, stroke_fill='#111421')


def label(god):
    return f'神明 · {god[0]} · {god[1]}'


def label_text(draw, xy, god, size, align='center'):
    f = font(size)
    value = label(god)
    segments = re.split('(·)', value)
    dot_start, _, dot_end, _ = f.getmask('·').getbbox()
    advances = [dot_end-dot_start if part == '·' else f.getlength(part) for part in segments]
    x, y = xy
    if align == 'center':
        x -= sum(advances)/2
    elif align == 'right':
        x -= sum(advances)
    text_top = f.getbbox(value)[1]
    for part, advance in zip(segments, advances):
        draw.text((round(x - (dot_start if part == '·' else 0)), y-text_top),
                  part, font=f, fill=god[5], stroke_width=1, stroke_fill='#111421')
        x += advance


def wrap(draw, value, width, size):
    tokens = re.findall(r'\d+(?:\.\d+)? +[秒层位]|\d+(?:\.\d+)?|符文印记|一道雷|敌人|射出|感电|引爆|冻结|穿透|冰箭| +|.', value)

    @lru_cache(maxsize=None)
    def best(start):
        if start == len(tokens):
            return 0, []
        result = (float('inf'), [])
        for end in range(start+1, len(tokens)+1):
            if end < len(tokens) and tokens[end] in PUNCTUATION:
                continue
            line = ''.join(tokens[start:end]).strip()
            length = draw.textlength(line, font=font(size))
            if length > width:
                break
            if not line:
                continue
            tail_cost, tail = best(end)
            penalty = 0 if not tail or line[-1] in PUNCTUATION else .25
            cost = 2 + ((width-length)/width)**2 + penalty + tail_cost
            if cost < result[0]:
                result = cost, [line, *tail]
        return result

    result = best(0)[1]
    if not result:
        raise ValueError(f'文字无法排入 {width}px：{value}')
    return result


def paragraph(draw, x, y, value, width, size, step, align='left'):
    for i, line in enumerate(wrap(draw, value, width, size)):
        text(draw, (x, y + i * step), line, size, align=align)


def key(draw, center, number, color, radius=21):
    x, y = center
    draw.ellipse((x-radius, y-radius, x+radius, y+radius),
                 fill='#161923', outline=color, width=1)
    digits = str(number)
    f = font(round(radius * 1.44), True)
    x0, y0, x1, y1 = draw.textbbox((0, 0), digits, font=f)
    draw.text((round(x-(x0+x1)/2), round(y-(y0+y1)/2)), digits, font=f, fill=color)


def shape(size, polygon=None, ellipse=None, feather=0):
    mask = Image.new('L', (size[0]*2, size[1]*2))
    draw = ImageDraw.Draw(mask)
    if polygon is not None:
        draw.polygon([(round(x*2), round(y*2)) for x, y in polygon], fill=255)
    if ellipse is not None:
        draw.ellipse(tuple(round(v*2) for v in ellipse), fill=255)
    mask = mask.resize(size, RESAMPLE)
    return mask.filter(ImageFilter.GaussianBlur(feather)) if feather else mask


def tint(im, mask, color, opacity=1.0):
    layer = Image.new('RGBA', im.size, color)
    layer.putalpha(mask.point(lambda v: round(v*opacity)))
    im.alpha_composite(layer)


def cutout(source, mask):
    layer = source.copy()
    layer.putalpha(mask)
    return layer


def place(im, layer, offset, scale=(1, 1), shadow=0):
    bounds = layer.getbbox()
    if not bounds:
        return
    layer = layer.crop(bounds)
    x = round(offset[0] + bounds[0] * scale[0])
    y = round(offset[1] + bounds[1] * scale[1])
    layer = layer.resize((round(layer.width*scale[0]), round(layer.height*scale[1])), RESAMPLE)
    if shadow:
        matte = Image.new('L', CANVAS)
        matte.paste(layer.getchannel('A'), (x+2, y+9))
        tint(im, matte.filter(ImageFilter.GaussianBlur(shadow)), '#02040b', .72)
    im.alpha_composite(layer, (x, y))


def glow(im, mask, color, blur, opacity=.75):
    tint(im, mask.filter(ImageFilter.GaussianBlur(blur)), color, opacity)


def portrait(im, god, mask, crop, *, cloth=False):
    box = mask.getbbox()
    original = card(god[4]).crop(crop)
    fitted = ImageOps.fit(original, (box[2]-box[0], box[3]-box[1]), RESAMPLE, centering=(.5, .19))
    matte = mask.crop(box)
    if cloth:
        fabric = im.crop(box).convert('RGB')
        gray = ImageOps.grayscale(fabric)
        fibers = ImageChops.subtract(gray, gray.filter(ImageFilter.GaussianBlur(1.25)), scale=.8, offset=128)
        fitted = Image.blend(fitted, ImageChops.soft_light(fitted, fibers.convert('RGB')), .8)
        fitted = Image.blend(fitted, fabric, .14)
        fade = Image.new('L', (1, fitted.height))
        fade.putdata([round(255*min(1, max(0, (1-y/fitted.height)/.30))) for y in range(fitted.height)])
        matte = ImageChops.multiply(matte, fade.resize(fitted.size))
    im.paste(fitted, box[:2], matte)


def disk(im, god, center, radius, crop):
    x, y = center
    matte = shape(SOURCE, ellipse=(x-radius, y-radius, x+radius, y+radius), feather=1.3)
    portrait(im, god, matte, crop)


def base():
    with Image.open(ROOT / '输入/游戏背景.png') as source:
        game = source.convert('RGB').resize(CANVAS, RESAMPLE)
    hud = Image.new('L', CANVAS)
    draw = ImageDraw.Draw(hud)
    draw.ellipse((-290, -215, 550, 300), fill=255)
    draw.ellipse((630, -180, 1290, 207), fill=255)
    draw.ellipse((650, 967, 1280, 1225), fill=255)
    hud = hud.filter(ImageFilter.GaussianBlur(45))
    soft_hud = ImageOps.colorize(ImageOps.grayscale(game.filter(ImageFilter.GaussianBlur(33))),
                                 '#0a0d15', '#787d8e')
    game = Image.composite(soft_hud, game, hud).convert('RGBA')
    game = Image.alpha_composite(game, Image.new('RGBA', CANVAS, (4, 8, 17, 170)))
    tint(game, hud, '#060a14', .28)
    return game


def chrome(im, accent):
    overlay = Image.new('RGBA', CANVAS)
    d = ImageDraw.Draw(overlay)
    text(d, (960, 45), '选择你的第一位神', 52, '#fff1da', True, 'center')
    for a, b in ((761, 944), (976, 1159)):
        d.line((a, 114, b, 114), fill=accent, width=1)
    d.polygon([(960,110),(965,114),(960,118),(955,114)], fill=accent)
    d.rounded_rectangle((768, 937, 1152, 993), radius=8, fill=(12,16,26,226), outline=accent, width=1)
    text(d, (960, 953), '重抽选项（剩余 1 次）  [R]', 26, '#fff0d8', align='center')
    text(d, (960, 1019), '点击卡牌或按数字键选择', 24, '#d7dce6', align='center')
    im.alpha_composite(overlay)


def stones(hover):
    im = base()
    source = art('A')
    for i in ((0, 2, 1) if hover else (0, 1, 2)):
        g = GODS[i]
        active = hover and i == 1
        matte = shape(SOURCE, polygon=STONE_OUTLINES[i], feather=.9)
        face = source.copy()
        portrait(face, g, shape(SOURCE, polygon=STONE_WINDOWS[i], feather=2.9), (0, 12, 720, 765))
        center = (421, 837, 1253)[i]
        if active:
            engraving = Image.new('L', SOURCE)
            pen = ImageDraw.Draw(engraving)
            pen.line([(669,203),(659,300),(655,440),(652,580),(651,638)], fill=228, width=17)
            pen.line([(995,203),(1005,309),(1012,446),(1013,590),(1012,634)], fill=228, width=17)
            for xy in ((816,80,857,122),(813,422,862,460)):
                pen.ellipse(xy, fill=238)
            gray = ImageOps.grayscale(source)
            relief = ImageChops.subtract(gray, gray.filter(ImageFilter.GaussianBlur(2.1)))
            relief = ImageChops.multiply(engraving, relief.point(lambda v: min(255, max(0, (v-2)*15))))
            glow(face, relief, '#a975fc', 11, .94)
            tint(face, relief, '#e0bfff', .97)
        d = ImageDraw.Draw(face)
        key(d, (center, 478), i+1, g[5], 18)
        label_text(d, (center, 505), g, 21)
        text(d, (center, 540), g[2], 39, '#ffdfaf', True, 'center')
        paragraph(d, center, 592, g[3], 274, 21, 27, 'center')
        text(d, (center, 674), NEW_GOD, 17, '#dbdbe3', align='center')
        scale = (1.15, 1.11) if active else (1.12, 1.08)
        offset = (-3, 61) if active else (24, 75)
        layer = cutout(face, matte)
        place(im, layer, offset, scale, shadow=10)
    chrome(im, '#c4b697')
    return im


def constellation(source):
    zone = Image.new('L', SOURCE)
    d = ImageDraw.Draw(zone)
    d.line([(205,245),(302,188),(420,150),(497,118),(600,85),(720,63),(836,57),
            (950,63),(1078,86),(1179,119),(1251,151),(1360,189),(1460,245)], fill=255, width=68)
    for chain in (
        [(256,69),(319,44),(371,67),(401,110)],
        [(1140,76),(1162,38),(1225,70),(1257,66),(1294,130)],
        [(526,256),(550,242),(583,213),(634,180),(698,195),(724,218)],
        [(527,280),(568,297),(607,309),(665,294),(687,271)],
        [(969,220),(1000,208),(1040,181),(1104,196),(1125,232),(1167,255)],
        [(983,266),(1026,289),(1067,310),(1101,274),(1124,231),(1165,224)],
        [(836,5),(836,123),(836,145)],
    ):
        d.line(chain, fill=255, width=34)
    d.ellipse((779,0,894,112), fill=255)
    gray = ImageOps.grayscale(source)
    detail = ImageChops.subtract(gray, gray.filter(ImageFilter.GaussianBlur(4)))
    alpha = ImageChops.multiply(zone.filter(ImageFilter.GaussianBlur(11)),
                               detail.point(lambda v: min(255, max(0, (v-4)*6))))
    return cutout(source, alpha)


def compass(hover):
    im = base()
    source = art('B')
    scale = (1.07, 1.01)
    offset = (65, 122)
    place(im, constellation(source), offset, scale)
    for i, x in enumerate((376, 836, 1297)):
        g = GODS[i]
        y = 315
        active = hover and i == 1
        frame = shape(SOURCE, ellipse=(x-166, y-163, x+166, y+163), feather=.8)
        for points in (
            [(x-158,y-25),(x-187,311),(x-159,335)],
            [(x+159,y-25),(x+182,311),(x+159,335)],
            [(x-17,159),(x,143),(x+17,159),(x,173)],
            [(x-16,473),(x,487),(x+16,473),(x,459)],
        ):
            frame = ImageChops.lighter(frame, shape(SOURCE, polygon=points, feather=.7))
        face = source.copy()
        disk(face, g, (x, y), 153, (0, 12, 720, 760))
        badge_scale = (1.16, 1.10) if active else scale
        badge_offset = (offset[0]+(scale[0]-badge_scale[0])*x,
                        offset[1]+(scale[1]-badge_scale[1])*y-8) if active else offset
        if active:
            halo = shape(SOURCE, ellipse=(x-170, y-167, x+170, y+167), feather=1)
            rim = ImageChops.subtract(halo, frame)
            luminous = Image.new('RGBA', SOURCE)
            glow(luminous, halo, '#9a62ff', 18, .65)
            tint(luminous, rim, '#d8b8ff', .78)
            place(im, luminous, badge_offset, badge_scale)
        place(im, cutout(face, frame), badge_offset, badge_scale, shadow=8)
        d = ImageDraw.Draw(im)
        cx = round(x*scale[0]+offset[0])
        key(d, (cx-161 if not active else cx-179, 321 if not active else 306), i+1, g[5], 24)
        label_text(d, (cx, 643), g, 25)
    panel_outline = [(175,601),(817,601),(831,593),(836,580),(843,593),(856,601),
                     (1497,601),(1497,615),(1504,628),(1517,639),(1530,642),(1530,803),
                     (1517,805),(1506,814),(1498,827),(1497,842),(854,842),(836,848),
                     (819,842),(174,842),(173,827),(167,815),(155,805),(141,802),(141,642),
                     (154,639),(165,631),(172,620)]
    panel = source.copy()
    inside = shape(SOURCE, polygon=[(179,609),(1490,609),(1519,646),(1519,796),
                                    (1490,833),(179,833),(152,796),(152,646)], feather=14)
    tint(panel, inside, '#111f3a', .59)
    place(im, cutout(panel, shape(SOURCE, polygon=panel_outline, feather=1)),
          (65, 280), (1.07, .75), shadow=9)
    g = GODS[1 if hover else 0]
    d = ImageDraw.Draw(im)
    text(d, (283, 777), g[2], 43, '#ffebcc', True)
    label_text(d, (1623, 780), g, 25, 'right')
    paragraph(d, 285, 835, g[3], 1290, 27, 34)
    text(d, (285, 881), NEW_GOD, 22, '#d3dce9')
    chrome(im, '#c2a77a')
    return im


def banners(hover):
    im = base()
    source = art('C')
    scale = (1.14, .94)
    offset = (7, 131)
    for i, shift in enumerate((0, 365, 729)):
        g = GODS[i]
        active = hover and i == 1
        outline = [(x+shift, y+(7 if i==1 and y>700 else 0)) for x,y in FIRST_BANNER]
        matte = shape(SOURCE, polygon=outline, feather=.65)
        # Warm threads at the fringe, against the blue generated backdrop.
        r, _, b, _ = source.split()
        warmth = ImageChops.subtract(r, b).point(lambda v: min(255, max(0, (v-7)*15)))
        fringe = Image.new('L', SOURCE)
        ImageDraw.Draw(fringe).polygon([(322+shift,702),(477+shift,787),(615+shift,704),
                                        (644+shift,839),(313+shift,839)], fill=255)
        matte = Image.composite(ImageChops.multiply(warmth, matte), matte,
                                fringe.filter(ImageFilter.GaussianBlur(3)))
        face = source.copy()
        lining = [(345,157),(367,147),(392,139),(568,139),(589,144),(601,161),
                  (601,450),(579,474),(355,474),(341,453),(341,180)]
        cloth_matte = shape(SOURCE, polygon=[(x+shift,y) for x,y in lining], feather=2.0)
        lx, ly, rx, ry = cloth_matte.getbbox()
        swatch = source.crop((349+shift, 469, 593+shift, 673)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        swatch = swatch.resize((rx-lx, ry-ly), RESAMPLE)
        fabric_fade = Image.new('L', (1, ry-ly))
        fabric_fade.putdata([round(255*min(1, (ry-y)/36)) for y in range(ly,ry)])
        face.paste(swatch, (lx, ly), ImageChops.multiply(cloth_matte.crop((lx,ly,rx,ry)),
                                                       fabric_fade.resize(swatch.size)))
        window = [(353,149),(384,146),(565,146),(587,151),(596,171),(596,441),
                  (574,461),(524,470),(427,470),(370,460),(347,439),(347,183)]
        portrait(face, g, shape(SOURCE, polygon=[(x+shift,y) for x,y in window], feather=4),
                 (18, 0, 702, 830), cloth=True)
        reading_area = shape(SOURCE, ellipse=(341+shift,440,601+shift,728), feather=24)
        tint(face, reading_area, '#140d1a', .40 if i == 2 else .25)
        if active:
            thread = Image.new('L', SOURCE)
            d = ImageDraw.Draw(thread)
            d.line([(704,170),(702,694),(838,787),(976,701),(972,170)],
                   fill=255, width=13, joint='curve')
            thread = ImageChops.multiply(thread, warmth)
            glow(face, thread, '#ffc369', 10, .85)
            tint(face, thread, '#ffe2a0', .58)
        layer = cutout(face, matte)
        if active:
            # The affine pivot stays at the hanging rod while the tip swings right and down.
            layer = layer.transform(SOURCE, Image.Transform.AFFINE,
                                    (1, -.044, .044*147, 0, 1/1.029, 147*(1-1/1.029)),
                                    Image.Resampling.BICUBIC)
        place(im, layer, offset, scale, shadow=9)
        center = 472 + shift
        d = ImageDraw.Draw(im)
        def banner_text_position(y):
            swing = max(0, y - 147) if active else 0
            return (round(offset[0]+(center+swing*.044)*scale[0]),
                    round(offset[1]+(y+swing*.029)*scale[1]))
        key(d, banner_text_position(462), i+1, g[5], 21)
        label_text(d, banner_text_position(492), g, 21)
        text(d, banner_text_position(528), g[2], 42, '#ffe6bd', True, 'center')
        for j, line in enumerate(wrap(d, g[3], 268, 22)):
            text(d, banner_text_position(590+j*29), line, 22, align='center')
        text(d, banner_text_position(690), NEW_GOD, 19, '#f2e6d5', align='center')
    place(im, cutout(source, shape(SOURCE, polygon=BEAM, feather=.85)), offset, scale, shadow=7)
    chrome(im, '#c39866')
    return im


def codex(hover):
    im = base()
    book = art('D').copy()
    pts = (367, 511, 655)
    active = 1 if hover else 0
    for i, y in enumerate(pts):
        g = GODS[i]
        if i == active:
            row = shape(SOURCE, polygon=[(349,y-44),(744,y-44),(769,y-31),(769,y+30),
                                         (744,y+49),(353,y+49),(337,y+35),(337,y-30)], feather=5)
            tint(book, row, '#a482da' if hover else '#6094c0', .29)
            ink = Image.new('L', SOURCE)
            pen = ImageDraw.Draw(ink)
            pen.line([(367,y-45),(745,y-45),(768,y-32)], fill=228, width=2)
            pen.line([(367,y+51),(745,y+51),(768,y+31)], fill=228, width=2)
            glow(book, ink, g[5], 5)
            tint(book, ink, g[5], .71)
        disk(book, g, (291, y), 60, (0, 15, 720, 710))
        d = ImageDraw.Draw(book)
        label_text(d, (386, y-13), g, 23, 'left')
        key(d, (723, y+1), i+1, g[5], 21)
    g = GODS[active]
    disk(book, g, (1174, 351), 144, (0, 5, 720, 795))
    d = ImageDraw.Draw(book)
    label_text(d, (1192, 527), g, 24)
    text(d, (1192, 567), g[2], 45, '#ffe9c6', True, 'center')
    paragraph(d, 1192, 629, g[3], 530, 24, 28, 'center')
    text(d, (1192, 694), NEW_GOD, 20, '#dfdddf', align='center')
    place(im, cutout(book, shape(SOURCE, polygon=BOOK, feather=1)), (116, -1), (1.01, 1.025), shadow=12)
    chrome(im, '#bdab8d')
    return im


if __name__ == '__main__':
    for name, render in zip(DIRS, (stones, compass, banners, codex)):
        for hover in (False, True):
            filename = '悬停.png' if hover else '样张.png'
            render(hover).convert('RGB').save(ROOT / name / filename, compress_level=5)
