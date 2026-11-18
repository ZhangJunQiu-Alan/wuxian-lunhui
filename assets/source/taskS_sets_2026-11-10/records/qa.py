from hashlib import file_digest
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from catalog import ASSET, BASE, DEST, GROUNDS, ROOT, collect


def digest(p):
    with p.open('rb') as f:
        return file_digest(f,'sha256').hexdigest()


def verify_existing():
    baseline = BASE/'records/baseline-assets.sha256'
    entries = [line.split('  ',1) for line in baseline.read_text().splitlines()]
    def verify(entry):
        expected, path = entry
        real = ROOT/path
        return None if real.is_file() and digest(real) == expected else path
    with ThreadPoolExecutor(max_workers=6) as pool:
        changes = [p for p in pool.map(verify,entries) if p]
    return len(entries),changes


def build_boards(data):
    destination = BASE/'previews'
    normal = ImageFont.truetype(str(ASSET/'fonts/NotoSansSC-Regular.otf'),13)
    tiny = ImageFont.truetype(str(ASSET/'fonts/NotoSansSC-Regular.otf'),10)
    tile_size, label_width = 95, 84
    canvas = Image.new('RGB',(label_width+tile_size*10,4*92+48),'#141c23')
    draw = ImageDraw.Draw(canvas)
    labels = ('头盔','胸甲','护腿','鞋子')
    for i, kit in enumerate(data['sets']):
        x = label_width+tile_size*i
        draw.text((x+45,19),kit['name'],font=normal,fill='#e8dfca',anchor='mm')
        for row, item in enumerate(kit['items']):
            if not item['asset']:
                continue
            y = 38+92*row
            draw.rectangle((x+2,y,x+91,y+84),fill='#68727a')
            png = Image.open(BASE/item['asset']['file'])
            silhouette = Image.new('RGBA',png.size,(0,0,0,255))
            silhouette.putalpha(png.getchannel('A'))
            silhouette = silhouette.resize((64,64),Image.Resampling.NEAREST)
            canvas.paste(silhouette,(x+15,y+2),silhouette)
            draw.text((x+47,y+71),item['name'],font=tiny,fill='#ffffff',anchor='mm')
    for row, label in enumerate(labels):
        draw.text((12,76+92*row),label,font=normal,fill='#e8dfca')
    canvas.save(destination/'silhouettes.png',optimize=True)

    width = 84+10*80
    for title, bg in GROUNDS.items():
        region = Image.open(ASSET/bg).convert('RGB')
        picture = Image.new('RGB',(width,4*69+41),'#141c23')
        draw = ImageDraw.Draw(picture)
        for i, kit in enumerate(data['sets']):
            x = 84+i*80
            draw.text((x+38,18),kit['name'],font=tiny,fill='#f1e7d2',anchor='mm')
            for row,item in enumerate(kit['items']):
                if not item['asset']:
                    continue
                y = 34+69*row
                picture.paste(region.resize((64,64),Image.Resampling.NEAREST),(x+6,y))
                icon = Image.open(BASE/item['asset']['file'])
                picture.paste(icon,(x+22,y+16),icon)
        for row,label in enumerate(labels):
            draw.text((12,55+69*row),label,font=normal,fill='#e8dfca')
        name = {'雪地':'midgard','冥界':'helheim','焦土':'vigrid'}[title]
        picture.save(destination/f'{name}-1x.png',optimize=True)

    keys = ['thornoath','lotus']
    width = 595
    picture = Image.new('RGB',(width,270),'#202b33')
    draw = ImageDraw.Draw(picture)
    for y,key in enumerate(keys):
        kit = next(k for k in data['sets'] if k['id']==key)
        draw.text((13,13+y*135),kit['name'],font=normal,fill='#ecdfbc')
        for x, item in enumerate(kit['items']):
            if not item['asset']:
                continue
            icon = Image.open(BASE/item['asset']['file']).resize((96,96),Image.Resampling.NEAREST)
            picture.paste(icon,(13+x*108,35+y*135),icon)
        if kit['status']:
            icon = Image.open(BASE/kit['status']['file']).resize((36,36),Image.Resampling.NEAREST)
            picture.paste(icon,(484,62+y*135),icon)
    picture.save(destination/'style-pair.png',optimize=True)


