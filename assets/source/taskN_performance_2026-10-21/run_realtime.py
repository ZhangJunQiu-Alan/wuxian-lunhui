from pathlib import Path
import subprocess,json,time
p=Path(__file__).resolve().parent;repo=p.parents[2];out=p/'results/normal_realtime';out.mkdir(parents=True,exist_ok=True)
cmd=['/Applications/Godot.app/Contents/MacOS/Godot','--path',str(repo),'--max-fps','60','--script','tools/acceptance_vigrid_normal.gd','--','--meta-max','--seed=20261020','--save-file='+str(p/'saves/normal_realtime.json'),'--settings-file='+str(p/'saves/normal_realtime.cfg'),'--output='+str(out)]
row={'command':cmd,'running':True,'mode':'real-window real-time normal-damage bot, max legitimate meta, no invincible/clock/enemy overrides'}
(p/'realtime_command.json').write_text(json.dumps(row,ensure_ascii=False,indent=2));start=time.monotonic()
with (p/'logs/normal_realtime.log').open('w') as log:
 try:
  result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=1350)
  row['exit_code']=result.returncode
 except subprocess.TimeoutExpired:row['exit_code']='timeout'
row['running']=False;row['wall_seconds']=round(time.monotonic()-start,3)
text=(p/'logs/normal_realtime.log').read_text();row['engine_errors']=any(s in text for s in ['SCRIPT ERROR:','ERROR:','ObjectDB instances leaked','resources still in use'])
(p/'realtime_command.json').write_text(json.dumps(row,ensure_ascii=False,indent=2));print(json.dumps(row,ensure_ascii=False),flush=True)
