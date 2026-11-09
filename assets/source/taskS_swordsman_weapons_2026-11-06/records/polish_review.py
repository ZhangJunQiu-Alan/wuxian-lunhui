"""Apply the second-round review to the carried weapon and off-hand motion assets."""
from pathlib import Path
import json

from PIL import Image, ImageDraw
from body import CHAR, strip
from motions import pose
from waist_assets import ARCHIVE, MANIFEST, W, save
from weapons import icon_group

def pix(path):
    return Image.open(path).convert('RGBA')

def sharp_tip(name):
    path=W/f'excalibur_{name}.png'
    im=pix(path)
    d=ImageDraw.Draw(im)
    tip=im.width-1
    d.rectangle((tip-6,0,tip,im.height-1),fill=(0,0,0,0))
    d.polygon([(tip-7,2),(tip-4,2),(tip,4),(tip-4,6),(tip-7,6)],fill='#111923')
    d.polygon([(tip-7,3),(tip-4,3),(tip-1,4),(tip-4,5),(tip-7,5)],fill='#536f91')
    d.line([(tip-6,3),(tip-4,3),(tip-1,4)],fill='#d0ac68')
    d.point((tip-3,4),fill='#8eb2c3')
    save(path,im)

for name in ('stow','sheath'):
    sharp_tip(name)

data=json.loads(MANIFEST.read_text())
by_id={x['id']:x for x in data}
for id,adjust in {'monohoshizao':dict(dx=-3,dy=-8,deg=119), 'chunyang':dict(dx=-3,dy=-6,deg=125)}.items():
    w=by_id[id]
    w['stow_socket_adjust'].update(adjust)
    path=W/Path(w['stow_file']).name
    im=pix(path)
    gx,gy=w['stow_grip']
    clasp=Image.new('RGBA',im.size)
    d=ImageDraw.Draw(clasp)
    d.line([(gx,gy-2),(gx,gy+2)],fill='#3b302a')
    d.line([(gx+1,gy-2),(gx+1,gy+1)],fill='#b49468' if id=='monohoshizao' else '#879982')
    d.point((gx+2,gy-1),fill='#ccb48c')
    name=f'{id}_stow_keeper.png'
    save(W/name,clasp)
    w['stow_keeper']='swordsman/'+name
by_id['qinglong'].update(idle_hold='held',idle_main_adjust=dict(deg=-61,x=40,y=37,z='front'))
by_id['zhuxian'].update(flight_px=102)
by_id['ganjiang_moye'].update(alternate_attack='off_attack')
by_id['riyue'].update(alternate_attack='variant')

path=W/'riyue_sun.png'
original=ARCHIVE/path.name
im=pix(original if original.exists() else path)
# Preserve the thin spine and downsize only the blade's width.
pivot=by_id['riyue']['variants']['sun']['grip'][1]
new=Image.new('RGBA',im.size)
for x in range(im.width):
    for y in range(im.height):
        c=im.getpixel((x,y))
        ny=y if x<6 else round(pivot+(y-pivot)*.64)
        if c[3]:new.putpixel((x,ny),c)
save(path,new)
tip=by_id['riyue']['variants']['sun']['tip']
tip[1]=round(pivot-pivot*.64)
save(W/'riyue_icon.png',icon_group([new,pix(W/'riyue_moon.png')],[42,-33],[(11,19),(20,13)]))

sp=CHAR/'swordsman_sockets.json'
s=json.loads(sp.read_text())
positions=[
    ((34,39,96),(24,37,119),((27,28),(24,33))),
    ((35,37,86),(23,21,-124),((27,28),(20,25))),
    ((37,38,90),(43,30,-5),((29,27),(35,29))),
    ((39,37,83),(44,40,19),((30,30),(37,36))),
    ((38,38,86),(34,42,44),((29,30),(30,37))),
    ((36,38,90),(24,37,122),((27,28),(24,33))),
]
frames=[]
s['actions']['off_attack']=[]
palette=sorted({p for p in pix(CHAR/'swordsman_bare_attack.png').getdata() if p[3]})
colors={}
for n,(main,off,arm) in enumerate(positions):
    im,loc=pose(('attack',n),main,off,main_arm=((35,28),(36,34)),off_arm=arm)
    for px in set(im.getdata()):
        if px[3] and px not in palette:colors[px]=min(palette,key=lambda p:sum((x-y)**2 for x,y in zip(px[:3],p[:3])))
    im.putdata([colors.get(px,px) for px in im.getdata()])
    frames.append(im)
    s['actions']['off_attack'].append(loc)
save(CHAR/'swordsman_bare_off_attack.png',strip(frames))
sp.write_text(json.dumps(s,ensure_ascii=False,indent=2)+'\n')
MANIFEST.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
