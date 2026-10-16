from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from collections import Counter
import json,hashlib,shutil,argparse
ROOT=Path(__file__).resolve().parent.parent
ASSETS=ROOT.parents[1]
BG=(18,23,33)
def plan():return {a['id']:a for a in json.loads((ROOT/'records/production_plan.json').read_text())['assets']}
def views(a,version):
 w,h,n=a['w'],a['h'],a['frames'];stem=f"{a['id']}_{version}";p=ROOT/'candidates'/f'{stem}.png';im=Image.open(p).convert('RGBA');frames=[im.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
 out=Image.new('RGB',(max(640,w*n*4),h*5+64),BG);d=ImageDraw.Draw(out);d.text((4,4),f'{stem}: {w}x{h} x{n} | native1x and nearest4x',fill='white');gifs=[]
 for i,f in enumerate(frames):
  c=Image.new('RGB',(w,h),BG);c.paste(f,mask=f.getchannel('A'));out.paste(c,(i*w,24));c4=c.resize((w*4,h*4),Image.Resampling.NEAREST);out.paste(c4,(i*w*4,h+40));gifs.append(c4)
 out.save(ROOT/'previews'/f'{stem}_review.png')
 if n>1:
  sequence=gifs*(2 if n%2 else 1);sequence[0].save(ROOT/'previews'/f'{stem}.gif',save_all=True,append_images=sequence[1:],duration=[120 if i%2==0 else 130 for i in range(len(sequence))],loop=0,disposal=2,optimize=False)
 info={'id':a['id'],'version':version,'size':im.size,'colors':len(set(p[:3] for p in im.getdata() if p[3])),'alpha':sorted(set(im.getchannel('A').getdata())),'frame_boxes':[f.getbbox() for f in frames],'unique_frames':len(set(f.tobytes() for f in frames)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
 (ROOT/'records'/f'check_{stem}.json').write_text(json.dumps(info,indent=2));return info
def normalize(id,version='v01',source=None):
 a=plan()[id];w,h,n=a['w'],a['h'],a['frames'];stem=f'{id}_{version}';source=Path(source) if source else ROOT/'originals'/f'{stem}_raw.png';im=Image.open(source).convert('RGBA');im.putalpha(im.getchannel('A').point(lambda v:255 if v>=128 else 0))
 cols,rows=((1,1) if n==1 else (3,2) if n==6 else (2,2) if n==4 else(3,1));cw,ch=im.width//cols,im.height//rows
 if id=='poison_pool':cols,rows=2,2;cw,ch=im.width//2,im.height//2
 frames=[im.crop((i%cols*cw,i//cols*ch,(i%cols+1)*cw,(i//cols+1)*ch)) for i in range(n)];boxes=[f.getbbox() for f in frames]
 if any(b is None for b in boxes):raise ValueError('Empty grid cell; inspect original layout')
 if id=='mist_wraith' and n==1 and version=='v02':
  b=boxes[0];boxes[0]=(b[0],b[1],b[0]+635,b[1]+1065)
 unit=a.get('unit');versions=json.loads((ROOT/'records/static_versions.json').read_text()) if (ROOT/'records/static_versions.json').exists() else{};sv=versions.get(unit,'v01');static=ROOT/'candidates'/f'{unit}_{sv}.png' if unit else None
 static_report=ROOT/'records'/f'check_{unit}_v01.json' if unit else None
 target_h=a.get('body_h',h-4) if n==1 else h-4
 if n>1 and static and static.exists():target_h=Image.open(static).getbbox()[3]-Image.open(static).getbbox()[1]
 reference_index=n-1 if a.get('action')=='emerge' else 0
 reference_h=boxes[reference_index][3]-boxes[reference_index][1]
 max_w=max(b[2]-b[0] for b in boxes);max_h=max(b[3]-b[1] for b in boxes)
 scale=min(target_h/reference_h,(w-4)/max_w,(h-4)/max_h)
 normalized=[];placements=[]
 for f,b in zip(frames,boxes):
  cut=f.crop(b);sw=max(1,round(cut.width*scale));sh=max(1,round(cut.height*scale));cut=cut.resize((sw,sh),Image.Resampling.NEAREST)
  x=(w-sw)//2;y=h-2-sh if a['anchor'] in ('bottom','float') else(h-sh)//2;out=Image.new('RGBA',(w,h));out.paste(cut,(x,y))
  if a['anchor'] in ('bottom','float') and out.getbbox()[3]!=h-2:
   dy=h-2-out.getbbox()[3];shifted=Image.new('RGBA',(w,h));shifted.paste(out,(0,dy));out=shifted;y+=dy
  normalized.append(out);placements.append([x,y,sw,sh])
 palette_ref=static if n>1 and static and static.exists() else None
 if palette_ref:
  pixels=list(dict.fromkeys(p[:3] for p in Image.open(palette_ref).convert('RGBA').getdata() if p[3]));pal=Image.new('P',(1,1));flat=[v for p in pixels for v in p];pal.putpalette(flat+list(pixels[0])*(256-len(pixels)))
 else:
  colors=Counter(p[:3] for f in normalized for p in f.getdata() if p[3]);pix=list(colors.elements());sample=Image.new('RGB',(len(pix),1));sample.putdata(pix);pal=sample.quantize(colors=min(48,len(colors)),method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
  if id=='mist_wraith':
   protected=sorted([c for c in colors if c[1]>130 and c[1]>c[0]*1.4 and c[1]>c[2]*1.12],key=lambda c:c[1],reverse=True)[:3]
   if protected:
    flat=pal.getpalette()[:(48-len(protected))*3]+[v for c in protected for v in c];pal.putpalette(flat+[0]*(768-len(flat)))
 sheet=Image.new('RGBA',(w*n,h))
 for i,f in enumerate(normalized):
  q=f.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(f.getchannel('A'));q.putdata([p if p[3] else(0,0,0,0) for p in q.getdata()]);sheet.paste(q,(i*w,0))
 path=ROOT/'candidates'/f'{stem}.png';sheet.save(path)
 info=views(a,version);record={'source':str(source),'raw_size':im.size,'grid':[cols,rows],'crop_boxes':boxes,'common_scale':scale,'target_body_height':target_h,'first_pose_reference_index':reference_index,'placements':placements,'palette_reference':str(palette_ref) if palette_ref else'48 colors extracted from generated/static source','note':'One shared scale across all frames; whole-cell crop and placement only, no character drawing.'}
 (ROOT/'records'/f'normalization_{stem}.json').write_text(json.dumps(record,indent=2));return info
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('ids',nargs='+');p.add_argument('--version',default='v01');args=p.parse_args()
 for id in args.ids:
  try:print(json.dumps(normalize(id,args.version)))
  except Exception as e:print(json.dumps({'id':id,'error':str(e)}))
