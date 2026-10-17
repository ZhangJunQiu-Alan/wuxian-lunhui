from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
from collections import Counter
import json, hashlib, argparse, math

ROOT=Path(__file__).resolve().parent.parent
BG=(18,23,33)
PLAN={a['id']:a for a in json.loads((ROOT/'records/production_plan.json').read_text())['assets']}
COLORS=json.loads((ROOT/'records/palette48.json').read_text())['colors']

def palette(a):
 colors=COLORS[:]
 if a['id']!='gjoll_bridge':colors=[c for c in colors if c not in COLORS[38:42]]
 if not a['id'].startswith('dried_blood'):colors=[c for c in colors if c not in COLORS[-2:]]
 if a['type']=='ground':colors=[c for c in colors if sum(c)/3<=120 and c[0]-c[2]<=8]
 if a['id']=='river_ice':colors=[c for c in colors if sum(c)/3<=80]
 if a['type']=='decals':
  colors=COLORS[-2:] if a['id'].startswith('dried_blood') else [c for c in colors if 28<=sum(c)/3<=95 and max(c)-min(c)<30]
 p=Image.new('P',(1,1));p.putpalette([v for c in colors for v in c]+colors[0]*(256-len(colors)))
 return p

def quantize(im,a):
 alpha=im.getchannel('A');q=im.convert('RGB').quantize(palette=palette(a),dither=Image.Dither.NONE).convert('RGBA');q.putalpha(alpha)
 q.putdata([p if p[3] else(0,0,0,0) for p in q.getdata()]);return q

def overlap_cut(a,b,overlap):
 w,h=overlap,a.height;pa=a.load();pb=b.load();dp=[];backs=[]
 for y in range(h):
  cost=[sum((pa[a.width-w+x,y][c]-pb[x,y][c])**2 for c in range(4)) for x in range(w)]
  if not y:dp.append(cost);continue
  row=[];back=[]
  for x in range(w):
   k=min(range(max(0,x-1),min(w,x+2)),key=lambda j:dp[-1][j]);back.append(k);row.append(cost[x]+dp[-1][k])
  dp.append(row);backs.append(back)
 path=[0]*h;path[-1]=min(range(w),key=lambda x:dp[-1][x])
 for y in range(h-1,0,-1):path[y-1]=backs[y-1][path[y]]
 out=a.copy();p=out.load()
 for y in range(h):
  for x in range(path[y],w):p[a.width-w+x,y]=pb[x,y]
 return out,path

def periodic(im,axis,overlap):
 if axis=='y':im=im.transpose(Image.Transpose.TRANSPOSE)
 out,path=overlap_cut(im,im.crop((0,0,overlap,im.height)),overlap);out=out.crop((overlap,0,out.width,out.height))
 if axis=='y':out=out.transpose(Image.Transpose.TRANSPOSE)
 return out,path

def views(a,v):
 stem=f"{a['id']}_{v}";im=Image.open(ROOT/'candidates'/f'{stem}.png').convert('RGBA');w,h=im.size
 out=Image.new('RGB',(max(640,w*4),h*5+70),BG);d=ImageDraw.Draw(out);d.text((4,4),f'{stem} | {w}x{h} | 1x and nearest4x',fill='white')
 out.paste(im,(0,24),im);big=im.resize((w*4,h*4),Image.Resampling.NEAREST);out.paste(big,(0,h+45),big);out.save(ROOT/'previews'/f'{stem}_review.png')
 if a.get('tile'):
  board=Image.new('RGBA',(w*4,h*4))
  for y in range(4):
   for x in range(4):board.paste(im,(x*w,y*h))
  board.save(ROOT/'previews'/f'{stem}_tile4x4.png')
 if a.get('axis'):
  axis=a['axis'];board=Image.new('RGBA',(w*4 if axis=='x' else w,h*4 if axis=='y' else h),BG+(255,))
  for i in range(4):board.alpha_composite(im,(w*i if axis=='x' else 0,h*i if axis=='y' else 0))
  board.save(ROOT/'previews'/f'{stem}_repeat4.png')
 info={'id':a['id'],'version':v,'size':[w,h],'mode':'RGBA','colors':len(set(p[:3] for p in im.getdata() if p[3])),'alpha':sorted(set(im.getchannel('A').getdata())),'bbox':im.getbbox(),'sha256':hashlib.sha256((ROOT/'candidates'/f'{stem}.png').read_bytes()).hexdigest()}
 (ROOT/'records'/f'check_{stem}.json').write_text(json.dumps(info,indent=2));return info

