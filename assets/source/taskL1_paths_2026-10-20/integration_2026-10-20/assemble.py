from pathlib import Path
import json, shutil, subprocess, tarfile, io, sys, hashlib

ROOT = Path(__file__).resolve().parents[4]
BASE = Path(__file__).resolve().parent
mode = sys.argv[1] if len(sys.argv) > 1 else 'current'
dest = BASE / ('runtime_' + mode)
assert not dest.exists(), dest
dest.mkdir()
if mode == 'commit':
    archive = subprocess.check_output(['git','archive','HEAD','scripts','scenes','locale','tools','project.godot'],cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(dest, filter='data')
    tracked = subprocess.check_output(['git','ls-tree','-r','--name-only','HEAD','assets'],cwd=ROOT,text=True).splitlines()
    for rel in tracked:
        if rel.startswith('assets/source/') or not (ROOT/rel).is_file(): continue
        target=dest/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,target)
else:
    for name in ['scripts','scenes','locale','tools']:
        if (ROOT/name).exists():shutil.copytree(ROOT/name,dest/name)
    shutil.copy2(ROOT/'project.godot',dest/'project.godot')
    shutil.copytree(ROOT/'assets',dest/'assets',ignore=lambda p,n: ['source'] if Path(p)==ROOT/'assets' else [])
jobs=json.loads((ROOT/'assets/source/taskL1_paths_2026-10-20/records/plan_all_L.json').read_text())
for j in jobs:
    for suffix in ['', '.import']:
        source=ROOT/(j['target']+suffix)
        if source.exists():
            target=dest/(j['target']+suffix);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
for rel in ['scripts/ui/level_up_panel.gd','tools/test_card_art.gd']:
    target=dest/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,target)
(dest/'validation').mkdir()
(dest/'validation/card_ids.json').write_text(json.dumps([j['id'] for j in jobs]))
(dest/'.gdignore').write_text('')
inventory={str(f.relative_to(dest)):hashlib.sha256(f.read_bytes()).hexdigest() for f in dest.rglob('*') if f.is_file()}
(BASE/'records'/f'runtime_{mode}_inputs.json').write_text(json.dumps({'mode':mode,'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'files':inventory},indent=2))
print(dest)
