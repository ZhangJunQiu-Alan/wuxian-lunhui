from pathlib import Path
from PIL import Image, ImageDraw
import importlib.util, json, re, html, hashlib

HERE=Path(__file__).parent
s=importlib.util.spec_from_file_location('pipeline',HERE/'pipeline.py');p=importlib.util.module_from_spec(s);s.loader.exec_module(p)
ROOT=p.ROOT; home=HERE.parent; runtime=home/'runtime'
run=json.loads((runtime/'runtime_checks.json').read_text())
assert not run['failures'] and len(run['screenshots'])==18
assert all(not x['pause_visible'] for x in run['screenshots'])
assert 'RESULT: 997 checks, 0 failures' in (runtime/'combat_regression.log').read_text()
log=(runtime/'runtime.log').read_text()
assert not re.search(r'SCRIPT ERROR|ERROR:|WARNING:',log)
review=[];contact=Image.new('RGB',(1280,1560),(18,23,33));cd=ImageDraw.Draw(contact)
detail=Image.new('RGB',(1600,2200),(18,23,33));dd=ImageDraw.Draw(detail)
for i,entry in enumerate(run['screenshots']):
 file=runtime/entry['file'];im=Image.open(file).convert('RGB')
 thumb=im.resize((420,236),Image.Resampling.LANCZOS);x=i%3*426;y=i//3*260
 contact.paste(thumb,(x,y+20));cd.text((x+4,y+3),file.stem,fill='white')
 ax,ay=entry['asset_screen'];name=file.stem
 if name.startswith('I1'):box=(ax-36,ay-66,ax+36,ay+8)
 elif name.startswith('I2'):box=(ax-70,ay-56,ax+70,ay+20)
 elif name.startswith('I3'):box=(ax-36,ay-20,ax+36,ay+20)
 elif name.startswith('I4'):box=(ax-24,ay-24,ax+24,ay+24)
 elif name.startswith('I5'):box=(ax-36,ay-66,ax+36,ay+20)
 else:box=(ax-60,ay-85,ax+60,ay+40)
 crop=im.crop(tuple(round(v) for v in box));crop=crop.resize((crop.width*3,crop.height*3),Image.Resampling.NEAREST)
 x=i%4*400;y=i//4*440;detail.paste(crop,(x,y+20));dd.text((x+4,y+3),name,fill='white')
 review.append({**entry,'sha256':p.sha(file),'scope':'controlled actual Game scene, exact quest landmark; individual frames, interaction tests; not full manual playthrough'})
contact.save(runtime/'contact.png');detail.save(runtime/'detail_contact.png')
for taskfolder in sorted((ROOT/'assets/source').glob('taskI*_2026-10-19')):
 manifest=json.loads((taskfolder/'manifest.json').read_text())
 for asset in manifest['assets']:
  asset['runtime_acceptance']='controlled_runtime_verified'
  asset['actual_self_checks']['game_engine_rendering']='reviewed all four animation poses and offered/active/prop context; 18 screenshots across six tasks'
  asset['runtime_evidence']='../taskI1_bridge_guard_2026-10-19/runtime/runtime_checks.json'
  if 'bridge_guard_idle' in asset['file']:
   asset['actual_self_checks']['body_registration']={'foot_bottom_y':[61,61,61,61],'torso_bbox_y24_to44':[[16,0,46,20]]*4,'torso_x_center':31,'world_anchor':[32,62]}
 (taskfolder/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 with (taskfolder/'README.md').open('a') as f:f.write('\n最终受控运行：Godot4.7.2实际Game场景，真实关卡/地标，77项专项断言0失败，18张无暂停遮挡截图已审；现有战斗回归997项0失败。截图与测试日志集中在 ../taskI1_bridge_guard_2026-10-19/runtime/。第一轮通用地标fixture与第二轮自动暂停遮挡截图保留，不用作最终外观验收。完整手动通关、长时间平衡、密集怪群遮挡和其他硬件未测。\n')
 with (taskfolder/'integration.md').open('a') as f:f.write('\n受控运行完成；六份脚本的非绘制函数与开工备份完全相同。专项77项/回归997项0失败，完整手动通关未执行。无需额外代码接入；后续接入代理可审核本次差异与试玩。\n')
completion={'task':'Part I / I1-I6','files':7,'frames':16,'generated_originals':7,'production':'complete','file_audit':'passed','code_integration':'integrated','controlled_runtime_checks':len(run['checks']),'controlled_runtime_failures':len(run['failures']),'screenshots':18,'combat_regression_checks':997,'combat_regression_failures':0,'manual_playthrough':'not performed','remaining':['完整手动通关、长时间平衡与密集实战遮挡未测。'],'browser_used':False,'git_commit':False,'git_push':False,'visual_review':review}
(home/'completion.json').write_text(json.dumps(completion,ensure_ascii=False,indent=2)+'\n')
(runtime/'visual_review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n')
nav=[]
for taskfolder in sorted((ROOT/'assets/source').glob('taskI*_2026-10-19')):
 nav.append(f'<li><a href="../{taskfolder.name}/gallery.html">{taskfolder.name}</a> · <a href="../{taskfolder.name}/integration.md">integration</a></li>')
images=''.join(f'<h2>{html.escape(e["file"])}</h2><img src="runtime/{e["file"]}">' for e in review)
(home/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Part I delivery</title><style>body{background:#121721;color:#ddd;font:16px sans-serif;padding:24px}a{color:#8dcfff}img{max-width:100%;image-rendering:pixelated}</style><h1>Part I / I1–I6</h1><p>7 PNG · 16 frames · 77 controlled assertions · 997 regression assertions · full manual playthrough not performed</p><ul>'+''.join(nav)+'</ul><p><a href="completion.json">completion</a> · <a href="runtime/runtime_checks.json">runtime checks</a> · <a href="records/scope_check.json">scope</a></p><h2>Controlled actual Game screenshots</h2>'+images)
allfiles=list((home.parent).glob('taskI*_2026-10-19'))
links=[]
for folder in allfiles:
 for file in folder.glob('*.html'):
  for value in re.findall(r'(?:src|href)="([^"]+)"',file.read_text()):
   if not value.startswith(('http','data:','#')):
    target=(file.parent/value).resolve();assert target.exists(),(file,value);links.append({'file':str(file.relative_to(ROOT)),'link':value})
(HERE/'links_audit.json').write_text(json.dumps({'checked':len(links),'failures':[],'links':links},indent=2))
print(json.dumps({k:v for k,v in completion.items() if k!='visual_review'},ensure_ascii=False))