def run(complete=False, check_baseline=False):
    data=collect()
    failures=[]
    metrics={}
    all_files={x['id']+'-'+x['kind']:x for x in data['files']}
    for file in data['files']:
        path=BASE/file['file']
        im=Image.open(path)
        kind=file['kind']
        w,h = file.get('frame_size', [32,32] if kind=='armor' else [12,12])
        frames=file['frames']
        msg=file['id']
        if im.size != (w*frames,h) or im.mode!='RGBA':
            failures.append(msg+' 尺寸 / 模式')
        if set(np.unique(np.asarray(im)[:,:,3])) != {0,255}:
            failures.append(msg+' alpha 非二值')
        pixels = np.asarray(im)
        colors = np.unique(pixels[pixels[:,:,3]>0,:3],axis=0)
        if len(colors)>48:
            failures.append(msg+' 超出 48 色')
        for i in range(frames):
            frame=im.crop((w*i,0,w*(i+1),h))
            bounds=frame.getchannel('A').getbbox()
            if not bounds:
                failures.append(msg+f' 空帧 {i}')
            elif kind=='armor' and (min(bounds[:2])<1 or max(bounds[2:])>31):
                failures.append(msg+' 未留 1 像素')
        if digest(path)!=file['sha256']:
            failures.append(msg+' 哈希变更')
        dest=ROOT/file['runtime']
        if complete and (not dest.exists() or digest(dest)!=file['sha256']):
            failures.append(msg+' 正式目录副本缺失或不同')
    for key in ['thornoath_burst','yellowwind_storm','yellowwind_storm_start','yellowwind_storm_end']:
        file=all_files.get(key+'-effects')
        if not file:
            continue
        frame_w, frame_h=file['frame_size']
        x,y=file['anchor']
        mask=np.asarray(Image.open(BASE/file['file']))[:,:,3]
        if key.startswith('yellowwind_storm'):
            core_rows = [int(np.count_nonzero(mask[58:85,i*frame_w:(i+1)*frame_w].sum(axis=0))) for i in range(file['frames'])]
            metrics[key]={'gameplay_radius':48,'art_has_ground_ring':False,
                          'foot_zone_width_by_frame':core_rows}
            if max(core_rows)>48:
                failures.append('风柱底部像素横跨判定区域，检查是否误留环形图案')
        else:
            yy,xx=np.nonzero(mask)
            reach=float(np.max(np.hypot(xx%frame_w-x,yy-y)))
            error=abs(reach-file['radius'])
            metrics[key]={'peak_reach':round(reach,3),'max_error_px':round(error,3)}
            if error>4:
                failures.append(key+' 外缘误差超过 4 像素')
    dragon=all_files.get('dragonslayer_scale-effects')
    if dragon:
        alpha=np.asarray(Image.open(BASE/dragon['file']))[:,:,3]
        top=int(np.flatnonzero(np.any(alpha!=0,axis=1))[0])
        metrics['dragonslayer_scale']={'first_opaque_y':top,'protected_head_rows':[0,28]}
        if top<29:
            failures.append('龙鳞闪光侵入头部预留区域')
    for action, actor in data['guardian'].items():
        w,h=actor['frame_size']
        alpha=np.asarray(Image.open(BASE/actor['file']))[:,:,3]
        if len(actor['hand'])!=actor['frames'] or len(actor['angles'])!=actor['frames']:
            failures.append('英灵挂点帧数不完整 '+action)
        for i,(x,y) in enumerate(actor['hand']):
            if not (0<=x<w and 0<=y<h and alpha[y,i*w+x]):
                failures.append('英灵主手挂点不在精灵内 '+action+str(i))
    counts = {k:len([x for x in data['files'] if x['kind']==k]) for k in DEST}
    concepts = len([s for s in data['sets'] if s['concept']])
    if complete and (counts != {'armor':40,'status':10,'effects':10,'actors':2} or concepts!=10):
        failures.append('交付数量不完整')
    result={'counts':counts,'concepts':concepts,'radius_checks':metrics,'failures':failures}
    original_records=json.loads((BASE/'records/revision-r1.json').read_text())
    changed_originals=[]
    for old in original_records:
        for path in (BASE/old['file'],ROOT/old['runtime']):
            if not path.exists() or digest(path)!=old['sha256']:
                changed_originals.append(path.relative_to(ROOT).as_posix())
    if changed_originals:
        failures.append('第一轮归档素材发生变化')
    result.update(revised_feedback=len(data['reviewNotes']),preserved_r1_files=len(original_records)*2,
                  changed_r1_files=changed_originals)
    if check_baseline:
        n,changed=verify_existing()
        result.update(existing_files=n,changed_assets=changed)
        if changed:
            failures.append('已有素材哈希发生变化')
    build_boards(data)
    (BASE/'records/qa.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return bool(failures)


if __name__=='__main__':
    cli=argparse.ArgumentParser()
    cli.add_argument('--complete',action='store_true')
    cli.add_argument('--baseline',action='store_true')
    args=cli.parse_args()
    raise SystemExit(run(args.complete,args.baseline))
