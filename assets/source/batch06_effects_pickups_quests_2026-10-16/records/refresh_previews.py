from pathlib import Path
from PIL import Image, ImageDraw
import json,hashlib,sys
ROOT=Path(__file__).resolve().parent.parent
PLAN={a['id']:a for a in json.loads((ROOT/'records/production_plan.json').read_text())['assets']}
BG=(18,23,33)
def refresh(asset_id,version):
 a=PLAN[asset_id];w,h,n=a['w'],a['h'],a['frames'];stem=f'{asset_id}_{version}';path=ROOT/'candidates'/f'{stem}.png';im=Image.open(path).convert('RGBA')
 frames=[im.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
 out=Image.new('RGB',(max(640,w*n*4),h*5+64),BG);d=ImageDraw.Draw(out);d.text((4,4),f'{stem}: {w}x{h} x{n} | 1x and4x',fill='white');gif=[]
 for i,f in enumerate(frames):
  c=Image.new('RGB',(w,h),BG);c.paste(f,mask=f.getchannel('A'));out.paste(c,(i*w,24));c4=c.resize((w*4,h*4),Image.Resampling.NEAREST);out.paste(c4,(i*w*4,h+40));gif.append(c4)
 out.save(ROOT/'previews'/f'{stem}_review.png')
 if n>1:gif[0].save(ROOT/'previews'/f'{stem}.gif',save_all=True,append_images=gif[1:],duration=[120,130,120,130],loop=0,disposal=2,optimize=False)
 reportfile=ROOT/'records'/f'normalization_{stem}.json';report=json.loads(reportfile.read_text()) if reportfile.exists() else {'id':asset_id,'version':version}
 report.update({'size':im.size,'colors':len(set(p[:3] for p in im.getdata() if p[3])),'alpha':sorted(set(im.getchannel('A').getdata())),'frame_boxes':[f.getbbox() for f in frames],'unique_frames':len(set(f.tobytes() for f in frames)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 reportfile.write_text(json.dumps(report,indent=2));return report
if __name__=='__main__':print(json.dumps(refresh(sys.argv[1],sys.argv[2])))
