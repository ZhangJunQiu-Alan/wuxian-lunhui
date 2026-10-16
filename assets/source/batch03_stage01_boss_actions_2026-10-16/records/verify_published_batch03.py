from pathlib import Path
from PIL import Image
import json,hashlib
r=Path(__file__).resolve().parents[1];ar=r.parents[1];m=json.loads((r/'manifest.json').read_text());report=[]
assert m['status']=='complete_self_checked_pending_game_review' and m['final_copied_count']==15
for a in m['assets']:
 p=ar/a['final_path'];q=r/a['approved_file'];sha=hashlib.sha256(p.read_bytes()).hexdigest();assert sha==a['sha256']==hashlib.sha256(q.read_bytes()).hexdigest();im=Image.open(p);im.load();assert im.mode=='RGBA' and list(im.size)==a['size'];g=Image.open(r/a['preview_gif']);dur=[]
 for k in range(g.n_frames):g.seek(k);g.load();dur.append(g.info.get('duration',0))
 assert g.n_frames==a['frames'];assert g.size==(a['frame_size'][0]*4,a['frame_size'][1]*4);assert dur==[120 if k%2==0 else 130 for k in range(a['frames'])]
 report.append(dict(id=a['id'],final_path=a['final_path'],sha256=sha,frames=a['frames'],gif_durations=dur,validated=True))
raw=[]
for p in (r/'originals').glob('*.png'):
 im=Image.open(p);im.load();raw.append(dict(file=p.name,size=im.size))
(r/'records/batch03_published_verification.json').write_text(json.dumps(dict(approved_count=15,final_hashes_verified=15,all_gif_frames_decoded=True,original_pngs_verified=len(raw),assets=report,originals=raw,game_test='not_performed'),ensure_ascii=False,indent=2)+'\n');print('15 final PNG hashes and 15 GIF full frame streams verified; originals:',len(raw))
