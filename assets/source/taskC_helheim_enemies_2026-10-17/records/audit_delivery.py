from pathlib import Path
from PIL import Image,ImageChops
import json,hashlib
ROOT=Path(__file__).resolve().parent.parent;ASSETS=ROOT.parents[1]
manifest=json.loads((ROOT/'manifest.json').read_text());plan=json.loads((ROOT/'records/production_plan.json').read_text())['assets'];byid={a['id']:a for a in manifest['assets']};results=[]
for a in manifest['assets']:
 errors=[];notes=[]
 if a['status']!='accepted':results.append({'id':a['id'],'status':a['status'],'errors':['Not art-accepted yet']});continue
 p=ROOT/a['candidate'];im=Image.open(p);w,h,n=a['w'],a['h'],a['frames']
 if im.mode!='RGBA' or im.size!=(w*n,h):errors.append('Wrong PNG mode/dimensions')
 if set(im.getchannel('A').getdata())!={0,255}:errors.append('Expected transparent background and binary0/255alpha')
 colors=set(v[:3] for v in im.getdata() if v[3]);frames=[im.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
 if len(colors)>48:errors.append('More than48opaque RGB colors')
 for i,f in enumerate(frames):
  b=f.getbbox()
  if b is None or b[0]<2 or b[1]<2 or b[2]>w-2 or b[3]>h-2:errors.append(f'Frame{i+1} lacks2pixelmargin')
 if n>1 and a['anchor'] in ('bottom','float') and len(set(f.getbbox()[3] for f in frames))>1:errors.append('Ground/tail anchors change')
 if n>1 and len(set(f.tobytes() for f in frames))<min(n,3):errors.append('Too few distinct animation poses')
 if n>1 and a.get('unit'):
  static=byid.get(a['unit'])
  if static and static['status']=='accepted':
   ref=Image.open(ROOT/static['candidate']).convert('RGBA');palette=set(v[:3] for v in ref.getdata() if v[3])
   if not colors<=palette:errors.append('Animation RGB outside static reference palette')
   if a['anchor'] in ('bottom','float') and ref.getbbox()[3]!=frames[0].getbbox()[3]:errors.append('Static/animation ground anchors differ')
 for rel in [a['approved'],a['source'],a['generation_record'],a['preview']]:
  if not (ROOT/rel).is_file():errors.append('Missing deliverable '+rel)
 for other in [ROOT/a['approved'],ASSETS/a['output']]:
  if not other.is_file() or p.read_bytes()!=other.read_bytes():errors.append('Final/approved bytes differ '+str(other))
 sha=hashlib.sha256(p.read_bytes()).hexdigest()
 if sha!=a['sha256'] or sha!=a['technical']['sha256']:errors.append('SHA256 mismatch')
 if n>1:
  factor=2 if n%2 else 1;expected_count=n*factor;gif=Image.open(ROOT/a['gif']);durations=[]
  if gif.n_frames!=expected_count or gif.size!=(w*4,h*4) or gif.info.get('loop')!=0:errors.append('Wrong GIF count,4xsize,loop flag')
  for i in range(min(gif.n_frames,expected_count)):
   f=frames[i%n];gif.seek(i);durations.append(gif.info.get('duration',0));expected=Image.new('RGB',(w,h),(18,23,33));expected.paste(f,mask=f.getchannel('A'));expected=expected.resize((w*4,h*4),Image.Resampling.NEAREST)
   if ImageChops.difference(gif.convert('RGB'),expected).getbbox():errors.append(f'GIF phase{i+1} differs from corresponding PNG cell')
  if sum(durations)!=expected_count*125:errors.append('GIF timing not average8fps')
  notes.append({'gif_frames':gif.n_frames,'timings':durations,'cycles_in_gif':factor,'note':'Odd3phase clips preview2cycles to achieve exact8fps average with GIF10ms timing granularity' if factor==2 else''})
 if a['id']=='nail_golem_small' and (frames[0].getbbox()[3]-frames[0].getbbox()[1])!=32:errors.append('Small construct body not32pixels high')
 results.append({'id':a['id'],'status':'failed' if errors else'passed','errors':errors,'size':im.size,'colors':len(colors),'frame_boxes':[f.getbbox() for f in frames],'sha256':sha,'notes':notes})
report={'task':manifest['task'],'expected':len(plan),'accepted':manifest['accepted'],'passed':sum(r['status']=='passed' for r in results),'failed':[r for r in results if r['status']=='failed'],'all_complete_and_passed':len(results)==len(plan) and all(r['status']=='passed' for r in results),'game_tested':False,'results':results}
(ROOT/'records/final_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='results'},ensure_ascii=False,indent=2))
