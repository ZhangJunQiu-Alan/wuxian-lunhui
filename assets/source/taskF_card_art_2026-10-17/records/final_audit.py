from pathlib import Path
from PIL import Image
from html.parser import HTMLParser
from urllib.parse import unquote
import json,hashlib
R=Path(__file__).resolve().parents[1];ROOT=R.parents[2];m=json.loads((R/'manifest.json').read_text());errors=[]
for row in m['files']:
 for k in ['approved_file','candidate_file']:
  p=R/row[k]
  with Image.open(p)as im:
   im.load()
   if im.size!=(720,1200)or im.mode!='RGB'or im.format!='PNG':errors.append([row['id'],k,'format'])
  if hashlib.sha256(p.read_bytes()).hexdigest()!=row['sha256']:errors.append([row['id'],k,'sha256'])
 p=ROOT/row['runtime_file']
 if hashlib.sha256(p.read_bytes()).hexdigest()!=row['sha256']:errors.append([row['id'],'runtime','sha256'])
 if any(v is not True and v!='not_applicable'for v in row['checks'].values()):errors.append([row['id'],'self_check'])
 for k,size in [('small',(260,433)),('masked',(260,433)),('cover_crop',(260,450)),('safe',(360,600))]:
  with Image.open(R/row['previews'][k])as im:
   im.load()
   if im.size!=size or im.mode!='RGB':errors.append([row['id'],k,'preview_format'])
levels=0
for row in json.loads((R/'records/mipmap_manifest.json').read_text()):
 for level in row['levels']:
  p=R/level['file'];levels+=1
  with Image.open(p)as im:
   im.load()
   if list(im.size)!=level['size']or im.mode!='RGB':errors.append([row['id'],'mipmap_format'])
  if hashlib.sha256(p.read_bytes()).hexdigest()!=level['sha256']:errors.append([row['id'],'mipmap_hash'])
class Links(HTMLParser):
 def handle_starttag(self,tag,attrs):
  for k,v in attrs:
   if k in ['src','href']and v and not v.startswith(('http:','https:','#','data:')):
    if not (R/unquote(v.split('#')[0])).exists():errors.append(['broken_link',v])
Links().feed((R/'gallery.html').read_text());jobs=json.loads((R/'records/generation_jobs.json').read_text());originals=0
for j in jobs:
 with Image.open(R/j['source_file'])as im:im.load();originals+=1
 if not j['prompt']or not j['tool']:errors.append(['missing_provenance',j['id']])
report={'delivered_cards':len(m['files']),'decoded_originals':originals,'rejected_originals':sum(not j['selected']for j in jobs),'mipmap_levels_checked':levels,'png_rgb_720x1200':not errors,'runtime_approved_candidate_hashes_match':not errors,'gallery_local_links_exist':not errors,'errors':errors,'game_test':'not_performed','godot_mipmap_configured':False,'status':'pass'if not errors else 'fail'}
(R/'records/final_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2));raise SystemExit(bool(errors))
