"""Compose the room modules into an editable layout for visual review."""
import importlib.util
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
BATCH=Path(__file__).resolve().parent
ROOT=BATCH.parents[2]
MODELS=ROOT / "assets/models/midgard/rooms"


def main(studio_transform=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source=ROOT / "assets/source/task3d_midgard_2026-11-13/refine_longhouse_blender.py"
    spec=importlib.util.spec_from_file_location("review_studio",source)
    helper=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    if studio_transform:
        helper=studio_transform(helper)
    placements=[]
    for x in [-3,0,3]:
        for y in [-3,0,3]:
            if (x,y)!=(0,0):
                placements.append(("snow_floor",(x,y,0)))
    placements += [("void_causeway",(0,0,0)),("rune_gate",(0,3.9,0)),
                   ("spike_trap",(-3,-1.7,.14)),("pressure_plate",(0,-3,.12)),
                   ("lever",(3,-1.8,.07)),("rune_trap",(3,2.5,.07)),
                   ("brazier",(-1.8,3.55,.03)),("brazier",(1.8,3.55,.03))]
    for asset,point in placements:
        previous=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(MODELS / f"{asset}.glb"))
        for obj in bpy.data.objects:
            if obj not in previous and obj.parent is None:
                obj.location+=Vector(point)
    scene=helper.studio()
    scene.camera.location=(8.8,-12.5,13.5)
    helper.aim(scene.camera,(0,.2,0))
    scene.camera.data.ortho_scale=13.8
    scene.render.resolution_x,scene.render.resolution_y=1500,1100
    scene.cycles.samples=20
    floor=bpy.data.objects.get("Review floor")
    floor.location.z=-1.5
    floor.data.materials[0].diffuse_color=(.012,.021,.032,1)
    scene.frame_set(23)
    for obj in bpy.data.objects:
        if obj.animation_data:
            obj.animation_data_clear()
        if obj.name.startswith("GateMoving"):
            obj.location.z=0
    bpy.context.view_layer.update()
    scene.render.filepath="//previews/room_assembly.png"
    scene["review_note"]="房间布局样例。中央虚空，两侧可绕行，左侧地刺，右侧拉杆与符文陷阱。玩法联动待接。"
    bpy.ops.wm.save_as_mainfile(filepath=str(BATCH/"room_assembly.blend"))
    bpy.ops.render.render(write_still=True)


if __name__=="__main__":
    main()
