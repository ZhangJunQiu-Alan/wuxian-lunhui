from pathlib import Path
import json
from PIL import Image,ImageDraw

BASE=Path(__file__).resolve().parent
ref=Image.open(BASE/'references/surtr.png').convert('RGBA');pal=sorted({p[:3] for p in ref.get_flattened_data() if p[3]})
calibration={'idle':(100,108),'move':(100,120),'windup':(100,96),'attack':(140,95),'plant':(100,108),'summon':(100,112)}
components=json.loads((BASE/'records/body_components.json').read_text());result=[]
for row in components:
    action=row['action'];version=row['version'];parts=[Image.open(BASE/r['raw_component']).convert('RGBA') for r in row['poses']]
    belt_y,belt_x=calibration[action];scale=106/(parts[0].height*(1-belt_y/240));root_raw=parts[0].height*belt_x/240
    if action=='attack':scale*=.92
    frames=[];positions=[]
    for i,part in enumerate(parts):
        im=part.resize((round(part.width*scale),round(part.height*scale)),Image.Resampling.NEAREST)
        if action in ['idle','move','summon']:
            pts=[x for y in range(round(im.height*.23),round(im.height*.40)) for x in range(im.width) if (lambda p:p[3]>=128 and p[0]>140 and p[0]>p[1]*1.35)(im.getpixel((x,y)))]
            pts.sort();chest=pts[len(pts)//2];x=160-chest
        else:
            raw_origin=row['poses'][i]['raw_box'][0]-(i%(3 if action=='move' else 2))*Image.open(BASE/f'originals/surtr_{action}_{version}_raw.png').width/(3 if action=='move' else 2)
            first_origin=row['poses'][0]['raw_box'][0]
            root=root_raw+first_origin-raw_origin;x=round(160-root*scale)
        y=318-im.height
        if x<2 or x+im.width>318 or y<2:raise RuntimeError(f'{action}:{i} over320 canvas x{x} y{y} w{im.width} h{im.height}; no clipping or squeezing')
        cache={};data=[]
        for r,g,b,a in im.get_flattened_data():
            if a<128:data.append((0,0,0,0));continue
            rgb=(r,g,b)
            if rgb not in cache:cache[rgb]=min(pal,key=lambda q:sum((q[j]-rgb[j])**2 for j in range(3)))
            data.append(cache[rgb]+(255,))
        im.putdata(data);frame=Image.new('RGBA',(320,320));frame.paste(im,(x,y));frames.append(frame);positions.append([x,y,im.width,im.height])
    n=len(frames);fps=8 if action in ['idle','move','windup'] else 16;loop=action in ['idle','move']
    sheet=Image.new('RGBA',(320*n,320))
    for i,f in enumerate(frames):sheet.paste(f,(320*i,0))
    sheet.save(BASE/f'candidates/surtr_{action}_{version}.png');reference=Image.new('RGBA',(320,320));reference.paste(ref,(64,128))
    board=Image.new('RGB',(320*(n+1),348),'#121721');draw=ImageDraw.Draw(board)
    for i,f in enumerate([reference]+frames):
        board.paste(f,(320*i,0),f);draw.line((320*i,318,320*(i+1)-1,318),fill='#7bb3aa');draw.text((320*i+4,328),'REF' if i==0 else action+str(i-1),fill='white')
    board.save(BASE/f'previews/surtr_{action}_{version}_1x.png')
    for i,f in enumerate(frames):
        bg=Image.new('RGB',(320,320),'#121721');bg.paste(f,(0,0),f);bg.resize((1280,1280),Image.Resampling.NEAREST).save(BASE/f'previews/qa4x_surtr_{action}_{i:02d}.png')
    for kind,rate in [('native',fps),('slow8',8)]:
        pics=[]
        for f in frames:
            bg=Image.new('RGB',(320,320),'#121721');bg.paste(f,(0,0),f);pics.append(bg.resize((640,640),Image.Resampling.NEAREST))
        ms=[round((i+1)*100/rate)*10-round(i*100/rate)*10 for i in range(n)]
        if not loop:ms[-1]+=600
        pics[0].save(BASE/f'previews/surtr_{action}_{version}_{kind}.gif',save_all=True,append_images=pics[1:],duration=ms,loop=0,optimize=False)
    result.append(dict(id='surtr_'+action,version=version,frame_size=[320,320],frames=n,fps=fps,loop=loop,scale=scale,calibration={'first_pose_belt_y_in240height_preview':belt_y,'first_pose_belt_x_in240height_preview':belt_x,'reference_belt_ground_span':106,'manual_source':'calibrate_* images actually viewed'},placements=positions,bboxes=[f.getbbox() for f in frames],method='one uniform scale per action calibrated using body waist-to-sole; no per-axis stretching; root/ground whole-frame placement; approved48RGB binaryalpha'))
(BASE/'records/body_normalization.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
