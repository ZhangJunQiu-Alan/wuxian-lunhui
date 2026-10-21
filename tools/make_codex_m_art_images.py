## 生成 docs/images/codex_m_art/ 下的三张美术对比图（M-ART-01～03）
##   python3 tools/make_codex_m_art_images.py <review_vigrid_aid.gd 的输出目录>
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
P = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + '/'
G = P + 'assets/sprites/ground/'
SHOTS = P + 'assets/source/taskK_code_integration_2026-10-20/screenshots/'
AID = sys.argv[1]
OUT = P + 'docs/images/codex_m_art/'
F = lambda s: ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc', s)
BG = (18, 18, 22); FG = (235, 230, 220); DIM = (160, 155, 150); OK = (120, 220, 120); BAD = (240, 110, 90)

def stats(path):
    im = Image.open(path).convert('RGB'); px = list(im.get_flattened_data()); n = len(px)
    avg = tuple(sum(p[i] for p in px) // n for i in range(3))
    lum = [0.299*p[0] + 0.587*p[1] + 0.114*p[2] for p in px]
    m = sum(lum) / n
    return avg, m, (sum((x - m) ** 2 for x in lum) / n) ** 0.5

def tiled(path, k=3, scale=2):
    t = Image.open(path).convert('RGB'); w = t.width
    im = Image.new('RGB', (w*k, w*k))
    for y in range(k):
        for x in range(k):
            im.paste(t, (x*w, y*w))
    return im.resize((w*k*scale, w*k*scale), Image.NEAREST)

def swatch_pair(canvas, d, x, y, title, items, size=192):
    d.text((x, y), title, font=F(22), fill=FG)
    y += 34
    for i, (name, path) in enumerate(items):
        avg, lum, sd = stats(path)
        canvas.paste(tiled(path, 3, 1).resize((size, size), Image.NEAREST), (x + i*(size+12), y))
        d.rectangle((x + i*(size+12), y + size + 6, x + i*(size+12) + 28, y + size + 34), fill=avg)
        d.text((x + i*(size+12) + 36, y + size + 4), name, font=F(15), fill=FG)
        d.text((x + i*(size+12) + 36, y + size + 22), f'亮度 {lum:.0f} · 对比 {sd:.1f}', font=F(14), fill=DIM)
    return y + size + 50

# ———— M-ART-01 地面 ————
W, H = 1960, 1500
c = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(c)
d.text((40, 24), 'M-ART-01  维格利德地面：现状和前两关对比', font=F(34), fill=FG)
d.text((40, 72), '每块是 64×64 地块平铺 3×3（原尺寸）。色块 = 平均色；亮度 = 平均亮度；对比 = 亮度标准差（纹理有多花）。', font=F(18), fill=DIM)
y = 120
y1 = swatch_pair(c, d, 40, y, '第 1 关：亮度相同，路的纹理对比度是底的 6 倍（看得出）', [('snow_01 底', G+'midgard/snow_01.png'), ('snow_trampled 路', G+'midgard/snow_trampled.png')])
swatch_pair(c, d, 1000, y, '第 2 关：亮度相同，路的纹理对比度是底的 2 倍（看得出）', [('stone_01 底', G+'helheim/stone_01.png'), ('bone_path 路', G+'helheim/bone_path.png')])
y2 = swatch_pair(c, d, 40, y1, '第 3 关现在：平均色都是 (38,31,32)，路的对比度只是底的 1.3 倍（看不出）',
    [('scorched_01 底', G+'vigrid/scorched_01.png'), ('scorched_02 当路用', G+'vigrid/scorched_02.png'),
     ('burnt_grass 焦草', G+'vigrid/burnt_grass.png'), ('cracked_lava 裂地', G+'vigrid/cracked_lava.png')])
d.text((900, y1 + 60), '问题', font=F(24), fill=BAD)
for i, t in enumerate(['底、路、焦草、裂地四种的平均色完全一样', '前两关的路靠纹理对比度拉开（2～6 倍），第 3 关只有 1.3 倍',
        '出生点是 5 条路的交汇处（路宽 256），截图里一条都看不到', '裂地的亮橙裂缝几乎没有，看不出是裂地']):
    d.text((900, y1 + 100 + i*34), '· ' + t, font=F(18), fill=FG)
# 实机现状 vs 示意
shot = Image.open(SHOTS + 'map_spawn.png').convert('RGB')
cur = shot.resize((880, 495), Image.LANCZOS)
d.text((40, y2), '实机现状：出生点 (0,0)，1280×720', font=F(22), fill=BAD)
c.paste(cur, (40, y2 + 36))
# 示意：把 5 条路按目标亮度涂出来
mock = shot.copy()
road = Image.open(G + 'vigrid/scorched_02.png').convert('RGB')
rpx = road.load()
for yy in range(64):
    for xx in range(64):
        r, g, b = rpx[xx, yy]; lum = 0.299*r + 0.587*g + 0.114*b
        k = lum / 33.4
        rpx[xx, yy] = (min(255, int(70*k)), min(255, int(60*k)), min(255, int(52*k)))
roads = Image.new('RGB', mock.size)
for y0 in range(0, mock.height, 64):
    for x0 in range(0, mock.width, 64):
        roads.paste(road, (x0, y0))
mask = Image.new('L', mock.size, 0); md = ImageDraw.Draw(mask)
random.seed(3)
for tx, ty in [(-1536, -1408), (1536, -1280), (-1536, 1024), (1536, 1280), (0, 1792)]:
    ang = math.atan2(ty, tx); ux, uy = math.cos(ang), math.sin(ang); px_, py_ = -uy, ux
    pts_l, pts_r = [], []
    for s in range(0, 900, 24):
        jl = random.uniform(-14, 14); jr = random.uniform(-14, 14)
        cx, cy = 640 + ux*s, 360 + uy*s
        pts_l.append((cx + px_*(128+jl), cy + py_*(128+jl))); pts_r.append((cx - px_*(128+jr), cy - py_*(128+jr)))
    md.polygon(pts_l + pts_r[::-1], fill=255)
md.ellipse((640-170, 360-170, 640+170, 360+170), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(3))
mock.paste(roads, (0, 0), mask)
# 焦草斑块示意
grass = Image.open(G + 'vigrid/burnt_grass.png').convert('RGB'); gpx = grass.load()
for yy in range(64):
    for xx in range(64):
        r, g, b = gpx[xx, yy]; k = (0.299*r + 0.587*g + 0.114*b) / 33.4
        gpx[xx, yy] = (min(255, int(44*k)), min(255, int(40*k)), min(255, int(26*k)))
gl = Image.new('RGB', mock.size)
for y0 in range(0, mock.height, 64):
    for x0 in range(0, mock.width, 64):
        gl.paste(grass, (x0, y0))
gm = Image.new('L', mock.size, 0); gd = ImageDraw.Draw(gm)
for cx, cy, r in [(1080, 140, 150), (190, 560, 130), (1150, 620, 110)]:
    gd.ellipse((cx-r, cy-r*0.7, cx+r, cy+r*0.7), fill=255)
gm = gm.filter(ImageFilter.GaussianBlur(6))
mock.paste(gl, (0, 0), gm)
mock = mock.resize((880, 495), Image.LANCZOS)
d.text((1000, y2), '示意：按目标数值程序调色（不是成品画法）', font=F(22), fill=OK)
c.paste(mock, (1000, y2 + 36))
y3 = y2 + 36 + 495 + 20
for i, t in enumerate(['示意图只演示「路比底色亮、焦草偏暗橄榄」的效果，纹理还是原来的 scorched_02 / burnt_grass 直接调色；成品用亮度差或纹理对比度都可以，见任务书的数值。',
        '成品要求：灰褐色、无方向的碎石灰烬纹理、不规则碎边过渡（ash_road + 12 张 ash_road_edge_*）；不能用橙红色。',
        '敌人、Boss 预警（红橙半透明）、火焰地面在新地面上必须依然是画面里最醒目的东西。']):
    d.text((40, y3 + i*32), '· ' + t, font=F(18), fill=FG)
c = c.crop((0, 0, W, y3 + 3*32 + 30)); c.save(OUT + 'M01_ground.png')

# ———— M-ART-02 剑弧 ————
shot = Image.open(SHOTS + 'surtr_sweep_release.png').convert('RGB')
W, H = 1960, 1060
c = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(c)
d.text((40, 24), 'M-ART-02  苏尔特炎之剑横扫：像素颗粒对比', font=F(34), fill=FG)
d.text((40, 76), '实机截图（1280×720）', font=F(22), fill=FG)
c.paste(shot.resize((960, 540), Image.LANCZOS), (40, 112))
# 放大局部：剑弧 vs 本体
arc = shot.crop((690, 220, 790, 320)).resize((400, 400), Image.NEAREST)
body = shot.crop((860, 250, 960, 350)).resize((400, 400), Image.NEAREST)
d.text((1040, 76), '同一张截图局部放大 4 倍', font=F(22), fill=FG)
c.paste(arc, (1040, 112)); c.paste(body, (1500, 112))
d.text((1040, 520), '剑弧：一个像素块 ≈ 4.8 个屏幕像素', font=F(18), fill=BAD)
d.text((1500, 520), '苏尔特本体：1 像素 = 1 屏幕像素', font=F(18), fill=OK)
d.text((1040, 560), '原因：surtr_sword_arc.png 是 128×128 帧、弧半径 60，', font=F(17), fill=DIM)
d.text((1040, 586), '伤害扇形半径 290，只能放大 290 / 60 ≈ 4.83 倍（还不是整数倍）。', font=F(17), fill=DIM)
# 规格示意：640 帧
x0, y0, S = 1040, 640, 380
d.text((40, 680), '交付规格示意：surtr_sword_arc_large.png', font=F(22), fill=OK)
for i, t in enumerate(['横排 4 帧，每帧 640×640（整张 2560×640），16 帧/秒单次', '锚点 = 帧中心 (320,320) = 苏尔特位置',
        '弧在 +x 方向，外沿半径 290，覆盖 ±60°（半角 1.05 弧度）', '弧不能超出扇形，也不能明显缩在里面', '1× 像素，黑焰 + 亮橙刃光，第 4 帧淡到 0.3 以下']):
    d.text((40, 724 + i*34), '· ' + t, font=F(18), fill=FG)
k = S / 640
d.rectangle((x0, y0, x0 + S, y0 + S), outline=DIM, width=2)
cx, cy = x0 + 320*k, y0 + 320*k
r = 290*k
d.pieslice((cx - r, cy - r, cx + r, cy + r), -60, 60, fill=(90, 30, 20), outline=(240, 120, 60), width=2)
d.arc((cx - r, cy - r, cx + r, cy + r), -60, 60, fill=(255, 200, 90), width=6)
d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=OK)
d.text((cx - 70, cy + 10), '锚点 (320,320)', font=F(15), fill=OK)
d.line((cx, cy, cx + r*math.cos(math.radians(-60)), cy + r*math.sin(math.radians(-60))), fill=DIM, width=1)
d.text((cx + 60, cy - 120), '半径 290', font=F(15), fill=FG)
d.text((cx + 70, cy - 12), '±60°', font=F(15), fill=FG)
d.text((x0, y0 + S + 6), '640 × 640 一帧（缩小示意）', font=F(15), fill=DIM)
c.save(OUT + 'M02_sword_arc.png')

