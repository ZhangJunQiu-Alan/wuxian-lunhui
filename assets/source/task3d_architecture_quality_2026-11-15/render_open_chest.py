from pathlib import Path
import bpy
from mathutils import Vector
BATCH=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(BATCH/'supply_chest.blend'))
scene=bpy.context.scene; scene.frame_set(65); bpy.context.view_layer.update()
root=bpy.data.objects['quality_supply_chest']
points=[o.matrix_world@Vector(v) for o in root.children_recursive if o.type=='MESH' for v in o.bound_box]
lo=Vector([min(p[a] for p in points) for a in range(3)]); hi=Vector([max(p[a] for p in points) for a in range(3)])
center=(lo+hi)/2; size=max(hi-lo)
camera=scene.camera; camera.location=center+Vector((size*.95,-size*1.35,size*1.35))
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.ortho_scale=size*1.95
scene.render.filepath=str(BATCH/'previews/supply_chest_open.png')
bpy.ops.render.render(write_still=True)
print('OPEN_CHEST_RENDERED',flush=True)
