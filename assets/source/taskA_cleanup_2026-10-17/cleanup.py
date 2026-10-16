from pathlib import Path
import json,re,hashlib,sys
R=Path(__file__).resolve().parent;A=R.parents[1];rules=json.loads((R/'rules.json').read_text());ids=[(''.join(map(chr,a)),b) for a,b in rules['identifiers']];names=[''.join(map(chr,x)) for x in rules['names']];marker='[已删除人物名]'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rename_text(s):
 for old,new in ids:s=re.sub(re.escape(old),new,s,flags=re.I)
 return s
def redact_names(s):
 for n in sorted(names,key=len,reverse=True):s=re.sub(re.escape(n),marker,s,flags=re.I)
 return s
def prompt(s):
 s=redact_names(s)
 for old,new in ids:s=re.sub(r'\b'+old+r'(?=[_./-])',new,s,flags=re.I)
 for old,new in ids:s=re.sub(old,marker,s,flags=re.I)
 return s
def edit(s,p):
 if p.suffix.lower()=='.txt' and 'prompt' in p.name.lower():return prompt(s)
 if p.suffix.lower() in ['.json','.piskel']:
  rx=r'("[^"\\]*(?:prompt|instruction)[^"\\]*"\s*:\s*)("(?:\\.|[^"\\])*")'
  def change(m):
   key=json.loads(m[1].split(':')[0]);value=json.loads(m[2]);return m[0] if 'file' in key or 'path' in key else m[1]+json.dumps(prompt(value),ensure_ascii=False)
  s=re.sub(rx,change,s,flags=re.I)
 s=redact_names(s);s=rename_text(s)
 if p==A/'LICENSES.md':
  s=re.sub(r'角色素材的文件名从原型人物名改为职业名：.*?(?=\n\n|\Z)','早期文件名用了原型人物名，已统一改为职业名。历史提示词只遮盖人物名，未改写成新的生成提示词。',s,flags=re.S)
 return s
protected={str(p.relative_to(A)):digest(p) for group in ['sprites','audio'] for p in (A/group).rglob('*') if p.is_file()}
changes=[];renames=[];binary_refs=[]
# Work on a snapshot of the old file tree; no generated report contains the removed spelling.
files=[p for p in A.rglob('*') if p.is_file() and R not in p.parents]
for p in files:
 data=p.read_bytes()
 try:s=data.decode('utf-8')
 except UnicodeDecodeError:
  if any(old.encode() in data.lower() for old,new in ids):binary_refs.append(str(p.relative_to(A)))
  continue
 if not any(re.search(re.escape(n),s,re.I) for n in names+[a for a,b in ids]):continue
 if p.parts[len(A.parts)] in ['sprites','audio']:raise RuntimeError('Protected game file contains a name; no change made')
 t=edit(s,p)
 if t!=s:
  before=digest(p);p.write_text(t,encoding='utf-8');changes.append({'path':rename_text(str(p.relative_to(A))),'before_sha256':before,'after_sha256':digest(p),'action':'identifier paths updated; recorded proper names redacted in place'})
for p in sorted([p for p in A.rglob('*') if R not in p.parents],key=lambda p:len(p.parts),reverse=True):
 new=rename_text(p.name)
 for n in names:new=re.sub(re.escape(n),marker,new,flags=re.I)
 if new==p.name:continue
 if p.parts[len(A.parts)] in ['sprites','audio']:raise RuntimeError('Protected path needs rename')
 target=p.with_name(new)
 if target.exists():raise RuntimeError('Rename collision:'+str(target))
 oldhash=hashlib.sha256(str(p.relative_to(A)).encode()).hexdigest();p.rename(target);renames.append({'removed_path_sha256':oldhash,'new_path':rename_text(str(target.relative_to(A))),'kind':'directory' if target.is_dir() else 'file'})
assert not binary_refs,binary_refs
assert all((A/p).exists() and digest(A/p)==h for p,h in protected.items())
(R/'runtime_hashes.json').write_text(json.dumps(protected,ensure_ascii=False,indent=2));(R/'manifest.json').write_text(json.dumps({'task':'A','date':'2026-10-17','status':'edited_pending_reference_audit','text_files_changed':len(changes),'paths_renamed':len(renames),'protected_runtime_files_verified':len(protected),'changes':changes,'renames':renames,'original_art_bytes_changed':False,'redaction_note':'Historical recorded prompts retain their original wording except proper-name redaction; old plaintext backups are intentionally not reintroduced.'},ensure_ascii=False,indent=2));print(json.dumps({'text_files_changed':len(changes),'paths_renamed':len(renames),'runtime_files_unchanged':len(protected)},ensure_ascii=False))
