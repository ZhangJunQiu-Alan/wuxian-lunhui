from pathlib import Path
import bpy,json,hashlib,struct,math,numpy as np
BATCH=Path(__file__).resolve().parent; ROOT=BATCH.parents[2]
manifest=json.loads((BATCH/'manifest.json').read_text());results=[]
TYPES={5120:('i1',1),5121:('u1',1),5122:('<i2',2),5123:('<u2',2),5125:('<u4',4),5126:('<f4',4)}
for entry in [e for e in manifest['models'] if e.get('current_batch')]:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/entry['blend']))
    root=bpy.data.objects.get(entry['id']);assert root,entry['id']
    objects=[o for o in root.children_recursive if o.type=='MESH'];assert objects
    materials={m for o in objects for m in o.data.materials};images={n.image for m in materials for n in m.node_tree.nodes if n.type=='TEX_IMAGE'}
    assert images and all(i.packed_file for i in images),entry['id']
    assert all(math.isfinite(c) for o in objects for v in o.data.vertices for c in v.co)
    raw=(ROOT/entry['glb']).read_bytes();assert hashlib.sha256(raw).hexdigest()==entry['sha256']
    n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);binary=memoryview(raw)[28+n:]
    def accessor(index):
        a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];dtype,size=TYPES[a['componentType']];cols={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        stride=v.get('byteStride',cols*size);offset=v.get('byteOffset',0)+a.get('byteOffset',0)
        result=np.ndarray((a['count'],cols),dtype=dtype,buffer=binary,offset=offset,strides=(stride,size)).copy()
        if a.get('normalized'):result=result.astype(float)/(255 if a['componentType']==5121 else 65535)
        return result
    if entry['id']=='quality_odin_portal':
        assert len([o for o in objects if o.name.startswith('Raven front corbel')])==2
        birds=[o for o in objects if o.name.startswith('Raven body')]
        assert len(birds)==2
        assert all(max((o.matrix_world@__import__('mathutils').Vector(v)).y for v in o.bound_box)<-.54 for o in birds)
    if entry.get('skins'):
        rigs=[o for o in root.children_recursive if o.type=='ARMATURE'];assert len(rigs)==1
        assert len(g['skins'])==1
        tracks=rigs[0].animation_data.nla_tracks
        source_actions={strip.action.name for track in tracks for strip in track.strips}
        assert set(entry['animations']).issubset(source_actions),entry['id']
        for mesh in g['meshes']:
            for primitive in mesh['primitives']:
                attributes=primitive['attributes'];assert 'JOINTS_0' in attributes and 'WEIGHTS_0' in attributes
                weights=accessor(attributes['WEIGHTS_0']);assert np.all(np.isfinite(weights)) and np.allclose(weights.sum(axis=1),1,atol=.005)
                joints=accessor(attributes['JOINTS_0']);assert joints.max()<len(g['skins'][0]['joints'])
        assert set(entry['animations'])=={a['name'] for a in g['animations']}
    if entry['id'] in ['quality_bifrost_bridge','quality_valhalla_wall','quality_fjord_dock']:assert root['module_pitch']==3.2
    if entry['id']=='quality_valhalla_wall':
        points=[o.matrix_world@__import__('mathutils').Vector(v) for o in objects for v in o.bound_box]
        assert max(p.x for p in points)-min(p.x for p in points)<=3.201
    results.append({'id':entry['id'],'source_mesh_parts':len(objects),'packed_maps':len(images),'skins':len(g.get('skins',[])),'animations':[a['name'] for a in g.get('animations',[])]})
(BATCH/'records/source-verification.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('PRODUCTION_SOURCES_VERIFIED',len(results),flush=True)
