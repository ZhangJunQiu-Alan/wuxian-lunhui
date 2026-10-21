from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import unquote
import hashlib,json
p=Path(__file__).resolve().parent;repo=p.parents[2];r=p/'runtime'
class Links(HTMLParser):
 def __init__(self):super().__init__();self.links=[]
 def handle_starttag(self,tag,attrs):
  for key,value in attrs:
   if key in ['href','src'] and value and not value.startswith(('http:','https:','#','data:')):self.links.append(value)
parser=Links();parser.feed((p/'gallery.html').read_text());missing=[x for x in parser.links if not (p/unquote(x.split('#')[0])).exists()]
changed=[]
for folder in ['scripts','scenes','locale']:
 for file in (repo/folder).rglob('*'):
  if file.is_file() and (r/file.relative_to(repo)).is_file() and file.read_bytes()!=(r/file.relative_to(repo)).read_bytes():changed.append(str(file.relative_to(repo)))
rows=json.loads((p/'commands.json').read_text());engine_bad=[x['id']for x in rows if x.get('engine_errors') or x.get('running')]
realtime=json.loads((p/'realtime_command.json').read_text()) if (p/'realtime_command.json').exists() else {}
report={'gameplay_source_matches_test_snapshot':not changed,'gameplay_mismatches':changed,'gallery_links':len(parser.links),'missing_links':missing,'technical_suite_errors':engine_bad,'expected_normal_bare_loss':next((x['exit_code']==1 for x in rows if x['id']=='normal_bare_probe'),False),'realtime_running':realtime.get('running'), 'realtime_engine_errors':realtime.get('engine_errors'),'git_commit':False,'git_push':False}
(p/'results/delivery_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
paths=[x for x in p.rglob('*') if x.is_file() and 'runtime' not in x.relative_to(p).parts and x.name!='SHA256SUMS.json']
(p/'SHA256SUMS.json').write_text(json.dumps({str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in paths},ensure_ascii=False,indent=2))
print(json.dumps(report,ensure_ascii=False))
