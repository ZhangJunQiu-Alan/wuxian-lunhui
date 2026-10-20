from pathlib import Path
from collections import Counter
from html.parser import HTMLParser
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from PIL import Image

BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def read(p):return json.loads((BASE/p).read_text())


def dump(p,data):(BASE/p).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')


checks=[]


def check(name,ok,detail=None):checks.append(dict(check=name,passed=bool(ok),detail=detail))


a=read('asset_plan.json')
rows=a['assets']
existing=[r for r in rows if r['representation']=='existing_file']
planned=[r for r in rows if r['representation']=='planned_file']
check('unique_final_paths',len({r['path'] for r in rows})==len(rows))
check('plan_not_falsely_frozen',a['final_production_frozen'] is False)
check('no_fixed_unknown_sfx_count',a['unresolved']['new_sfx_files'] is None)
check('K1_to_K7_coverage',set(['K1','K2','K3','K4','K5','K6','K7']).issubset({r['task'] for r in rows+a['non_file_representations']}))
reference_paths=set()
for r in existing:
    p=ROOT/r['path']
    check('reuse_hash:'+r['path'],p.is_file() and sha(p)==r['sha256'])
    if p.suffix=='.png':
        im=Image.open(p)
        check('reuse_dimensions:'+r['path'],list(im.size)==r['sheet_size'])
for r in planned:
    check('planned_not_reproduced:'+r['path'],not (ROOT/r['path']).exists())
    check('planned_not_claimed_complete:'+r['path'],r['production_status']=='not_created' and r.get('sha256') is None)
    check('integration_named:'+r['path'],bool(r.get('integration_target')))
    if r['path'].endswith('.png'):
        w,h=r['frame_size'];n=r['frames'];anchor=r['anchor_px']
        check('strip_math:'+r['path'],r['sheet_size']==[w*n,h] and n>0)
        check('anchor_bounds:'+r['path'],0<=anchor[0]<=w and 0<=anchor[1]<=h)
        check('frame_rate:'+r['path'],r['fps'] in [0,8,16])
        check('commercial_generation_not_fabricated:'+r['path'],r['reference_paths'] and r['specification_status']=='K0_proposal_not_runtime_frozen')
        reference_paths.update(r['reference_paths'])
ref=[]
for name in sorted(reference_paths):
    p=ROOT/name;check('reference_exists:'+name,p.is_file())
    if p.is_file():ref.append(dict(path=name,sha256=sha(p)))
dump('records/reference_inputs.json',ref)

prov=read('records/reuse_provenance.json')
for r in existing:check('reuse_source_manifest:'+r['path'],bool(prov.get(r['path'])))
for p in sorted(reference_paths):check('reference_source_manifest:'+p,bool(prov.get(p)))
ports=read('records/snake_ports.json')
for k in ['body_left_right_equal','body_tail_equal','body_head_equal']:check('exact_socket:'+k,ports[k])
layout=read('layout.json');geom=read('records/layout_geometry_check.json')
for k in ['all_unblocked_reachable','spawn_clear','central_reserve_clear','horizon_outside_walk','corridors_allow_256px_plus_player_radius']:check('static_geometry:'+k,geom[k])
for k,v in geom['landmarks_reachable'].items():check('static_landmark:'+k,v)
check('no_new_quests_in_layout',not any('quest' in l or 'hidden' in l for l in layout['landmarks']))
walk=layout['walk_rect'];limit=walk[0]+walk[2]
for lm in layout['landmarks']:
    check('landmark_fits:'+lm['id'],all(-limit<=v-lm['radius'] and v+lm['radius']<=limit for v in lm['pos']))
audio=read('audio_events.json')
check('audio_unknown_total_explicit',audio['new_sfx_total'] is None)
check('audio_event_ids_unique',len(audio['events'])==len({x['event'] for x in audio['events']}))
for event in audio['events']:
    for f in event['files']:check('audio_reuse_hash:'+event['event']+':'+f['path'],sha(ROOT/f['path'])==f['sha256'])

