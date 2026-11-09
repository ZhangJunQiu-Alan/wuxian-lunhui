from math import cos, radians, sin
import json

from PIL import Image, ImageDraw, ImageOps
from qa import B, D, GROUNDS, ITEMS, P, WEAPONS, arr, composite, draw_part, im, mounts, path, shifted, stow_point, text, ground

OUT = P/'carry_2026-11-09'
SIZE = (112,88)
WAIST = [id for id,*_ in ITEMS if WEAPONS[id].get('sheath_file')]

def tile(id, action, frame, bg, left=False, variant=None):
    out=ground(bg,SIZE)
    s=D['sockets'][action][frame]
    c=composite(WEAPONS[id],s,action,frame,mode=variant)
    out.alpha_composite(ImageOps.mirror(c) if left else c)
    return out

def board(filename, rows, columns):
    im=Image.new('RGB',(len(columns)*SIZE[0],26+len(rows)*(SIZE[1]+4)),'#202b37')
    d=ImageDraw.Draw(im)
    for j,(label,*_) in enumerate(columns):
        text(d,(j*SIZE[0]+4,7),label)
    for i,(id,action,variant) in enumerate(rows):
        for j,(_,frame,bg,left) in enumerate(columns):
            if frame>=len(D['sockets'][action]):continue
            c=tile(id,action,frame,bg,left,variant)
            text(ImageDraw.Draw(c),(4,3),f'{id} {variant or (action if action!="idle" else "")}')
            im.paste(c,(j*SIZE[0],26+i*(SIZE[1]+4)))
    im.save(OUT/filename)
    return 'previews/'+OUT.name+'/'+filename

def verify():
    results={}
    for id in WAIST:
        w=WEAPONS[id]
        closed=arr(path(w['stow_file']))
        empty=arr(path(w['sheath_file']))
        x,y=w['stow_grip']
        assert closed.shape==empty.shape and closed[:,0:x-2,3].any()
        assert not empty[:,0:x,3].any() and empty[:,x:,3].any()
        assert 120<=w['stow_socket_adjust']['deg']<=135
        count=0
        for action in ('idle','move','attack','sheathe','iai_stance','iai_dash'):
            for n,s in enumerate(D['sockets'][action]):
                refs=mounts(w,s,action,n=n)
                file=w['sheath_file'] if s['mode']=='held' else w['stow_file']
                carried=[(ref,p,z) for ref,p,z in refs if ref['file'] in (w['sheath_file'],w['stow_file'])]
                assert len(carried)==1 and carried[0][0]['file']==file
                assert carried[0][1]==stow_point(w,s,action,n)
                assert len([v for v,p,z in refs if v['file']==w['main']['file']])==(s['mode']=='held')
                frame=D['waistFrames'].get(action,[{}]*len(D['sockets'][action]))[n]
                if 'feed_px' in frame:
                    ref,p,_=next(r for r in refs if r[0]['file']==w['main']['file'])
                    mouth=carried[0][1]
                    d=frame['feed_px']
                    assert abs(p['x']+d*cos(radians(p['deg']))-mouth['x'])<0.01
                    assert abs(p['y']+d*sin(radians(p['deg']))-mouth['y'])<0.01
                    assert ref['clip']==ref['grip'][0]+d+1
                count+=1
        s=D['sockets']['idle'][0]
        ref,p,_=mounts(w,s,'idle')[0]
        tail=draw_part(dict(ref,grip=[x,y]),p)
        body=im('swordsman_bare_idle').crop((0,0,64,64))
        rear=tail.getbbox()[0]
        visible_left=any(
            (outline:=body.crop((0,row-12,64,row-11)).getbbox())
            and any(tail.getpixel((col,row))[3] and col<24+outline[0] for col in range(rear,rear+4))
            for row in range(max(12,tail.getbbox()[1]),min(76,tail.getbbox()[3])))
        assert visible_left,(id,tail.getbbox(),body.getbbox())
        results[id]=dict(checked_frames=count,tail_exits_idle_outline=visible_left)
    g=WEAPONS['chunyang']['props']['gourd']
    for n in (0,5):
        s=D['sockets']['drink'][n]
        hip=shifted(s['hip']|dict(deg=0),g['hip_adjust'])
        assert (hip['x'],hip['y'],hip['deg'])==tuple(s['off'][k] for k in ('x','y','deg'))
    return results

if __name__=='__main__':
    OUT.mkdir(exist_ok=True)
    all_rows=[(id,'idle',None) for id,*_ in ITEMS]
    waist=[(id,'idle',None) for id in WAIST]
    grounds=[(label,0,bg,left) for bg,tag in zip(GROUNDS,('SNOW','HELHEIM','ASH')) for left,label in ((False,tag+' / R'),(True,tag+' / L'))]
    visual={
        'all':board('all_idle.png',all_rows,grounds),
        'waist':board('waist_idle.png',waist,grounds),
        'move':board('waist_move.png',[(id,'move',None) for id in WAIST],
                       [(f'MOVE {n+1}',n,'雪地',False) for n in range(6)]),
        'attack':{id:f'previews/{OUT.name}/{id}_attack.png' for id in WAIST},
        'checks':verify(),
    }
    # Separate right and left rows for every six-frame attack.
    for id in WAIST:
        plate=Image.new('RGB',(672,2*92+26),'#202b37')
        d=ImageDraw.Draw(plate)
        for n in range(6):
            text(d,(n*112+5,7),f'{n+1} / '+('STOW' if n in (0,5) else 'FEED' if n==4 else 'DRAWN'))
            for k in (0,1):
                c=tile(id,'attack',n,'雪地',bool(k))
                text(ImageDraw.Draw(c),(4,3),'LEFT' if k else 'RIGHT')
                plate.paste(c,(n*112,26+k*92))
        plate.save(OUT/f'{id}_attack.png')
    visual['handoffs']=board('handoffs.png',[
        ('excalibur','sheathe',None),('excalibur','iai_stance',None),('excalibur','iai_dash',None),
        ('chunyang','drink',None),('ganjiang_moye','throw',None),
        ('riyue','idle','sun'),('riyue','idle','moon')],
        [(f'FRAME {n+1}',n,'焦土',False) for n in range(6)])
    (B/'records/carry-visual.json').write_text(json.dumps(visual,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(visual['checks'],ensure_ascii=False))
