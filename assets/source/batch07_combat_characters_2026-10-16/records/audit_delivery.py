from pathlib import Path
from PIL import Image,ImageSequence
import json,hashlib
r=Path(__file__).resolve().parents[1];project=r.parents[2]
m=json.loads((r/'manifest.json').read_text());plan=json.loads((r/'records/production_plan.json').read_text())
assert len(m['assets'])==29 and len({a['id'] for a in m['assets']})==29
assert {a['id'] for a in m['assets']}=={p['id'] for p in plan}
result=[]
for a in m['assets']:
    ident=a['id'];path=project/a['output'];im=Image.open(path);assert im.mode=='RGBA' and list(im.size)==a['size'],ident
    assert path.read_bytes()==(r/a['candidate']).read_bytes()==(r/a['approved']).read_bytes(),ident
    digest=hashlib.sha256(path.read_bytes()).hexdigest();assert digest==a['sha256'],ident
    alpha=sorted(set(im.getchannel('A').get_flattened_data()));assert alpha==[0,255],ident
    colors={p[:3] for p in im.get_flattened_data() if p[3]};assert len(colors)==a['colors'] and len(colors)<=48,ident
    fw,fh=a['frame_size'];assert im.size==(fw*a['frames'],fh),ident
    boxes=[]
    for n in range(a['frames']):
        b=im.crop((n*fw,0,(n+1)*fw,fh)).getbbox();assert b and b[0]>=2 and b[1]>=2 and b[2]<=fw-2 and b[3]<=fh-2,(ident,n,b)
        if a.get('baseline') is not None:assert b[3]-1==a['baseline'],(ident,n,b,a['baseline'])
        boxes.append(b)
    if a.get('reference_palette'):
        palette={tuple(c) for c in json.loads((r/a['reference_palette']).read_text())};assert colors<=palette,ident
    for key in ['source','generation_record']:assert (r/a[key]).is_file(),(ident,key)
    for key,p in a['previews'].items():assert (r/p).is_file() and (r/p).stat().st_size>0,(ident,key)
    gif=None
    if a['frames']>1:
        g=Image.open(r/a['previews']['slow8fps']);durations=[f.info.get('duration',0) for f in ImageSequence.Iterator(g)]
        assert g.n_frames==a['frames'] and g.size==(fw*4,fh*4),(ident,'gif frames/size')
        assert sum(durations)==a['frames']*125,(ident,'8fps timing',durations)
        gif={'frames':g.n_frames,'size':list(g.size),'8fps_durations_ms':durations}
    if ident.endswith('_cutin'):
        logical=Image.open(r/a['logical_candidate']);assert logical.size==(200,160)
        assert im.tobytes()==logical.resize((400,320),Image.Resampling.NEAREST).tobytes(),ident
    result.append({'id':ident,'output':a['output'],'sha256':digest,'size':list(im.size),'frames':a['frames'],'colors':len(colors),'alpha_values':alpha,'bboxes':boxes,'source_and_generation_record_exist':True,'approved_candidate_output_identical':True,'gif':gif,'technical_checks_passed':True})
audit={'date':'2026-10-16','batch':'07','assets':29,'animation_strips':sum(a['frames']>1 for a in m['assets']),'static_sprites':3,'cutins':3,'technical_checks_passed':True,'visual_review_records':'C_review_decisions.json plus manifest checks and A/B pixel export verification records','game_tested':False,'ground_4x4_tiling':'not_applicable_no_ground_assets','items':result}
(r/'records/final_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in audit.items() if k!='items'},ensure_ascii=False))
