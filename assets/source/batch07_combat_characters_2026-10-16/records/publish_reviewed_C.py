from pathlib import Path
from PIL import Image
import json,hashlib,shutil,sys
r=Path(__file__).resolve().parents[1];project=r.parents[2]
items=json.loads((r/'records/candidates.json').read_text());m=json.loads((r/'manifest.json').read_text());plan=json.loads((r/'records/production_plan.json').read_text())
reviews=json.loads((r/'records/C_review_decisions.json').read_text())
for path in sys.argv[1:]:
    j=next(x for x in items if x['candidate']==path);review=reviews[path];assert review['decision']=='pass'
    image=Image.open(r/path);fw,fh=j['frame_size'];assert image.mode=='RGBA' and image.size==(fw*j['frames'],fh)
    assert set(image.getchannel('A').get_flattened_data())<={0,255}
    palette={tuple(c) for c in json.loads((r/j['reference_palette']).read_text())}
    assert {p[:3] for p in image.get_flattened_data() if p[3]}<=palette
    for i in range(j['frames']):
        b=image.crop((i*fw,0,(i+1)*fw,fh)).getbbox();assert b and b[0]>=2 and b[1]>=2 and b[2]<=fw-2 and b[3]<=fh-2
    ident=j['id'];out=project/'assets/sprites/characters'/f'{ident}.png';old=next((a for a in m['assets'] if a['id']==ident),None)
    if out.exists():
        digest=hashlib.sha256(out.read_bytes()).hexdigest()[:12];backup=r/'backups'/f'{ident}_before_{digest}.png'
        if not backup.exists():shutil.copy2(out,backup)
    shutil.copy2(r/path,out);shutil.copy2(r/path,r/'approved'/f'{ident}.png')
    for other in items:
        if other['id']==ident and other['candidate']!=path and other.get('status')=='art_self_check_passed_pending_game_review':other['status']='superseded_palette_revision'
    j.update(status='art_self_check_passed_pending_game_review',output=str(out.relative_to(project)),approved=f'approved/{ident}.png',checks=review['checks'],review_note=review['note'],generation_record=review.get('generation_record',j['generation_record']),ground_tiling='not_applicable_character_asset')
    if j['frames']>1:
        stem=Path(path).stem;j['previews']={'contact_1x':f'previews/{stem}_contact_1x.png','contact_4x':f'previews/{stem}_contact_4x.png','slow8fps':f'previews/{stem}_slow8fps.gif'}
        for p in j['previews'].values():assert (r/p).exists()
    m['assets']=[a for a in m['assets'] if a['id']!=ident]+[dict(j)]
    next(p for p in plan if p['id']==ident)['status']=j['status']
m['approved_assets']=len(m['assets']);m['status']='in_progress' if len(m['assets'])<29 else 'art_self_check_passed_pending_game_review'
for name,data in [('manifest.json',m),('records/candidates.json',items),('records/production_plan.json',plan)]:(r/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('published',len(sys.argv)-1,'current total',m['approved_assets'])
