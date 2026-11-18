from pathlib import Path
import json
BATCH=Path(__file__).resolve().parent; ROOT=BATCH.parents[2]
ids=['ruined_wall','timber_pillar','stone_stairs','barricade','supply_chest','runestone']
new=[json.loads((BATCH/'records'/(id+'.json')).read_text()) for id in ids]
next(e for e in new if e['id']=='quality_supply_chest')['additional_previews']=[{'label':'查看开盖与内部','path':str((BATCH/'previews/supply_chest_open.png').relative_to(ROOT))}]
previous=json.loads((BATCH.parent/'task3d_rooms_quality_2026-11-15/manifest.json').read_text())['models']
(BATCH/'new-models.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
manifest={'batch':BATCH.name,'stage':'architecture and cover asset review','models':new+previous,'new_model_ids':[e['id'] for e in new],'gameplay_integrated':False,'material_sources':'assets/source/task3d_gate_quality_2026-11-15/records/material-sources.json'}
(BATCH/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(ROOT/'docs/芬布尔之冬模型清单/quality-models.js').write_text('const qualityModels = '+json.dumps(manifest['models'],ensure_ascii=False,indent=2)+';\n')
print('ARCHITECTURE_CATALOG_WRITTEN',len(manifest['models']))
