from pathlib import Path
import json
import sys

from PIL import Image, ImageDraw
from weapons import B, W, INK

ARCHIVE = B/'candidates/waist-pre-revision'
MANIFEST = W.parent/'manifest.json'
# length, curvature, rotation, x/y correction, ink, edge, fitting, wrap
DESIGNS = {
    'katana':   (22, 0, 132, -4, 1, '#4c3029', '#99664b', '#c9a26a', '#80533e'),
    'muramasa': (26, 2, 135, -4, 1, '#302532', '#69515e', '#a78675', '#8b4554'),
    'duanshui': (25, 0, 133, -4, 1, '#38453a', '#798468', '#bea978', '#5d9891'),
    'higekiri': (23, 2, 132, -4, 1, '#532f2c', '#a2624c', '#c19b6d', '#9a7a57'),
    'excalibur':(23, 0, 131, -4, 1, '#22364e', '#497491', '#d0ac68', '#6196ab'),
}
MOUTH = (10, 4)

def save(path, image):
    previous = ARCHIVE/path.name
    if path.exists() and not previous.exists():
        previous.write_bytes(path.read_bytes())
    image.save(path)
    image.save(B/'approved'/path.name)

def make(id, config):
    length, curve, deg, dx, dy, base, edge, metal, wrap = config
    end = MOUTH[0]+length-1
    sheath = Image.new('RGBA',(end+1,9))
    d = ImageDraw.Draw(sheath)
    d.polygon([(10,2),(15,2),(end-4,2-curve),(end-1,2-curve),(end,3-curve),
               (end,5-curve),(end-2,6-curve),(15,6),(10,6)], fill=INK)
    d.line([(11,4),(15,4),(end-3,4-curve),(end-1,4-curve)], fill=base, width=2)
    d.line([(12,3),(16,3),(end-3,3-curve)], fill=edge)
    d.line([(10,2),(10,6)], fill=metal)
    d.point((10,4),fill='#242029')
    d.line([(end-2,3-curve),(end-2,5-curve)],fill=metal)
    if id in ('katana','muramasa','higekiri'):
        # Two pixels of knot sit on the belt side of the collar.
        d.line([(12,2),(12,1),(13,0),(15,0)],fill=metal if id!='muramasa' else '#ab5967')
        d.line([(13,2),(14,5),(16,6)],fill='#753a49' if id=='muramasa' else '#815a43')
    if id=='duanshui':
        d.point((11,3),fill='#77b8a7')
        for x in (17,21,25,29):
            d.point((x,4), fill='#516959')
    if id=='excalibur':
        for x in (14,21,28):
            d.line([(x,3),(x+1,4),(x+2,3)],fill='#7ea7be')
        d.line([(11,2),(end-3,2)],fill='#8d7653')
    stowed = sheath.copy()
    d = ImageDraw.Draw(stowed)
    d.polygon([(0,3),(7,2),(9,3),(10,3),(10,5),(7,6),(0,5)],fill=INK)
    d.line([(1,4),(8,4)],fill=wrap)
    for x in (2,4,6):
        d.point((x,3),fill=edge)
    d.line([(1,3),(1,5)],fill=metal)
    d.line([(8,1),(8,7)],fill=INK)
    d.line([(8,2),(8,6)],fill=metal)
    if id in ('excalibur','duanshui'):
        d.point((0,4),fill='#83c2c9')
    save(W/f'{id}_stow.png',stowed)
    save(W/f'{id}_sheath.png',sheath)
    if id=='excalibur':
        shine=Image.new('RGBA',stowed.size)
        d=ImageDraw.Draw(shine)
        d.line([(9,2),(10,4),(9,6)],fill='#ffe8a2')
        d.point((12,3),fill='#fff3c5')
        save(W/'excalibur_stow_glow.png',shine)
    return dict(stow_grip=list(MOUTH), stow_socket_adjust=dict(dx=dx,dy=dy,deg=deg,z='front'),
                sheath_file=f'swordsman/{id}_sheath.png')

if __name__=='__main__':
    weapons=json.loads(MANIFEST.read_text())
    selected=set(sys.argv[1:]) or set(DESIGNS)
    for weapon in weapons:
        id=weapon['id']
        if id in selected:
            weapon.update(make(id,DESIGNS[id]))
    MANIFEST.write_text(json.dumps(weapons,ensure_ascii=False,indent=2)+'\n')
