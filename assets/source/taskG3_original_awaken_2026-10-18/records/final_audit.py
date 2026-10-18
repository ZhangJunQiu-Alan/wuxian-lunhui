from pathlib import Path
from PIL import Image
from html.parser import HTMLParser
from urllib.parse import unquote
import hashlib,json
R=Path(__file__).resolve().parents[1]
ROOT=R.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((R/'manifest.json').read_text());errors=[];links=0;image_count=0
for item in m['files']:
 for key in ['candidate_file','approved_file','runtime_file']:
  p=(ROOT if key=='runtime_file' else R)/item[key]
  with Image.open(p)as im:
   im.load();image_count+=1
   if im.size!=(720,1200)or im.mode!='RGB'or im.format!='PNG':errors.append([item['id'],key,'format'])
  if sha(p)!=item['sha256']:errors.append([item['id'],key,'hash'])
 for key,size in [('260',(260,433)),('masked',(260,433)),('cover',(260,450)),('safe',(360,600))]:
  with Image.open(R/item['previews'][key])as im:
   im.load()
   if im.size!=size or im.mode!='RGB':errors.append([item['id'],key,'preview_format'])
 if not all(item['checks'].values()):errors.append([item['id'],'self_check'])
levels=0
for entry in json.loads((R/'records/mipmap_manifest.json').read_text()):
 expected=(720,1200)
 for level in entry['levels']:
  expected=tuple(max(1,v//2)for v in expected);p=R/level['file'];levels+=1
  with Image.open(p)as im:
   im.load()
   if im.size!=expected or list(im.size)!=level['size']or im.mode!='RGB':errors.append([entry['id'],'mipmap_format'])
  if sha(p)!=level['sha256']:errors.append([entry['id'],'mipmap_hash'])
 if expected!=(1,1):errors.append([entry['id'],'incomplete_mip_chain'])
jobs=json.loads((R/'records/generation_jobs.json').read_text())
for j in jobs:
 p=R/j['original_file']
 with Image.open(p)as im:im.load()
 if sha(p)!=j['sha256']:errors.append([j['id'],j['version'],'original_hash'])
 for ref in j['archived_references']:
  if sha(R/ref['file'])!=ref['sha256']:errors.append([j['id'],'reference_hash'])
 if not j['prompt']or not j['tool']:errors.append([j['id'],'missing_provenance'])
for id in ['thor','odin','loki','freyja']:
 if sha(R/'references'/f'{id}.png')!=sha(ROOT/'assets/sprites/cards'/f'{id}.png'):errors.append([id,'old_card_changed'])
class Links(HTMLParser):
 def handle_starttag(self,tag,attrs):
  global links
  for k,v in attrs:
   if k in ['src','href']and v and not v.startswith(('http:','https:','#','data:')):
    links+=1
    if not(R/unquote(v.split('#')[0])).exists():errors.append(['broken_gallery_link',v])
Links().feed((R/'gallery.html').read_text())
for p in R.rglob('*.json'):
 try:json.loads(p.read_text())
 except Exception as e:errors.append(['invalid_json',str(p.relative_to(R)),str(e)])
report={'task':m['task'],'status':'pass'if not errors else'fail','delivered_cards':len(m['files']),'generation_calls':len(jobs),'decoded_originals':len(jobs),'rejected_originals':sum(not j['selected']for j in jobs),'candidate_approved_runtime_triplets_checked':len(m['files']),'mipmap_levels_checked':levels,'gallery_links_checked':links,'original_four_cards_unchanged':not any('old_card_changed'in e for e in errors),'errors':errors,'visual_review':'Performed during generation and preview review; this script checks files, not anatomy.','godot_mipmaps_configured':False,'game_test':'not_performed'}
(R/'records/final_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2));raise SystemExit(bool(errors))
