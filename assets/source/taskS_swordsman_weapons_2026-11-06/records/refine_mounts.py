from catalog import B,WP
from PIL import Image, ImageDraw
import json

p=WP/'manifest.json'
weapons=json.loads(p.read_text())
adjust={
 'qinglong':dict(deg=136,dx=-2,dy=-5),
 'monohoshizao':dict(deg=132,dx=-5,dy=-6),
 'chunyang':dict(deg=142,dx=-6,dy=-5),
 'excalibur':dict(deg=158,dx=2,dy=4,z='front'),
}
for w in weapons:
    if w['id'] in adjust:w['stow_socket_adjust']=adjust[w['id']]
p.write_text(json.dumps(weapons,indent=2)+'\n')
def update(id,transform):
    p=WP/'swordsman'/f'{id}.png'
    (B/'candidates'/f'{id}_v1.png').write_bytes(p.read_bytes())
    v=transform(Image.open(p).convert('RGBA'))
    v.save(p);v.save(B/'approved'/p.name)
def fan(im):
    bounds=im.getbbox()
    cropped=im.crop(bounds)
    cropped.thumbnail((30,30),Image.Resampling.NEAREST)
    out=Image.new('RGBA',(32,32))
    out.alpha_composite(cropped,((32-cropped.width)//2,(32-cropped.height)//2))
    return out
def mono(im):
    d=ImageDraw.Draw(im)
    d.line([(6,4),(20,4),(33,3)],fill='#626878')
    d.point((6,3),fill='#8e8881')
    d.point((34,3),fill='#7e818a')
    return im
update('zhuxian_icon',fan)
update('monohoshizao_stow',mono)
