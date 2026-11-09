from pathlib import Path
import math
from PIL import Image, ImageDraw
import numpy as np
import json

B = Path(__file__).resolve().parents[1]
ROOT = B.parents[2]
CHAR = ROOT/'assets/sprites/characters'
W = ROOT/'assets/sprites/weapons/swordsman'
W.mkdir(parents=True, exist_ok=True)
def save(im, path):
    with path.open('xb') as f: im.save(f, 'PNG')
def publish(im, path):
    save(im, path)
    save(im, B/'approved'/path.name)
def strip(frames):
    w,h=frames[0].size
    out=Image.new('RGBA',(len(frames)*w,h))
    for i,f in enumerate(frames): out.paste(f,(i*w,0))
    return out
def crop(im, index):
    return im.crop((index*64,0,(index+1)*64,64))
def polygon(points):
    m=Image.new('1',(64,64))
    ImageDraw.Draw(m).polygon(points, fill=1)
    return np.asarray(m)
def sockets(main, off, hip, back, head, mode='stow', front=True):
    def xydeg(coords, z):
        x,y,deg=coords
        return dict(x=x,y=y,deg=deg,z=z)
    return dict(mode=mode, main=xydeg(main,'front' if front else 'back'),
                off=xydeg(off,'back'),hip=xydeg(hip,'back'),
                back=xydeg(back,'back'),head=dict(x=head[0],y=head[1]))
# Main, off, hip, back, head, and stow/held/none. Coordinates in source pixels.
I = ((40,38,90),(24,37,90),(38,33,151),(30,30,123),(33,15))
S = {
 'idle':[I]*4,
 'move':[
 ((43,31,0),(18,36,90),(37,35,153),(30,31,128),(34,16)),
 ((42,33,0),(25,36,90),(36,35,166),(31,31,128),(34,16)),
 ((44,31,0),(33,36,90),(38,36,165),(30,33,130),(34,16)),
 ((43,29,0),(19,36,90),(38,36,150),(30,31,128),(34,16)),
 ((43,34,0),(24,36,90),(36,36,163),(30,32,128),(34,16)),
 ((38,34,0),(22,37,90),(37,36,176),(30,34,130),(34,16))],
 'attack':[
 ((40,37,90),(23,37,90),(37,34,147),(29,31,125),(31,15)),
 ((28,18,-147),(34,35,148),(36,36,146),(32,32,125),(36,19),'held'),
 ((43,29,0),(28,33,148),(38,36,147),(31,33,125),(37,18),'held'),
 ((36,36,26),(33,34,151),(35,37,147),(29,34,125),(31,19),'held'),
 ((35,36,23),(29,32,154),(35,38,147),(30,34,125),(32,17),'held'),
 I],
 'hurt':[
 ((27,31,-29),(39,35,104),(34,36,145),(29,34,129),(23,19)),
 ((22,38,90),(42,39,105),(38,34,151),(30,32,130),(32,16))],
 'death':[
 ((34,31,-55),(40,40,90),(37,35,151),(31,31,128),(34,16)),
 ((32,35,0),(37,44,90),(32,39,151),(34,36,135),(41,26),'none'),
 ((33,44,-62),(44,54,35),(32,45,150),(33,41,144),(40,34),'none'),
 ((32,54,55),(48,56,10),(27,47,150),(30,45,170),(40,43),'none'),
 ((38,54,48),(53,57,5),(27,50,193),(31,48,195),(45,48),'none'),
 ((45,57,3),(52,57,4),(28,53,192),(30,52,192),(51,52),'none')]
}
# Trim only the protruding portions, then restore fabric where the sheath crosses the body.
idle=[([(21,43),(23,39),(27,36),(28,37),(25,42)],(-1,-2)),
      ([(36,32),(41,29),(44,28),(44,34),(41,35),(38,34)],(-1,3))]
