from pathlib import Path
from PIL import Image,ImageDraw,ImageSequence
import json,hashlib
r=Path(__file__).resolve().parents[1];project=r.parents[2]
m=json.loads((r/'manifest.json').read_text());items=json.loads((r/'records/candidates.json').read_text())
for a in m['assets']:
    a.setdefault('frame_size',[a['size'][1],a['size'][1]])
    a.setdefault('tool','Chrome ChatGPT image generation; Chrome Piskel actual pixel edits; Pillow format normalization')
    a.setdefault('generation_record','records/generation_jobs.json')
    a['ground_tiling']='not_applicable_character_asset'
    if a['id']=='frost_giant_elite_attack':a['generation_record']='records/builtin_giant_generation_jobs.json'
    if a['frames']>1:
        stem=Path(a['candidate']).stem;suffix='attack16fps' if a['fps']==16 else 'action8fps'
        a['previews']={'contact_1x':f'previews/{stem}_contact_1x.png','contact_4x':f'previews/{stem}_contact_4x.png','slow8fps':f'previews/{stem}_slow8fps.gif','target_fps_one_shot':f'previews/{stem}_{suffix}.gif','target_fps_QA_loop':f'previews/{stem}_{suffix}_QA_loop.gif'}
        a['gif_timing_note']='GIF uses10ms timing. 8fps preview alternates120/130ms. Game uses PNG at exact16fps attack /8fps other actions. QA loop may repeat non-looping attacks/deaths.'
    else:
        stem=Path(a['candidate']).stem;a['previews']={'contact_1x':f'previews/{stem}_contact_1x.png','contact_4x':f'previews/{stem}_contact_4x.png'}
    for j in items:
        if j['candidate']==a['candidate']:j.update(a)
        elif j['id']==a['id'] and j['status'].startswith('candidate_pending'):j.update(status='superseded_not_selected',selection_note='Only manifest-listed candidate is delivered; earlier intermediate retains its original production record.')
    if a['id']=='merlin_move':
        for j in items:
            if j['candidate']=='candidates/merlin_move_v01.png':j.update(status='rejected',rejection_reason='Repeated first half-cycle; near boot did not visibly lead opposite half.')
m['approved_assets']=len(m['assets']);assert m['approved_assets']==29
m['status']='art_self_check_passed_pending_game_review';m['ground_tiling']='not_applicable_no_ground_tiles_in_batch07';m['final_audit']='records/final_audit.json'
(r/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
(r/'records/candidates.json').write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n')
canvas=Image.new('RGB',(1200,760),'#121721');draw=ImageDraw.Draw(canvas)
draw.text((20,12),'BATCH07 - 29 assets - art self-check complete / game review pending',fill='#e0e7ef')
for col,c in enumerate(['annie','lanling','merlin']):
    x=col*400
    im=Image.open(project/'assets/sprites/characters'/f'{c}_cutin.png').convert('RGBA');canvas.paste(im,(x,40),im)
    draw.text((x+16,370),c+' - static / walk / attack / death',fill='#e0e7ef')
    for row,(action,frame) in enumerate([('',0),('_move',3),('_attack',2),('_death',5)]):
        im=Image.open(project/'assets/sprites/characters'/f'{c}{action}.png').convert('RGBA');im=im.crop((frame*64,0,(frame+1)*64,64)).resize((128,128),Image.Resampling.NEAREST)
        canvas.paste(im,(x+row*88,400),im)
for i,a in enumerate(m['assets'][:8]):
    im=Image.open(project/a['output']).convert('RGBA');fw,fh=a['frame_size'];f=im.crop((fw*2,0,fw*3,fh));canvas.paste(f,(20+i*145,610),f);draw.text((20+i*145,718),a['id'].replace('_attack',''),fill='#aebfd0')
canvas.save(r/'previews/handoff_overview.png')
print('metadata finalized',m['approved_assets'])