# ———— M-ART-03 援助 ————
gods = [('thor', '托尔（对照：辨识度好）', OK), ('freyja', '弗蕾亚', BAD), ('baldr', '巴德尔', BAD), ('ran', '澜', BAD), ('skadi', '斯卡蒂', BAD)]
cw, ch = 380, 300
W = 40 + len(gods) * (cw + 12) + 28
c = Image.new('RGB', (W, 1500), BG); d = ImageDraw.Draw(c)
d.text((40, 24), 'M-ART-03  周期援助：现状对比（实机 1280×720 截图局部）', font=F(34), fill=FG)
d.text((40, 72), '同一机位：玩家身边 10 个打不死的亡者，直接请这位神出手一次；上排 = 出手后第 2 帧，下排 = 第 12 帧。角色武器已关掉，画面里只有援助效果。', font=F(17), fill=DIM)
for i, (g, name, col) in enumerate(gods):
    x = 40 + i * (cw + 12)
    d.text((x, 112), name, font=F(22), fill=col)
    for j, f in enumerate(['f02', 'f12']):
        im = Image.open(f'{AID}/aid_{g}_{f}.png').convert('RGB').crop((450, 210, 830, 510))
        c.paste(im, (x, 148 + j * (ch + 10)))
y = 148 + 2 * (ch + 10) + 20
for i, t in enumerate(['托尔：三道从天而降的落雷，一眼看出是神出手，也看出打在哪。',
        '另外四位：只有一圈通用的白蓝光环加粒子，四位神看起来几乎一样；玩家分不清是谁出手、效果是什么、范围多大。',
        '要做的：每位神一套 8 帧 320×320 特效，第 1～2 帧从天而降（羽毛 / 光柱 / 渔网 / 冰箭雨），第 3～6 帧在地面展开到判定半径，第 7～8 帧消散。',
        '地面圈外沿 = 判定半径：弗蕾亚 140（以玩家为中心）、巴德尔 110、澜 130、斯卡蒂 130（敌人最密的点）。主色用神的色值，不用红橙。']):
    d.text((40, y + i * 34), '· ' + t, font=F(18), fill=FG)
# 帧布局示意
y += 4 * 34 + 20
d.text((40, y), '帧布局示意（320×320，锚点在中心；圆 = 判定半径）', font=F(20), fill=OK)
y += 36
colors = {'freyja': (255, 217, 102), 'baldr': (255, 242, 178), 'ran': (89, 178, 242), 'skadi': (191, 235, 255)}
radii = {'freyja': 140, 'baldr': 110, 'ran': 130, 'skadi': 130}
for i, g in enumerate(['freyja', 'baldr', 'ran', 'skadi']):
    x = 40 + i * 250; s = 220; k = s / 320
    d.rectangle((x, y, x + s, y + s), outline=DIM, width=1)
    cx, cy = x + s/2, y + s/2; r = radii[g] * k
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=colors[g], width=3)
    d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=OK)
    d.text((x, y + s + 6), f'{g}  半径 {radii[g]}', font=F(15), fill=FG)
c = c.crop((0, 0, W, y + 220 + 40)); c.save(OUT + 'M03_aid.png')
print('ok')
