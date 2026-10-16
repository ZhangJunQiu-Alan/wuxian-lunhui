from PIL import Image,ImageFilter,ImageStat,ImageDraw
from pathlib import Path
import cmath,math,json
R=Path(__file__).resolve().parents[1]
INV=json.loads((R/'records/asset_inventory.json').read_text())
def fft(x):
 n=len(x)
 if n==1:return x
 a=fft(x[::2]);b=fft(x[1::2]);q=[cmath.exp(-2j*math.pi*k/n)*b[k] for k in range(n//2)]
 return [a[k]+q[k] for k in range(n//2)]+[a[k]-q[k] for k in range(n//2)]
def ifft(x):return [v.conjugate()/len(x) for v in fft([c.conjugate() for c in x])]
def f2(a,inverse=False):
 f=ifft if inverse else fft;b=[f(row) for row in a];return list(map(list,zip(*[f(list(col)) for col in zip(*b)])))
def periodic(im):
 n=64;p=im.load();out=[[[0]*3 for x in range(n)] for y in range(n)]
 for c in range(3):
  a=[[float(p[x,y][c]) for x in range(n)] for y in range(n)];v=[[0j]*n for y in range(n)]
  for x in range(n):v[0][x]=a[-1][x]-a[0][x];v[-1][x]=-v[0][x]
  for y in range(n):v[y][0]+=a[y][-1]-a[y][0];v[y][-1]-=a[y][-1]-a[y][0]
  fv=f2(v)
  for y in range(n):
   for x in range(n):
    den=2*math.cos(2*math.pi*x/n)+2*math.cos(2*math.pi*y/n)-4
    fv[y][x]=fv[y][x]/den if (x or y) else 0j
  sm=f2(fv,True)
  for y in range(n):
   for x in range(n):out[y][x][c]=a[y][x]-sm[y][x].real
 return out
allrows=[]
for a in INV:
 if a['type']!='ground':continue
 level=a['level'];name=a['id'];raw=Image.open(R/f'candidates/{level}_{name}_unfixed.png').convert('RGB');blur=raw.filter(ImageFilter.GaussianBlur(5));mean=ImageStat.Stat(raw).mean
 target={'midgard':(56,67,80),'helheim':(37,47,52),'vigrid':(40,34,34)}[level]
 if name=='frozen_dirt':target=(48,44,44)
 if name.startswith('nail_deck'):target=(51,49,45)
 if name=='ice':target=(43,60,75)
 micro=.42;macro=.08
 if name.startswith('nail_deck'):micro=.46;macro=.12
 if name in ('ice','cracked_lava','snow_trampled','fog_ground','burnt_grass'):macro=.22
 data=[]
 for (r,g,b),(br,bg,bb) in zip(raw.getdata(),blur.getdata()):
  data.append(tuple(max(0,min(150,round(target[c]+(v-bv)*micro+(bv-mean[c])*macro))) for c,(v,bv) in enumerate(zip((r,g,b),(br,bg,bb)))))
 im=Image.new('RGB',(64,64));im.putdata(data);per=periodic(im);im.putdata([tuple(max(0,min(150,round(c))) for c in p) for row in per for p in row]);im.convert('RGBA').save(R/f'candidates/{level}_{name}_v02.png')
 def tiled(im):
  tile=Image.new('RGBA',(256,256))
  for y in range(4):
   for x in range(4):tile.paste(im,(64*x,64*y))
  return tile
 tiled(im).save(R/f'previews/{level}_{name}_v02_4x4.png')
 p=im.load();sx=sum(abs(p[0,y][c]-p[63,y][c]) for y in range(64) for c in range(3))/192;sy=sum(abs(p[x,0][c]-p[x,63][c]) for x in range(64) for c in range(3))/192
 ix=sum(abs(p[x,y][c]-p[x-1,y][c]) for y in range(64) for x in range(1,64) for c in range(3))/(64*63*3)
 iy=sum(abs(p[x,y][c]-p[x,y-1][c]) for y in range(1,64) for x in range(64) for c in range(3))/(64*63*3)
 allrows.append(dict(id=name,level=level,seam_mean_x=round(sx,3),seam_mean_y=round(sy,3),internal_mean_x=round(ix,3),internal_mean_y=round(iy,3),status='candidate_pending_visual_review'))
mos=Image.new('RGB',(1024,1400),'#121721');d=ImageDraw.Draw(mos)
for i,a in enumerate(allrows):
 x=i%4*256;y=i//4*280;mos.paste(Image.open(R/f"previews/{a['level']}_{a['id']}_v02_4x4.png"),(x,y+20));d.text((x+3,y+3),a['level']+'/'+a['id'],fill='white')
mos.save(R/'previews/ground_seam_review_v02.png');(R/'records/ground_metrics_v02.json').write_text(json.dumps(allrows,indent=2));print('20 ground v02 candidates; periodic decomposition; pending visual review')
