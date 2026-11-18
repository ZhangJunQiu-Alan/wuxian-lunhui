from pathlib import Path
import bpy,json
batch=Path(__file__).resolve().parents[1]
results=[]
for name,expected in [('room_assembly',11),('actors_assembly',5),('environment_assembly',6)]:
    bpy.ops.wm.open_mainfile(filepath=str(batch/(name+'.blend')))
    roots=[o for o in bpy.data.objects if o.get('asset_id') and o.get('asset_id')!='quality_snow_floor']
    assert len(roots)==expected,(name,len(roots))
    meshes=[o for root in roots for o in root.children_recursive if o.type=='MESH']
    assert all(o.data.vertices and o.data.polygons for o in meshes)
    images={node.image for o in meshes for mat in o.data.materials if mat and mat.use_nodes for node in mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image}
    assert images and all(image.packed_file for image in images)
    assert bpy.context.scene.camera
    results.append({'gallery':name,'asset_instances':len(roots),'mesh_parts':len(meshes),'packed_images':len(images)})
(batch/'records/gallery-verification.json').write_text(json.dumps(results,indent=2)+'\n')
print('GALLERIES_VERIFIED',len(results),flush=True)
