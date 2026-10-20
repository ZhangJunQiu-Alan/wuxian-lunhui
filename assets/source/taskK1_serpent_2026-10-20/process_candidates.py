from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
REF=Image.open(BASE/'references/jormungandr_head.png').convert('RGBA')
PALETTE=sorted({p[:3] for p in REF.get_flattened_data() if p[3]})
FONT=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',12)
report=[]


def bg(frame, factor=1):
    b=Image.new('RGB',(128,128),'#121721');b.paste(frame,(0,0),frame)
    return b.resize((128*factor,128*factor),Image.Resampling.NEAREST)


for action,count,fps,loop in [('idle',4,8,True),('windup',3,8,False),('attack',4,16,False)]:
    raw=Image.open(BASE/f'originals/head_{action}_v01_raw.png').convert('RGBA')
    frames=[]
    for i in range(count):
        c=raw.crop(((i%2)*raw.width//2,(i//2)*raw.height//2,(i%2+1)*raw.width//2,(i//2+1)*raw.height//2))
        c=c.resize((128,128),Image.Resampling.NEAREST)
        out=Image.new('RGBA',(128,128));colors={};pixels=[]
        for r,g,b,a in c.get_flattened_data():
            if a<128:pixels.append((0,0,0,0));continue
            rgb=(r,g,b)
            if rgb not in colors:colors[rgb]=min(PALETTE,key=lambda p:sum((p[j]-rgb[j])**2 for j in range(3)))
            pixels.append(colors[rgb]+(255,))
        out.putdata(pixels);frames.append(out)
    strip=Image.new('RGBA',(128*count,128))
    for i,f in enumerate(frames):strip.paste(f,(128*i,0))
    candidate=BASE/f'candidates/head_{action}_v01.png';strip.save(candidate)
    board=Image.new('RGB',(128*(count+1),160),'#121721');d=ImageDraw.Draw(board)
    for i,f in enumerate([REF]+frames):
        board.paste(f,(i*128,0),f);d.text((i*128+4,138),'REF' if i==0 else f'{action} {i-1}',font=FONT,fill='white')
    board.save(BASE/f'previews/head_{action}_v01_review_1x.png')
    board.resize((board.width*4,board.height*4),Image.Resampling.NEAREST).save(BASE/f'previews/head_{action}_v01_review_4x.png')
    for name,rate in [('native',fps),('slow8',8)]:
        pictures=[bg(f,4) for f in frames]
        durations=[round((i+1)*1000/rate/10)*10-round(i*1000/rate/10)*10 for i in range(count)]
        if not loop:durations[-1]+=600
        pictures[0].save(BASE/f'previews/head_{action}_v01_{name}.gif',save_all=True,append_images=pictures[1:],duration=durations,loop=0,optimize=False)
    info=[]
    for i,f in enumerate(frames):
        mask=f.getchannel('A');ys=[y for y in range(128) if mask.getpixel((0,y))]
        info.append(dict(frame=i,bbox=list(mask.getbbox()),neck_span=[min(ys),max(ys)] if ys else None,
                         neck_center=(min(ys)+max(ys))/2 if ys else None,
                         neck_socket_occupied=bool(mask.getpixel((0,62))),
                         sha256=hashlib.sha256(f.tobytes()).hexdigest(),
                         rgb_colors=len({p[:3] for p in f.get_flattened_data() if p[3]})))
    pairs=[]
    for i in range(count):
        pairs.append(sum(p!=q for p,q in zip(frames[i].get_flattened_data(),frames[(i+1)%count].get_flattened_data())))
    report.append(dict(action=action,candidate=str(candidate.relative_to(BASE)),raw_size=raw.size,
                       method='fixed 2x2 cells, nearest128, alpha>=128, nearest color from exact approved 48RGB palette; no painted pixels or motion synthesis',
                       logical_frame=[128,128],frames=count,fps=fps,loop=loop,per_frame=info,
                       distinct_frame_hashes=len({x['sha256'] for x in info}),adjacent_pixel_changes=pairs,
                       candidate_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),
                       all_sockets_occupied=all(x['neck_socket_occupied'] for x in info),
                       socket_center_range=[min(x['neck_center'] for x in info),max(x['neck_center'] for x in info)],
                       visual_review='pending',game_test='not_performed'))
    body=Image.open(BASE/'references/jormungandr_body.png').convert('RGBA')
    joints=Image.new('RGB',(320,140*count),'#121721');jd=ImageDraw.Draw(joints)
    for i,f in enumerate(frames):
        joints.paste(body,(16,140*i+46),body);joints.paste(body,(80,140*i+46),body)
        joints.paste(f,(144,140*i+14),f)
        jd.text((5,140*i+120),f'{action} {i} / fixed socket(0,62)',font=FONT,fill='white')
    joints.resize((960,420*count),Image.Resampling.NEAREST).save(BASE/f'previews/head_{action}_v01_joints.png')
(BASE/'records/normalization_candidates_v01.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps([{k:r[k] for k in ['action','all_sockets_occupied','socket_center_range','distinct_frame_hashes','adjacent_pixel_changes']} for r in report],indent=2))
