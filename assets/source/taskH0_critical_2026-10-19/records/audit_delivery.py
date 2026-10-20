from pathlib import Path
from PIL import Image,ImageSequence,ImageStat
import hashlib,json,re,ast
R=Path(__file__).resolve().parents[4];H=Path(__file__).resolve().parent.parent
PLAN=json.loads((H/'records/plan_all_H.json').read_text());BG=(18,23,33,255)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def check(ok,message):
 if not ok:errors.append(message)
errors=[];groups=[];total_frames=0;gifs=0;total_links=0;orig_count=0;refs_count=0;allpaths=[]
for task in [f'H{i}'for i in range(7)]:
 r=R/next(a['source_root']for a in PLAN if a['task']==task);manifest=json.loads((r/'manifest.json').read_text());group_errors=len(errors);files=manifest['files'];frame_count=0;gif_local=0
 check(len(files)==len([a for a in PLAN if a['task']==task]),task+' expected file count')
 for name in ['README.md','integration.md','gallery.html','manifest.json','records/generation_jobs.json','records/visual_reviews.json']:
  check((r/name).exists(),task+' missing '+name)
 for a in files:
  id=a['id'];paths=[R/a['target'],r/a['candidate'],r/a['approved']];allpaths.append(a['target'])
  for p in paths:check(p.exists(),id+' missing '+str(p))
  hashes=[sha(p)for p in paths];check(len(set(hashes+[a['sha256']]))==1,id+' runtime/candidate/approved/manifest hash')
  with Image.open(paths[0])as im:
   im.load();check(im.format=='PNG'and im.mode=='RGBA',id+' mode/format');check(im.size==(a['w']*a['frames'],a['h']),id+' size');im=im.copy()
  pixels=list(im.getdata());colors={p[:3]for p in pixels if p[3]};alphas=sorted({p[3]for p in pixels});check(len(colors)<=48 and len(colors)==a['actual_RGB_colors'],id+' RGB budget/count');check(alphas==a['actual_alpha_values'],id+' alpha metadata');check(alphas[0]==0,id+' no true transparency');check(all(p[:3]==(0,0,0)for p in pixels if not p[3]),id+' hidden RGB')
  if'body'in a['flags']or'chain'in a['flags']:check(set(alphas)<={0,255},id+' binary alpha')
  frames=[im.crop((k*a['w'],0,(k+1)*a['w'],a['h']))for k in range(a['frames'])];frame_count+=len(frames);total_frames+=len(frames)
  check(len({hashlib.sha256(f.tobytes()).hexdigest()for f in frames})==len(frames),id+' duplicate frame')
  tile='tile'in a['flags'];ports='band'in a['flags']or'chain'in a['flags']
  for f in frames:
   box=f.getbbox();check(box is not None,id+' empty frame')
   if not(tile or ports):check(box[0]>=2 and box[1]>=2 and box[2]<=a['w']-2 and box[3]<=a['h']-2,id+' 2px margins')
   if'body'in a['flags']:check(box[3]==a['anchor'][1],id+' foot baseline')
   if'hole'in a['flags']:check(f.getchannel('A').crop((round(a['w']*.45),round(a['h']*.45),round(a['w']*.55),round(a['h']*.55))).getextrema()==(0,0),id+' center hole')
   if'front'in a['flags']:check(f.getchannel('A').crop((0,0,a['w']//2,a['h'])).getextrema()==(0,0),id+' rear half')
   if ports or tile:check(f.crop((0,0,1,a['h'])).tobytes()==f.crop((a['w']-1,0,a['w'],a['h'])).tobytes(),id+' horizontal repeat ports')
   if tile:check(f.crop((0,0,a['w'],1)).tobytes()==f.crop((0,a['h']-1,a['w'],a['h'])).tobytes(),id+' vertical repeat ports')
  if id.startswith('thokk_'):
   base=Image.open(R/'assets/sprites/enemies/thokk.png');check(colors<={p[:3]for p in base.getdata()if p[3]},id+' static palette')
  if id=='skoll_howl_body':
   base=Image.open(R/'assets/sprites/bosses/skoll.png').convert('RGBA');check(colors<={p[:3]for p in base.getdata()if p[3]},id+' static wolf palette')
  check((a['code_integration'],a['game_acceptance']) in [('not_performed','not_performed'),('integrated','controlled_runtime_verified')],id+' status boundary')
  if a['code_integration']=='integrated':check(bool(a.get('runtime_verification',{}).get('scope')),id+' runtime scope missing')
  check(bool(a['hook'])and bool(a['keep'])and bool(a['visual_review']['observations']),id+' handoff/review missing')
  check(bool(a.get('transparent_strategy'))and bool(a.get('loop_mode')),id+' transparent/playback specification')
  norm=r/'records'/f'normalization_{id}_{a["version"]}.json';check(norm.exists(),id+' normalization source missing')
  if norm.exists():check(json.loads(norm.read_text())['candidate_sha256']==a['sha256'],id+' normalization hash')
  for label,fps in [('native',a['fps']),('slow8',8)]:
   if len(frames)<2:continue
   path=r/'previews'/f'{id}_{a["version"]}_{label}.gif';check(path.exists(),id+' GIF missing');g=Image.open(path);count=0;ms=0
   for k,f in enumerate(ImageSequence.Iterator(g)):
    expected=Image.new('RGBA',(a['w'],a['h']),BG);expected.alpha_composite(frames[k%len(frames)]);expected=expected.convert('RGB').resize((a['w']*4,a['h']*4),Image.Resampling.NEAREST)
    check(expected.tobytes()==f.convert('RGB').tobytes(),id+' '+label+' GIF pixels frame'+str(k));ms+=f.info.get('duration',0);count+=1
   check(ms>0 and abs(count*1000/ms-fps)<.001,id+' '+label+' GIF fps');gifs+=1;gif_local+=1
  check(a['sha256']in(r/'integration.md').read_text(),id+' integration hash')
 for p in r.rglob('*.json'):
  try:json.loads(p.read_text())
  except Exception as e:errors.append(str(p)+' invalid JSON '+str(e))
 for p in r.rglob('*.py'):
  try:ast.parse(p.read_text())
  except Exception as e:errors.append(str(p)+' invalid Python '+str(e))
 originals=[]
 for p in sorted((r/'originals').glob('*.png')):
  with Image.open(p)as im:im.load()
  originals.append({'file':str(p.relative_to(r)),'sha256':sha(p),'bytes':p.stat().st_size});orig_count+=1
 check({x['file']:x['sha256']for x in originals}=={x['file']:x['sha256']for x in manifest['originals']},task+' original manifest hashes')
 refs=json.loads((r/'records/source_inventory.json').read_text())['references']
 for ref in refs:check(sha(r/ref['archived_path'])==ref['sha256'],task+' reference hash '+ref['archived_path']);refs_count+=1
 for page in [r/'gallery.html']+([r/'handoff.html']if task=='H0'else[]):
  links=re.findall(r'(?:src|href)="([^"]+)"',page.read_text());total_links+=len(links)
  for url in links:
   if ':'not in url and not url.startswith('#'):check((page.parent/url).exists(),task+' broken page link '+url)
 group={'task':task,'files_checked':len(files),'source_originals_decoded':len(originals),'frames_checked':frame_count,'GIFs_decoded_checked':gif_local,'status':'pass'if group_errors==len(errors)else'fail','code_integration':manifest.get('code_integration','not_performed'),'game_acceptance':manifest.get('game_acceptance','not_performed')};groups.append(group);save(r/'records/final_audit.json',group)
check(len(allpaths)==33 and len(set(allpaths))==33,'unique 33 runtime paths')
# Actual source-based repeat texture luminance comparison, not game output.
means={}
for id in ['hel_life_ground','hel_death_ground']:
 im=Image.open(R/f'assets/sprites/effects/bosses/{id}.png').convert('RGBA');bg=Image.new('RGBA',im.size,BG);bg.alpha_composite(im);means[id]=ImageStat.Stat(bg.convert('L')).mean[0]
check(abs(means['hel_life_ground']-means['hel_death_ground'])<2,'life/death dark-overlay luminance mismatch')
report={'date':'2026-10-19','status':'pass'if not errors else'fail','formal_files':len(allpaths),'unique_formal_paths':len(set(allpaths)),'total_frames_checked':total_frames,'GIFs_decoded_checked':gifs,'originals_decoded_and_hashed':orig_count,'archived_reference_hashes_checked':refs_count,'local_links_checked':total_links,'groups':groups,'life_death_overlay_mean_grey':means,'errors':errors,'production':'delivered','file_self_checks':'pass'if not errors else'fail','code_integration':'integrated'if all(g['code_integration']=='integrated'for g in groups)else'mixed','game_acceptance':'controlled_runtime_verified'if all(g['game_acceptance']=='controlled_runtime_verified'for g in groups)else'mixed','scope':'H0 through H6 only; no G6/I/J/K/L work; no commits or pushes'}
save(H/'records/final_delivery_audit.json',report);print(json.dumps(report,ensure_ascii=False,indent=2));raise SystemExit(bool(errors))
