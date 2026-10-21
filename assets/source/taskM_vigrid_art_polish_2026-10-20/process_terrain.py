from PIL import ImageFilter
from pathlib import Path
import json,hashlib,colorsys
from PIL import Image,ImageStat,ImageChops
import numpy as np
B=Path(__file__).resolve().parent;R=B.parents[2]
def stats(im):
 a=np.asarray(im.convert('RGB'),dtype=float);l=a@np.array([.299,.587,.114]);return dict(meanRGB=a.mean(axis=(0,1)).tolist(),luminance=float(l.mean()),contrast=float(l.std()))
def write(name,im):
 im=im.convert('RGB')
 if name=='cracked_lava_02':
  px=list(im.get_flattened_data());hot=[.02<=h<=.15 and ss>=.45 and v>=.20 for rgb in px for h,ss,v in [colorsys.rgb_to_hsv(*(c/255 for c in rgb))]];out=list(px)
  for flag,count in [(False,40),(True,8)]:
   idx=[i for i,v in enumerate(hot) if v==flag];pool=Image.new('RGB',(len(idx),1));pool.putdata([tuple(round(c*255) for c in colorsys.hsv_to_rgb(.07,.76,max(90,min(160,max(px[i])))/255)) if flag else px[i] for i in idx]);clean=list(pool.quantize(colors=count,method=Image.Quantize.MEDIANCUT).convert('RGB').get_flattened_data())
   for i,c in zip(idx,clean):out[i]=c
  im.putdata(out)
 else:im=im.quantize(colors=48,method=Image.Quantize.MEDIANCUT).convert('RGB')
 im=im.convert('RGBA');version='v02' if name=='cracked_lava_02' else 'v01';im.save(B/f'candidates/{name}_{version}.png');return im
rows=[]
for name in ['ash_road','burnt_grass_02','cracked_lava_02']:
 p=B/f'originals/{name}_v01_raw.png';source=Image.open(p).convert('RGB');source=ImageChops.offset(source,6,6) if name=='cracked_lava_02' else source;im=source.resize((64,64),Image.Resampling.NEAREST);before=stats(im);a=np.asarray(im,dtype=float)
 if name=='ash_road':
  l=a@np.array([.299,.587,.114]);d=(l-l.mean())*(17/max(l.std(),1));a=np.clip(np.array([70,60,52])+d[:,:,None],0,155)
 elif name=='burnt_grass_02':
  m=a.mean(axis=(0,1));a=np.clip(a*(np.array([46,44,28])/np.maximum(m,1)),0,110)
 else:
  a=np.minimum(a,160)
 im=write(name,Image.fromarray(np.uint8(np.rint(a))));after=stats(im);row=dict(id=name,raw=str(p.relative_to(B)),raw_size=Image.open(p).size,before=before,after=after,processing=('raw cyclic sample offset6, NN64, 40 background plus8 existing warm-pixel colors; no painted source pixels' if name=='cracked_lava_02' else 'NN64, whole image color normalization, median48; no painted source pixels'));rows.append(row)
 for count in [3,4]:
  tile=Image.new('RGBA',(64*count,64*count))
  for y in range(count):
   for x in range(count):tile.paste(im,(x*64,y*64))
  tile.save(B/f'previews/{name}_{count}x{count}_1x.png');tile.resize((tile.width*4,tile.height*4),Image.Resampling.NEAREST).save(B/f'previews/{name}_{count}x{count}_4x.png')
 im.save(B/f'previews/{name}_1x.png');im.resize((256,256),Image.Resampling.NEAREST).save(B/f'previews/{name}_4x.png')
 px=np.asarray(im,dtype=float);dr=np.abs(px[:,:-1,:3]-px[:,1:,:3]).mean();dv=np.abs(px[:-1,:,:3]-px[1:,:,:3]).mean();row['seams']=dict(horizontal=float(np.abs(px[:,0,:3]-px[:,-1,:3]).mean()),vertical=float(np.abs(px[0,:,:3]-px[-1,:,:3]).mean()),internal_horizontal=float(dr),internal_vertical=float(dv))
 if name=='cracked_lava_02':
  hsv=[colorsys.rgb_to_hsv(*(c/255 for c in p[:3])) for p in im.get_flattened_data()];orange=[h>=.02 and h<=.15 and s>=.45 and v>=.20 for h,s,v in hsv];row['orange_fraction']=sum(orange)/4096
 if name=='burnt_grass_02':row['ember_fraction']=sum(r>g*1.4 and r>45 for r,g,b,a in im.get_flattened_data())/4096
road=Image.open(B/'candidates/ash_road_v01.png').convert('RGBA');edge_rows=[]
def chip_mask(mask):
 a=np.array(mask);l=np.array(road)[:,:,:3]@np.array([.299,.587,.114])
 rim1=(a>0)&(np.array(mask.filter(ImageFilter.MinFilter(3)))==0)
 rim3=(a>0)&(np.array(mask.filter(ImageFilter.MinFilter(7)))==0)
 a[(rim1&(l<np.quantile(l,.48)))|(rim3&(l<np.quantile(l,.18)))]=0
 return Image.fromarray(a)

for part in ['n','s','e','w','inner_ne','inner_nw','inner_se','inner_sw','outer_ne','outer_nw','outer_se','outer_sw']:
 source=R/f'assets/sprites/ground/helheim/bone_path_edge_{part}.png';mask=Image.open(source).convert('RGBA').getchannel('A').point(lambda a:255 if a>=128 else 0);mask=chip_mask(mask);im=road.copy();im.putalpha(mask);im.putdata([(r,g,b,a) if a else (0,0,0,0) for r,g,b,a in im.get_flattened_data()]);name='ash_road_edge_'+part;im.save(B/f'candidates/{name}_v02.png');edge_rows.append(dict(id=name,mask_source=str(source.relative_to(R)),sha256=hashlib.sha256(source.read_bytes()).hexdigest(),method='helheim binary topology; contour chips subtract 1-3 pixels using generated road luminance, no new RGB pixels'))
(B/'records/terrain_processing.json').write_text(json.dumps(dict(tiles=rows,edges=edge_rows),ensure_ascii=False,indent=2)+'\n');print(json.dumps(rows,ensure_ascii=False))
