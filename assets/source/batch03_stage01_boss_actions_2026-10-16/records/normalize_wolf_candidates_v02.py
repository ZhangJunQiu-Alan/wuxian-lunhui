from pathlib import Path
from PIL import Image,ImageDraw
from collections import deque
import json
r=Path(__file__).resolve().parents[1]
jobs=json.loads((r/'records/generation_jobs_v02.json').read_text())
raw_frames={};extraction=[]
for j in jobs:
 im=Image.open(r/j['raw_file']).convert('RGBA');w,h=im.size;mask=bytearray(1 if a>=128 else 0 for a in im.getchannel('A').get_flattened_data());components=[]
 for i in range(w*h):
  if not mask[i]:continue
  mask[i]=0;q=deque([i]);pts=[]
  while q:
   k=q.popleft();pts.append(k);x=k%w;y=k//w
   for n in ((k-1 if x else -1),(k+1 if x<w-1 else -1),k-w,k+w):
    if 0<=n<w*h and mask[n]:mask[n]=0;q.append(n)
  if len(pts)>=1000:
   xs=[k%w for k in pts];ys=[k//w for k in pts];components.append({'pts':pts,'bbox':[min(xs),min(ys),max(xs)+1,max(ys)+1],'area':len(pts)})
 components=sorted(components,key=lambda c:c['area'],reverse=True)[:j['frames']];assert len(components)==j['frames'],(j['id'],len(components));components.sort(key=lambda c:(round((c['bbox'][1]+c['bbox'][3])/2/h),c['bbox'][0]));frames=[]
 for idx,c in enumerate(components):
  b=c['bbox'];crop=im.crop(tuple(b));a=Image.new('L',crop.size);ap=a.load()
  for k in c['pts']:ap[k%w-b[0],k//w-b[1]]=255
  crop.putalpha(a);frames.append(crop)
  extraction.append({'job':j['id'],'frame':idx+1,'bbox':b,'component_area':c['area'],'alpha_threshold':128})
 raw_frames[j['id']]=frames
report=[]
for char,baseline in [('skoll',117),('hati',118)]:
 all_frames=[im for j in jobs if j['character']==char for im in raw_frames[j['id']]];pal=Image.new('P',(1,1));palette=json.loads((r/f'records/{char}_reference_palette.json').read_text());flat=[x for c in palette for x in c];pal.putpalette(flat+[0]*(768-len(flat)))
 for job in [j for j in jobs if j['character']==char]:
  source_group=raw_frames[job['id']];scale=min(120/max(f.width for f in source_group),110/max(f.height for f in source_group))
  normalized=[];boxes=[]
  for f in raw_frames[job['id']]:
   z=f.resize((round(f.width*scale),round(f.height*scale)),Image.Resampling.NEAREST);rgb=z.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');rgb.putalpha(z.getchannel('A'));out=Image.new('RGBA',(128,128));out.alpha_composite(rgb,((128-rgb.width)//2,baseline+1-rgb.height));normalized.append(out);boxes.append(out.getbbox())
  ranges=[('move',0,job['frames'])] if job['id'].endswith('_move') else [('windup',0,3),('attack',3,6)]
  for action,start,end in ranges:
   frames=normalized[start:end];name=char+'_'+action;sheet=Image.new('RGBA',(128*len(frames),128))
   for i,f in enumerate(frames):sheet.alpha_composite(f,(128*i,0))
   sheet.save(r/f'candidates/{name}_v02.png');preview=[]
   for f in frames:
    bg=Image.new('RGBA',(128,128),'#121721');bg.alpha_composite(f);preview.append(bg.resize((512,512),Image.Resampling.NEAREST).convert('RGB'))
   options={'save_all':True,'append_images':preview[1:],'duration':[120 if i%2==0 else 130 for i in range(len(frames))],'disposal':2}
   if action=='move':options['loop']=0
   preview[0].save(r/f'previews/{name}_v02.gif',**options)
   report.append({'id':name,'candidate':f'candidates/{name}_v02.png','frames':len(frames),'frame_size':[128,128],'source_job':job['id'],'source':job['raw_file'],'generation_url':job['url'],'source_frame_indices_1based':list(range(start+1,end+1)),'scale_common_to_raw_job':scale,'baseline':baseline,'bboxes_exclusive':boxes[start:end],'palette':f'records/{char}_reference_palette.json','status':'candidate_pending_visual_and_motion_review','preview':f'previews/{name}_v02.gif','loop':action=='move'})
contact=Image.new('RGB',(800,1080),'#121721');d=ImageDraw.Draw(contact)
for i,a in enumerate(report):
 y=i*178;d.text((12,y+5),a['id']+' v02 / NOT APPROVED',fill='white');im=Image.open(r/a['candidate']);contact.paste(im,(12,y+30),im);ref=Image.open(r/f'references/{a["id"].split("_")[0]}_48color.png');d.text((650,y+5),'REFERENCE',fill='white');contact.paste(ref,(650,y+30),ref)
contact.save(r/'previews/wolf_candidates_contact_1x_v02.png');(r/'records/wolf_extraction_v02.json').write_text(json.dumps(extraction,indent=2)+'\n');(r/'records/wolf_candidates_metadata_v02.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps([{'id':a['id'],'frames':a['frames'],'boxes':a['bboxes_exclusive']} for a in report],indent=2))
