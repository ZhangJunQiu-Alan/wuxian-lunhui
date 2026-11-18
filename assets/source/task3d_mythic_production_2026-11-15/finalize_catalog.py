from pathlib import Path
import json
BATCH=Path(__file__).resolve().parent; ROOT=BATCH.parents[2]
actors=['hero_swordsman','enemy_draugr','enemy_winter_wolf','boss_skoll','enemy_ice_spirit','swordsman_sword','swordsman_scabbard']
structures=['odin_portal','yggdrasil_altar','norn_well','bifrost_bridge','bifrost_pillar','valhalla_wall','thor_shrine','skadi_shrine','hel_gate','offering_table']
environment=['snow_rocks','dead_tree','burial_mound','fjord_dock','mooring_bollard','campfire_ring']
new=[json.loads((BATCH/'records'/(id+'.json')).read_text()) for id in actors+structures+environment]
for e in new: e['current_batch']=True
previous=json.loads((BATCH.parent/'task3d_architecture_quality_2026-11-15/manifest.json').read_text())['models']
for e in previous: e['current_batch']=False
manifest={'batch':BATCH.name,'stage':'首版待人工审批','models':new+previous,'new_model_ids':[e['id'] for e in new],'gameplay_integrated':False,'review_document':'docs/芬布尔之冬模型清单/index.html','material_sources':'assets/source/task3d_gate_quality_2026-11-15/records/material-sources.json'}
(BATCH/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(ROOT/'docs/芬布尔之冬模型清单/quality-models.js').write_text('const qualityModels = '+json.dumps(manifest['models'],ensure_ascii=False,indent=2)+';\n')
print('PRODUCTION_CATALOG_WRITTEN',len(manifest['models']),'new',len(new))
