from pathlib import Path
import subprocess,json,time,hashlib
root=Path('/Users/zhangjunqiu/Desktop/无限恐怖');qa=root/'assets/source/taskK_independent_qa_2026-10-20'
def active():
 lines=subprocess.check_output(['ps','-Ao','pid=,command='],text=True).splitlines()
 return [x.strip() for x in lines if x.strip().split(' ',1)[-1].startswith(('/Applications/Godot.app/Contents/MacOS/Godot ','/opt/homebrew/bin/godot '))]
while active():time.sleep(1)
records=[]
def run(name,script,extra=(),render=False):
 cmd=['/opt/homebrew/bin/godot',*([] if render else ['--headless']),'--path',str(root),*(['--max-fps','60'] if render else ['--fixed-fps','60']),'--script',script,'--',f'--save-file={qa}/{name}_save.json',f'--settings-file={qa}/settings_zh.cfg',f'--output={qa}/results/{name}',*extra]
 before=active();t=time.time();others=[]
 with (qa/f'logs/{name}.log').open('w') as log:
  child=subprocess.Popen(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
  while child.poll() is None:
   others.extend(x for x in active() if not x.startswith(str(child.pid)+' '));time.sleep(0.5)
 records.append({'name':name,'command':cmd,'exit_code':child.returncode,'wall_seconds':time.time()-t,'other_godot_before':before,'other_godot_during':sorted(set(others))})
 (qa/'post_density_commands.json').write_text(json.dumps(records,indent=2,ensure_ascii=False))
 print(name,child.returncode,flush=True)
 return child.returncode
if run('density_buffers','tools/test_density_buffers.gd')==0:
 run('density_after','tools/acceptance_vigrid_soak.gd',['--seconds=55','--stages=-1,1','--awake=odin','--reentries=0'],True)
 run('release_combat_v4','res://assets/source/taskK_independent_qa_2026-10-20/diagnostics/combat.gd')
 s=json.loads((qa/'results/density_after/soak.json').read_text())
 if s['violations']:
  run('density_profile_fixed','tools/acceptance_vigrid_soak.gd',['--seconds=30','--stages=-1','--awake=odin','--reentries=0','--profile-gods'],True)
