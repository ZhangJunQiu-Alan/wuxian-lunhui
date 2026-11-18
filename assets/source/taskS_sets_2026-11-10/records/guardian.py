"""Original weapon-free Valhalla guardian. Main-hand mounts use local frame pixels."""
from PIL import Image, ImageDraw

from pixels import save

IDLE_HAND = [(41,34),(41,33),(42,34),(41,34)]
ATTACK_HAND = [(38,33),(34,24),(40,18),(48,28),(48,37),(43,35)]
ACTIONS = {
    'idle': dict(frames=4,fps=8,play='loop',hand=IDLE_HAND,
        angles=[-14,-17,-14,-14]),
    'attack': dict(frames=6,fps=16,play='once',hand=ATTACK_HAND,
        angles=[-12,-112,-63,4,26,9]),
}
INK='#182334'
SHADE='#28364b'
DEEP='#37495f'
STEEL='#547189'
COOL='#7d9db0'
SILVER='#b9cfcd'
LIGHT='#e0e6d7'
GOLD='#ad946b'
PALE='#ebd3a0'


def paint(action,index):
    image=Image.new('RGBA',(64,64))
    d=ImageDraw.Draw(image)
    x=([0,0,0,0] if action=='idle' else [0,-2,-1,2,3,1])[index]
    y=([0,-1,0,0] if action=='idle' else [0,1,-1,-1,1,0])[index]
    def poly(points,fill,outline=INK):
        d.polygon([(a+x,b+y) for a,b in points],fill=fill,outline=outline)
    def line(points,fill,width=1):
        d.line([(a+x,b+y) for a,b in points],fill=fill,width=width)
    # Ragged cape and rear leg under the armor.
    sway=([0,1,2,0] if action=='idle' else [-1,-2,-4,-3,0,1])[index]
    poly([(24,20),(29,22),(30,34),(26,41),(20,47),(13+sway,50),
          (15+sway,45),(8+sway,48),(13+sway,39),(16,30),(21,24)],SHADE)
    poly([(22,24),(24,26),(23,37),(18,43),(13+sway,44),(17,36)],DEEP,None)
    line([(20,28),(18,34),(16+sway,40),(12+sway,44)],STEEL)
    line([(15+sway,46),(20,43),(24,38)],COOL)
    line([(13+sway,43),(17+sway,41),(20,38)],GOLD)
    d.polygon([(27,35),(33,38),(29,47),(25,52),(24,55),(17,55),(18,52),
               (21,49),(23,42)],fill=DEEP,outline=INK)
    d.line([(25,43),(22,49),(20,52)],fill=STEEL,width=2)
    d.line([(19,54),(24,54)],fill=COOL)
    forward=([0,0,0,0] if action=='idle' else [0,1,2,3,3,1])[index]
    d.polygon([(32,36),(38,38),(37+forward,44),(39+forward,50),(45+forward,52),
               (46+forward,54),(37+forward,55),(34+forward,53),(32,46),(30,43)],
              fill=STEEL,outline=INK)
    d.line([(35,44),(36+forward,48),(39+forward,52)],fill=SILVER,width=2)
    d.line([(36+forward,53),(44+forward,54)],fill=COOL)
    # Body.
    poly([(22,23),(26,19),(36,19),(41,23),(41,31),(38,36),(39,40),
          (34,44),(29,42),(23,43),(22,40),(24,34),(21,30)],DEEP)
    poly([(25,22),(33,21),(38,23),(38,30),(35,34),(28,35),(24,31)],STEEL)
    line([(27,22),(31,23),(34,25),(37,26)],SILVER)
    line([(25,29),(29,31),(35,33)],COOL)
    line([(30,24),(30,28),(32,26),(32,29)],PALE)
    line([(27,24),(30,26),(36,28)],DEEP,2)
    line([(27,24),(30,26),(36,28)],GOLD)
    poly([(23,33),(37,34),(38,37),(24,38)],SHADE)
    line([(25,35),(30,35),(34,36),(36,36)],PALE)
    d.point((31+x,35+y),fill=LIGHT)
    line([(24,40),(29,38),(31,41)],COOL)
    line([(35,39),(37,40)],SILVER)
    # Spectacle helm, two feather-shaped silver blades and a spectral slit.
    poly([(23,13),(26,8),(31,6),(36,7),(40,11),(41,17),(39,21),
          (36,23),(28,23),(24,19)],STEEL)
    poly([(24,15),(20,12),(17,8),(18,14),(21,18),(24,19)],COOL)
    line([(18,9),(20,12),(24,14)],SILVER)
    line([(20,15),(23,17)],LIGHT)
    poly([(36,10),(41,7),(44,5),(44,9),(41,13),(39,14)],STEEL)
    line([(40,10),(44,6)],SILVER)
    line([(26,12),(29,8),(34,8),(37,10)],SILVER)
    line([(33,8),(34,12),(33,14)],GOLD)
    poly([(27,14),(32,13),(35,14),(38,13),(40,15),(39,20),
          (35,21),(33,19),(30,20),(27,18)],SHADE)
    line([(27,14),(32,14),(34,15),(37,14),(39,14)],COOL)
    line([(34,15),(35,18),(35,20)],SILVER)
    line([(30,16),(32,16)],'#94dae1')
    d.point((38+x,16+y),fill='#94dae1')
    line([(28,21),(32,21),(34,23)],COOL)
    # Far arm and free weapon hand.
    poly([(22,23),(25,25),(23,30),(21,33),(22,37),(19,39),(17,36),(18,31),
          (18,27)],DEEP)
    line([(19,28),(19,32),(20,35)],COOL)
    hand=ACTIONS[action]['hand'][index]
    shoulder=(37+x,25+y)
    elbow=((shoulder[0]+hand[0])//2+2,(shoulder[1]+hand[1])//2+2)
    d.line([shoulder,elbow,hand],fill=INK,width=7)
    d.line([shoulder,elbow,hand],fill=STEEL,width=5)
    d.line([(shoulder[0]-1,shoulder[1]-2),(elbow[0]-1,elbow[1]-1)],fill=SILVER,width=2)
    hx,hy=hand
    d.rectangle((hx-2,hy-2,hx+2,hy+2),fill=COOL,outline=INK)
    d.point((hx,hy-1),fill=LIGHT)
    poly([(35,22),(40,22),(43,25),(40,28),(35,28),(33,25)],STEEL)
    line([(35,24),(38,23),(41,24)],SILVER)
    d.point((39+x,26+y),fill=GOLD)
    return image


def make():
    for action,meta in ACTIONS.items():
        sheet=Image.new('RGBA',(64*meta['frames'],64))
        for i in range(meta['frames']):
            sheet.paste(paint(action,i),(64*i,0))
        save(sheet,'actors',f'valhalla_guardian_{action}.png')


if __name__=='__main__':
    make()
