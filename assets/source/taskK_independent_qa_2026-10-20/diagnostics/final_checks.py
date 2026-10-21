from pathlib import Path
import subprocess,json,time
root=Path('/Users/zhangjunqiu/Desktop/无限恐怖')
qa=root/'assets/source/taskK_independent_qa_2026-10-20'
godot='/opt/homebrew/bin/godot'
records=[]
def run(name,script=None,extra=(),settings='zh',editor=False):
 cmd=[godot,'--headless','--path',str(root)]
 if editor:cmd+=['--editor','--import']
 else:cmd+=['--fixed-fps','60','--script',script,'--',f'--save-file={qa}/{name}_save.json',f'--settings-file={qa}/settings_{settings}.cfg',*extra]
 start=time.time()
 with (qa/f'logs/{name}.log').open('w') as log:
  result=subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 records.append({'name':name,'command':cmd,'exit_code':result.returncode,'wall_seconds':time.time()-start})
 (qa/'final_commands.json').write_text(json.dumps(records,indent=2,ensure_ascii=False))
 print(name,result.returncode,flush=True)

for lang in ['zh','en']:
 run('release_card_'+lang,'res://assets/source/taskK_independent_qa_2026-10-20/diagnostics/card_layout.gd',[f'--output={qa}/results/release_card_{lang}/',f'--ids-file={root}/assets/source/taskL1_paths_2026-10-20/integration_2026-10-20/card_ids.json'],lang)
run('release_combat_v3','res://assets/source/taskK_independent_qa_2026-10-20/diagnostics/combat.gd')
run('release_flow_v2','tools/acceptance_vigrid_run.gd',['--invincible','--meta-max',f'--output={qa}/results/release_flow_v2'])
