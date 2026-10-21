from pathlib import Path
import subprocess, json, time, shutil, hashlib, zipfile
p=Path(__file__).resolve().parent; repo=p.parents[2]; r=p/'runtime'; binary='/Applications/Godot.app/Contents/MacOS/Godot'
# Wait for the one pressure process so measurements never overlap another Godot run.
while True:
 listing=subprocess.check_output(['ps','-axo','pid=,comm='],text=True)
 ids=[line.strip().split()[0] for line in listing.splitlines() if line.strip().endswith('/Godot')]
 if not ids: break
 time.sleep(2)
pressure=[]
for name,candidate in [('baseline_seeded',False),('final_extreme',True)]:
 for file in ['scripts/game.gd','scripts/entities/enemy.gd']:
  if candidate: shutil.copy2(p/'candidate_final'/file,r/file)
  else:
   with zipfile.ZipFile(p/'before/source.zip') as z: (r/file).write_bytes(z.read(file))
 out=p/'results'/name;out.mkdir(exist_ok=True,parents=True)
 cmd=[binary,'--path',str(r),'--max-fps','60','--script','tools/acceptance_vigrid_soak.gd','--','--seconds=55','--stages=-1,1','--awake=odin','--reentries=0','--save-file='+str(p/f'{name}_save.json'),'--settings-file='+str(repo/'assets/source/taskK_independent_qa_2026-10-20/settings_zh.cfg'),'--output='+str(out)]
 start=time.monotonic()
 with (p/'logs'/f'{name}.log').open('w') as log:
  try: result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180); code=result.returncode
  except subprocess.TimeoutExpired: code='timeout'
 row={'id':name,'command':cmd,'exit_code':code,'wall_seconds':round(time.monotonic()-start,3)}
 pressure.append(row);(p/'pressure_commands.json').write_text(json.dumps(pressure,ensure_ascii=False,indent=2))
 print(json.dumps({k:v for k,v in row.items() if k!='command'}),flush=True)
 if code=='timeout': raise SystemExit(2)

for name in ['test_spatial_queries.gd','acceptance_vigrid_run.gd','acceptance_vigrid_normal.gd']:
 shutil.copy2(repo/'tools'/name,r/'tools'/name)
(r/'validation/quest').mkdir(parents=True,exist_ok=True)
replacements={
 'test_boss_art.gd':{'res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/runtime_checks.json':'res://validation/boss_checks.json'},
 'test_quest_art.gd':{'res://assets/source/taskI1_bridge_guard_2026-10-19/runtime/':'res://validation/quest/'},
}
for name,pairs in replacements.items():
 s=(r/'tools'/name).read_text()
 for old,new in pairs.items(): s=s.replace(old,new)
 (r/'tools'/name).write_text(s)
(p/'saves').mkdir(exist_ok=True)
# All suites use fresh isolated profiles and retain full logs; report output is redirected away from old archives.
jobs=[]
for name,script in [('spatial','test_spatial_queries'),('combat','test_combat_regressions'),('vigrid','test_vigrid'),('acceptance','acceptance_vigrid'),('god_fx','test_god_fx_cadence'),('odin','test_odin_density'),('skadi','test_skadi_balance'),('m_art','test_vigrid_art'),('boss','test_boss_art'),('cards','test_card_art'),('combat_art','test_combat_art')]:
 jobs.append((name,script,['--headless'],[],240))
for name,level,meta in [('normal_meta_probe','vigrid',True),('normal_bare_probe','vigrid',False),('midgard_meta_probe','midgard',True),('helheim_meta_probe','helheim',True)]:
 jobs.append((name,'acceptance_vigrid_normal',['--headless','--fixed-fps','60'],['--level='+level,'--meta-max'] if meta else ['--level='+level],240))
rows=[]
for name,script,flags,args,timeout in jobs:
 out=p/'results'/name;out.mkdir(parents=True,exist_ok=True)
 cmd=[binary,*flags,'--path',str(r),'--script','tools/'+script+'.gd','--','--save-file='+str(p/'saves'/f'{name}.json'),'--settings-file='+str(p/'saves'/f'{name}.cfg'),'--output='+str(out)+'/',*args]
 start=time.monotonic(); row={'id':name,'command':cmd,'running':True};rows.append(row);(p/'commands.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
 with (p/'logs'/f'{name}.log').open('w') as log:
  try:
   result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
   row['exit_code']=result.returncode
  except subprocess.TimeoutExpired: row['exit_code']='timeout'
 row['wall_seconds']=round(time.monotonic()-start,3);row['running']=False
 text=(p/'logs'/f'{name}.log').read_text();row['engine_errors']=any(t in text for t in ['SCRIPT ERROR:','ERROR:','ObjectDB instances leaked','resources still in use'])
 print(json.dumps({k:v for k,v in row.items() if k!='command'}),flush=True)
 (p/'commands.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
 if row['engine_errors'] or row['exit_code']=='timeout': break
# Preserve redirected output and exact tested sources.
shutil.copytree(r/'validation',p/'results/legacy_reports',dirs_exist_ok=True)
files=[x for folder in ['scripts','tools','scenes','locale'] for x in (r/folder).rglob('*') if x.is_file()]
(p/'tested_hashes.json').write_text(json.dumps({str(x.relative_to(r)):hashlib.sha256(x.read_bytes()).hexdigest() for x in files},indent=2))
print('CHECK_RUNNER_DONE',flush=True)
