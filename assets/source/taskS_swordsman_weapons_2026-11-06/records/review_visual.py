from copy import deepcopy
from PIL import Image, ImageDraw, ImageOps
from qa import B, D, ITEMS, P, WEAPONS, arr, composite, draw_part, ground, im, mounts, text
import json
import numpy as np

OLD = {
    'monohoshizao': {'deg':132,'dx':-5,'dy':-6},
    'chunyang': {'deg':142,'dx':-6,'dy':-5},
    'qinglong': {'deg':136,'dx':-2,'dy':-5},
    'excalibur': {'deg':158,'dx':2,'dy':4,'z':'front'}
}
items = [row for row in ITEMS if WEAPONS[row[0]].get('stow_file')]
base_idle = im('swordsman_bare_idle')
size = (112,96)
origin = (24,12)
backgrounds = dict(雪地='snow', 冥界='helheim', 焦土='ash')

def old_composite(weapon, sockets, frame):
    w = deepcopy(weapon)
    w['stow_socket_adjust'] = OLD.get(w['id'], {})
    if w['id'] == 'katana':
        return composite(w, sockets, 'idle', frame, exact=True)
    out = Image.new('RGBA', size)
    body = base_idle.crop((frame*64,0,(frame+1)*64,64))
    layers = mounts(w,sockets,'idle')
    for layer in (1,4):
        if layer == 4:
            out.alpha_composite(body,origin)
        for ref, point, z in layers:
            if z != layer:continue
            previous = B/'candidates'/(ref['file'].rsplit('/',1)[1].replace('.png','_pre_review.png'))
            if previous.is_file():
                transformed = render_previous(previous,ref,point)
            else:
                transformed = draw_part(ref,point)
            out.alpha_composite(transformed)
    return out

def render_previous(previous,ref,s):
    from math import cos, sin, radians
    sprite = Image.open(previous).convert('RGBA')
    gx,gy=ref['grip']
    px,py=s['x']+origin[0]+.5,s['y']+origin[1]+.5
    angle=radians(s['deg']-ref.get('base_deg',0))
    c,t=cos(angle),sin(angle)
    matrix=(c,t,gx+.5-c*px-t*py,-t,c,gy+.5+t*px-c*py)
    return sprite.transform(size,Image.Transform.AFFINE,matrix,Image.Resampling.NEAREST)

def inspection():
    figures={}
    outdir=P/'review';outdir.mkdir(exist_ok=True)
    for bg, key in backgrounds.items():
        plate=Image.new('RGBA',(4*112,36+8*100),'#202b37')
        dd=ImageDraw.Draw(plate)
        for j,label in enumerate(('OLD / RIGHT','NEW / RIGHT','OLD / LEFT','NEW / LEFT')):
            text(dd,(j*112+9,8),label)
        for i,(id,*_) in enumerate(items):
            w=WEAPONS[id];s=D['sockets']['idle'][1]
            old=old_composite(w,s,1);new=composite(w,s,'idle',1)
            for j, c in enumerate((old,new,ImageOps.mirror(old),ImageOps.mirror(new))):
                sample=ground(bg,size);sample.alpha_composite(c)
                text(ImageDraw.Draw(sample),(5,4),id)
                plate.paste(sample,(j*112,34+i*100))
        filename=f'idle_{key}.png'
        plate.convert('RGB').save(outdir/filename)
        figures[bg]=f'previews/review/{filename}'
    for id in ('muramasa','duanshui'):
        w=WEAPONS[id]
        plate=Image.new('RGBA',(6*112,216),'#202b37')
        for n,s in enumerate(D['sockets']['attack']):
            c=composite(w,s,'attack',n)
            for k,img in enumerate((c,ImageOps.mirror(c))):
                sample=ground('雪地',size);sample.alpha_composite(img)
                text(ImageDraw.Draw(sample),(6,4),f'{n+1} / '+('left' if k else 'right'))
                plate.paste(sample,(n*112,k*100))
        plate.convert('RGB').save(outdir/f'attack_{id}.png')
    return figures

def verify():
    result={}
    for id,*_ in items:
        weapon=WEAPONS[id];values=[]
        for n,s in enumerate(D['sockets']['idle']):
            ref,p,z=mounts(weapon,s,'idle')[0]
            body=Image.new('RGBA',size)
            body.alpha_composite(base_idle.crop((n*64,0,(n+1)*64,64)),origin)
            weapon_alpha=arr(draw_part(ref,p))[:,:,3]>0
            body_alpha=arr(body)[:,:,3]>0
            exposed=int((weapon_alpha&~body_alpha).sum())
            total=int(weapon_alpha.sum())
            values.append(round(100*exposed/total,1))
            assert exposed/total > .52, (id,n,exposed,total)
            if z>=4:
                assert not np.any(weapon_alpha[:origin[1]+20]&body_alpha[:origin[1]+20]),(id,n,'head')
        result[id]=values
    return result

if __name__=='__main__':
    figures=inspection()
    ratios=verify()
    (B/'records/review-visual.json').write_text(json.dumps(dict(idle=figures,exposed_percent=ratios),ensure_ascii=False,indent=2)+'\n')
    print(ratios)
