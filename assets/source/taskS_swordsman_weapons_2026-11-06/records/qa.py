from catalog import B,R,A,CHAR,WP,FX,UI,SFX,COUNTS,GROUNDS,ITEMS
from PIL import Image,ImageDraw,ImageOps,ImageFont
from pathlib import Path
from functools import lru_cache
import json, math, hashlib, wave, subprocess, struct, zlib
import numpy as np

P=B/'previews'
D=json.loads((B/'manifest.json').read_text())
WEAPONS=D['weapons']
FXS={e['id']:e for e in D['effects']}
F=D['files']
bad=[]; notes=[]; metrics={}
font=ImageFont.load_default()
def check(b,msg):
    if not b:bad.append(msg)
def arr(im):
    return np.asarray(im.convert('RGBA'))
@lru_cache(maxsize=None)
def load(path):
    return Image.open(path).convert('RGBA')
def im(id):
    return load((B/F[id]['file']).resolve())
def path(name):
    return load(WP/name)
def png_strip(e,n):
    w,h=e['size']
    return load(A/e['file']).crop((n*w,0,(n+1)*w,h))
def text(d,xy,value,color='#b1c4d1'):
    d.text(xy,value,font=font,fill=color)
def ground(g,size):
    im=load(A/'sprites/ground'/GROUNDS[g])
    out=Image.new('RGBA',size)
    for y in range(0,size[1],im.height):
        for x in range(0,size[0],im.width):out.paste(im,(x,y))
    return out
def source_asset_integrity():
    for k,f in F.items():
        p=(B/f['file']).resolve()
        check(p.is_file(),'缺失 '+str(p))
        check(hashlib.sha256(p.read_bytes()).hexdigest()==f['sha256'],'SHA256 '+k)
        if p.suffix=='.wav':
            with wave.open(str(p)) as w:
                check((w.getnchannels(),w.getsampwidth(),w.getframerate())==(1,2,44100),'WAV 格式 '+k)
                x=np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(float)/32768
                check(np.max(np.abs(x))<.99,'WAV 削波 '+k)
                if k=='qinglong_spin_loop.wav':
                    d=np.abs(np.diff(x,append=x[0]))
                    metrics['spin_seam_delta']=round(float(d[-1]),7)
                    check(d[-1]<=np.quantile(d,.95),'旋风循环接缝')
            continue
        src=Image.open(p)
        check(src.size==tuple(f['size']),'画布 '+k)
        check(src.mode=='RGBA','PNG 色彩模式 '+k)
        x=arr(src)
        alpha=set(np.unique(x[:,:,3]))
        cap={'higekiri_oni_aura':160,'higekiri_oni_horns':160,'duanshui_scar':200,'qinglong_avatar':180,'excalibur_guard':120}.get(k,255)
        check(max(alpha)<=cap,'alpha 上限 '+k)
        check(len(alpha)<=8 if k in FXS else alpha<={0,255},'alpha 档数 '+k)
        check(len(np.unique(x[x[:,:,3]>0,:3],axis=0))<=48,'单文件色板 '+k)
        check(src.width % f.get('frames',1)==0,'帧条 '+k)
        check(len(set(f['path'].split()) & {''})==0 and p.stem==p.stem.lower(),'命名 '+k)
        if k.endswith('_icon'):
            b=src.getbbox()
            check(src.size==(32,32) and b and min(b[:2])>=1 and max(b[2:])<=31,'图标留白 '+k)
        if (UI/p.name).is_file():
            check(src.size==(12,12),'HUD 图标尺寸 '+k)
        source=B/'approved/editable'/f'{k}.aseprite'
        data=source.read_bytes()
        total,magic,frames,w,h,bpp=struct.unpack_from('<I5H',data)
        check(total==len(data) and magic==0xa5e0 and bpp==32 and frames==f.get('frames',1) and (w*frames,h)==src.size,'Aseprite 头 '+k)
        offset=128
        for n in range(frames):
            length,tag,count,ms=struct.unpack_from('<IHHH',data,offset)
            check(tag==0xf1fa and ms>0,'Aseprite 帧头 '+k)
            cel=offset+16; layer0=Image.new('RGBA',(w,h))
            for _ in range(count):
                size,kind=struct.unpack_from('<IH',data,cel)
                if kind==0x2005:
                    j,x,y,_,ctype,_,cw,ch=struct.unpack_from('<HhhBHh5xHH',data,cel+6)
                    if j==0:
                        check(ctype==2,'Aseprite 压缩类型 '+k)
                        layer0.paste(Image.frombytes('RGBA',(cw,ch),zlib.decompress(data[cel+26:cel+size])),(x,y))
                cel+=size
            check(cel==offset+length,'Aseprite 块长度 '+k)
            a=arr(src.crop((n*w,0,(n+1)*w,h)));o=arr(layer0)
            check(np.array_equal(a[a[:,:,3]>0],o[a[:,:,3]>0]) and np.array_equal(a[:,:,3],o[:,:,3]),'Aseprite 像素一致性 '+k)
            offset+=length
    check(len(WEAPONS)==11,'武器套数')
    check(len(FXS)==46 and len(D['ui'])==10 and len(D['audio'])==19,'特效/UI/音效数量')
    check(len(D['actions'])==14 and sum(len(x) for x in D['sockets'].values())==64,'动作/挂点数量')
    check(len(F)==144,'总文件数')
    metrics.update(body_actions=14,body_frames=64,new_fx=46,ui_icons=10,new_wav=19,new_png=125)

