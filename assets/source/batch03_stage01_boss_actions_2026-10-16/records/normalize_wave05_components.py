from pathlib import Path
from collections import deque
r=Path(__file__).resolve().parents[1]
s=(r/'records/normalize_wave05.py').read_text();start=s.index(" im=Image.open(r/j['raw_file'])");end=s.index('\n maxw=',start)
replacement=''' im=Image.open(r/j['raw_file']).convert('RGBA');cols,rows=j['layout'];n=j['frame_size'][0];base={'skoll':117,'hati':118,'hrym':189}[j['character']];frames=[];boxes=[]
 w,h=im.size;mask=bytearray(1 if a>=128 else 0 for a in im.getchannel('A').get_flattened_data());components=[]
 for idx in range(w*h):
  if not mask[idx]:continue
  mask[idx]=0;q=deque([idx]);pts=[]
  while q:
   k=q.popleft();pts.append(k);x=k%w;y=k//w
   for z in ((k-1 if x else -1),(k+1 if x<w-1 else -1),k-w,k+w):
    if 0<=z<w*h and mask[z]:mask[z]=0;q.append(z)
  if len(pts)>2000:
   xs=[p%w for p in pts];ys=[p//w for p in pts];components.append(dict(pts=pts,bbox=[min(xs),min(ys),max(xs)+1,max(ys)+1],area=len(pts)))
 components=sorted(components,key=lambda c:c['area'],reverse=True)[:j['frames']];assert len(components)==j['frames'];components.sort(key=lambda c:(c['bbox'][1]+c['bbox'][3])/2);ordered=[]
 for row in range(rows):ordered+=sorted(components[row*cols:(row+1)*cols],key=lambda c:c['bbox'][0])
 for c in ordered:
  b=c['bbox'];cell=im.crop(b);a=Image.new('L',cell.size);ap=a.load()
  for p in c['pts']:ap[p%w-b[0],p//w-b[1]]=255
  cell.putalpha(a);boxes.append(b);frames.append(cell)
'''
s=s[:start]+replacement+s[end:];s=s.replace('from PIL import Image,ImageDraw','from PIL import Image,ImageDraw\nfrom collections import deque').replace("v=j['id'].split('_')[-1]","v=j['id'].split('_')[-1]+'_cc'").replace('wave05_candidates_metadata','wave05_components_metadata').replace("f'previews/{j[\"id\"]}_sequence_QA.gif'","f'previews/{j[\"id\"]}_cc_sequence_QA.gif'");exec(compile(s,__file__,'exec'))
