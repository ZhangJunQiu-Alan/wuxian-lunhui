from body import B, CHAR, strip, crop, publish, sockets
from PIL import Image, ImageDraw, ImageOps
import math, json, sys

INK='#161418'; CLOTH='#30333e'; SEAM='#545867'
SKIN='#926952'; LIGHT='#d29e79'; SHADOW='#634639'
SOURCE={a:Image.open(CHAR/f'swordsman_bare_{a}.png').convert('RGBA') for a in ['idle','move','attack','hurt','death']}
STATE=json.loads((CHAR/'swordsman_sockets.json').read_text())

def source(ref,mirror=False,x=0,y=0,lean=0):
    act,n=ref
    frame=crop(SOURCE[act],n)
    s=STATE['actions'][act][n]
    if mirror: frame=ImageOps.mirror(frame)
    out=Image.new('RGBA',(64,64))
    def dx(yy):return round(max(0,57-yy)*lean/45)
    for yy in range(64):
        if 0<=yy+y<64:out.paste(frame.crop((0,yy,64,yy+1)),(x+dx(yy),yy+y))
    loc={k:((63-v['x'] if mirror else v['x'])+x+dx(v['y']),v['y']+y,v.get('deg',0)) for k,v in s.items() if k!='mode'}
    return out,loc

def arm(im,shoulder,elbow,fist,behind=False):
    layer=Image.new('RGBA',(64,64));d=ImageDraw.Draw(layer)
    d.line([shoulder,elbow],fill=INK,width=7)
    d.line([shoulder,elbow],fill=CLOTH,width=5)
    d.line([(shoulder[0],shoulder[1]-1),(elbow[0],elbow[1]-1)],fill=SEAM,width=2)
    d.line([elbow,fist],fill=INK,width=5)
    d.line([elbow,fist],fill=SHADOW,width=3)
    d.line([(elbow[0],elbow[1]-1),(fist[0],fist[1]-1)],fill=SKIN,width=2)
    x,y=fist
    d.polygon([(x-2,y-1),(x-1,y-2),(x+1,y-2),(x+2,y-1),(x+2,y+1),(x+1,y+2),(x-1,y+2),(x-2,y+1)],fill=INK)
    d.rectangle((x-1,y-1,x+1,y),fill=LIGHT)
    d.point((x,y+1),fill=SKIN)
    if behind: layer.alpha_composite(im);return layer
    im.alpha_composite(layer);return im

def move_hand(im,loc,hand,xy,shoulder=None,elbow=None,behind=False):
    ox,oy,_=loc[hand]; x,y,deg=xy
    d=ImageDraw.Draw(im)
    if abs(x-ox)+abs(y-oy)>4:
        for yy in range(oy-2,oy+3):
            for xx in range(ox-2,ox+3):
                r,g,b,a=im.getpixel((xx,yy))
                if a and r>g+14 and g>b+8:
                    color=im.getpixel((xx-2 if ox>=loc['back'][0] else xx+2,yy))
                    d.point((xx,yy),fill=color if color[3] and color[0]<color[2]+15 else (0,0,0,0))
    loc[hand]=xy
    if shoulder:
        im=arm(im,shoulder,elbow,(x,y),behind)
    return im

def pose(ref,main=None,off=None,mirror=False,lean=0,x=0,y=0,mode='held',front=True,main_arm=None,off_arm=None,turn=None):
    im,loc=source(ref,mirror,x,y,lean)
    if turn:
        hx,hy,_=loc['head'];d=ImageDraw.Draw(im)
        if turn=='back':
            for yy in range(hy-2,hy+9):
                for xx in range(hx-6,hx+7):
                    r,g,b,a=im.getpixel((xx,yy))
                    if a and r>g+16 and g>b+7:d.point((xx,yy),fill='#2a2427' if yy<hy+5 else '#473c3a')
            d.line([(hx-2,hy),(hx+1,hy-1),(hx+4,hy+1)],fill='#4a3f41',width=1)
        if turn=='front':
            d.polygon([(hx-3,hy+1),(hx+3,hy+1),(hx+3,hy+5),(hx+1,hy+7),(hx-2,hy+6)],fill=SKIN)
            d.line([(hx-2,hy+3),(hx-1,hy+3)],fill=INK)
            d.line([(hx+1,hy+3),(hx+2,hy+3)],fill=INK)
            d.point((hx,hy+5),fill=LIGHT)
    if off:
        im=move_hand(im,loc,'off',off,*(off_arm or (None,None)),behind=False)
    if main:
        im=move_hand(im,loc,'main',main,*(main_arm or (None,None)),behind=False)
    return im,sockets(loc['main'],loc['off'],loc['hip'],loc['back'],loc['head'],mode,front)