def shifted(point,adjustment):
    p=point|adjustment
    p['x']+=p.get('dx',0);p['y']+=p.get('dy',0)
    return p

def stow_point(w,s,a,n):
    hip=D['waistFrames'].get(a,[{}]*COUNTS[a])[n].get('hip',{}) if w.get('sheath_file') else {}
    return shifted(s[w['stow']]|hip,w.get('stow_socket_adjust',{}))

def mounts(w,s,a,mode=None,n=0):
    if s['mode']=='none':return []
    m=[]
    held=w['idle_hold']=='held' or s['mode']=='held'
    if w.get('stow_file') and (not held or w.get('sheath_file')):
        p=stow_point(w,s,a,n)
        m.append((dict(file=w['sheath_file'] if held else w['stow_file'],grip=w['stow_grip'],
                       base_deg=w.get('stow_base_deg',0)),p,4 if p['z']=='front' else 1))
        if not held and w.get('stow_keeper'):
            m.append((dict(file=w['stow_keeper'],grip=w['stow_grip'],base_deg=w.get('stow_base_deg',0)),p,4))
    if held:
        variants=w.get('variants',{})
        v=variants.get(mode,w.get('main',next(iter(variants.values()),None)))
        point=s['main']
        if a=='idle':point=shifted(point,w.get('idle_main_adjust',{}))
        if w.get('flight_px') and a=='attack':
            t=(0,.52,1,.77,.36,0)[n]
            reach=w['flight_px']-(v['tip'][0]-v['grip'][0])
            point=point|dict(x=point['x']+(32+reach-point['x'])*t,y=point['y']+(31-point['y'])*t,
                             deg=0 if n<3 else 180,z='front')
        feed=D['waistFrames'].get(a,[{}]*COUNTS[a])[n].get('feed_px') if w.get('sheath_file') else None
        if feed is not None:
            mouth=stow_point(w,s,a,n)
            rad=math.radians(mouth['deg'])
            point=mouth|dict(x=mouth['x']-feed*math.cos(rad),y=mouth['y']-feed*math.sin(rad))
            v=v|dict(clip=min(v['tip'][0]+1,v['grip'][0]+feed+1))
        if v:m.append((v,point,2 if point['z']=='back' else 4))
        off=shifted(s['off'],w.get('off_idle_adjust',{}) if a in ('idle','move') else {})
        if w['id']=='riyue':m.append((variants['sun' if mode=='moon' else 'moon'],off,2))
        if w['id']=='zhuxian':
            for (dx,dy),vv in zip(w['reserve_offsets'],(item for item in variants.values() if item!=v)):
                b=s['back'];m.append((vv,dict(x=b['x']+dx,y=b['y']+dy,deg=-90),1))
        if 'off' in w and (w['id']!='ganjiang_moye' or a!='throw' or n<2):m.append((w['off'],off,4 if a=='off_attack' else 2))
    if 'props' in w:
        g=w['props']['gourd']
        p=s['off'] if a=='drink' else shifted(s['hip']|dict(deg=0),g['hip_adjust'])
        m.append((g,p,4))
    return m

