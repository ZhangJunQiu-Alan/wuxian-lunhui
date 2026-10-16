from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
r=Path(__file__).resolve().parents[1]
jobs=json.loads((r/'records/generation_jobs_wave03.json').read_text());report=[]
for j in jobs:
 im=Image.open(r/j['raw_file']).convert('RGBA');cols,rows=j['layout'];n=j['frame_size'][0];base={'skoll':117,'hati':118,'hrym':189}[j['character']];frames=[];boxes=[]
 for i in range(j['frames']):
  x=i%cols;y=i//cols;cell=im.crop((round(x*im.width/cols),round(y*im.height/rows),round((x+1)*im.width/cols),round((y+1)*im.height/rows)));cell.putalpha(cell.getchannel('A').point(lambda a:255 if a>=128 else 0));b=cell.getbbox();assert b;boxes.append(b);frames.append(cell.crop(b))
 maxw=max(f.width for f in frames);maxh=max(f.height for f in frames);scale=min((n-8)/maxw,(base-7)/maxh);pal=Image.new('P',(1,1));colors=json.loads((r/f'records/{j["character"]}_reference_palette.json').read_text());flat=[v for c in colors for v in c];pal.putpalette(flat+list(colors[0])*(256-len(colors)));norm=[]
 for f in frames:
  z=f.resize((round(f.width*scale),round(f.height*scale)),Image.Resampling.NEAREST);q=z.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(z.getchannel('A'));o=Image.new('RGBA',(n,n));o.alpha_composite(q,((n-q.width)//2,base+1-q.height));norm.append(o)
 ranges=[('windup',0,3),('attack',3,6)] if 'attack_sequence' in j['id'] else [(j['id'].split('_')[1],0,j['frames'])];v=j['id'].split('_')[-1]
 for action,a,b in ranges:
  outid=j['character']+'_'+action;fs=norm[a:b];sheet=Image.new('RGBA',(n*len(fs),n));preview=[];contact=Image.new('RGB',(n*len(fs)*4,n*4),'#121721')
  for i,f in enumerate(fs):
   sheet.alpha_composite(f,(n*i,0));bg=Image.new('RGBA',(n,n),'#121721');bg.alpha_composite(f);bg=bg.resize((n*4,n*4),Image.Resampling.NEAREST).convert('RGB');preview.append(bg);contact.paste(bg,(i*n*4,0))
  png=f'candidates/{outid}_{v}.png';gif=f'previews/{outid}_{v}.gif';sheet.save(r/png);opts=dict(save_all=True,append_images=preview[1:],duration=[120 if i%2==0 else 130 for i in range(len(fs))],disposal=2)
  if action=='move':opts['loop']=0
  preview[0].save(r/gif,**opts);contact.save(r/f'previews/{outid}_{v}_contact_4x.png');used={p[:3] for p in sheet.get_flattened_data() if p[3]};assert len(used)<=48;assert set(sheet.getchannel('A').get_flattened_data())<={0,255}
  report.append(dict(id=outid,version=v,source_job=j['id'],source=j['raw_file'],generation_url=j['conversation_url'],candidate=png,preview=gif,frame_size=[n,n],frames=len(fs),palette=f'records/{j["character"]}_reference_palette.json',colors=len(used),alpha_values=[0,255],baseline=base,bboxes=[f.getbbox() for f in fs],scale=scale,status='candidate_pending_visual_and_motion_review',sha256=hashlib.sha256((r/png).read_bytes()).hexdigest()))
 # continuous QA with all actual frames
 ps=[]
 for f in norm:
  bg=Image.new('RGBA',(n,n),'#121721');bg.alpha_composite(f);ps.append(bg.resize((n*3,n*3),Image.Resampling.NEAREST).convert('RGB'))
 ps[0].save(r/f'previews/{j["id"]}_sequence_QA.gif',save_all=True,append_images=ps[1:],duration=[120 if i%2==0 else 130 for i in range(len(ps))],loop=0,disposal=2)
 j.update(status='normalized_candidates_pending_review',raw_cell_bboxes=boxes)
(r/'records/wave03_candidates_metadata.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');(r/'records/generation_jobs_wave03.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False,indent=2))