M = {
 'idle':[idle]*4,
 'move':[
 [([(15,44),(15,41),(23,37),(27,36),(25,39),(20,43)],(-1,1)), ([(35,35),(39,33),(41,35),(39,39),(36,38)],(-2,1))],
 [([(17,42),(18,39),(24,36),(25,38),(22,42)],(0,3)), ([(35,36),(41,35),(41,38),(38,39)],(-3,0))],
 [([(20,43),(21,41),(29,38),(32,38),(31,40),(24,44)],(0,2)), ([(35,35),(43,35),(45,36),(42,38),(36,38)],(-3,1))],
 [([(15,44),(15,41),(24,37),(27,36),(25,39),(20,43)],(-1,1)), ([(35,35),(39,34),(42,35),(40,38),(36,38)],(-3,1))],
 [([(17,42),(18,39),(24,36),(25,38),(22,42)],(0,3)), ([(33,36),(40,36),(42,38),(36,39)],(-2,1))],
 [([(17,44),(19,41),(27,37),(30,37),(29,40),(22,44)],(0,2)), ([(34,35),(45,35),(45,37),(40,38),(35,38)],(-3,1))]
 ],
 'attack':[
 [([(19,47),(21,43),(27,37),(29,38),(25,43),(22,47)],(0,3)), ([(36,32),(41,30),(44,30),(43,33),(39,35)],(-2,2))],
 [([(12,6),(15,5),(29,15),(30,17),(27,18),(12,9)],None), ([(20,43),(22,39),(27,36),(30,37),(27,40),(23,43)],(0,2))],
 [([(45,27),(62,27),(62,31),(45,31)],None), ([(19,47),(20,43),(26,39),(30,39),(29,41),(23,46)],(0,2))],
 [([(36,37),(39,37),(57,45),(58,48),(55,48),(42,42),(38,41)],(-2,2)), ([(19,47),(21,43),(26,39),(30,39),(28,42),(22,46)],(0,2))],
 [([(36,36),(39,36),(47,40),(47,44),(43,43),(37,40)],(-2,2)), ([(20,45),(22,42),(27,38),(30,38),(27,42),(24,44)],(0,2))],
 idle],
 'hurt':[
 [([(19,46),(21,41),(26,38),(29,38),(27,41),(23,44)],(0,2)), ([(36,34),(39,32),(45,34),(46,37),(42,38),(36,37)],(-2,2))],
 [([(18,45),(20,42),(26,37),(28,38),(24,42),(21,45)],(0,2)), ([(39,32),(44,31),(46,30),(47,33),(45,36),(41,36)],(-1,3))]],
 'death':[
 [([(20,45),(21,42),(26,37),(30,37),(28,41),(24,44)],(0,3)), ([(39,34),(45,32),(46,34),(42,37),(40,37)],(-2,2))],
 [([(19,46),(20,42),(26,39),(30,38),(27,42),(22,45)],(0,3))],
 [([(16,51),(17,47),(22,43),(26,43),(25,46),(20,50)],(0,3))],
 [([(15,48),(16,44),(23,42),(27,43),(24,47),(19,48)],(0,3))],
 [([(20,40),(22,40),(28,44),(28,46),(26,47),(20,43)],None)],
 [([(21,46),(23,46),(31,50),(30,52),(25,50),(21,49)],None)]]
}
def remove_weapon(frame, edits):
    src=np.asarray(frame)
    out=src.copy()
    for points, repair in edits:
        m=polygon(points) & (src[:,:,3]>0)
        out[m]=0
        if repair:
            dx,dy=repair
            yy,xx=np.where(m)
            for y,x in zip(yy,xx):
                # Preserve the belt and restore fabric only within the torso and legs.
                if src[y,x,3] and src[y,x,0]>70 and abs(int(src[y,x,0])-int(src[y,x,2]))>19 and 32<=y<=37 and 27<=x<=38:
                    out[y,x]=src[y,x]
                elif (x < 38 or y >= 39) and src[y+dy,x+dx,3] and src[y+dy,x,3] and src[y,x-1,3]:
                    out[y,x]=src[y+dy,x+dx]
    return Image.fromarray(out)

def blade():
    source=crop(Image.open(CHAR/'swordsman_attack.png').convert('RGBA'),2)
    out=Image.new('RGBA',(21,5))
    out.paste(source.crop((45,28,62,31)),(4,1))
    d=ImageDraw.Draw(out)
    d.line([(0,2),(6,2)],fill='#15141a',width=3)
    for x in (1,3): d.point((x,2),fill='#74584c')
    d.line([(5,0),(5,4)],fill='#453639')
    d.point((5,1),fill='#886c54')
    return out

def scabbard():
    out=Image.new('RGBA',(24,7))
    d=ImageDraw.Draw(out)
    d.polygon([(0,2),(6,2),(7,3),(17,3),(23,4),(23,5),(18,6),(8,5),(6,4),(0,4)],fill='#141318')
    d.line([(1,3),(4,3)],fill='#62473c')
    d.line([(6,1),(6,5)],fill='#3b2d2d')
    d.line([(8,4),(16,4),(21,5)],fill='#403337')
    d.point((22,5),fill='#66524a')
    return out

def icon_single(im):
    r=im.rotate(43,Image.Resampling.NEAREST,expand=True)
    r=r.crop(r.getbbox())
    r.thumbnail((29,29),Image.Resampling.NEAREST)
    out=Image.new('RGBA',(32,32))
    out.paste(r,((32-r.width)//2,(32-r.height)//2))
    return out

def original_body():
    rows={}
    for a, edits in M.items():
        original=Image.open(CHAR/f'swordsman_{a}.png').convert('RGBA')
        frames=[remove_weapon(crop(original,i),e) for i,e in enumerate(edits)]
        bare=strip(frames)
        publish(bare,CHAR/f'swordsman_bare_{a}.png')
        diff=np.any(np.asarray(original)!=np.asarray(bare),axis=2)
        delta=np.zeros((64,original.width,4),np.uint8)
        delta[diff]=[239,95,115,255]
        Image.fromarray(delta).save(B/'previews'/f'bare_diff_{a}.png')
        rows[a]=frames
    for file,im in [('katana',blade()),('katana_stow',scabbard()),('katana_icon',icon_single(blade()))]:
        publish(im,W/f'{file}.png')
    return rows

def write_sockets():
    path=CHAR/'swordsman_sockets.json'
    path.write_text(json.dumps(dict(character='swordsman',frame_size=[64,64],
        actions={a:[sockets(*s) for s in row] for a,row in S.items()}),indent=2)+'\n')

if __name__=='__main__':
    original_body()
    write_sockets()