def draw_part(ref,s,size=(112,96),o=(24,12)):
    im=path(ref['file']);gx,gy=ref['grip']
    if ref.get('clip'):im=im.crop((0,0,ref['clip'],im.height))
    px,py=s['x']+o[0]+.5,s['y']+o[1]+.5
    theta=math.radians(s.get('deg',0)-ref.get('base_deg',0))
    c,t=math.cos(theta),math.sin(theta)
    f=(c,t,gx+.5-c*px-t*py,-t,c,gy+.5+t*px-c*py)
    return im.transform(size,Image.Transform.AFFINE,f,Image.Resampling.NEAREST)

def composite(w,s,a,n,exact=False,mode=None,size=(112,96),origin=(24,12)):
    stationary=w.get('flight_px') and a=='attack'
    if stationary:s=D['sockets']['idle'][0]
    out=Image.new('RGBA',size)
    o=origin
    body=D['waistBodies'].get(a) if w.get('sheath_file') and not exact else None
    sprite=load((B/body).resolve()) if body else im('swordsman_bare_'+('idle' if stationary else a))
    index=0 if stationary else n
    source=sprite.crop((64*index,0,64*(index+1),64))
    leg=w.get('legacy_layers',{}).get(a) if exact else None
    layers=mounts(w,s,a,mode,n)
    if not leg:
        for v,k,z in layers:
            if z<3:out.alpha_composite(draw_part(v,k,size=size,o=o))
    out.alpha_composite(source,o)
    if leg:
        out.alpha_composite(path(leg['file']).crop((64*n,0,64*(n+1),64)),o)
    else:
        for v,k,z in layers:
            if z>=4:out.alpha_composite(draw_part(v,k,size=size,o=o))
    return out

def bodies():
    recon={}; universal={}
    for a,count in COUNTS.items():
        offsets=D['sockets'][a]
        check(len(offsets)==count and im('swordsman_bare_'+a).size==(count*64,64),'空手帧条规格 '+a)
        check(all(set(x)=={'mode','main','off','hip','back','head'} and x['mode'] in ('held','stow','none') for x in offsets),'挂点字段 '+a)
        for frame in offsets:
            for k in ('main','off','hip','back','head'):
                s=frame[k]
                check(isinstance(s['x'],int) and 0<=s['x']<64 and isinstance(s['y'],int) and 0<=s['y']<64,'挂点坐标 '+a+'/'+k)
        if a in ('idle','move','attack','hurt','death'):
            src=load(CHAR/f'swordsman_{a}.png')
            recon[a]=[]; universal[a]=[]
            for n,s in enumerate(offsets):
                x=arr(src.crop((n*64,0,(n+1)*64,64)))
                for exact,report in [(True,recon),(False,universal)]:
                    y=arr(composite(WEAPONS['katana'],s,a,n,exact).crop((24,12,88,76)))
                    mismatch=np.any(x!=y,axis=2) & ((x[:,:,3]>0)|(y[:,:,3]>0))
                    report[a].append(int(mismatch.sum()))
                check(recon[a][-1]==0,f'旧太刀还原 {a}/{n+1}')
    metrics['universal_katana_delta_px']=sum(sum(a) for a in universal.values())
    (B/'records/katana-pixel-check.json').write_text(json.dumps({'frame_matched':recon,'universal':universal},indent=2)+'\n')
    atlas={}
    atlas_dir=P/'mounts';atlas_dir.mkdir(exist_ok=True)
    gnames=list(GROUNDS)
    stage_keys=['初始','第一关','第二关','第三关']
    mini=Image.new('RGBA',(9*112,6*96),'#202b37')
    for j,(id,nm,g,*_) in enumerate(ITEMS):
        w=WEAPONS[id]
        plate=Image.new('RGBA',(6*112,len(COUNTS)*216+42),'#202b37');dd=ImageDraw.Draw(plate)
        text(dd,(9,10),f'{id.upper()}   |   RIGHT + LEFT   |   1X   |   {sum(COUNTS.values())} FRAMES PER SIDE')
        ground_image=ground(gnames[max(0,stage_keys.index(g)-1)],(112,96))
        for i,(a,count) in enumerate(COUNTS.items()):
            y=i*216+36
            text(dd,(9,y),f'{a}  /  {count} frames')
            for n,s in enumerate(D['sockets'][a]):
                c=composite(w,s,a,n)
                for k,img in enumerate((c,ImageOps.mirror(c))):
                    shot=ground_image.copy();shot.alpha_composite(img)
                    plate.paste(shot,(n*112,y+16+k*97))
                if n==1 and a in ('idle','attack','spin') and j<9:
                    x0=(j%9)*112;y0={'idle':0,'attack':96,'spin':192}[a]
                    sample=ground_image.copy();sample.alpha_composite(c)
                    mini.paste(sample,(x0,y0));text(ImageDraw.Draw(mini),(x0+3,y0+3),id[:13])
        name=f'mounts/{id}.png'
        plate.convert('RGB').save(P/name)
        atlas[id]='previews/'+name
    mini.crop((0,0,9*112,3*96)).convert('RGB').resize((1512,432),Image.Resampling.NEAREST).save(P/'mount_sample.png')
    metrics['composited_frames']=11*sum(COUNTS.values())*2
    return recon,atlas

