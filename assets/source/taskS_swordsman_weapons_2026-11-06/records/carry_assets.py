import json
from math import cos, radians, sin

from PIL import Image, ImageDraw
from body import CHAR, crop, strip
from motions import pose
from waist_assets import ARCHIVE, MANIFEST, W, save

SOCKETS = CHAR/'swordsman_sockets.json'
data = json.loads(SOCKETS.read_text())
actions = data['actions']
# Hip is the belt-side reference before adding the common (-4,+1) mouth offset.
hip = {
    'attack': [(37,34),(36,35),(38,35),(35,36),(36,35),(38,33)],
    'sheathe': [(37,35),(37,35),(37,35),(38,33)],
    'iai_stance': [(35,37)]*4,
    'iai_dash': [(39,34),(41,36),(38,36)],
}
feed = {'attack': {4:9}, 'sheathe': {0:16,1:11,2:6}, 'iai_dash': {0:8}}
data['waist_frames'] = {
    action: [dict(hip=dict(x=x,y=y), **({'feed_px': feed[action][n]} if n in feed.get(action,{}) else {}))
             for n,(x,y) in enumerate(points)] for action,points in hip.items()
}

def keep_palette(frames, base):
    palette = sorted({pixel for pixel in base.getdata() if pixel[3]})
    atlas = strip(frames)
    closest = {}
    pixels = []
    for pixel in atlas.getdata():
        if not pixel[3] or pixel in palette:
            pixels.append(pixel)
            continue
        if pixel not in closest:
            closest[pixel] = min(palette,key=lambda c: sum((a-b)**2 for a,b in zip(c[:3],pixel[:3])))
        pixels.append(closest[pixel])
    atlas.putdata(pixels)
    return atlas

def wrist(action,n):
    angle=radians(132)
    x,y=hip[action][n]
    distance=feed[action][n]
    return round(x-4-cos(angle)*distance),round(y+1-sin(angle)*distance),132

# Return poses have a fist where the shared feed distance puts the hilt.
attack = Image.open(CHAR/'swordsman_bare_attack.png').convert('RGBA')
frames = [crop(attack,n) for n in range(6)]
frames[4],_ = pose(('attack',4),wrist('attack',4),main_arm=((32,26),(34,29)))
save(CHAR/'swordsman_waist_attack.png',keep_palette(frames,attack))
frames = []
for n,(shoulder,elbow) in enumerate([((31,26),(38,25)),((31,26),(37,27)),((31,27),(35,31))]):
    frame,_ = pose(('attack',4),wrist('sheathe',n),main_arm=(shoulder,elbow))
    frames.append(frame)
frame,_ = pose(('idle',2),(37,31,132),main_arm=((34,26),(39,32)))
frames.append(frame)
save(CHAR/'swordsman_waist_sheathe.png',keep_palette(frames,Image.open(CHAR/'swordsman_bare_sheathe.png').convert('RGBA')))
data['waist_bodies'] = {
    'attack':'sprites/characters/swordsman_waist_attack.png',
    'sheathe':'sprites/characters/swordsman_waist_sheathe.png',
}

# Single prop changes socket on drink frames. The endpoint coincides with the belt socket.
for n in (0,5):
    point = actions['drink'][n]
    point['off'].update(x=point['hip']['x']-10,y=point['hip']['y']+5,deg=0)
SOCKETS.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

weapons = json.loads(MANIFEST.read_text())
by_id = {w['id']:w for w in weapons}
for name,angle,dx,dy in [('ganjiang_moye',125,-1,0),('riyue',123,-1,0)]:
    by_id[name]['off_idle_adjust'] = dict(deg=angle,dx=dx,dy=dy)
by_id['zhuxian']['reserve_offsets'] = [[-18,4],[-11,1],[-4,4]]
by_id['chunyang']['props']['gourd']['hip_adjust'] = dict(dx=-10,dy=5)

def base_image(name):
    path=W/(name+'.png')
    previous=ARCHIVE/path.name
    return path,Image.open(previous if previous.exists() else path).convert('RGBA')

# Brass or leather keeper is painted on the carried part, then shares its transform.
path,img=base_image('monohoshizao_stow')
d=ImageDraw.Draw(img)
d.line([(9,3),(21,3),(31,2)],fill='#92684c')
d.line([(7,4),(19,4),(31,3)],fill='#7c5038')
d.line([(7,2),(7,6)],fill='#35292b')
d.line([(8,2),(8,5)],fill='#b29a72')
d.line([(11,3),(11,6)],fill='#624735')
d.point((8,3),fill='#dcc49a')
save(path,img)
by_id['monohoshizao']['stow_socket_adjust'].update(dx=-5,dy=-5,deg=131)

path,img=base_image('qinglong_stow')
d=ImageDraw.Draw(img)
d.line([(1,9),(28,9)],fill='#4b7a77',width=2)
d.line([(2,8),(11,8),(27,8)],fill='#779f95')
for x in (4,17,22,26):
    d.line([(x,8),(x,10)],fill='#b39264')
d.line([(17,7),(17,11)],fill='#79563e')
save(path,img)
by_id['qinglong']['stow_socket_adjust'].update(dx=-6,dy=-1,deg=141)

path,img=base_image('chunyang_stow')
d=ImageDraw.Draw(img)
d.line([(7,4),(19,4),(22,4)],fill='#719489')
d.line([(8,3),(8,5)],fill='#aa9864')
d.point((20,4),fill='#9eb3a3')
d.point((22,4),fill='#c2aa72')
save(path,img)
by_id['chunyang']['stow_socket_adjust'].update(dx=-7,dy=-4,deg=139)

# Accent existing colored blades. Keep the alpha mask and the character's scale.
for name,colors in [('moye',('#648195','#9acbd9','#e0f1f0')),('riyue_moon',('#526c8b','#91bfd7','#e0ecf8'))]:
    path,img=base_image(name)
    d=ImageDraw.Draw(img)
    for x in range(6,img.width-1):
        opaque=[y for y in range(img.height) if img.getpixel((x,y))[3]]
        if len(opaque)<3:continue
        d.point((x,opaque[len(opaque)//2]),fill=colors[1])
        if x>=img.width-5 and x%2==0:
            d.point((x,opaque[len(opaque)//2]),fill=colors[2])
        if x<=10:
            d.point((x,opaque[0]),fill=colors[0])
    save(path,img)

MANIFEST.write_text(json.dumps(weapons,ensure_ascii=False,indent=2)+'\n')
