from pathlib import Path
import subprocess,json,time,os
root=Path('/Users/zhangjunqiu/Desktop/无限恐怖');qa=root/'assets/source/taskK_independent_qa_2026-10-20'
records=[]
start=time.time()
def active_godot():
 lines=subprocess.check_output(['ps','-Ao','pid=,command='],text=True).splitlines()
 return [x.strip() for x in lines if ('/Godot ' in x or '/godot ' in x) and '--path' in x and 'ps -Ao' not in x]
while active_godot():
 (qa/'exclusive_wait.json').write_text(json.dumps({'state':'waiting_for_existing_godot','elapsed_seconds':time.time()-start,'processes':active_godot()},ensure_ascii=False,indent=2))
 time.sleep(1)
(qa/'exclusive_wait.json').write_text(json.dumps({'state':'starting_exclusive','wait_seconds':time.time()-start,'other_godot':active_godot()},ensure_ascii=False,indent=2))
for name,stages,awake,reentry in [('exclusive_odin','-1,1','odin',0),('exclusive_skadi','0,2','skadi',12)]:
 cmd=['/opt/homebrew/bin/godot','--path',str(root),'--max-fps','60','--script','tools/acceptance_vigrid_soak.gd','--','--seconds=55',f'--stages={stages}',f'--awake={awake}',f'--reentries={reentry}',f'--save-file={qa}/{name}_save.json',f'--settings-file={qa}/settings_zh.cfg',f'--output={qa}/results/{name}']
 before=active_godot();t=time.time()
 with (qa/f'logs/{name}.log').open('w') as log:
  child=subprocess.Popen(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
  competitors=[]
  while child.poll() is None:
   competitors.extend(x for x in active_godot() if not x.startswith(str(child.pid)+' '))
   time.sleep(1)
 records.append({'name':name,'command':cmd,'exit_code':child.returncode,'wall_seconds':time.time()-t,'other_godot_before':before,'other_godot_during':sorted(set(competitors))})
 (qa/'exclusive_commands.json').write_text(json.dumps(records,indent=2,ensure_ascii=False))
 print(name,child.returncode,flush=True)
