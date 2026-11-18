"""Sample reachable player centres using the gate limits and circular collision anchors."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from prepare import OLD, DATA, floor_polygon, expand

ROOT = Path(__file__).resolve().parents[5]
REPORT = ROOT/'docs/Codex_冻石庭院第四版/截图/轮次08'
STEP = 2
LEFT, NORTH = -700, -960
SIZE = (1100, 960)
OLD_FOES = [(-358,-246),(-194,-271),(106,229),(250,147)]
NEW_FOES = [(-195,-470),(350,420),(905,100),(545,-556)]


def grid_point(point):
    return ((point[0]-LEFT)/STEP, (point[1]-NORTH)/STEP)


def walkable(new):
    mask = Image.new('L', SIZE)
    d = ImageDraw.Draw(mask)
    polygon = floor_polygon()
    if new:
        polygon = np.array(expand(*polygon.T)).T
    d.polygon([grid_point(p*100) for p in polygon],fill=255)
    if new:
        circles = DATA['anchors'] + [c[1:4] for c in DATA['covers']]
    else:
        circles = [(a['world'][0]*100,a['world'][2]*100,a['radius_world']*100) for a in OLD['collision_anchors']]
    for x,y,r in circles:
        cx,cy = grid_point((x,y))
        r = (r+14)/STEP
        d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=0)
    # Game.clamp_to_map applies the player's margin before resolving circular footprints.
    east = 1388 if new else 808
    half = 936 if new else 720
    l,t = grid_point((-642+14,-half+14))
    r,b = grid_point((east-14,half-14))
    d.rectangle((0,0,l-1,SIZE[1]),fill=0)
    d.rectangle((r+1,0,SIZE[0],SIZE[1]),fill=0)
    d.rectangle((0,0,SIZE[0],t-1),fill=0)
    d.rectangle((0,b+1,SIZE[0],SIZE[1]),fill=0)
    ImageDraw.floodfill(mask,tuple(map(int,grid_point((0,0)))),128)
    return mask.point(lambda a: 255 if a==128 else 0)


def diagram():
    im = Image.new('RGB',(1660,1000),'#172231')
    d = ImageDraw.Draw(im)
    def label(x,y,txt,size,color='#edf4f7'):
        d.text((x,y),txt,font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',size),fill=color)
    label(50,35,'冻石庭院   /   中庭战斗布局',42)
    label(51,99,'同一比例尺   ·   俯视   ·   北侧长厅在上   ·   横轴从西入口向东出口',22,'#aebfcb')
    summary=[]
    for i,new in enumerate([False,True]):
        pane=50+i*800
        mask=walkable(new)
        m=np.asarray(mask)>0
        area=m.sum()*STEP**2/10000
        depth=m.sum(axis=0).max()*STEP/100
        span=np.ptp(np.where(m)[0])*STEP/100
        width=(1388+642 if new else 808+642)/100
        summary.append((area,depth,span))
        label(pane,172,'轮次 08   扩建后' if new else '轮次 07   扩建前',29)
        label(pane,223,f'门间 {width:.2f}  ×  南北跨度 {span:.2f} 世界单位',23,'#afc4d0')
        scale=.58
        top=300
        def point(p):
            x,y=grid_point(p)
            return pane+x*scale,top+y*scale
        small=mask.resize((round(SIZE[0]*scale),round(SIZE[1]*scale)),Image.Resampling.LANCZOS)
        im.paste('#889da9',(pane,top,pane+small.width,top+small.height),small)
        for x in range(-600,1401,200):
            px,_=point((x,0));d.line((px,top,px,top+small.height),fill='#40515d')
        for y in range(-800,801,200):
            _,py=point((0,y));d.line((pane,py,pane+small.width,py),fill='#40515d')
        if new:
            cx,cy=point(DATA['ring'][:2]);r=DATA['ring'][2]/STEP*scale
            d.ellipse((cx-r,cy-r,cx+r,cy+r),outline='#dfca98',width=3)
            for _,x,y,r,_,_ in DATA['covers']:
                px,py=point((x,y));r=r/STEP*scale
                d.ellipse((px-r,py-r,px+r,py+r),fill='#dfb870',outline='#172231',width=2)
        for x,y in (NEW_FOES if new else OLD_FOES):
            px,py=point((x,y));d.ellipse((px-6,py-6,px+6,py+6),fill='#bc665e')
        for pos,tag in [((-642,-165),'西闸'),((1388 if new else 808,124),'东门')]:
            px,py=point(pos);label(px-9,py-32,tag,18,'#ffffff')
        label(pane,881,f'角色中心可达面积  {area:.1f} 平方世界单位',24)
    label(50,943,'蓝灰   可走地面        金色   掩体 / 符文环        红点   敌人出生位        网格   2 × 2 世界单位',20,'#afc4d0')
    im.save(REPORT/'新旧中庭俯视布局.png')
    print(summary, 'net ratio', summary[1][0]/summary[0][0])

if __name__ == '__main__':
    diagram()
