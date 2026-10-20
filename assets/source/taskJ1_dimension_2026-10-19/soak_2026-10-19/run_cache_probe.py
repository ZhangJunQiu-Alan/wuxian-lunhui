from pathlib import Path
import csv,json,subprocess,time,sys
base=Path(__file__).resolve().parent
smoke='--smoke' in sys.argv
out=base/'cache_probe';out.mkdir(exist_ok=True)
run=base/'runtime'
args=['godot','--path',str(run),'--max-fps','60','--script','tools/cache_probe.gd','--','--save-file=res://validation/soak_save.json','--settings-file=res://validation/soak_settings.cfg']
if smoke:args+=['--smoke']
with (out/'console.log').open('w') as log,(out/'rss.csv').open('w',newline='') as rss:
 writer=csv.writer(rss);writer.writerow(['seconds','rss_kib','cpu_percent']);start=time.monotonic()
 p=subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT)
 (base/'process.json').write_text(json.dumps({'pid':p.pid,'output':str(out),'smoke':smoke,'args':args},indent=2)+'\n')
 while p.poll() is None:
  r=subprocess.run(['ps','-o','rss=,%cpu=','-p',str(p.pid)],text=True,capture_output=True)
  parts=r.stdout.split()
  if len(parts)==2:writer.writerow([round(time.monotonic()-start,3),*parts]);rss.flush()
  time.sleep(3)
 code=p.wait()
 for f in (run/'validation').iterdir():
  if f.suffix in ['.json','.png']:
   import shutil
   shutil.copy2(f,out/f.name)
 (out/'process_exit.json').write_text(json.dumps({'returncode':code,'wall_seconds':time.monotonic()-start},indent=2)+'\n')
 print(json.dumps({'output':str(out),'returncode':code,'seconds':round(time.monotonic()-start,1)}))
 raise SystemExit(code)