class Links(HTMLParser):
    def __init__(self):super().__init__();self.links=[]
    def handle_starttag(self,tag,attrs):
        for k,v in attrs:
            if k in ['href','src']:self.links.append(v)

parser=Links();parser.feed((BASE/'gallery.html').read_text())
for v in parser.links:
    check('gallery_target:'+v,(BASE/v).exists() or v=='records/self_check.json')
ET.parse(BASE/'previews/layout.svg');check('svg_well_formed',True)
for p in (BASE/'previews').glob('*.png'):
    with Image.open(p) as im:im.verify()
    check('preview_png_decodes:'+p.name,True)
snapshot=read('records/input_snapshot.json')
changed=[name for name,h in snapshot.items() if not (ROOT/name).exists() or sha(ROOT/name)!=h]
check('protected_inputs_unchanged',not changed,changed)
lic=(ROOT/'assets/LICENSES.md').read_text()
check('license_tool_record_present','K0 第三关布局与制作前置方案（2026-10-20' in lic)
old_prefix=lic.split('\n\n## K0 第三关布局与制作前置方案（2026-10-20')[0]
check('preexisting_license_text_preserved',hashlib.sha256(old_prefix.encode()).hexdigest()==(BASE/'records/licenses_before.sha256').read_text().strip())
check('no_generation_originals_fabricated',not (BASE/'originals').exists())
result=dict(task='K0',status='pass' if all(x['passed'] for x in checks) else 'fail',
            checks=len(checks),failures=sum(not x['passed'] for x in checks),items=checks,
            runtime_validation='not_performed',new_animation_visual_audit='not_applicable_no_new_animation',
            music_listening='not_performed',new_final_assets=0,
            planning_counts=dict(reused_or_reference_files=len(existing),proposed_new_files=len(planned),
                                 proposed_png=sum(r['path'].endswith('.png') for r in planned),
                                 proposed_ogg=sum(r['path'].endswith('.ogg') for r in planned),audio_events=len(audio['events'])),
            visual_review_record='records/visual_review.json; actual image viewing is recorded separately, not inferred from decoding')
dump('records/self_check.json',result)
dump('completion.json',dict(task='K0',planning_delivery='complete',planning_check=result['status'],
     K1_to_K7='planned_only_not_produced',integration='not_implemented',game_acceptance='not_tested',
     commit='not_executed',push='not_executed',production_contracts='C1-C8 proposed, awaiting integration freeze'))
manifest=dict(task='K0',date='2026-10-20',status='planning_delivered_not_runtime_accepted',
              final_production='not_started',new_final_assets=0,existing_files_modified=0,
              source_rights='project-owned existing pixels; original manifest chain in records/reuse_provenance.json',
              tools=['Python standard library','Pillow 12.1.1 MIT-CMU for existing-image previews and checks only'],
              format_exceptions=dict(originals='not applicable: no new image generation',
                                     preview_gif='not applicable: K0 contains no newly produced animation',
                                     terrain_preview='six existing textures, 4x4 repeats; no new terrain production'),
              existing_assets=[dict(path=r['path'],sha256=r['sha256']) for r in existing],
              planning_file='asset_plan.json',self_check=result['status'],game_acceptance='not_tested',
              deliverables=[dict(path=str(p.relative_to(BASE)),sha256=sha(p)) for p in sorted(BASE.rglob('*'))
                            if p.is_file() and p.name not in ['manifest.json','source_inventory.json'] and '__pycache__' not in p.parts])
dump('manifest.json',manifest)
dump('source_inventory.json',[dict(path=str(p.relative_to(BASE)),sha256=sha(p)) for p in sorted(BASE.rglob('*'))
                             if p.is_file() and p.name!='source_inventory.json' and '__pycache__' not in p.parts])
print(json.dumps({k:v for k,v in result.items() if k!='items'},ensure_ascii=False,indent=2))
if result['failures']:
    print(json.dumps([x for x in checks if not x['passed']],ensure_ascii=False,indent=2))
    raise SystemExit(1)
