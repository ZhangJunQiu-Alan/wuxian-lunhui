import json
from PIL import Image, ImageDraw
from weapons import W, B, INK, kat, straight, sheath, glow, icon_single

def save(name, image):
    path = W / (name + '.png')
    backup = B / 'candidates' / (name + '_pre_review.png')
    if not backup.exists():
        backup.write_bytes(path.read_bytes())
    image.save(path)
    image.save(B / 'approved' / path.name)

manifest = W.parent / 'manifest.json'
weapons = json.loads(manifest.read_text())
by_id = {weapon['id']: weapon for weapon in weapons}
mounts = {
    'katana': (3, 1, 76, 'front'),
    'muramasa': (3, 1, 73, 'front'),
    'duanshui': (4, 1, 77, 'front'),
    'higekiri': (4, 0, 82, 'front'),
    'excalibur': (3, 1, 70, 'front'),
    'monohoshizao': (-7, -5, 132, 'back'),
    'qinglong': (-7, -1, 143, 'back'),
    'chunyang': (-7, -5, 142, 'back'),
}
for name, (dx, dy, deg, z) in mounts.items():
    by_id[name]['stow_socket_adjust'] = dict(dx=dx, dy=dy, deg=deg, z=z)

blade, grip, tip = kat(27, 3, ('#414655','#8d96a7','#e0e5ef'), '#73384b')
draw = ImageDraw.Draw(blade)
points = [(7,5),(9,5),(11,4),(13,5),(15,4),(17,3),(19,4),(21,3),(23,3),(25,2)]
for a, b in zip(points, points[1:]):
    draw.line([a,b],fill='#b9c0cb')
save('muramasa', blade)
save('muramasa_icon', icon_single(blade))
save('muramasa_glow', glow(blade, points, '#9e1b32', '#db5064'))
scabbard, grip_stow = sheath(28, 2, '#42323c', '#89545b', cord=True)
draw = ImageDraw.Draw(scabbard)
draw.line([(9,4),(15,4),(21,3),(26,2)],fill='#71606d')
draw.point((26,3),fill='#b78a88')
save('muramasa_stow', scabbard)
by_id['muramasa']['main'].update(grip=list(grip),tip=list(tip))
by_id['muramasa']['stow_grip'] = list(grip_stow)

scabbard, grip_stow = sheath(36, 1, '#976642', '#c2a069')
draw = ImageDraw.Draw(scabbard)
draw.line([(7,4),(19,4),(31,3)],fill='#9d6945')
draw.line([(9,3),(21,3),(31,2)],fill='#b78559')
draw.line([(7,5),(18,5),(30,4)],fill='#653f34')
for x,y in [(7,4),(11,4),(31,3),(34,3)]:
    draw.line([(x,y-1),(x,y+1)], fill='#d0b184')
    draw.point((x,y+1), fill='#91734e')
draw.line([(1,4),(4,4)],fill='#593936')
save('monohoshizao_stow', scabbard)
by_id['monohoshizao']['stow_grip'] = list(grip_stow)

blade, grip, tip = straight(27, 5, ('#404838','#8c8757','#bddfc5'),
                            ('#294f4d','#4f9891','#7fe0d4'),'bronze')
draw = ImageDraw.Draw(blade)
y = grip[1]
draw.line([(8,y+1),(20,y+1),(25,y)],fill='#9faa77')
for x in (9,12,15,18,21):
    draw.point((x,y),fill='#2e3b34')
    draw.point((x+1,y-1),fill='#798359')
draw.point((0,y),fill='#c5ae71')
draw.point((6,y+1),fill='#4ca8b6')
save('duanshui', blade)
save('duanshui_icon', icon_single(blade))
scabbard, grip_stow = sheath(27, 0, '#59664b', '#b6a36e')
draw = ImageDraw.Draw(scabbard)
draw.line([(7,4),(24,4)], fill='#61775e')
draw.point((24,3),fill='#89a697')
draw.point((25,4),fill='#b6a36e')
save('duanshui_stow', scabbard)
by_id['duanshui']['main'].update(grip=list(grip),tip=list(tip))
by_id['duanshui']['stow_grip'] = list(grip_stow)

for name, core, highlights in [
    ('katana_stow', ((64,51,55), (116,95,91)), [(8,3),(15,3),(22,4)]),
    ('higekiri_stow', ((78,58,54), (127,87,67)), [(8,3),(15,4),(21,5)]),
    ('chunyang_stow', ((60,89,79), (94,130,113)), [(9,3),(15,3),(22,3)]),
]:
    original = B / 'candidates' / (name + '_pre_review.png')
    source = original if original.exists() else W / (name + '.png')
    scabbard = Image.open(source).convert('RGBA')
    old, new = core
    scabbard.putdata([new+(255,) if pixel==old+(255,) else pixel for pixel in scabbard.get_flattened_data()])
    draw = ImageDraw.Draw(scabbard)
    for point in highlights:
        if scabbard.getpixel(point)[3]:
            draw.point(point, fill=new)
    save(name, scabbard)

manifest.write_text(json.dumps(weapons,ensure_ascii=False,indent=2)+'\n')
