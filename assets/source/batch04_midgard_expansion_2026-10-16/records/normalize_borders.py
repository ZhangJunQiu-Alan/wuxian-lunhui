from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
import json,math
R=Path(__file__).resolve().parents[1];pal=json.loads((R/'references/existing_midgard_palette48.json').read_text());pim=Image.new('P',(1,1));flat=[v for c in pal for v in c];pim.putpalette(flat+flat[:3]*(256-len(pal)))
def norm(im,size):
 im=im.convert('RGBA').resize(size,Image.Resampling.NEAREST);a=im.getchannel('A').point(lambda x:255 if x>=128 else 0);im=im.convert('RGB').quantize(palette=pim,dither=Image.Dither.NONE).convert('RGBA');im.putalpha(a);return im
src=Image.open(R/'originals/borders_straight_v01_raw.png').convert('RGBA');w,h=src.size
recs=[]
# Keep pixel scale consistent with192px depth; search full-depth crop ports rather than handpainting edges.
for name,box,axis in [('cliff_ice',(0,30,w,255),'x'),('frozen_sea',(0,294,w,518),'y')]:
 strip=src.crop(box);sw=round(strip.width/strip.height*192);sw=round(sw/64)*64;im=norm(strip,(sw,192))
 if axis=='y':im=im.transpose(Image.Transpose.ROTATE_270)
 # Select a 256px section with smallest edge discontinuity, independently for two source halves.
 for k in range(2):
  length=im.width if axis=='x' else im.height;best=None
  for start in range(k*(length-256)//2,(k+1)*(length-256)//2+1):
   b=(start,0,start+256,192) if axis=='x' else (0,start,192,start+256);tile=im.crop(b);p=tile.load()
   cost=sum(abs(p[0,y][c]-p[255,y][c]) for y in range(192) for c in range(3)) if axis=='x' else sum(abs(p[x,0][c]-p[x,255][c]) for x in range(192) for c in range(3))
   if best is None or cost<best[0]:best=(cost,start,tile)
  cost,start,out=best;fn=f'{name}_{k+1:02d}';out.save(R/f'candidates/{fn}_v01.png');recs.append({'id':fn,'source':'originals/borders_straight_v01_raw.png','strip_crop':list(box),'normalized_strip_size':list(im.size),'subsection_start':start,'repeat_axis':axis,'size':list(out.size),'seam_mean':round(cost/(192*3),3),'status':'candidate_pending_seam_review'})
for name,file,size,axis in [('dead_forest','border_west_v02_raw.png',(192,256),'y'),('rock_wall','border_south_v02_raw.png',(512,192),'x')]:
 im=norm(Image.open(R/'originals'/file),size)
 for k in range(2):
  out=im if k==0 else ImageChops.offset(im,0,128) if axis=='y' else ImageChops.offset(im,256,0)
  fn=f'{name}_{k+1:02d}';out.save(R/f'candidates/{fn}_v01.png');recs.append({'id':fn,'source':'originals/'+file,'repeat_axis':axis,'size':list(out.size),'cyclic_offset':0 if k==0 else 128 if axis=='y' else 256,'variant_note':'second is cyclic phase variant, not separately generated','status':'candidate_pending_seam_review'})
raw=Image.open(R/'originals/borders_corners_v01_raw.png');w,h=raw.size
for name,box in [('nw',(40,20,615,575)),('ne',(670,25,1250,575)),('sw',(38,635,615,1183)),('se',(675,635,1252,1183))]:
 out=norm(raw.crop(box),(192,192));fn='border_corner_'+name;out.save(R/f'candidates/{fn}_v01.png');recs.append({'id':fn,'source':'originals/borders_corners_v01_raw.png','crop':list(box),'size':[192,192],'status':'candidate_pending_corner_join_review'})
for a in recs:
 im=Image.open(R/f"candidates/{a['id']}_v01.png");axis=a.get('repeat_axis');tiled=Image.new('RGBA',(im.width*3 if axis=='x' else im.width,im.height*3 if axis=='y' else im.height),'#121721')
 for i in range(3 if axis else 1):tiled.alpha_composite(im,(i*im.width if axis=='x' else 0,i*im.height if axis=='y' else 0))
 tiled.save(R/f"previews/{a['id']}_repeat_v01.png")
contact=Image.new('RGBA',(1280,1120),'#121721');d=ImageDraw.Draw(contact)
for i,a in enumerate(recs):
 im=Image.open(R/f"candidates/{a['id']}_v01.png");x=i%4*320;y=i//4*370;d.text((x+8,y+6),a['id'],fill='white');contact.alpha_composite(im,(x+8,y+30))
contact.convert('RGB').save(R/'previews/borders_contact_v01.png');(R/'records/borders_normalization_v01.json').write_text(json.dumps(recs,indent=2));print('12 border candidates, pending seam and joins. No final files published.')
