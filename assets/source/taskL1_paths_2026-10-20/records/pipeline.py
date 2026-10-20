from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageStat
import json, hashlib, shutil, sys

ROOT=Path(__file__).resolve().parents[4]
PLAN=ROOT/'assets/source/taskL1_paths_2026-10-20/records/plan_all_L.json'
def sha(f):return hashlib.sha256(Path(f).read_bytes()).hexdigest()
def job(id):return next(j for j in json.loads(PLAN.read_text()) if j['id']==id)
def save(f,v):Path(f).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def record(result):
 j=job(result['id']);d=ROOT/j['root'];v=result.get('version','v01');dst=d/'originals'/f'{j["id"]}_{v}.png'
 assert not dst.exists(),dst
 shutil.copy2(result['raw_path'],dst)
 refs=[]
 for rel in result.get('references',j['references']):
  source=ROOT/rel;assert source.exists(),source;out=d/'references'/source.name
  if out.exists() and sha(out)!=sha(source):out=out.with_name(out.stem+'_'+sha(source)[:8]+out.suffix)
  if not out.exists():shutil.copy2(source,out)
  refs.append({'actual_input':rel,'archive':str(out.relative_to(d)),'sha256':sha(out)})
 item={**j,'version':v,'prompt':result.get('prompt',j['prompt']),'references':refs,'tool':'OpenAI built-in image_gen','raw_output_path':result['raw_path'],'original':str(dst.relative_to(d)),'original_sha256':sha(dst),'commercial_basis':'https://openai.com/policies/terms-of-use/','status':'candidate','review':None}
 save(d/'records'/f'generation_{j["id"]}_{v}.json',item)
 return normalize(j['id'],v)
def normalize(id,v='v01'):
 j=job(id);d=ROOT/j['root'];src=d/'originals'/f'{id}_{v}.png';raw=Image.open(src)
 rgb=raw.convert('RGB');im=ImageOps.fit(rgb,(720,1200),Image.Resampling.LANCZOS,centering=(.5,.5));out=d/'candidates'/f'{id}_{v}.png';im.save(out)
 thumb=im.resize((260,433),Image.Resampling.LANCZOS);thumb.save(d/'previews'/f'{id}_{v}_260.png')
 masked=im.convert('RGBA');shade=Image.new('RGBA',im.size);px=shade.load()
 for y in range(660,1200):
  alpha=round(160+80*(y-660)/540)
  for x in range(720):px[x,y]=(9,12,20,alpha)
 masked.alpha_composite(shade);masked.convert('RGB').resize((260,433),Image.Resampling.LANCZOS).save(d/'previews'/f'{id}_{v}_masked.png')
 safe=thumb.copy();dr=ImageDraw.Draw(safe);dr.rectangle((14,0,245,432),outline=(230,140,40));dr.line((0,238,259,238),fill=(230,140,40));dr.line((0,260,259,260),fill=(90,180,220));safe.save(d/'previews'/f'{id}_{v}_safe.png')
 gray=im.convert('L');bottom=gray.crop((0,720,720,1200));values=list(bottom.getdata());stats={'mean':round(sum(values)/len(values),2),'pixels_over_100_fraction':round(sum(v>100 for v in values)/len(values),4),'stddev':round(ImageStat.Stat(bottom).stddev[0],2)}
 data={'id':id,'raw_size':raw.size,'raw_mode':raw.mode,'output_size':im.size,'mode':im.mode,'operation':'centered aspect crop to3:5, Lanczos resize720x1200, RGB only; no repaint, no artificial background darkening','candidate_sha256':sha(out),'bottom40_luminance':stats,'status':'awaiting visual QA'}
 save(d/'records'/f'normalization_{id}_{v}.json',data);print(json.dumps(data));return data
def review(id,v,passed,notes):
 j=job(id);d=ROOT/j['root'];path=d/'records'/f'generation_{id}_{v}.json';item=json.loads(path.read_text());item['status']='approved' if passed else 'rejected';item['review']=notes;save(path,item)
 if not passed:return
 im=Image.open(d/'candidates'/f'{id}_{v}.png');target=ROOT/j['target'];assert not target.exists(),target
 shutil.copy2(d/'candidates'/f'{id}_{v}.png',d/'approved'/f'{id}.png');shutil.copy2(d/'approved'/f'{id}.png',target)
 mip=d/'mipmaps'/id;mip.mkdir(exist_ok=True)
 level=0;w,h=im.size
 while w>1 or h>1:
  level+=1;w=max(1,w//2);h=max(1,h//2);im.resize((w,h),Image.Resampling.LANCZOS).save(mip/f'level_{level:02}_{w}x{h}.png')
 save(d/'records'/f'approved_{id}.json',{'id':id,'selected_version':v,'formal':j['target'],'sha256':sha(target),'review':notes,'mipmaps':'offline reference chain only; Godot import mipmaps must be enabled by integration agent'})
def contact(ids,name):
 out=Image.new('RGB',(1040,475*((len(ids)+3)//4)),(18,23,33));dr=ImageDraw.Draw(out)
 for i,id in enumerate(ids):
  j=job(id);d=ROOT/j['root'];gens=sorted((d/'records').glob(f'generation_{id}_v*.json'));g=json.loads(gens[-1].read_text());v=g['version'];im=Image.open(d/'previews'/f'{id}_{v}_260.png');x=i%4*260;y=i//4*475;out.paste(im,(x,y+22));dr.text((x+5,y+4),id,fill='white');dr.text((x+5,y+457),v+' '+g['status'],fill='white')
 dst=ROOT/'assets/source/taskL1_paths_2026-10-20/previews'/f'{name}.png';out.save(dst);print(dst)

if __name__=='__main__':
 if sys.argv[1]=='record':
  for result in json.loads(Path(sys.argv[2]).read_text()):record(result)
 elif sys.argv[1]=='normalize':normalize(*sys.argv[2:])
 elif sys.argv[1]=='contact':contact(sys.argv[3:],sys.argv[2])
