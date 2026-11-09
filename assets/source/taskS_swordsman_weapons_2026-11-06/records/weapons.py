from body import B, ROOT, W, publish, icon_single
from PIL import Image, ImageDraw
import json, sys

INK='#131319'
STEEL=('#424955','#828994','#dfe4ea')
GOLD=('#594132','#a47846','#e4c88a')
JADE=('#153333','#28695f','#6ea797')
BLUE=('#18283e','#2b5881','#81b5d3')
RED=('#391a27','#773344','#c4646d')

def shape(size):
    im=Image.new('RGBA',size)
    return im,ImageDraw.Draw(im)

def kat(length,curve,steel=STEEL,grip='#513b3b',hollow=False):
    h=9 if curve>=3 else 7
    im,d=shape((length,h))
    y=h-4; t=y-curve; end=length-1; g=5
    d.polygon([(g,y-1),(length//2,y-2),(end-4,t),(end,t-1),(end-1,t+2),(end-4,t+3),(length//2,y+1),(g,y+2)],fill=INK)
    d.polygon([(g+1,y),(length//2,y-1),(end-3,t+1),(end-1,t),(end-3,t+2),(length//2,y),(g+1,y+1)],fill=steel[0])
    d.line([(g+1,y+1),(length//2,y),(end-4,t+2),(end-1,t)],fill=steel[1])
    d.line([(end-5,t+2),(end-2,t+1)],fill=steel[2])
    d.rectangle((0,y-1,g,y+1),fill=INK)
    d.line([(1,y),(4,y)],fill=grip)
    if hollow:d.point((2,y),fill=(0,0,0,0))
    else:d.point((3,y),fill='#312728')
    d.line([(g,y-2),(g,y+2)],fill=steel[0] if hollow else GOLD[0])
    d.point((g,y-1),fill=steel[1] if hollow else GOLD[1])
    return im,(2,y),(end,t-1)

def sheath(length,curve,primary,detail,hang=False,cord=False):
    h=10 if hang else 8
    im,d=shape((length,h));y=3 if hang else 4; end=length-1;cy=y+(curve if hang else -curve)
    d.polygon([(0,y-1),(6,y-1),(length//2,y-1),(end,cy-1),(end,cy+1),(length//2,y+2),(6,y+2),(5,y+1),(0,y+1)],fill=INK)
    d.line([(1,y),(4,y)],fill=detail)
    d.line([(6,y),(length//2,y),(end-1,cy)],fill=primary)
    d.point((end-1,cy+1),fill=detail)
    d.line([(5,y-2),(5,y+2)],fill=detail)
    if hang:
        d.line([(8,y+2),(8,y+4),(10,y+4),(10,y+2)],fill=GOLD[1])
        d.point((14,y+3),fill=GOLD[2])
    if cord:
        d.line([(7,y),(8,y+3),(11,y+2),(13,y+4)],fill=RED[1])
        d.point((11,y+2),fill=RED[2])
    return im,(5,y)

def straight(length,w,metal=STEEL,ornament=GOLD,style='cruciform'):
    im,d=shape((length, max(9,w+4)))
    y=im.height//2; t=length-1; g=5
    d.polygon([(g,y-w//2),(t-5,y-w//2),(t,y),(t-5,y+w//2),(g,y+w//2)],fill=INK)
    d.polygon([(g+1,y-w//2+1),(t-5,y-w//2+1),(t-1,y),(t-5,y+w//2-1),(g+1,y+w//2-1)],fill=metal[1])
    d.line([(g+1,y),(t-2,y)],fill=metal[0])
    d.line([(g+1,y-1),(t-5,y-1),(t-1,y)],fill=metal[2])
    d.line([(0,y),(5,y)],fill=INK,width=3)
    d.line([(1,y),(4,y)],fill='#453843')
    d.point((0,y),fill=ornament[1])
    if style=='cruciform':
        d.polygon([(4,y-4),(6,y-4),(7,y-3),(6,y),(7,y+3),(6,y+4),(4,y+4),(5,y)],fill=INK)
        d.line([(5,y-3),(5,y+3)],fill=ornament[1])
        d.point((5,y-1),fill=ornament[2])
        d.point((0,y),fill=BLUE[2])
    if style in ('bronze','paired','talisman','taiji'):
        d.polygon([(3,y-2),(5,y-3),(7,y-2),(7,y+2),(5,y+3),(3,y+2),(4,y)],fill=INK)
        d.line([(4,y-2),(6,y-1),(6,y+1),(4,y+2)],fill=ornament[1])
        d.point((6,y),fill=ornament[2])
    return im,(2,y),(t,y)

def glow(im,points,color,second=None):
    a,d=shape(im.size)
    d.line(points,fill=color,width=1)
    if second:
        for p in points[::3]: d.point(p,fill=second)
    for x in range(a.width):
        for y in range(a.height):
            if not im.getpixel((x,y))[3]: a.putpixel((x,y),(0,0,0,0))
    return a

def icon_group(ims, angles, centers, size=32):
    out=Image.new('RGBA',(size,size))
    for im,angle,(x,y) in zip(ims,angles,centers):
        a=im.rotate(angle,Image.Resampling.NEAREST,expand=True)
        a=a.crop(a.getbbox()); a.thumbnail((29,29),Image.Resampling.NEAREST)
        out.alpha_composite(a,(x-a.width//2,y-a.height//2))
    return out

def image(id,im):
    publish(im,W/(id+'.png'))
    return 'swordsman/'+id+'.png'

def hand(id,im,grip,tip,g=None):
    out=dict(file=image(id,im),grip=grip,tip=tip,base_deg=0)
    if g:out['glow']=image(id+'_glow',g)
    return out

def base(id,main=None,off=None,variants=None):
    out=dict(id=id,**{'class':'swordsman'},idle_hold='held')
    if main:out['main']=main
    if off:out['off']=off
    if variants:out['variants']=variants
    return out

def stow(w,im,grip,socket='hip',g=None,adjust=None):
    id=w['id']
    w.update(idle_hold='stow',stow=socket,stow_file=image(id+'_stow',im),
        stow_grip=grip,stow_base_deg=0)
    if g:w['stow_glow']=image(id+'_stow_glow',g)
    if adjust:w['stow_socket_adjust']=adjust

def icon(w,im):
    w['icon']=image(w['id']+'_icon',im)
    return w

def qinglong():
    im,d=shape((52,18))
    d.polygon([(0,7),(4,7),(5,8),(31,8),(33,7),(39,7),(43,5),(45,5),(46,3),(48,4),(51,0),(51,6),(48,10),(44,12),(38,13),(34,12),(30,10),(5,10),(4,11),(0,11)],fill=INK)
    d.line([(1,8),(3,8),(4,9),(31,9)],fill=JADE[1])
    d.line([(1,9),(3,9)],fill=STEEL[1])
    for x in (8,13,20,22,24,29):d.point((x,9),fill=JADE[2] if x%2 else '#32403a')
    d.polygon([(33,8),(38,8),(42,6),(43,7),(46,5),(47,6),(50,2),(50,6),(47,10),(43,11),(38,12),(34,11)],fill='#405a60')
    d.line([(35,11),(40,11),(45,10),(48,8),(50,4),(50,2)],fill='#b8dfd4')
    d.line([(37,9),(41,9),(45,7),(48,6)],fill=JADE[1])
    d.polygon([(28,7),(31,7),(31,5),(33,6),(34,5),(35,7),(38,7),(39,8),(36,9),(37,10),(34,11),(31,10),(28,10)],fill=INK)
    d.line([(29,8),(32,7),(34,7),(37,8),(35,9),(32,9),(32,10)],fill=JADE[2])
    d.point((34,8),fill='#e4ca84')
    d.line([(32,10),(32,13),(31,16)],fill=JADE[1]);d.line([(33,13),(34,16)],fill=JADE[0])
    w=base('qinglong',hand('qinglong',im,(20,9),(51,0),glow(im,[(30,8),(35,8),(40,9),(47,7),(50,3)],'#6ce4c5','#d7f6eb')))
    s=im.copy()
    sd=ImageDraw.Draw(s)
    sd.polygon([(37,8),(46,6),(50,2),(50,6),(46,9),(43,10),(37,11)],fill='#24433e')
    sd.line([(37,9),(43,8),(48,6),(50,3)],fill=JADE[1])
    stow(w,s,(17,9),'back',adjust={'deg':116})
    return icon(w,icon_single(im))

def excalibur():
    im,g,t=straight(23,5)
    w=base('excalibur',hand('excalibur',im,g,t))
    s,d=shape((24,9))
    d.polygon([(0,3),(4,3),(4,0),(6,0),(7,2),(20,2),(23,4),(21,6),(7,6),(6,8),(4,8),(4,5),(0,5)],fill=INK)
    d.line([(0,4),(4,4)],fill=BLUE[1]);d.point((0,4),fill=BLUE[2])
    d.line([(5,1),(5,7)],fill=GOLD[1]);d.line([(6,3),(20,3),(22,4),(20,5),(6,5)],fill=GOLD[1])
    d.line([(7,4),(20,4)],fill=BLUE[1])
    d.line([(8,4),(10,3),(13,4),(16,5),(19,4),(20,4)],fill='#668c9f')
    d.point((5,3),fill=GOLD[2]);d.point((21,4),fill=GOLD[2])
    stow(w,s,(5,4),g=glow(s,[(5,1),(5,4),(6,5),(10,5),(13,4),(16,5),(21,4)],'#eac783','#fff0b4'))
    return icon(w,icon_single(im))

def muramasa():
    im,g,t=kat(21,2,grip='#602f3d')
    points=[(x,g[1]-(x>11)-(x>16)-(x%5 in (3,4))) for x in range(7,20)]
    d=ImageDraw.Draw(im);d.line(points,fill='#bbc3cf')
    w=base('muramasa',hand('muramasa',im,g,t,glow(im,points,'#9e1b32','#db5064')))
    s,p=sheath(22,1,'#352b32','#7a454c',cord=True)
    stow(w,s,p)
    return icon(w,icon_single(im))

def monohoshizao():
    im,g,t=kat(35,1,('#3c4454','#889bb2','#e8f0ff'),'#322b34')
    w=base('monohoshizao',hand('monohoshizao',im,g,t))
    s,p=sheath(36,1,'#343e4a','#6b605e')
    stow(w,s,p,'back',adjust={'deg':112})
    return icon(w,icon_single(im))

def duanshui():
    im,g,t=straight(21,7,('#51553f','#8c8955','#afd6be'),('#2a5b59','#4e9291','#7fe0d4'),'bronze')
    d=ImageDraw.Draw(im);y=g[1]
    for x in range(8,18,3):
        d.point((x,y-1),fill='#293c37');d.point((x+1,y),fill='#263532');d.point((x,y+1),fill='#3c493d')
    d.point((0,y),fill='#c5ae71');d.point((1,y),fill='#715d3e');d.point((6,y+1),fill='#4ca8b6')
    w=base('duanshui',hand('duanshui',im,g,t))
    s,p=sheath(22,0,'#4c5746','#aa9f62')
    stow(w,s,p)
    return icon(w,icon_single(im))

def higekiri():
    im,g,t=kat(23,4,('#4f505c','#a5a4ae','#ebdfd1'),'#aaa08c',True)
    w=base('higekiri',hand('higekiri',im,g,t,glow(im,[(6,6),(11,5),(16,4),(20,3),(22,0)],'#c4203a','#e36e7f')))
    s,p=sheath(24,3,'#4e3a36','#9e7857',hang=True)
    stow(w,s,p)
    return icon(w,icon_single(im))

def ganjiang_moye():
    a,p,t=straight(19,5,('#33373c','#565759','#a49168'),GOLD,'paired')
    d=ImageDraw.Draw(a);d.line([(8,4),(9,3),(11,3),(12,4),(11,5),(9,5),(8,4),(12,4),(13,3),(15,3),(16,4),(15,5),(13,5),(12,4)],fill='#a37e43')
    b,q,u=straight(19,5,('#607380','#b3c7d4','#e7f2ee'),GOLD,'paired')
    d=ImageDraw.Draw(b);d.line([(7,4),(9,3),(11,4),(13,5),(15,4),(17,4)],fill='#91bcd8')
    m=hand('moye',b,q,u)
    w=base('ganjiang_moye',hand('ganjiang',a,p,t),m)
    w['variants']={'ganjiang':w['main'],'moye':m}
    planted=b.rotate(-90,Image.Resampling.NEAREST,expand=True)
    w['planted']=dict(file=image('moye_planted',planted),grip=[4,18],anchor=[4,18],base_deg=0)
    return icon(w,icon_group([b,a],[137,42],[(16,15),(16,16)]))

def zhuxian():
    names=['zhu','lu','xian','jue']
    patterns=[[(8,4),(10,4),(10,3),(11,3),(11,5),(13,5)],[(8,5),(9,3),(11,4),(12,3),(13,5)],[(8,3),(9,5),(10,3),(12,3),(12,5),(14,5)],[(8,3),(10,3),(9,5),(12,5),(13,3)]]
    palette=[GOLD,RED,('#282342','#5d5083','#b3a5d5'),('#1a1a21','#35343c','#e6e3de')]
    v={}; ims=[]
    for k,p,pattern in zip(names,palette,patterns):
        im,g,t=straight(21,5,p,GOLD,'talisman')
        d=ImageDraw.Draw(im);d.line(pattern,fill=p[2])
        ims.append(im)
        v[k]=hand('zhuxian_'+k,im,g,t)
    w=base('zhuxian',v['zhu'],variants=v)
    return icon(w,icon_group(ims,[126,102,78,54],[(7,17),(13,15),(19,15),(25,17)]))

def riyue():
    a,d=shape((19,11));y=5
    d.polygon([(0,4),(3,4),(4,1),(7,1),(8,3),(12,3),(17,1),(18,0),(18,5),(16,8),(10,9),(7,8),(7,9),(4,9),(3,6),(0,6)],fill=INK)
    d.polygon([(8,4),(12,4),(17,2),(17,5),(15,7),(10,8),(8,7)],fill='#968569')
    d.line([(8,7),(10,8),(15,7),(17,5),(18,2)],fill='#eddbab')
    d.ellipse((3,2,8,8),fill='#745339');d.ellipse((4,3,7,7),fill='#d3ad68')
    d.point((6,4),fill='#fff0bd');d.point((1,5),fill='#765746')
    b,g,t=kat(19,4,('#333a54','#8499b2','#e5edff'),'#455476',True)
    d=ImageDraw.Draw(b);d.line([(6,3),(4,4),(4,6),(6,7)],fill='#7c9bb9')
    w=base('riyue',variants={'sun':hand('riyue_sun',a,(2,y),(18,0)),
        'moon':hand('riyue_moon',b,g,t)})
    return icon(w,icon_group([a,b],[132,50],[(15,16),(16,16)]))

def chunyang():
    im,g,t=straight(23,3,('#3c5556','#8ca6a6','#e6f7ff'),('#3b413e','#637575','#eee4bf'),'taiji')
    out=Image.new('RGBA',(23,13));out.alpha_composite(im,(0,0));d=ImageDraw.Draw(out)
    for p in [(8,4),(10,4),(12,4),(13,4),(15,4),(17,4),(18,4)]:d.point(p,fill='#d8c98d')
    d.point((5,4),fill='#e6e5d9');d.point((6,4),fill='#222b31')
    d.line([(0,5),(0,8),(2,9),(2,11),(4,12)],fill='#b99348')
    d.line([(1,8),(3,10),(3,12)],fill='#e0bd6e')
    w=base('chunyang',hand('chunyang',out,g,t))
    s,p=sheath(24,0,'#3c594f','#b0a176')
    stow(w,s,p,'back',adjust={'deg':110})
    a,d=shape((8,10));d.polygon([(3,0),(5,0),(5,2),(6,3),(6,5),(7,7),(6,9),(1,9),(0,7),(2,5),(2,3),(3,2)],fill=INK)
    d.ellipse((2,5,6,8),fill='#833d35');d.ellipse((3,2,5,5),fill='#a45a48')
    d.line([(2,5),(5,5)],fill='#ad804b');d.point((3,7),fill='#c57c58');d.point((4,1),fill='#a69368')
    w['props']={'gourd':dict(file=image('chunyang_gourd',a),grip=[4,4],base_deg=0)}
    return icon(w,icon_single(out))

if __name__=='__main__':
    manifest=W.parent/'manifest.json'
    entries=json.loads(manifest.read_text())
    for id in sys.argv[1:]:
        if any(v['id']==id for v in entries):raise ValueError(id)
        entries.append(globals()[id]())
    manifest.write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')