def compare_arcs():
    arcs={}; measurements={}
    out=P/'hit_ranges';out.mkdir(exist_ok=True)
    for e in D['effects']:
        if 'radius' not in e:continue
        r=e['radius'];a=e['angle'];cx,cy=e['anchor']
        source=png_strip(e,1)
        y,x=np.where(np.asarray(source)[:,:,3]>0)
        coords=np.column_stack((x-cx,y-cy))
        curve=np.deg2rad(np.linspace(-a/2,a/2,max(12,a*2+1)))
        target=np.column_stack((r*np.cos(curve),r*np.sin(curve)))
        dist=np.linalg.norm(target[:,None,:]-coords[None,:,:],axis=2).min(axis=1)
        over=max(float(np.hypot(coords[:,0],coords[:,1]).max()-r),0)
        check(float(max(dist.max(),over))<=4.0,'判伤几何 '+e['id'])
        measurements[e['id']]={'edge_px':round(float(dist.max()),3),'outer_overshoot_px':round(over,3),'radius':r,'angle':a,'frame':2}
        dst=ground('冥界',(360,344));mark=Image.new('RGBA',dst.size)
        ox=29 if a<=180 else 180; oy=171
        dd=ImageDraw.Draw(mark);box=(ox-r,oy-r,ox+r,oy+r)
        if a==360:dd.ellipse(box,outline='#deb883',fill='#d7af6231')
        else:dd.pieslice(box,-a/2,a/2,outline='#deb883',fill='#d7af6231')
        dst.alpha_composite(mark);dst.alpha_composite(source,(ox-cx,oy-cy))
        text(ImageDraw.Draw(dst),(8,8),e['id']+f'  |  {r}px / {a} deg', '#f4ead5')
        p=out/(e['id']+'.png');dst.convert('RGB').save(p);arcs[e['id']]='previews/hit_ranges/'+p.name
    (B/'records/hit-range-check.json').write_text(json.dumps(measurements,indent=2)+'\n')
    metrics['max_arc_edge_px']=max(max(v['edge_px'],v['outer_overshoot_px']) for v in measurements.values())
    return arcs

