from pathlib import Path
from PIL import Image
import json,shutil
ROOT=Path(__file__).resolve().parent.parent
im=Image.open(ROOT/'originals/lightning_v02_raw.png').convert('RGBA');w,h=im.size
mask=bytearray(v>=128 for v in im.getchannel('A').getdata());parts=[]
for start in range(len(mask)):
 if not mask[start]:continue
 mask[start]=0;queue=[start];pixels=[];x0=w;y0=h;x1=y1=0
 while queue:
  p=queue.pop();pixels.append(p);x=p%w;y=p//w;x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
  for q in (p-1 if x else -1,p+1 if x<w-1 else -1,p-w if y else -1,p+w if y<h-1 else -1):
   if q>=0 and mask[q]:mask[q]=0;queue.append(q)
 parts.append({'pixels':pixels,'box':[x0,y0,x1+1,y1+1]})
roots=sorted([p for p in parts if p['box'][3]-p['box'][1]>700],key=lambda p:p['box'][0])
assert len(roots)==4
anchors=[]
for p in roots:
 base=[v%w for v in p['pixels'] if v//w>=p['box'][3]-25];anchors.append(round(sum(base)/len(base)))
groups=[[] for _ in roots]
for p in parts:
 index=next((i for i,r in enumerate(roots) if p is r),None)
 if index is None:index=min(range(4),key=lambda i:abs((p['box'][0]+p['box'][2])/2-anchors[i]))
 groups[index].extend(p['pixels'])
boxes=[]
for group in groups:boxes.append([min(p%w for p in group),min(p//w for p in group),max(p%w for p in group)+1,max(p//w for p in group)+1])
half=max(max(anchors[i]-b[0],b[2]-anchors[i]) for i,b in enumerate(boxes));height=max(b[3]-b[1] for b in boxes);cw=half*2+2
out=Image.new('RGBA',(cw*4,height));pixels=im.load()
for i,group in enumerate(groups):
 for p in group:
  x,y=p%w,p//w;out.putpixel((i*cw+half+x-anchors[i],y-boxes[i][3]+height),(*pixels[x,y][:3],255))
out.save(ROOT/'refs/lightning_extracted_v02.png')
for name in ['candidates/lightning_v02.png','records/normalization_lightning_v02.json']:
 path=ROOT/name
 if path.exists():shutil.copy2(path,path.with_name(path.stem+'_grid_rejected'+path.suffix))
(ROOT/'records/lightning_component_extraction.json').write_text(json.dumps({'source':'originals/lightning_v02_raw.png','root_boxes':[p['box'] for p in roots],'all_component_boxes':boxes,'impact_x_anchors':anchors,'cell':[cw,height],'formatting':'Separate four long connected bolt components; assign detached sparks to nearest impact column, copy source pixels unchanged, align impact points. Use one common horizontal scale and one common vertical scale for all four effect frames to fit64x256. No branches clipped or redrawn.'},indent=2))
print('lightning extraction',cw,height,anchors)
