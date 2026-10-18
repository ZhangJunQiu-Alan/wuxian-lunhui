from pathlib import Path
import json,shutil,subprocess

ROOT=Path(__file__).resolve().parents[4]
BASE=Path(__file__).resolve().parent
RUN=BASE/'runtime_commit'
info=json.loads((BASE/'commit_candidate_base.json').read_text())
head=info['head']
if RUN.exists():
    raise SystemExit('Runtime already exists; use it or remove only this rebuildable copy first.')
RUN.mkdir()
names=subprocess.check_output(['git','ls-tree','-r','--name-only',head],cwd=ROOT,text=True).splitlines()
for name in names:
    dest=RUN/name
    if name.startswith(('scripts/','scenes/','locale/','tools/')) or name=='project.godot':
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(subprocess.check_output(['git','show',head+':'+name],cwd=ROOT))
    elif name.startswith('assets/') and not name.startswith('assets/source/'):
        dest.parent.mkdir(parents=True,exist_ok=True)
        if (ROOT/name).exists():shutil.copy2(ROOT/name,dest)
for name,edits in json.loads((BASE/'changes.json').read_text()).items():
    dest=RUN/name
    source=dest.read_text()
    for edit in edits:
        assert source.count(edit['old'])==1,name
        source=source.replace(edit['old'],edit['new'])
    dest.write_text(source)
for name in ['scripts/effects/combat_fx.gd','tools/test_combat_art.gd','tools/review_combat_art.gd']:
    dest=RUN/name
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/name,dest)
    uid=ROOT/(name+'.uid')
    if uid.exists():shutil.copy2(uid,RUN/(name+'.uid'))
for batch in sorted((ROOT/'assets/source').glob('taskJ*_2026-10-19')):
    for asset in json.loads((batch/'manifest.json').read_text())['files']:
        name=asset['formal_path']
        dest=RUN/name
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/name,dest)
(RUN/'validation').mkdir()
(RUN/'.gdignore').write_text('')
print(RUN)
