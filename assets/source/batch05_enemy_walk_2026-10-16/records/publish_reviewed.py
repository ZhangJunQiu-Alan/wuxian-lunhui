from pathlib import Path
from PIL import Image
import json,hashlib,shutil,sys
r=Path(__file__).resolve().parents[1];project=r.parents[2]
items=json.loads((r/'records/candidates.json').read_text());m=json.loads((r/'manifest.json').read_text());plan=json.loads((r/'records/production_plan.json').read_text());decisions=json.loads((r/'records/review_decisions.json').read_text())
for path in sys.argv[1:]:
    j=next(x for x in items if x['candidate']==path);review=decisions[path];assert review['decision']=='pass'
    image=Image.open(r/path);w,h=j['frame_size'];assert image.mode=='RGBA' and image.size==(w*j['frames'],h)
    assert set(image.getchannel('A').get_flattened_data())=={0,255}
    palette={tuple(c) for c in json.loads((r/j['reference_palette']).read_text())};assert {p[:3] for p in image.get_flattened_data() if p[3]}<=palette
    for i in range(j['frames']):
        b=image.crop((i*w,0,(i+1)*w,h)).getbbox();assert b and b[0]>=2 and b[1]>=2 and b[2]<=w-2 and b[3]<=h-2
        assert b[3]-1==j['baseline']
    ident=j['id'];out=project/'assets/sprites/enemies'/f'{ident}.png'
    if out.exists():
        digest=hashlib.sha256(out.read_bytes()).hexdigest()[:12];backup=r/'backups'/f'{ident}_before_{digest}.png'
        if not backup.exists():shutil.copy2(out,backup)
    shutil.copy2(r/path,out);shutil.copy2(r/path,r/'approved'/f'{ident}.png')
    for other in items:
        if other['id']==ident and other['candidate']!=path and other['status'] not in ['rejected','superseded_not_selected']:other['status']='superseded_not_selected'
    stem=Path(path).stem;j.update(status='art_self_check_passed_pending_game_review',output=str(out.relative_to(project)),approved=f'approved/{ident}.png',checks=review['checks'],review_note=review['note'],ground_tiling='not_applicable_enemy_animation',previews={'contact_1x':f'previews/{stem}_contact_1x.png','contact_4x':f'previews/{stem}_contact_4x.png','loop8fps_4x':f'previews/{stem}_8fps.gif'})
    for p in j['previews'].values():assert (r/p).is_file()
    m['assets']=[a for a in m['assets'] if a['id']!=ident]+[dict(j)];next(p for p in plan if p['id']==ident)['status']=j['status']
m['approved_assets']=len(m['assets']);m['status']='in_progress' if len(m['assets'])<7 else 'art_self_check_passed_pending_game_review'
for name,data in [('manifest.json',m),('records/candidates.json',items),('records/production_plan.json',plan)]:(r/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('published',len(sys.argv)-1,'current',m['approved_assets'],'/7')
