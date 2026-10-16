from pathlib import Path
from PIL import Image,ImageSequence,ImageDraw
import json,hashlib
r=Path(__file__).resolve().parents[1];sheet=Image.open(r/'candidates/skoll_idle_v02.png').convert('RGBA');base=Image.open(r/'references/skoll_48color.png').convert('RGBA');report=json.loads((r/'records/skoll_idle_v02_export_diff.json').read_text());frames=[]
def same_visible(a,b):
 return all((not x[3]and not y[3])or x==y for x,y in zip(a.get_flattened_data(),b.get_flattened_data()))
for i,row in enumerate(report):
 f=sheet.crop((i*128,0,(i+1)*128,128));row['head']=same_visible(f.crop((83,40,122,99)),base.crop((83,40,122,99)));row['feet']=same_visible(f.crop((0,96,128,128)),base.crop((0,96,128,128)));row['bbox']=f.getbbox();assert row['diff_count']==0 and row['new_hole_pixels']==0 and row['head']and row['feet'];frames.append(f)
assert sheet.size==(512,128)and set(sheet.getchannel('A').get_flattened_data())=={0,255};assert same_visible(frames[1],frames[3]);previews=[]
for f in frames:
 bg=Image.new('RGBA',(128,128),'#121721');bg.alpha_composite(f);previews.append(bg.resize((512,512),Image.Resampling.NEAREST).convert('RGB'))
previews[0].save(r/'previews/skoll_idle_v02.gif',save_all=True,append_images=previews[1:],duration=[120,130,120,130],loop=0,disposal=2);gif=Image.open(r/'previews/skoll_idle_v02.gif');dur=[f.info['duration']for f in ImageSequence.Iterator(gif)];contact=Image.new('RGB',(1024,300),'#121721');d=ImageDraw.Draw(contact);d.text((10,8),'ACTUAL PISKEL EXPORT v02 / BODY CONNECTION REPAIRED',fill='white')
for i,f in enumerate(frames):z=f.resize((256,256),Image.Resampling.NEAREST);contact.paste(z,(256*i,35),z)
contact.save(r/'previews/skoll_idle_actual_contact_v02.png');out={'frames':report,'colors':len(set(p[:3]for p in sheet.get_flattened_data()if p[3])),'gif_size':[512,512],'gif_frames':gif.n_frames,'gif_durations_ms':dur,'gif_effective_fps':len(dur)*1000/sum(dur),'sha256':hashlib.sha256((r/'candidates/skoll_idle_v02.png').read_bytes()).hexdigest(),'comparison_note':'RGB values under alpha=0 are ignored; Piskel resets hidden RGB to zero. Opaque face/feet pixels are identical.','status':'technical_pass_pending_visual_motion_review'};(r/'records/skoll_idle_v02_verification.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items()if k!='frames'},indent=2))
