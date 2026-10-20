from pathlib import Path
import json
from PIL import Image,ImageDraw

BASE=Path(__file__).resolve().parent
for name in ['fenrir_maw_upper','fenrir_maw_lower']:
    im=Image.open(BASE/f'candidates/{name}_v01.png').convert('RGBA')
    im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST).save(BASE/f'previews/{name}_v01_4x.png')
    for i in range(4):
        f=im.crop((i*256,0,(i+1)*256,128));bg=Image.new('RGB',f.size,'#121721');bg.paste(f,(0,0),f)
        bg.resize((1024,512),Image.Resampling.NEAREST).save(BASE/f'previews/qa4x_{name}_{i:02d}.png')
    (BASE/f'previews/{name}_v01_slow8.gif').write_bytes((BASE/f'previews/{name}_v01_native.gif').read_bytes())
data=json.loads((BASE/'preview_project/captures/result.json').read_text());audit=[]
for mode,rect in [('maw',(96,144,208,208)),('binding',(56,54,136,138))]:
    for i in range(4):
        im=Image.open(BASE/f'preview_project/captures/alpha_{mode}_{i:02d}.png').convert('RGBA')
        occupied=sum(a>0 for a in im.crop(rect).getchannel('A').get_flattened_data())
        coverage=sum(im.crop((0,0,192,192)).getchannel('A').get_flattened_data())/(255*192*192) if mode=='binding' else None
        audit.append(dict(mode=mode,frame=i,protected_occupied=occupied,alpha_weighted_coverage=coverage))
(BASE/'records/render_geometry_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
board=Image.new('RGB',(1280,180*13),'#121721');draw=ImageDraw.Draw(board)
for k,r in enumerate(data['captures']):
    im=Image.open(BASE/'preview_project'/r['file']).convert('RGBA');im.thumbnail((320,180),Image.Resampling.NEAREST)
    board.paste(im,((k%4)*320,(k//4)*180),im);draw.text(((k%4)*320+4,(k//4)*180+4),Path(r['file']).stem,fill='white')
board.save(BASE/'previews/godot_all_cases.png')
for mode,ids,crop in [('binding',range(4),(150,230,342,422)),('contact',range(2,5),(130,155,430,440)),('maw',range(4),(125,100,425,450))]:
    fs=[Image.open(BASE/f'preview_project/captures/{mode}_{i:02d}.png').convert('RGB').crop(crop).resize(((crop[2]-crop[0])*2,(crop[3]-crop[1])*2),Image.Resampling.NEAREST) for i in ids]
    for kind,ms in [('native',[120,130,120,130] if mode!='contact' else [60,60,660]),('slow8',[120,130,120,130] if mode!='contact' else [120,130,720])]:
        fs[0].save(BASE/f'previews/fixture_{mode}_{kind}.gif',save_all=True,append_images=fs[1:],duration=ms,loop=0,optimize=False)
link=Image.open(BASE/'candidates/fenrir_bind_link_v01.png').convert('RGBA');tile=Image.new('RGBA',(64,32))
for y in range(4):
    for x in range(4):tile.paste(link,(x*16,y*8))
tile.resize((512,256),Image.Resampling.NEAREST).save(BASE/'previews/bind_material_repeat_4x4.png')
print(json.dumps(audit))
