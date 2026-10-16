from pathlib import Path
from PIL import Image,ImageSequence
import json,hashlib
r=Path(__file__).resolve().parents[1];project=r.parents[2]
m=json.loads((r/'manifest.json').read_text());plan=json.loads((r/'records/production_plan.json').read_text())
assert len(m['assets'])==7 and {a['id'] for a in m['assets']}=={p['id'] for p in plan}
report=[]
for a in m['assets']:
    path=project/a['output'];im=Image.open(path);w,h=a['frame_size'];n=a['frames']
    assert im.mode=='RGBA' and im.size==(w*n,h) and a['fps']==8 and a['loop'] is True,a['id']
    assert path.read_bytes()==(r/a['candidate']).read_bytes()==(r/a['approved']).read_bytes(),a['id']
    sha=hashlib.sha256(path.read_bytes()).hexdigest();assert sha==a['sha256']
    alpha=sorted(set(im.getchannel('A').get_flattened_data()));assert alpha==[0,255]
    colors={p[:3] for p in im.get_flattened_data() if p[3]};assert len(colors)==a['colors'] and len(colors)<=48
    palette={tuple(c) for c in json.loads((r/a['reference_palette']).read_text())};assert colors<=palette
    ref=Image.open(r/'references'/f'{a["character"]}.png').convert('RGBA');assert palette<={p[:3] for p in ref.get_flattened_data() if p[3]}
    frames=[im.crop((i*w,0,(i+1)*w,h)) for i in range(n)];assert len({f.tobytes() for f in frames})==n
    boxes=[f.getbbox() for f in frames]
    for b in boxes:assert b[0]>=2 and b[1]>=2 and b[2]<=w-2 and b[3]<=h-2 and b[3]-1==a['baseline'],(a['id'],b)
    for key in ['source','generation_record']:assert (r/a[key]).is_file()
    for p in a.get('sources',[]):assert (r/p).is_file()
    for p in a['previews'].values():assert (r/p).is_file() and (r/p).stat().st_size>0
    gif=Image.open(r/a['previews']['loop8fps_4x']);durations=[]
    assert gif.n_frames==n and gif.size==(w*4,h*4) and gif.info.get('loop')==0
    for f,original in zip(ImageSequence.Iterator(gif),frames):
        durations.append(f.info['duration']);bg=Image.new('RGBA',(w,h),'#121721');bg.alpha_composite(original);expected=bg.resize((w*4,h*4),Image.Resampling.NEAREST).convert('RGB')
        assert f.convert('RGB').tobytes()==expected.tobytes(),(a['id'],'GIF pixel fidelity')
    assert sum(durations)==n*125
    spec=next(p for p in plan if p['id']==a['id']);assert spec['frames']==n and spec['frame_size']==[w,h]
    report.append({'id':a['id'],'size':list(im.size),'frames':n,'colors':len(colors),'alpha_values':alpha,'baseline':a['baseline'],'bboxes':boxes,'sha256':sha,'approved_candidate_output_identical':True,'palette_all_original_rgb':True,'all_frames_unique':True,'gif_4x_pixels_equal_png_composite':True,'gif_durations_ms':durations,'technical_checks_passed':True})
out={'date':'2026-10-16','scope':'batch05 firststage7only','assets':7,'technical_checks_passed':True,'visual_review_records':'records/review_decisions.json','ground_4x4_tiling':'not_applicable_enemy_animations','game_tested':False,'items':report}
(r/'records/final_audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k!='items'},ensure_ascii=False))
