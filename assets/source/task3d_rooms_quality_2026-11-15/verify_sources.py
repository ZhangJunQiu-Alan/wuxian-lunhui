from pathlib import Path
import bpy,json,struct
from mathutils import Vector
BATCH=Path(__file__).resolve().parent
ROOT=BATCH.parents[2]
manifest=json.loads((BATCH/'manifest.json').read_text())
results=[]
for entry in manifest['models']:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/entry['blend']))
    root=bpy.data.objects.get(entry['id']); assert root,entry['id']
    meshes=[o for o in root.children_recursive if o.type=='MESH']
    assert len(meshes)>10
    used={mat for o in meshes for mat in o.data.materials}
    images={node.image for mat in used for node in mat.node_tree.nodes if node.type=='TEX_IMAGE'}
    assert images and all(i.packed_file for i in images)
    if entry['expected_clip']!='static':
        assert any(o.animation_data for o in root.children_recursive)
    if entry['id']=='quality_snow_floor':
        assert root['tile_pitch']==3.2
        assert max(entry['dimensions_blender_xyz'][:2])<=3.201
    glb=(ROOT/entry['glb']).read_bytes(); n=struct.unpack_from('<I',glb,12)[0]; gltf=json.loads(glb[20:20+n])
    assert len(gltf['meshes'])<=15
    assert all(n.get('name')!='Review ground' for n in gltf['nodes'])
    assert all(i['mimeType']=='image/png' for i in gltf['images'])
    results.append({'id':entry['id'],'source_parts':len(meshes),'packed_maps_used':len(images),'exported_meshes':len(gltf['meshes'])})
bpy.ops.wm.open_mainfile(filepath=str(BATCH/'room_assembly.blend'))
assert len([o for o in bpy.data.objects if o.get('asset_id')])>=8
assert not any(o.animation_data for o in bpy.data.objects if o.type=='EMPTY')
(BATCH/'records/source-verification.json').write_text(json.dumps(results,indent=2)+'\n')
print('QUALITY_SOURCES_VERIFIED',len(results),flush=True)
