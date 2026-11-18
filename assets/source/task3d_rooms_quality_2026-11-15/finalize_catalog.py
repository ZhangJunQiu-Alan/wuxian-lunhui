from pathlib import Path
import json
BATCH=Path(__file__).resolve().parent
ROOT=BATCH.parents[2]
ids=['snow_floor','void_causeway','spike_trap','rune_trap','pressure_plate','lever','brazier']
new=[json.loads((BATCH/'records'/(id+'.json')).read_text()) for id in ids]
gate=json.loads((ROOT/'assets/source/task3d_gate_quality_2026-11-15/manifest.json').read_text())['models'][0]
manifest={'batch':BATCH.name,'stage':'models and animation review','models':[gate]+new,'material_sources':'assets/source/task3d_gate_quality_2026-11-15/records/material-sources.json','gameplay_integrated':False}
(BATCH/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(ROOT/'docs/芬布尔之冬模型清单/quality-models.js').write_text('const qualityModels = '+json.dumps(manifest['models'],ensure_ascii=False,indent=2)+';\n')
print('CATALOG_WRITTEN',len(manifest['models']))
