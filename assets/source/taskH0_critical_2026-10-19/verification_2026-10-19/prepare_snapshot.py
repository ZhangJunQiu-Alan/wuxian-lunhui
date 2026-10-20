from pathlib import Path
import shutil,json,hashlib
v=Path(__file__).resolve().parent
r=v.parents[3]
p=v/'runtime_snapshot'
if p.exists():raise SystemExit('runtime_snapshot already exists; preserve or remove only this test copy before preparing another')
(v/'.gdignore').write_text('')
p.mkdir()
files=[]
for sub in ['scripts','scenes','assets','locale']:
 for src in (r/sub).rglob('*'):
  rel=src.relative_to(r)
  if sub=='assets' and len(rel.parts)>1 and rel.parts[1]=='source':continue
  if not src.is_file() or src.suffix in ['.import','.uid'] or '.godot' in rel.parts:continue
  dst=p/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
  files.append({'path':str(rel),'sha256':hashlib.sha256(src.read_bytes()).hexdigest()})
shutil.copy2(r/'project.godot',p/'project.godot')
files.append({'path':'project.godot','sha256':hashlib.sha256((r/'project.godot').read_bytes()).hexdigest()})
(p/'tools').mkdir(exist_ok=True)
shutil.copy2(v/'test_combat_regressions_snapshot.gd',p/'tools/test_combat_regressions.gd')
for name in ['verify_h_runtime.gd','render_thokk.gd']:shutil.copy2(v/name,p/name)
shutil.copy2(v.parent/'records/plan_all_H.json',p/'h_plan.json')
(v/'rerun_snapshot_inventory.json').write_text(json.dumps(files,ensure_ascii=False,indent=2)+'\n')
print(p)
