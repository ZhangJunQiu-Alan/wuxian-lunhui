from body import B, CHAR, W, publish, crop, strip
from PIL import Image
import numpy as np
import json

R=B.parents[2]
FX=R/'assets/sprites/effects/weapons/swordsman'
WP=W.parent/'manifest.json'
SOCKET=CHAR/'swordsman_sockets.json'
legacy={}
for a in ('idle','move','attack','hurt','death'):
    src=np.asarray(Image.open(CHAR/f'swordsman_{a}.png').convert('RGBA'))
    bare=np.asarray(Image.open(CHAR/f'swordsman_bare_{a}.png').convert('RGBA'))
    changed=np.any(src!=bare,axis=2)
    assert not np.any(changed&(bare[:,:,3]>src[:,:,3]))
    data=np.zeros_like(src)
    data[changed]=src[changed]
    name=f'katana_legacy_{a}'
    publish(Image.fromarray(data),W/(name+'.png'))
    legacy[a]=dict(file=f'swordsman/{name}.png',size=[64,64],frames=src.shape[1]//64,anchor=[0,0],layer=4)
m=json.loads(WP.read_text())
m[0]['legacy_layers']=legacy
WP.write_text(json.dumps(m,indent=2)+'\n')
s=json.loads(SOCKET.read_text())
for p in s['actions']['spin']:
    for k in ('x','y'):
        p['main'][k]=round((p['main'][k]+p['off'][k])/2)
SOCKET.write_text(json.dumps(s,indent=2)+'\n')

def update(path,data):
    (B/'candidates'/f'{path.stem}_v1.png').write_bytes(path.read_bytes())
    Image.fromarray(data).save(path)
    Image.fromarray(data).save(B/'approved'/path.name)
p=FX/'duanshui_scar.png'
x=np.array(Image.open(p))
x[:,:,3]=np.minimum(x[:,:,3],192)
update(p,x)
p=CHAR/'swordsman_bare_sheathe.png'
x=np.array(Image.open(p))
colors,count=np.unique(x[x[:,:,3]>0,:3],axis=0,return_counts=True)
ind=np.argsort(count,kind='stable')
main=colors[ind[2:]].astype(int)
for c in colors[ind[:2]]:
    m=(x[:,:,3]>0)&np.all(x[:,:,:3]==c,axis=2)
    x[m,:3]=main[np.argmin(np.sum((main-c.astype(int))**2,axis=1))]
update(p,x)
