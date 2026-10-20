from pathlib import Path
import hashlib,json
B=Path(__file__).resolve().parent;R=B.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
checks=[]
def ck(n,ok,d=None):checks.append(dict(check=n,passed=bool(ok),detail=d))
batches=[];formal=[];stale=[]
for key in ['K1','K2','K3','K4','K5','K6','K7']:
 paths=sorted((R/'assets/source').glob('task'+key+'_*'));ck(key+':single_taskfolder',len(paths)==1)
 p=paths[0];manifest=json.loads((p/'manifest.json').read_text());audit=json.loads((p/'records/final_audit.json').read_text());ck(key+':selfcheck_no_failures',audit['failures']==0)
 for f in ['README.md','integration.md','gallery.html','manifest.json','completion.json','source_inventory.json']:ck(key+':'+f,(p/f).exists())
 for a in manifest.get('assets',[]):
  formal.append(dict(task=key,path=a['formal_path'],sha256=a['sha256'],frames=a.get('frames')));ck(key+':formal:'+a['id'],sha(R/a['formal_path'])==a['sha256'])
  if a.get('candidate'):ck(key+':candidate:'+a['id'],sha(p/a['candidate'])==a['sha256'])
  elif a.get('file'):ck(key+':candidate:'+a['id'],sha(p/a['file'])==a['sha256'])
  approved=p/a.get('approved','approved/'+Path(a['formal_path']).name);ck(key+':approved:'+a['id'],sha(approved)==a['sha256'])
 inventory=json.loads((p/'source_inventory.json').read_text())
 for i in inventory:
  item=p/i['path']
  if not item.exists() or sha(item)!=i['sha256']:stale.append(dict(task=key,path=i['path']))
 batches.append(dict(task=key,directory=str(p.relative_to(R)),self_checks=audit['checks'],self_check_failures=audit['failures'],formal_png=manifest.get('formal_png',0),frames=manifest.get('frames',0),formal_audio=manifest.get('formal_wav',0)+manifest.get('formal_ogg',0),manifest_sha256=sha(p/'manifest.json'),game_acceptance='not_tested'))
ck('47uniquepaths',len(formal)==47 and len({r['path'] for r in formal})==47);ck('42png156frames',sum(r['formal_png'] for r in batches)==42 and sum(r['frames'] for r in batches)==156);ck('source_inventory_no_stale',not stale,stale)
d=dict(scope='current formal/candidate/approved hashes and delivery metadata; no game acceptance',checks=len(checks),failures=sum(not c['passed'] for c in checks),items=checks,batches=batches,formal_files=formal,total_formal_png=42,total_frames=156,total_formal_audio=5,total_batch_self_checks=sum(r['self_checks'] for r in batches),git_commit=False,git_push=False)
(B/'records/delivery_audit.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:d[k] for k in ['checks','failures','total_batch_self_checks','total_formal_png','total_frames','total_formal_audio']},ensure_ascii=False));print('stale',stale[:20])
if d['failures']:raise SystemExit(1)
