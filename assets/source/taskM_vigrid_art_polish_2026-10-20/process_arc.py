from pathlib import Path
import json,math,hashlib
import numpy as np
from PIL import Image,ImageDraw
B=Path(__file__).resolve().parent
frames=[];records=[];ladder=np.array([0,24,48,72,120,168,216,255]);yy,xx=np.indices((640,640));radius=np.hypot(xx-320,yy-320);angle=np.arctan2(yy-320,xx-320);valid=(radius<=290)&(abs(angle)<=1.05)
for i,gain in enumerate([.60,1,.65,.28]):
 p=B/f'originals/surtr_sword_arc_large_f0{i}_v01_raw.png';raw=Image.open(p).convert('RGBA');small=np.asarray(raw.resize((640,640),Image.Resampling.NEAREST));mask=(small[:,:,0]>200)&(small[:,:,1]>140)&(small[:,:,2]>65)&(small[:,:,3]>100)&(xx>350);x=xx[mask];y=yy[mask];v=np.linalg.lstsq(np.c_[2*x,2*y,np.ones(len(x))],x*x+y*y,rcond=None)[0];r=np.sqrt(v[2]+v[0]**2+v[1]**2);factor=raw.width/640;cx,cy=v[:2]*factor;scale=286/(r*factor);matrix=(1/scale,0,cx-320/scale,0,1/scale,cy-320/scale);im=raw.transform((640,640),Image.Transform.AFFINE,matrix,Image.Resampling.NEAREST);a=np.asarray(im).copy();alpha=a[:,:,3].astype(float)*gain;alpha[~valid]=0;alpha=ladder[np.argmin(abs(alpha[:,:,None]-ladder),axis=2)];
 if i==3:alpha=np.minimum(alpha,72)
 a[:,:,3]=alpha;a[alpha==0,:3]=0;im=Image.fromarray(a);frames.append(im);records.append(dict(frame=i,source=str(p.relative_to(B)),source_size=raw.size,fit_center_on640=v[:2].tolist(),fit_radius_on640=float(r),fit_core_pixels=len(x),uniform_source_scale=float(scale),target_core_radius=286,geometric_clip_radius=290,half_angle=1.05,alpha_gain=gain,method='rigid center registration and uniform nearest transform from full raw; sector alpha clipping only; no new painted pixels'))
opaque=np.concatenate([np.asarray(f)[:,:,:3][np.asarray(f)[:,:,3]>0] for f in frames]);pool=Image.fromarray(opaque.reshape(1,-1,3).astype('uint8'),'RGB');q=pool.quantize(colors=48,method=Image.Quantize.MEDIANCUT);colors=np.unique(np.asarray(q.convert('RGB')).reshape(-1,3),axis=0);cache={}
for i,im in enumerate(frames):
 a=np.asarray(im).copy();mask=a[:,:,3]>0;rgb=a[:,:,:3][mask];unique,idx=np.unique(rgb,axis=0,return_inverse=True);mapped=colors[np.argmin(np.sum((unique[:,None,:].astype(float)-colors[None,:,:])**2,axis=2),axis=1)];a[:,:,:3][mask]=mapped[idx];frames[i]=Image.fromarray(a)
strip=Image.new('RGBA',(2560,640));board=Image.new('RGBA',(1280,1280),(14,18,22,255));floor=Image.open(B/'candidates/ash_road_v01.png').convert('RGBA');gif=[]
for i,f in enumerate(frames):
 strip.paste(f,(640*i,0));bg=Image.new('RGBA',(640,640))
 for y in range(10):
  for x in range(10):bg.paste(floor,(64*x,64*y))
 bg.alpha_composite(f);board.paste(bg,(i%2*640,i//2*640));gif.append(bg.convert('RGB'))
 a=np.asarray(f);visible=a[:,:,3]>0;records[i].update(alpha_max=int(a[:,:,3].max()),alpha_sum=int(a[:,:,3].sum()),outside_sector_pixels=int(np.count_nonzero(visible&~valid)),center160_pixels=int(np.count_nonzero(visible&(radius<160))),bbox=f.getchannel('A').getbbox())
 if i==1:
  support=[]
  for lo in np.linspace(-1.05,1.05,43)[:-1]:
   m=visible&(angle>=lo)&(angle<lo+.05);support.append(float(radius[m].max()) if np.any(m) else 0)
  records[i]['outer_radius_42_angle_bins']=support
strip.save(B/'candidates/surtr_sword_arc_large_v01.png');board.convert('RGB').save(B/'previews/surtr_sword_arc_large_1x.png');board.resize((5120,5120),Image.Resampling.NEAREST).save(B/'previews/surtr_sword_arc_large_4x.png');gif[0].save(B/'previews/surtr_sword_arc_large_native.gif',save_all=True,append_images=gif[1:],duration=[60,60,70,60],loop=0,optimize=False);gif[0].save(B/'previews/surtr_sword_arc_large_slow8.gif',save_all=True,append_images=gif[1:],duration=[120,130,120,130],loop=0,optimize=False)
(B/'records/arc_processing.json').write_text(json.dumps(dict(frames=records,palette=colors.tolist(),alpha_levels=ladder.tolist()),ensure_ascii=False,indent=2)+'\n');print(json.dumps(records,ensure_ascii=False))
