from pathlib import Path
import datetime
import json
import subprocess

B=Path(__file__).parent.resolve()
R=B/'runtime'
G='/Applications/Godot.app/Contents/MacOS/Godot'
jobs=[
 ('soak','acceptance_vigrid_soak',['--seconds=180','--reentries=12']),
 ('realtime_meta','acceptance_vigrid_run',['--meta-max']),
]
status=[]
for ident,script,extra in jobs:
    out=B/'results'/ident
    out.mkdir(exist_ok=True)
    command=[G,'--path',str(R),'--script',f'res://tools/{script}.gd','--',
        f'--save-file={B}/saves/{ident}.json',f'--settings-file={B}/saves/{ident}.cfg',f'--output={out}/']+extra
    row={'id':ident,'command':command,'started':datetime.datetime.now().isoformat(),'status':'running'}
    status.append(row)
    (B/'long_test_status.json').write_text(json.dumps(status,indent=2))
    with (B/'logs'/f'{ident}.log').open('w') as log:
        result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
    row.update(status='finished',exit_code=result.returncode,finished=datetime.datetime.now().isoformat())
    (B/'long_test_status.json').write_text(json.dumps(status,indent=2))
    print(json.dumps(row),flush=True)
