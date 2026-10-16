from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import unquote,urlsplit
import re,json,hashlib,sys
R=Path(__file__).resolve().parent;A=R.parents[1];rules=json.loads((R/'rules.json').read_text());terms=[''.join(map(chr,a)) for a,b in rules['identifiers']]+[''.join(map(chr,a)) for a in rules['names']]
if '--patterns' in sys.argv:print('\n'.join(terms));raise SystemExit
hits=[];bad_json=[];links=[]
class Links(HTMLParser):
 def handle_starttag(self,tag,attrs):
  for k,v in attrs:
   if k in ('src','href','poster') and v and not v.startswith(('http:','https:','data:','mailto:','javascript:','#','blob:')):links.append((current,v))
for current in A.rglob('*'):
 if any(t.casefold() in str(current).casefold() for t in terms):hits.append({'type':'path','path':str(current.relative_to(A))})
 if not current.is_file():continue
 data=current.read_bytes()
 if any(t.casefold().encode() in data.lower() for t in terms):hits.append({'type':'content','path':str(current.relative_to(A))})
 try:s=data.decode('utf-8')
 except UnicodeDecodeError:continue
 if current.suffix in ('.json','.piskel'):
  try:json.loads(s)
  except json.JSONDecodeError as e:bad_json.append({'path':str(current.relative_to(A)),'error':str(e)})
 if current.suffix=='.html':
  try:Links().feed(s)
  except Exception:pass
broken=[]
for file,url in links:
 p=unquote(urlsplit(url).path)
 if not p:continue
 target=Path(p) if p.startswith('/') else file.parent/p
 if not target.exists():broken.append({'file':str(file.relative_to(A)),'reference':url,'target':str(target)})
protected=json.loads((R/'runtime_hashes.json').read_text());changed=[p for p,h in protected.items() if not (A/p).exists() or hashlib.sha256((A/p).read_bytes()).hexdigest()!=h]
report={'case_insensitive_path_and_binary_content_matches':len(hits),'matches':hits,'json_parse_failures':bad_json,'html_local_links_checked':len(links),'broken_html_links':[x for x in broken if not re.search(r'source/task[CDE]_',x['file'])],'other_agents_in_progress_links':[x for x in broken if re.search(r'source/task[CDE]_',x['file'])],'runtime_hash_changes':changed}
(R/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps({k:(len(v) if isinstance(v,list) else v) for k,v in report.items()},ensure_ascii=False))