def spin():
    return [
      pose(('attack',1),(36,19,-6),(32,20,169),main_arm=((33,28),(41,24)),off_arm=((29,29),(28,24))),
      pose(('attack',0),(32,23,76),(28,21,145),x=2,main_arm=((36,30),(39,26)),off_arm=((28,31),(24,25)),turn='front'),
      pose(('attack',1),(30,20,172),(34,20,14),mirror=True,main_arm=((34,28),(25,24)),off_arm=((39,28),(39,23)),turn='back',front=False),
      pose(('attack',0),(33,19,-93),(37,22,33),mirror=True,x=-1,main_arm=((29,28),(26,24)),off_arm=((37,28),(41,25)),turn='back',front=False)
    ]
def heavy():
    return [
      pose(('attack',1),(28,18,-151),(31,21,31),off_arm=((36,28),(36,24))),
      pose(('attack',1),(34,12,-92),(35,17,91),main_arm=((36,28),(29,19)),off_arm=((38,28),(42,20))),
      pose(('attack',2),(44,28,9),(39,30,164),off_arm=((33,28),(34,33))),
      pose(('attack',3),(42,42,26),(37,40,199),lean=4,main_arm=((33,29),(36,36)),off_arm=((29,30),(31,37))),
      pose(('attack',4),(36,39,26),(32,37,197),lean=2)
    ]
def sheathe():
    return [
      pose(('attack',3),(37,36,153),(32,39,152)),
      pose(('attack',4),(38,36,154),(32,39,154),main_arm=((34,29),(43,32))),
      pose(('attack',4),(35,36,156),(31,38,156),lean=-1),
      pose(('idle',2),(37,34,152),(29,40,92),mode='stow',main_arm=((36,26),(40,31)))
    ]
def iai_stance():
    return [pose(('attack',4),(35+(i==2),37,151),(28,39,150),lean=-3+(i==2),mode='stow',
         main_arm=((34,28),(39,33)),off_arm=((26,28),(24,35))) for i in range(4)]
def iai_dash():
    return [
      pose(('move',0),(19,36,160),(40,33,0),lean=4,front=False),
      pose(('move',3),(18,38,160),(47,31,0),lean=6,front=False,main_arm=((32,27),(25,32))),
      pose(('attack',3),(25,35,157),(43,36,18),lean=6,front=False,main_arm=((35,27),(30,31)))
    ]
def thrust():
    return [
      pose(('attack',4),(35,35,0),(26,33,166),lean=-3),
      pose(('attack',2),(44,29,0),(26,36,160),lean=2),
      pose(('attack',2),(48,29,0),(28,36,156),lean=5,main_arm=((35,27),(42,29))),
      pose(('attack',3),(38,34,7),(28,34,148),lean=1)
    ]
def throw():
    return [
      pose(('attack',4),(37,35,15),(22,29,-146),off_arm=((28,28),(24,33))),
      pose(('attack',1),(36,35,27),(27,18,-76),main_arm=((38,27),(40,33)),off_arm=((31,28),(24,24))),
      pose(('attack',2),(34,35,16),(44,29,0),lean=2,main_arm=((32,27),(29,34))),
      pose(('attack',3),(36,37,28),(42,32,8),off_arm=((30,30),(36,30)))
    ]
def drink():
    return [
      pose(('idle',0),off=(25,39,0),mode='stow'),
      pose(('idle',1),off=(38,28,-28),off_arm=((28,28),(29,34)),mode='stow'),
      pose(('idle',2),off=(39,20,-93),off_arm=((29,28),(34,30)),mode='stow',lean=-1),
      pose(('idle',2),off=(38,19,-125),off_arm=((28,28),(34,28)),mode='stow',lean=-2),
      pose(('idle',3),off=(38,26,-50),off_arm=((28,28),(31,34)),mode='stow'),
      pose(('idle',0),off=(30,36,0),off_arm=((27,27),(25,33)),mode='stow')
    ]

if __name__=='__main__':
    for a in sys.argv[1:]:
        frames,points=zip(*globals()[a]())
        publish(strip(frames),CHAR/f'swordsman_bare_{a}.png')
        STATE['actions'][a]=points
    (CHAR/'swordsman_sockets.json').write_text(json.dumps(STATE,indent=2)+'\n')
