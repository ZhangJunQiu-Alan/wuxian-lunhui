from pathlib import Path
from PIL import Image,ImageChops
import json,hashlib
ROOT=Path(__file__).resolve().parent.parent
ASSETS=ROOT.parents[1]
manifest=json.loads((ROOT/'manifest.json').read_text())
results=[]
for a in manifest['assets']:
 errors=[];notes=[]
 if a['status']!='accepted':
  results.append({'id':a['id'],'status':a['status'],'errors':['Not accepted yet']});continue
 p=ROOT/a['candidate'];im=Image.open(p);w,h,n=a['w'],a['h'],a['frames']
 if im.mode!='RGBA' or im.size!=(w*n,h):errors.append('Wrong PNG mode or dimensions')
 alpha=set(im.getchannel('A').getdata())
 if alpha!={0,255}:errors.append('Not binary alpha with transparent background')
 colors=set(v[:3] for v in im.getdata() if v[3]);frames=[im.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
 if len(colors)>48:errors.append('More than48 opaque RGB colors')
 for i,f in enumerate(frames):
  b=f.getbbox()
  if b is None or b[0]<2 or b[1]<2 or b[2]>w-2 or b[3]>h-2:errors.append(f'Frame{i+1} missing2px margin')
 if a['anchor']=='bottom' and n>1 and len(set(f.getbbox()[3] for f in frames))!=1:errors.append('Uneven bottom anchors')
 if n>1 and len(set(f.tobytes() for f in frames))<3:errors.append('Animation has fewer than3 unique phases')
 for name in [a['approved'],a['source'],a['generation_record'],a['preview']]:
  if not (ROOT/name).exists():errors.append('Missing file '+name)
 for other in [ROOT/a['approved'],ASSETS/a['output']]:
  if not other.exists() or other.read_bytes()!=p.read_bytes():errors.append('Published bytes differ '+str(other))
 sha=hashlib.sha256(p.read_bytes()).hexdigest()
 if sha!=a['sha256'] or sha!=a['technical']['sha256']:errors.append('Hash mismatch')
 if n>1:
  gif=Image.open(ROOT/a['gif']);durations=[]
  if gif.n_frames!=n or gif.size!=(w*4,h*4) or gif.info.get('loop')!=0:errors.append('Wrong GIF frames,4xsize or looping')
  for i,f in enumerate(frames):
   gif.seek(i);durations.append(gif.info.get('duration',0));expected=Image.new('RGB',(w,h),(18,23,33));expected.paste(f,mask=f.getchannel('A'));expected=expected.resize((w*4,h*4),Image.Resampling.NEAREST)
   if ImageChops.difference(gif.convert('RGB'),expected).getbbox():errors.append(f'GIF frame{i+1} pixels differ from PNG')
  if sum(durations)!=n*125:errors.append('GIF timing is not8fps average')
  notes.append({'gif_durations_ms':durations})
 if a['id'].startswith('einherjar_'):
  palette=Image.open(ROOT/'candidates/einherjar_idle_v01.png').convert('RGBA');allowed=set(v[:3] for v in palette.getdata() if v[3])
  if not colors<=allowed:errors.append('Warrior colors outside idle reference RGB palette')
 if a['id']=='campfire':
  if len(set(f.crop((0,30,w,h)).tobytes() for f in frames))!=1:errors.append('Campfire base changes')
 if a['id']=='iron_brazier':
  for region in [(0,27,48,48),(0,18,18,27),(31,18,48,27)]:
   if len(set(f.crop(region).tobytes() for f in frames))!=1:errors.append('Brazier body changes '+str(region))
 results.append({'id':a['id'],'status':'passed' if not errors else 'failed','errors':errors,'size':im.size,'colors':len(colors),'frame_boxes':[f.getbbox() for f in frames],'sha256':sha,'notes':notes})
accepted=sum(a['status']=='accepted' for a in manifest['assets'])
report={'batch':6,'expected_outputs':34,'accepted':accepted,'audited':len(results),'passed':sum(r['status']=='passed' for r in results),'failed':[r for r in results if r['status']=='failed'],'all_complete_and_passed':len(results)==34 and accepted==34 and all(r['status']=='passed' for r in results),'tiling_4x4':'N/A - no ground tiles in batch6','game_tested':False,'results':results}
(ROOT/'records/final_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='results'},ensure_ascii=False,indent=2))
