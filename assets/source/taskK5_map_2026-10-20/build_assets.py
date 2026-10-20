from pathlib import Path
import json,hashlib,shutil
from PIL import Image,ImageDraw

BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=[]
for path in sorted((ROOT/'assets/sprites/ground/vigrid').glob('*.png')):
    im=Image.open(path).convert('RGBA');tile=Image.new('RGBA',(256,256))
    for y in range(4):
        for x in range(4):tile.paste(im,(x*64,y*64))
    tile.save(BASE/f'previews/{path.stem}_4x4_1x.png');tile.resize((768,768),Image.Resampling.NEAREST).save(BASE/f'previews/{path.stem}_4x4_3x.png')
    rgb=im.convert('RGB');inside=[]
    for y in range(64):
        for x in range(63):inside.append(sum(abs(rgb.getpixel((x,y))[k]-rgb.getpixel((x+1,y))[k]) for k in range(3))/3)
    seam=sum(sum(abs(rgb.getpixel((0,y))[k]-rgb.getpixel((63,y))[k]) for k in range(3))/3 for y in range(64))/64
    tile.resize((1024,1024),Image.Resampling.NEAREST).save(BASE/f'previews/{path.stem}_4x4_4x.png')
    rows.append(dict(path=str(path.relative_to(ROOT)),sha256=sha(path),size=im.size,rgb_count=len(set(rgb.get_flattened_data())),opaque=im.getchannel('A').getextrema()==(255,255),horizontal_seam_mean_absRGB=seam,interior_neighbor_mean_absRGB=sum(inside)/len(inside),scope='reuse tile sampling evidence, not proof of all crossvariant edges seamless'))
grass=Image.open(ROOT/'assets/sprites/ground/vigrid/burnt_grass.png').convert('RGBA');ground=Image.open(ROOT/'assets/sprites/ground/vigrid/scorched_01.png').convert('RGBA')
rules={12:['n'],5:['e'],3:['s'],10:['w'],4:['outer_ne'],8:['outer_nw'],1:['outer_se'],2:['outer_sw'],13:['inner_ne'],14:['inner_nw'],7:['inner_se'],11:['inner_sw'],9:['outer_se','outer_nw'],6:['outer_sw','outer_ne']}
mask_checks=[];patch=Image.new('RGBA',(256,256))
for code in range(16):
    f=ground.copy();mask=Image.new('L',(64,64),255 if code==15 else 0)
    for part in rules.get(code,[]):
        shape=Image.open(ROOT/f'assets/sprites/ground/midgard/path_edge_{part}.png').convert('RGBA').getchannel('A')
        from PIL import ImageChops
        mask=ImageChops.lighter(mask,shape)
        tile=grass.copy();tile.putalpha(shape);tile.save(BASE/f'references/runtime_derived_grass_edge_{part}.png')
    fill=grass.copy();fill.putalpha(mask);f.alpha_composite(fill);patch.paste(f,(code%4*64,code//4*64))
    actual=sum((1<<i) for i,q in enumerate([(4,4),(59,4),(4,59),(59,59)]) if mask.getpixel(q)>0)
    mask_checks.append(dict(code=code,actual_corner_bits=actual,passed=actual==code))
patch.save(BASE/'previews/transition_16cases_1x.png');patch.resize((1024,1024),Image.Resampling.NEAREST).save(BASE/'previews/transition_16cases_4x.png')
captures=json.loads((BASE/'preview_project/captures/distant_result.json').read_text());frames=[]
for i,r in enumerate(captures):
    src=BASE/'preview_project'/r['file'];shutil.copyfile(src,BASE/f'originals/distant_composite_{i:02d}_godot.png');frames.append(Image.open(src).convert('RGBA'))
pixels=[p[:3] for f in frames for p in f.get_flattened_data() if p[3]>=16];pool=Image.new('RGB',(len(pixels),1));pool.putdata(pixels);pal=sorted(set(pool.quantize(colors=24,method=Image.Quantize.MEDIANCUT).convert('RGB').get_flattened_data()));cache={};clean=[]
for f in frames:
    data=[]
    for r,g,b,a in f.get_flattened_data():
        a=round(a/255*7)*255//7
        if not a:data.append((0,0,0,0));continue
        rgb=(r,g,b)
        if rgb not in cache:cache[rgb]=min(pal,key=lambda c:sum((c[k]-rgb[k])**2 for k in range(3)))
        data.append(cache[rgb]+(a,))
    f.putdata(data);clean.append(f)
strip=Image.new('RGBA',(2048,128))
for i,f in enumerate(clean):strip.paste(f,(512*i,0))
strip.save(BASE/'candidates/distant_battle_composite_v01.png')
views=[]
for f in clean:
    bg=Image.new('RGBA',(512,128));
    for y in range(2):
        for x in range(8):bg.paste(ground,(64*x,64*y))
    bg.alpha_composite(f);views.append(bg.convert('RGB'))
for kind in ['native','slow8']:views[0].save(BASE/f'previews/distant_battle_composite_v01_{kind}.gif',save_all=True,append_images=views[1:],duration=[120,130,120,130],loop=0,optimize=False)
board=Image.new('RGB',(512,512),'#121721')
for i,f in enumerate(views):board.paste(f,(0,128*i))
board.save(BASE/'previews/distant_battle_1x.png');board.resize((2048,2048),Image.Resampling.NEAREST).save(BASE/'previews/distant_battle_4x.png')
stamp=Image.open(BASE/'candidates/giant_tread_v01.png').convert('RGBA');stamp.save(BASE/'previews/giant_tread_1x.png');stamp.resize((256,256),Image.Resampling.NEAREST).save(BASE/'previews/giant_tread_4x.png');patch=ground.copy();patch.alpha_composite(stamp);patch.resize((512,512),Image.Resampling.NEAREST).save(BASE/'previews/giant_tread_context8x.png')
board=Image.new('RGBA',(1280,768))
for y in range(12):
    for x in range(20):board.paste(ground,(x*64,y*64))
for x in [64,448,832]:board.alpha_composite(clean[2],(x,0))
for name,pos in [('bifrost_fragment',(120,220)),('giant_remains',(370,245)),('burning_wreckage',(655,210)),('fallen_shield',(850,250)),('broken_weapons',(1080,230))]:
    f=Image.open(ROOT/f'assets/sprites/props/vigrid/{name}.png').convert('RGBA');board.alpha_composite(f,pos)
for pos in [(200,430),(400,500),(700,450)]:board.alpha_composite(stamp,pos)
player=Image.open(ROOT/'assets/sprites/characters/swordsman.png').convert('RGBA');board.alpha_composite(player,(600,480));board.save(BASE/'previews/map_context_1x.png')
(BASE/'records/terrain_audit.json').write_text(json.dumps({'tiles':rows,'mask16cases':mask_checks,'distant_palette':pal,'distant_alpha':'8levels','scope':'asset/geometry previews; no playable map'},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'tiles':len(rows),'mask_cases':len(mask_checks),'failures':[r for r in mask_checks if not r['passed']]}))
