import json
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[1]
strip=Image.open(root/'candidates/musashi_move_v03.png').convert('RGBA')
frames=[strip.crop((i*64,0,(i+1)*64,64)) for i in range(6)]
cloth=['#151011','#1b181c','#232229','#2b2c38','#3d404f','#565561','#616375']
skin=['#5e453e','#855946','#ad7e63','#e1a377']
def rgba(h):return tuple(bytes.fromhex(h[1:]))+(255,)
cloth=list(map(rgba,cloth));skin=list(map(rgba,skin))
def shade(p,shift):
    ramp=skin if p in skin else cloth if p in cloth else None
    return ramp[max(0,min(len(ramp)-1,ramp.index(p)+shift))] if ramp else p

def target_pixel(i,x,y):
    source=frames[i%3]
    p=source.getpixel((x,y))
    if y<24 or (24<=y<29 and 33<=x<=36):
        return frames[0].getpixel((x,y))
    if not p[3]:return (0,0,0,0)
    opposite=i>=3
    # Side-view ownership: near limbs use the lit ramp; far limbs use the shade ramp.
    if 26<=y<=38 and x<=28:return shade(p,-1 if opposite else 0)
    if 28<=y<=35 and x>=37:return shade(p,0 if opposite else -1)
    if y>=43:return shade(p,(-1 if x<32 else 1) if opposite else (0 if x<32 else -1))
    return p

plan={'source':'candidates/musashi_move_v03.png','method':'Piskel UI manual profile lock and six-phase near/far limb correction','head_reference_frame':0,'frames':[]}
for i,old in enumerate(frames):
    edits=[]
    for y in range(64):
        for x in range(64):
            p=target_pixel(i,x,y);q=old.getpixel((x,y))
            if (p if p[3] else (0,0,0,0))!=(q if q[3] else (0,0,0,0)):
                edits.append({'x':x,'y':y,'rgba':list(p),'hex':'#'+''.join(f'{v:02x}' for v in p[:3]) if p[3] else None})
    plan['frames'].append({'index':i,'reference_pose':i%3,'near_limb':'front' if i>=3 else 'rear','edits':edits})
(root/'records/move_manual_pixel_plan_v04.json').write_text(json.dumps(plan,indent=2))
print([len(f['edits']) for f in plan['frames']])
