import html
import json
from pathlib import Path

from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'manifest.json').read_text())
cards = []
for item in manifest['assets']:
    passed = item['status'].startswith('self_check_passed')
    name = item['id']
    count = item['frame_count']
    path = item.get('approved_copy', item['candidate'])
    width, height = item['size']
    note = '美术自检通过；待游戏实测' if passed else ('不通过：局部脸、鞋、衣纹漂移。' if name.endswith('idle') else '不通过：后两帧躯干转向，循环回首帧时跳动。')
    originals = [item['source']] if isinstance(item['source'], str) else item['source']
    links = ' · '.join(f'<a href="{html.escape(p)}">原图 {index + 1}</a>' for index, p in enumerate(originals))
    if count > 1:
        version = item.get('preview_version', 'v02' if passed else 'v03')
        action = name.removeprefix('musashi_')
        native = ''.join(f'<figure><img width="64" height="64" src="candidates/musashi_{action}_frame_{index:02d}_{version}.png"><figcaption>{index + 1}</figcaption></figure>' for index in range(count))
        enlarged = ''.join(f'<figure><img width="256" height="256" src="candidates/musashi_{action}_frame_{index:02d}_{version}.png"><figcaption>{index + 1}</figcaption></figure>' for index in range(count))
        gif = f'<img width="256" height="256" src="previews/{name}_{version}.gif">'
        preview = f'<h3>1 倍逐帧</h3><div class="row native">{native}</div><h3>4 倍逐帧（横向滚动）</h3><div class="row">{enlarged}</div><h3>4 倍 GIF · 平均 8 fps</h3>{gif}'
    else:
        preview = f'<h3>1 倍</h3><img width="{width}" height="{height}" src="{path}"><details><summary>查看 4 倍</summary><div class="row"><img width="{width*4}" height="{height*4}" src="{path}"></div></details>'
    cards.append(f'<article class="{"pass" if passed else "fail"}"><h2>{name}</h2><p class="status">{html.escape(note)}</p><p>{width}×{height} · {count} 帧 · {item["colors"]} 色 · {links} · <a href="{path}">PNG</a> · <a href="{item["generation_url"]}">生成记录</a></p>{preview}</article>')

page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>第 1 批武藏 · 6 项通过 / 0 项退回</title><style>*{box-sizing:border-box}body{margin:0;padding:28px;background:#121721;color:#e4eaf3;font:15px/1.65 system-ui}h1{font-size:26px}h2{font-size:21px}h3{font-size:15px;color:#a8b8cd}p{max-width:1100px}a{color:#9dccff}article{margin:32px 0;padding:20px 0;border-top:1px solid #3c485f}.pass .status{color:#8dddaf}.fail .status{color:#ffc08d}img{image-rendering:pixelated;flex:none}.row{display:flex;align-items:start;gap:12px;overflow-x:auto;max-width:100%;padding-bottom:8px}figure{margin:0;flex:none}figcaption{color:#a8b8cd;font-size:12px;text-align:center}summary{cursor:pointer;color:#9dccff}details{margin-top:16px}</style><h1>第 1 批 · 宫本武藏</h1><p><strong>第 1 批：6 项美术自检通过，等待游戏内复核。第 2 批素材修复进行中；第 3 至第 6 批尚未开始。</strong></p><p>画面背景 #121721；本页标明的 1 倍与 4 倍均为实际 CSS 像素尺寸，不用缩小接触表代替。所有最终文件仍待代码代理在游戏内实测。受击、倒地为单次动作，预览 GIF 重复只为检查。</p><p><a href="manifest.json">manifest.json</a> · <a href="README.md">README</a> · <a href="../../LICENSES.md">授权台账</a></p><article><h2>1 倍风格与体量对照</h2><div class="row"><figure><img width="64" height="64" src="approved/musashi.png"><figcaption>武藏 · 人物高48px</figcaption></figure><figure><img width="64" height="64" src="../norse_pixel_2026-10-16/64/mobs/draugr.png"><figcaption>既有尸鬼</figcaption></figure><figure><img width="64" height="64" src="../norse_pixel_2026-10-16/64/mobs/wolf.png"><figcaption>既有冬狼</figcaption></figure></div></article>'''+''.join(cards)+'<article><h2>地块 4×4 平铺</h2><p>本批不含地块，不适用。地块将在第 4 批制作时逐张检查。</p></article></html>'
(root / 'gallery.html').write_text(page)
overview = Image.new('RGB', (1280, 860), '#121721')
draw = ImageDraw.Draw(overview)
draw.text((24, 16), 'Musashi batch 1: all 6 assets self-checked; in-game review pending', fill='white')
for x,y,name,frame_index in [(24,60,'musashi',0),(408,60,'musashi_idle',2),(792,60,'musashi_hurt',0),(24,470,'musashi_move',3),(408,470,'musashi_death',5)]:
    strip = Image.open(root / f'approved/{name}.png').convert('RGBA')
    frame = strip.crop((frame_index*64,0,(frame_index+1)*64,64))
    enlarged = frame.resize((256,256), Image.Resampling.NEAREST)
    overview.paste(enlarged,(x,y),enlarged)
    draw.text((x,y-22),name,fill='white')
    overview.paste(frame,(x+96,y+272),frame)
cutin = Image.open(root / 'approved/musashi_cutin.png').convert('RGBA')
overview.paste(cutin,(792,470),cutin)
draw.text((792,448),'musashi_cutin: 400x320',fill='white')
draw.text((24,838),'64x64 frames / binary alpha / shared 48-color palette / no game testing',fill='white')
overview.save(root / 'previews/approved_progress_overview.png')
