from pathlib import Path
import subprocess,json,time
root=Path('/Users/zhangjunqiu/Desktop/无限恐怖');qa=root/'assets/source/taskK_independent_qa_2026-10-20';records=[]
tasks=[('fx_cadence','tools/test_god_fx_cadence.gd',[],False),('fx_combat','res://assets/source/taskK_independent_qa_2026-10-20/diagnostics/combat.gd',[],False),('fx_odin','tools/test_odin_density.gd',[],False),('fx_skadi','tools/test_skadi_balance.gd',[],False),('fx_review','tools/review_god_fx_cadence.gd',[],True)]
for lang in ['zh','en']:tasks.append(('fx_card_'+lang,'res://assets/source/taskK_independent_qa_2026-10-20/diagnostics/card_layout.gd',[f'--ids-file={root}/assets/source/taskL1_paths_2026-10-20/integration_2026-10-20/card_ids.json'],False))
for name,script,extra,render in tasks:
 lang='en' if name.endswith('_en') else 'zh';out=qa/('screenshots/fx_final' if name=='fx_review' else f'results/{name}')
 cmd=['/opt/homebrew/bin/godot',*([] if render else ['--headless']),'--path',str(root),'--fixed-fps','60','--script',script,'--',f'--save-file={qa}/{name}_save.json',f'--settings-file={qa}/settings_{lang}.cfg',f'--output={out}/',*extra]
 t=time.time()
 with (qa/f'logs/{name}_final.log').open('w') as log:r=subprocess.run(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 body=(qa/f'logs/{name}_final.log').read_text();errors=[x for x in body.splitlines() if x.startswith(('SCRIPT ERROR:','ERROR:'))]
 records.append({'name':name,'command':cmd,'exit_code':r.returncode,'wall_seconds':time.time()-t,'engine_errors':errors})
 (qa/'fx_final_commands.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
 print(name,r.returncode,len(errors),flush=True)
