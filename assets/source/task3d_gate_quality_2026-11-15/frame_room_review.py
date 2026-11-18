from pathlib import Path
import bpy
from mathutils import Vector
batch=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(batch/'room_assembly.blend'))
scene=bpy.context.scene
camera=scene.camera
camera.rotation_euler=(Vector((0,-.55,1.7))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=9.1
scene.cycles.samples=24
bpy.ops.wm.save_as_mainfile(filepath=str(batch/'room_assembly.blend'))
bpy.ops.render.render(write_still=True)
