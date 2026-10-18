from pathlib import Path
from PIL import Image, ImageDraw
import json, hashlib, shutil, sys

ROOT = Path(__file__).resolve().parents[4]
SPECS = {
    'bridge_guard': ('I1', 'bridge_guard', 64, 64, 1, 'feet'),
    'bridge_guard_idle': ('I1', 'bridge_guard', 64, 64, 4, 'feet'),
    'bonfire_survivors': ('I2', 'bonfire_survivors', 128, 64, 1, 'feet'),
    'valkyrie_wings': ('I3', 'valkyrie_wings', 64, 32, 4, 'center'),
    'iron_horseshoe': ('I4', 'iron_horseshoe', 16, 16, 1, 'feet'),
    'river_sword': ('I5', 'river_sword', 32, 64, 4, 'feet'),
    'sun_altar': ('I6', 'sun_altar', 96, 96, 1, 'feet'),
}
BG = (18, 23, 33, 255)

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def directory(name):
    task, folder, *_ = SPECS[name]
    return ROOT / 'assets/source' / f'task{task}_{folder}_2026-10-19'

def record(name, source, prompt, refs, version='v01'):
    d = directory(name)
    dst = d / 'originals' / f'{name}_{version}.png'
    shutil.copy2(source, dst)
    inputs = []
    for p in map(Path, refs):
        archived = d / 'references' / p.name
        if archived.exists() and sha(archived) != sha(p):
            archived = archived.with_name(p.stem + '_' + sha(p)[:8] + p.suffix)
        shutil.copy2(p, archived)
        inputs.append({'input': str(p), 'archive': str(archived.relative_to(d)), 'sha256': sha(p)})
    job = {'tool': 'OpenAI built-in image_gen', 'prompt': prompt, 'references': inputs,
           'original': str(dst.relative_to(d)), 'sha256': sha(dst), 'source_path': str(source),
           'commercial_basis': 'https://openai.com/policies/terms-of-use/', 'status': 'candidate'}
    (d / 'records' / f'generation_{name}_{version}.json').write_text(json.dumps(job, ensure_ascii=False, indent=2))

def normalize(name, version='v01'):
    task, folder, w, h, n, anchor = SPECS[name]
    d = directory(name)
    raw = Image.open(d / 'originals' / f'{name}_{version}.png').convert('RGBA')
    raw.putalpha(raw.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
    parts = [raw.crop((round(i * raw.width / n), 0, round((i + 1) * raw.width / n), raw.height)) for i in range(n)]
    if name == 'bonfire_survivors':
        parts = [raw.crop((0,0,raw.width//2,raw.height)),raw.crop((raw.width//2,0,raw.width,raw.height))]
    boxes = [f.getbbox() for f in parts]
    assert all(boxes), boxes
    crops = [f.crop(b) for f,b in zip(parts, boxes)]
    maxw, maxh = max(f.width for f in crops), max(f.height for f in crops)
    scale = min((35 if name == 'bonfire_survivors' else w - 4) / maxw, (h - 4) / maxh)
    sample = Image.new('RGB', (sum(f.width for f in crops), maxh))
    x = 0
    for f in crops:
        sample.paste(f.convert('RGB'), (x, 0)); x += f.width
    palette = sample.quantize(48, dither=Image.Dither.NONE)
    if name == 'bridge_guard_idle':
        palette = Image.open(directory('bridge_guard') / 'candidates/bridge_guard_v01.png').convert('RGB').quantize(48, dither=Image.Dither.NONE)
    out = Image.new('RGBA', (w*n, h))
    placements = []
    for i, f in enumerate(crops):
        size = (max(1, round(f.width*scale)), max(1, round(f.height*scale)))
        f = f.resize(size, Image.Resampling.NEAREST)
        alpha = f.getchannel('A')
        f = f.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE).convert('RGBA')
        f.putalpha(alpha)
        pos = ((w-size[0])//2, h-2-size[1] if anchor=='feet' else (h-size[1])//2)
        if name == 'river_sword':
            blade = f.getchannel('A').crop((0,0,f.width,12)).getbbox()
            pos = (w//2-(blade[0]+blade[2])//2, pos[1])
        if name == 'bonfire_survivors':
            pos = (2 if i==0 else 91, h-2-size[1])
        out.paste(f, ((0 if name == 'bonfire_survivors' else i*w)+pos[0], pos[1]))
        placements.append({'crop': boxes[i], 'size': size, 'position': pos})
    dst = d / 'candidates' / f'{name}_{version}.png'
    out.save(dst)
    bg = Image.new('RGBA', out.size, BG); bg.alpha_composite(out)
    bg.resize((out.width*4, out.height*4), Image.Resampling.NEAREST).save(d/'previews'/f'{name}_{version}_4x.png')
    bg.save(d/'previews'/f'{name}_{version}_1x.png')
    frames = [bg.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
    if n>1:
        for mul in [1,4]:
            fs=[f.resize((w*mul,h*mul),Image.Resampling.NEAREST).convert('RGB') for f in frames]
            fs[0].save(d/'previews'/f'{name}_{version}_{mul}x.gif',save_all=True,append_images=fs[1:],duration=[120,130,120,130],loop=0,disposal=2)
    colors = {p[:3] for p in out.getdata() if p[3]}
    audit = {'source_size': raw.size, 'output_size': out.size, 'placements': placements,
             'scale': scale, 'rgb_count': len(colors), 'alpha_values': sorted(set(out.getchannel('A').getdata())),
             'unique_frames': len({out.crop((i*w,0,(i+1)*w,h)).tobytes() for i in range(n)}),
             'sha256': sha(dst), 'operations': ['alpha threshold 128','equal-width frame crop','common nearest-neighbor scale','48-color source palette','whole-frame bottom/center placement'],
             'status': 'awaiting visual review'}
    (d/'records'/f'normalization_{name}_{version}.json').write_text(json.dumps(audit,indent=2))
    print(json.dumps(audit))

if __name__ == '__main__':
    normalize(*sys.argv[1:])
