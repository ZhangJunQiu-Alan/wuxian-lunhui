from pathlib import Path
import bpy,bmesh,json,hashlib,struct,math
BATCH=Path(__file__).resolve().parent; ROOT=BATCH.parents[2]
entries=json.loads((BATCH/'new-models.json').read_text()); results=[]
for entry in entries:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/entry['blend']))
    root=bpy.data.objects.get(entry['id']); assert root
    parts=[o for o in root.children_recursive if o.type=='MESH']; assert len(parts)>=10
    images={n.image for o in parts for m in o.data.materials for n in m.node_tree.nodes if n.type=='TEX_IMAGE'}
    assert images and all(i.packed_file for i in images)
    assert all(math.isfinite(v) for o in parts for p in o.data.vertices for v in p.co)
    if entry['id']=='quality_ruined_wall':
        assert root['module_pitch']==3.2
        assert entry['dimensions_blender_xyz'][0]<=3.201
    if entry['id']=='quality_runestone':
        stone=next(o for o in parts if o.name.startswith('Engraved standing stone'))
        bm=bmesh.new(); bm.from_mesh(stone.data)
        assert not any(e.is_boundary for e in bm.edges),'Open stone surface'
        assert abs(bm.calc_volume())>.1,'Empty engraved stone'
        assert len(stone.data.polygons)>300,'Missing carved geometry'
        bm.free()
    if entry['id']=='quality_supply_chest':
        lid=bpy.data.objects['HingedLid']; assert lid.animation_data
        bpy.context.scene.frame_set(1); bpy.context.view_layer.update(); before=lid.rotation_euler.x
        bpy.context.scene.frame_set(65); bpy.context.view_layer.update()
        assert abs(lid.rotation_euler.x-before)>1.5
    data=(ROOT/entry['glb']).read_bytes(); g=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
    assert len(g['meshes'])<=15
    assert all(i['mimeType']=='image/png' for i in g['images'])
    assert hashlib.sha256(data).hexdigest()==entry['sha256']
    results.append({'id':entry['id'],'parts':len(parts),'packed_maps':len(images),'exported_meshes':len(g['meshes'])})
bpy.ops.wm.open_mainfile(filepath=str(BATCH/'room_assembly.blend'))
assert len({o.get('asset_id') for o in bpy.data.objects if o.get('asset_id')})>=9
assert not any(o.animation_data for o in bpy.data.objects if o.type=='EMPTY')
(BATCH/'records/source-verification.json').write_text(json.dumps(results,indent=2)+'\n')
print('ARCHITECTURE_SOURCES_VERIFIED',len(results),flush=True)
