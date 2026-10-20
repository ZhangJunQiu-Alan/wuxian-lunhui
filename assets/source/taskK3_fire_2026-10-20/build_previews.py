from pathlib import Path
import json,math
from PIL import Image,ImageDraw

BASE=Path(__file__).resolve().parent
data=json.loads((BASE/'preview_project/captures/result.json').read_text())
board=Image.new('RGB',(1280,180*math.ceil(len(data['captures'])/4)),'#121721');draw=ImageDraw.Draw(board)
for k,r in enumerate(data['captures']):
    im=Image.open(BASE/'preview_project'/r['file']).convert('RGBA');im.thumbnail((320,180),Image.Resampling.NEAREST)
    board.paste(im,((k%4)*320,(k//4)*180),im);draw.text(((k%4)*320+4,(k//4)*180+4),Path(r['file']).stem,fill='white')
board.save(BASE/'previews/godot_all_cases.png')
for page in range(3):board.crop((0,page*1260,1280,min((page+1)*1260,board.height))).save(BASE/f'previews/godot_cases_page{page+1}.png')
audit=[]
for i in range(4):
    grid=Image.open(BASE/f'preview_project/captures/alpha_grid_{i:02d}.png').convert('RGBA')
    for x,y in data['safe_cells']:
        audit.append(dict(id=f'grid{i}:safe{x},{y}',passed=not grid.crop((64*x,64*y,64*(x+1),64*(y+1))).getchannel('A').getbbox()))
    gate=Image.open(BASE/f'preview_project/captures/alpha_gate_{i:02d}.png').convert('RGBA')
    audit.append(dict(id=f'gate{i}:48x70clear',passed=not gate.crop((40,46,88,116)).getchannel('A').getbbox()))
    wall=Image.open(BASE/f'preview_project/captures/alpha_wall_{i:02d}.png').convert('RGBA');a=wall.getchannel('A')
    count=sum(a.getpixel((x,y))>0 for y in range(112,589) for x in range(112,589) if (x-350)**2+(y-350)**2<238**2)
    audit.append(dict(id=f'wall{i}:insideR238clear',passed=count==0,occupied=count))
    arc=Image.open(BASE/f'preview_project/captures/alpha_arc_{i:02d}.png').convert('RGBA');a=arc.getchannel('A')
    count=sum(a.getpixel((x,y))>0 for y in range(119,182) for x in range(119,182) if (x-150)**2+(y-150)**2<31**2)
    audit.append(dict(id=f'arc{i}:centerR31clear',passed=count==0,occupied=count))
(BASE/'records/render_geometry_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
for mode,ids,rate,crop in [('grid',range(4),16,(60,180,636,564)),('wall_r150',range(4),8,(165,165,535,535)),('gate',range(4),8,(140,260,280,435)),('freyr_heal',range(4),16,(150,320,370,485))]:
    fs=[Image.open(BASE/f'preview_project/captures/{mode}_{i:02d}.png').convert('RGB').crop(crop) for i in ids]
    for kind,fps in [('native',rate),('slow8',8)]:
        ms=[round((i+1)*100/fps)*10-round(i*100/fps)*10 for i in range(4)]
        fs[0].save(BASE/f'previews/fixture_{mode}_{kind}.gif',save_all=True,append_images=fs[1:],duration=ms,loop=0,optimize=False)
print(json.dumps({'render_checks':len(audit),'failures':[r for r in audit if not r['passed']]}))
