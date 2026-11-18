from pathlib import Path
import bpy, json
from mathutils import Vector
batch=Path(__file__).resolve().parent
results=[]
for filename in ['rune_gate.blend','room_assembly.blend']:
    bpy.ops.wm.open_mainfile(filepath=str(batch/filename))
    assert bpy.data.objects.get('quality_rune_gate')
    assert bpy.data.objects.get('GateMoving').animation_data
    images=[i for i in bpy.data.images if i.type=='IMAGE' and i.name!='Render Result']
    assert len(images)==9,[(i.name,i.type) for i in images]
    assert all(i.packed_file for i in images)
    verts=[o.matrix_world @ Vector(v) for o in bpy.data.objects['quality_rune_gate'].children_recursive if o.type=='MESH' for v in o.bound_box]
    dimensions=[round(max(v[a] for v in verts)-min(v[a] for v in verts),3) for a in range(3)]
    results.append({'file':filename,'packed_maps':len(images),'objects':len(bpy.data.objects),'dimensions':dimensions})
(batch/'records/source-verification.json').write_text(json.dumps(results,indent=2))
print('QUALITY_BLEND_VERIFIED',results)
