"""Render the revised peak frames over all three stage backgrounds at native size."""
import json

from PIL import Image, ImageDraw
from qa import B, D, ITEMS, P, WEAPONS, composite, ground, png_strip, text

OUT=P/'vfx_polish'
OUT.mkdir(exist_ok=True)
PRIMARY=[
 ('katana','katana_slash'),('muramasa','muramasa_slash'),('monohoshizao','monohoshizao_slash'),
 ('duanshui','duanshui_slash'),('higekiri','higekiri_oni_slash'),('ganjiang_moye','ganjiang_slash'),
 ('ganjiang_moye','moye_slash'),('zhuxian','zhuxian_slash_xian'),('qinglong','qinglong_sweep'),
 ('excalibur','excalibur_slash'),('riyue','riyue_sun_sweep'),('riyue','riyue_moon_thrust'),
 ('chunyang','chunyang_slash'),
]
effects={e['id']:e for e in D['effects']}
size=(230,288)
board={}
for label,key in [('雪地','snow'),('冥界','helheim'),('焦土','ash')]:
    plate=Image.new('RGB',(size[0]*4,size[1]*4+24),'#16202b')
    text(ImageDraw.Draw(plate),(8,7),'S-SW   /   REVISED ATTACK EFFECTS   /   NATIVE PIXELS')
    for i,(id,fx) in enumerate(PRIMARY):
        e=effects[fx]
        surface=ground(label,size)
        origin=(38,143)
        action='off_attack' if fx=='moye_slash' else 'thrust' if fx=='riyue_moon_thrust' else 'attack'
        mode='moon' if fx=='riyue_moon_thrust' else 'xian' if id=='zhuxian' else None
        actor=composite(WEAPONS[id],D['sockets'][action][2],action,2,mode=mode,size=size,origin=(origin[0]-32,origin[1]-32))
        surface.alpha_composite(actor)
        frame=png_strip(e,1)
        surface.alpha_composite(frame,(origin[0]-e['anchor'][0],origin[1]-e['anchor'][1]))
        d=ImageDraw.Draw(surface)
        d.rectangle((0,0,size[0],17),fill='#17242f')
        text(d,(6,4),fx.upper())
        plate.paste(surface,(i%4*size[0],i//4*size[1]+24))
    name=f'{key}_attack_peaks.png'
    plate.save(OUT/name)
    board[label]=f'previews/{OUT.name}/{name}'
(B/'records/vfx-visual.json').write_text(json.dumps(dict(boards=board,concept='originals/vfx_polish_style.png'),ensure_ascii=False,indent=2)+'\n')