def contrasts():
    output={}
    rows=[('断水 / 斯卡蒂冰晶','duanshui', 'duanshui_scar','sprites/effects/gods/skadi_ice.png','Water wall','Skadi crystal'),
          ('诛仙浮剑 / 弗雷飞剑','zhuxian',None,'sprites/effects/gods/freyr_sword.png','Back-mounted swords','Freyr projectile'),
          ('湖中剑 / 次元斩','excalibur','excalibur_line_burst','sprites/effects/ultimates/dimension_cut.png','Lake-blue burst','Dimension cut')]
    for label,id,fx_id,other,left_caption,right_caption in rows:
        dst=ground('冥界',(680,280))
        if id=='zhuxian':
            c=composite(WEAPONS[id],D['sockets']['idle'][0],'idle',0)
            dst.alpha_composite(c.resize((224,192),Image.Resampling.NEAREST),(55,32))
        elif id=='excalibur':
            sprite=png_strip(FXS[fx_id],2)
            for i in range(9):dst.alpha_composite(sprite,(25+i*31,111))
        else:
            dst.alpha_composite(png_strip(FXS[fx_id],3),(38,18))
        legacy=load(A/other)
        cellw=legacy.height if legacy.width>=legacy.height and legacy.width%legacy.height==0 else legacy.width
        cell_count=legacy.width//cellw
        frame=1 if cell_count>1 else 0
        legacy=legacy.crop((frame*cellw,0,(frame+1)*cellw,legacy.height))
        legacy.thumbnail((310,236),Image.Resampling.NEAREST)
        dst.alpha_composite(legacy,(510-legacy.width//2,135-legacy.height//2))
        dd=ImageDraw.Draw(dst);dd.rectangle((338,0,340,280),fill='#9bb2ba')
        text(dd,(13,255),left_caption);text(dd,(352,255),right_caption)
        name=f'contrast_{id}.png'
        dst.convert('RGB').save(P/name)
        output[label]='previews/'+name
    return output

def media():
    for item in D['items']:
        id=item['id']
        p=P/(id+'.png')
        check(p.is_file() and Image.open(p).size==(1280,720),'Godot 截图 '+id)
        if id=='katana':continue
        p=P/(id+'.webm')
        if not p.is_file():bad.append('Godot 录屏缺失 '+id);continue
        data=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(p)]))
        streams={s['codec_type']:s for s in data['streams']}
        v=streams.get('video',{})
        check((v.get('width'),v.get('height'),v.get('codec_name'))==(1280,720,'vp9') and streams.get('audio',{}).get('codec_name')=='opus','Godot 视频规格 '+id)

def userdata():
    before=json.loads((B/'records/userdata-before.json').read_text())
    root=Path.home()/'Library/Application Support/Godot/app_userdata/无限轮回'
    current={p.name:{'mtime_ns':p.stat().st_mtime_ns,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in root.iterdir() if p.is_file() and any(k in p.name for k in ['save','settings'])}
    check(before==current,'正式存档与设置的 mtime／SHA256')
    (B/'records/userdata-after.json').write_text(json.dumps(current,indent=2)+'\n')
    metrics['userdata_files_checked']=len(before)

if __name__=='__main__':
    source_asset_integrity()
    recon,atlas=bodies()
    arcs=compare_arcs()
    comparisons=contrasts()
    media()
    userdata()
    notes.extend([
        '太刀逐帧拆层在 24 帧可见像素上完全还原。单一手持与刀鞘按通用挂点合成时仍有 '+str(metrics['universal_katana_delta_px'])+' 个不同像素，页面保留两种视图。',
        '水壁初稿有高于 200 的 alpha，已改为上限 192。收剑动作初稿有 50 色，已并至 48 色。诛仙图标补齐了 1 像素留边。',
        '按确认图重做五套腰挂。刀柄朝前上方，鞘尾往身后斜下；拔刀与回鞘期间保留独立空鞘。其余六套沿用原持械方式并调整轮廓。',
        '高清概念由内置图像工具生成。游戏尺寸由概念重新描像素，旧动作以原画局部拆修，新动作沿用原角色躯干和服装并重绘手臂。',
        '武器规则按本地任务书转述。任务书引用的 Claude 设计稿未能打开核对逐字文本。',
        '视频是独立 Godot 工程的预编排素材演示。正式游戏的判伤、数值、输入、敌人和状态逻辑仍属后续接入。',
    ])
    q=dict(failures=bad,notes=notes,metrics=metrics,reconstruction=recon,atlases=atlas,arc_previews=arcs,contrasts=comparisons,
        candidates={'断水水壁第一版':'candidates/duanshui_scar_v1.png','收剑动作第一版':'candidates/swordsman_bare_sheathe_v1.png','诛仙图标第一版':'candidates/zhuxian_icon_v1.png','物干竿刀鞘第一版':'candidates/monohoshizao_stow_v1.png','概念全览':'previews/concepts_contact.jpg'})
    (B/'records/qa.json').write_text(json.dumps(q,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'failures':bad,'metrics':metrics},ensure_ascii=False,indent=2))