def normalize(id,v='v01'):
 a=PLAN[id];stem=f'{id}_{v}';src=ROOT/'originals'/f'{stem}_raw.png';im=Image.open(src).convert('RGBA');rawsize=im.size
 im.putalpha(im.getchannel('A').point(lambda p:255 if p>=128 else 0));record={'source':str(src),'raw_size':rawsize,'target':[a['w'],a['h']],'tool':'Pillow','no_character_redrawing':True}
 if a.get('tile'):
  im=im.resize((96,96),Image.Resampling.NEAREST);im.putalpha(255);im=quantize(im,a);cuts={}
  for axis in ['x','y']:im,cuts[axis]=periodic(im,axis,32)
  record.update(operation='Nearest96x96, fixed dark palette; source-pixel minimum-error overlap and crop to64x64 on both axes',cut_paths=cuts)
 elif a['type']=='borders':
  size=(320,a['h']) if a.get('axis')=='x' else(a['w'],320) if a.get('axis')=='y' else(a['w'],a['h'])
  im=im.resize(size,Image.Resampling.NEAREST);im=quantize(im,a)
  if a.get('axis'):im,path=periodic(im,a['axis'],64);record['cut_path']=path
  record['operation']='Full-canvas nearest resize and fixed palette; repeating strips source-pixel overlap crop only'
 else:
  b=im.getbbox()
  if not b:raise ValueError('Empty image')
  contact=b[0]==0 or b[1]==0 or b[2]==im.width or b[3]==im.height
  im=im.crop(b);scale=min((a['w']-4)/im.width,(a['h']-4)/im.height);size=(max(1,round(im.width*scale)),max(1,round(im.height*scale)));im=im.resize(size,Image.Resampling.NEAREST);im=quantize(im,a)
  x=(a['w']-im.width)//2;y=(a['h']-im.height)//2 if a['type']=='decals' or id=='hall_carpet' else a['h']-2-im.height
  out=Image.new('RGBA',(a['w'],a['h']));out.paste(im,(x,y));im=out;record.update(operation='Whole silhouette crop, aspect-preserving nearest fit, binaryalpha, fixed palette and whole-object placement',crop_bbox=b,source_edge_contact=contact,scale=scale,placement=[x,y])
 im.save(ROOT/'candidates'/f'{stem}.png');(ROOT/'records'/f'normalization_{stem}.json').write_text(json.dumps(record,indent=2));return views(a,v)

def transitions(v='v01'):
 def mask(kind):
  m=Image.new('L',(64,64));p=m.load()
  for y in range(64):
   for x in range(64):
    if kind=='edge':inside=y>=32+round(1.5*math.sin(x*math.pi/16))
    elif kind=='outer':inside=math.hypot(63.5-x,63.5-y)<=32+round(math.sin((x+y)*math.pi/12))
    else:inside=math.hypot(x+.5,y+.5)>=32+round(math.sin((x+y)*math.pi/12))
    p[x,y]=255 if inside else 0
  return m
 rows=[]
 for fam in ['river','bone_path','marsh']:
  source='river_01' if fam=='river' else fam;sv='v03' if source=='bone_path' else 'v01';tex=Image.open(ROOT/'candidates'/f'{source}_{sv}.png')
  for kind,dirs in [('edge',['n','w','s','e']),('outer',['nw','sw','se','ne']),('inner',['nw','sw','se','ne'])]:
   for k,d in enumerate(dirs):
    id=f'{fam}_edge_{d}' if kind=='edge' else f'{fam}_edge_{kind}_{d}';im=tex.copy();im.putalpha(mask(kind).rotate(k*90,expand=False));im.putdata([p if p[3] else(0,0,0,0) for p in im.getdata()]);im.save(ROOT/'candidates'/f'{id}_{v}.png');views(PLAN[id],v)
    record={'tool':'Pillow binary alpha crop only','source':f'candidates/{source}_{sv}.png','source_generation_record':f'records/generation_{source}_{sv}.json','operation':'Original texture RGB unchanged, same pixel coordinates; rounded connected edge/corner binary alpha crop, matches prior delivered transition orientation','kind':kind,'direction':d,'mask_rotation_degrees':k*90};(ROOT/'records'/f'generation_{id}_{v}.json').write_text(json.dumps(record,indent=2));rows.append({'id':id,**record})
 (ROOT/'records/transitions.json').write_text(json.dumps(rows,indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('ids',nargs='+');p.add_argument('--version',default='v01');args=p.parse_args()
 for id in args.ids:
  try:
   if id=='transitions':transitions(args.version);print('36 alpha-only transitions')
   else:print(json.dumps(normalize(id,args.version)))
  except Exception as e:print(json.dumps({'id':id,'error':str(e)}))
