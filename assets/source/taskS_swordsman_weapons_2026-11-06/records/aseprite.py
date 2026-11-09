import json, struct, zlib
from pathlib import Path
from PIL import Image

B=Path(__file__).resolve().parents[1]
OUT=B/'approved/editable'
OUT.mkdir(exist_ok=True)

def chunk(ident,raw):
    return struct.pack('<IH',len(raw)+6,ident)+raw
def layer(name,visible):
    name=name.encode('utf-8')
    return chunk(0x2004,struct.pack('<6HB3xH',3 if visible else 2,0,0,0,0,0,255,len(name))+name)
def cel(i,frame):
    box=frame.getbbox(alpha_only=True)
    if not box:return b''
    f=frame.crop(box)
    body=struct.pack('<HhhBHh5xHH',i,box[0],box[1],255,2,0,f.width,f.height)
    return chunk(0x2005,body+zlib.compress(f.tobytes()))
def save(path,images,n,fps):
    w,h=images[0][1].width//n,images[0][1].height
    frames=[]
    ms=max(1,round(1000/fps))
    for i in range(n):
        cs=[layer(label,visible) for label,im,visible in images] if i==0 else []
        cs += [c for j,(_,im,_) in enumerate(images) if (c:=cel(j,im.crop((i*w,0,(i+1)*w,h))))]
        payload=b''.join(cs)
        frames.append(struct.pack('<IHHH2xI',len(payload)+16,0xF1FA,len(cs),ms,len(cs))+payload)
    raw=b''.join(frames)
    header=struct.pack('<I5HIHII4xHBBhhHH84x',len(raw)+128,0xA5E0,n,w,h,32,1,ms,0,0,0,1,1,0,0,0,0)
    assert len(header)==128
    path.write_bytes(header+raw)
def main():
    data=json.loads((B/'manifest.json').read_text())
    files=data['files']; fps={x['id']:x['fps'] for x in data['effects']}
    fps.update({'swordsman_bare_'+a:p['fps'] for a,p in data['actions'].items()})
    for id,item in files.items():
        if 'size' not in item:continue
        im=Image.open(B/item['file']).convert('RGBA')
        group=[(id,im,True)]
        if id.startswith('swordsman_bare_'):
            a=id.removeprefix('swordsman_bare_')
            f=files.get('katana_legacy_'+a)
            if f:group.append(('Katana legacy overlay',Image.open(B/f['file']).convert('RGBA'),False))
        if not id.endswith('_glow') and id+'_glow' in files:
            group.append(('Glow',Image.open(B/files[id+'_glow']['file']).convert('RGBA'),False))
        save(OUT/f'{id}.aseprite',group,item.get('frames',1),fps.get(id,16))
    print(len(list(OUT.glob('*.aseprite'))),'editable sprites')
if __name__=='__main__':main()
