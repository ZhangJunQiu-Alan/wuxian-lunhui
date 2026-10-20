from pathlib import Path
import hashlib,json,shutil,subprocess
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[3]
RUN=BASE/'runtime'
head=json.loads((BASE/'scope.json').read_text())['commit']
if RUN.exists():raise SystemExit('Existing runtime retained; inspect/remove only this rebuildable copy before preparing.')
RUN.mkdir()
for name in subprocess.check_output(['git','ls-tree','-r','--name-only',head],cwd=ROOT,text=True).splitlines():
 if name.startswith(('scripts/','scenes/','locale/','tools/')) or name=='project.godot':
  dest=RUN/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(subprocess.check_output(['git','show',head+':'+name],cwd=ROOT))
 elif name.startswith('assets/') and not name.startswith('assets/source/'):
  dest=RUN/name;dest.parent.mkdir(parents=True,exist_ok=True);
  expected=json.loads((BASE/'runtime_asset_inputs.json').read_text()).get(name)
  if expected and hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=expected:raise SystemExit('Asset differs from measured input: '+name)
  shutil.copy2(ROOT/name,dest)
for name in ['soak_combat_art.gd','cache_probe.gd']:
 shutil.copy2(BASE/name,RUN/'tools'/name)
(RUN/'.gdignore').write_text('')
(RUN/'validation').mkdir()
paths=['res://'+str(p.relative_to(RUN)) for p in (RUN/'assets').rglob('*') if p.is_file() and p.suffix in ['.png','.otf','.ogg','.wav','.tres']]
(RUN/'validation/cache_paths.json').write_text(json.dumps(paths)+'\n')
print('Prepared isolated',head,'runtime. Run Godot --headless --editor --import before run_soak.py.')
