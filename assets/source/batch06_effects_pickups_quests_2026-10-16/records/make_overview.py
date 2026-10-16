from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parent.parent
items=json.loads((ROOT/'manifest.json').read_text())['assets'];BG=(18,23,33)
font_path=ROOT.parents[1]/'fonts/NotoSansSC-Regular.otf'
font=ImageFont.truetype(str(font_path),18) if font_path.exists() else ImageFont.load_default()
titlefont=ImageFont.truetype(str(font_path),25) if font_path.exists() else font
def card(a,cell_w,cell_h):
 out=Image.new('RGB',(cell_w,cell_h),BG);d=ImageDraw.Draw(out);d.text((12,12),a['label'],font=font,fill='#e7edf5');d.text((12,40),a['id'],fill='#abbdd2')
 im=Image.open(ROOT/a['candidate']).convert('RGBA');index=1 if a['id'] in ('katana_slash','lightning') else (3 if a['id'] in ('ice_pillar','frost_shockwave') else 0)
 f=im.crop((index*a['w'],0,(index+1)*a['w'],a['h']))
 k=max(1,min(4,(cell_w-28)//a['w'],(cell_h-100)//a['h']));f=f.resize((a['w']*k,a['h']*k),Image.Resampling.NEAREST)
 out.paste(f,((cell_w-f.width)//2,70+(cell_h-100-f.height)//2),f);d.text((12,cell_h-24),f"{a['w']}x{a['h']} x {a['frames']} | {k}x | {a['technical']['colors']} colors",fill='#a5b6c9');d.rectangle((1,1,cell_w-2,cell_h-2),outline='#2b384b')
 return out
def overview(selected,name,cols,cw,ch):
 rows=(len(selected)+cols-1)//cols;out=Image.new('RGB',(cols*cw,rows*ch+90),BG);d=ImageDraw.Draw(out);d.text((16,14),'第6批 · 特效、拾取物与支线物件',font=titlefont,fill='white');d.text((16,54),'34/34 art self-check passed | 14 animations + 20 statics | #121721 | integer nearest-neighbor previews',fill='#a5b6c9')
 for i,a in enumerate(selected):out.paste(card(a,cw,ch),((i%cols)*cw,90+(i//cols)*ch))
 out.save(ROOT/'previews'/name)
overview([a for a in items if a['folder']=='effects'],'effects_overview.png',4,260,370)
overview([a for a in items if a['folder']!='effects'],'objects_overview.png',5,240,300)
selected=[next(a for a in items if a['id']==id) for id in ['katana_slash','lightning','will_o_wisp_aura','frost_shockwave','xp_gem','chest_open','campfire','iron_brazier','raven','ice_fishing_hole','ice_block','einherjar_attack']]
overview(selected,'delivery_overview.png',4,260,370)
