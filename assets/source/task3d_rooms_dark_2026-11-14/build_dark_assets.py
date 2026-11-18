"""Build a dark ruin variant while retaining the original model batch."""
import importlib.util
import math
import sys
from pathlib import Path

import bpy

sys.dont_write_bytecode = True
BATCH = Path(__file__).resolve().parent
ROOT = BATCH.parents[2]
spec = importlib.util.spec_from_file_location("room_assets", ROOT / "assets/source/task3d_rooms_2026-11-14/build_room_assets.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
base.BATCH = BATCH
base.MODELS = ROOT / "assets/models/midgard/rooms_dark"
base.PREVIEWS = BATCH / "previews"
original_finish = base.finish
original_load = base.load_materials
original_gate = base.rune_gate
original_bank = base.bank


def finish(obj, name, material, bevel=0):
    return original_finish(obj, name, material, bevel * .24)


def dark_studio(helper):
    original = helper.studio

    def studio():
        scene = original()
        world = scene.world.node_tree.nodes.get("Background")
        world.inputs["Color"].default_value = (.055, .080, .12, 1)
        world.inputs["Strength"].default_value = .38
        colors = {
            "Warm key": ((.74, .83, 1.0), 390),
            "Cool fill": ((.51, .66, .86), 125),
            "Roof rim": ((.92, .56, .27), 300),
        }
        for name, (color, power) in colors.items():
            light = bpy.data.objects.get(name)
            light.data.color = color
            light.data.energy = power
        floor = bpy.data.objects.get("Review floor")
        floor.data.materials[0].diffuse_color = (.012, .019, .026, 1)
        floor.data.materials[0].use_nodes = True
        floor.data.materials[0].node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (.012, .019, .026, 1)
        scene.view_settings.look = "AgX - Medium High Contrast"
        return scene

    helper.studio = studio
    return helper


def load_materials():
    helper = original_load()
    palette = [("Stone", "3e4852"), ("Timber", "3c302b"), ("Snow", "82959d"),
               ("Iron", "303b44"), ("Amber glass", "cb8047"), ("Dark oak", "171e27")]
    images, _ = helper.make_atlas(palette)
    for group, _ in palette:
        material = helper.material_for(group, images)
        shader = material.node_tree.nodes.get("Principled BSDF")
        if group == "Amber glass":
            shader.inputs["Emission Color"].default_value = (.8, .17, .025, 1)
            shader.inputs["Emission Strength"].default_value = 1.1
        if group == "Iron":
            shader.inputs["Roughness"].default_value = .72
        base.MATS[group] = material
    return dark_studio(helper)


def snow_floor():
    base.box("Basalt foundation", (0,0,-.20), (3,3,.40), "Dark oak", .015)
    for i in range(5):
        for j in range(5):
            x,y=(i-2)*.59,(j-2)*.59
            base.box("Split basalt", (x,y,-.045+base.RNG.uniform(-.012,.012)), (.551,.561,.13),
                     "Stone", .018, (0,0,base.RNG.uniform(-.035,.035)))
    for i in range(5):
        x,y=base.RNG.uniform(-1.20,1.20),base.RNG.uniform(-1.20,1.20)
        width=.24+base.RNG.random()*.35
        depth=.08+base.RNG.random()*.19
        z=.035+i*.003
        vertices=[(x+math.cos(a)*width*.5*base.RNG.uniform(.7,1.1),
                   y+math.sin(a)*depth*.5*base.RNG.uniform(.65,1.1),z)
                  for a in [j*math.tau/7 for j in range(7)]]
        mesh=bpy.data.meshes.new("Wind-scoured snow")
        mesh.from_pydata(vertices,[],[tuple(range(7))])
        mesh.update()
        patch=bpy.data.objects.new("Dirty windpacked snow",mesh)
        bpy.context.collection.objects.link(patch)
        bpy.ops.object.select_all(action="DESELECT")
        patch.select_set(True)
        bpy.context.view_layer.objects.active=patch
        base.finish(patch,"Dirty windpacked snow","Snow")
    for i in range(4):
        x,y=base.RNG.uniform(-1.15,1.15),base.RNG.uniform(-1.1,1.1)
        base.beam("Stone fracture",(x,y,.025),(x+.18,y+.26,.025),.009,"Dark oak")


def bank(x):
    original_bank(x)
    for j in range(6):
        y=(j-2.5)*.47
        inner = x + (.73 if x < 0 else -.73)
        base.box("Fractured cliff face",(inner,y,-.56),(.13,.18,.64), "Stone",.01,
                 (0,base.RNG.uniform(-.12,.12),base.RNG.uniform(-.18,.18)))
    for i in range(4):
        base.box("Weathered rim",(x+base.RNG.uniform(-.5,.5),base.RNG.uniform(-1.4,1.4),.046),
                 (.15,.065,.012),"Stone",.004)


def rune_gate():
    original_gate()
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    moving = bpy.data.objects.get("GateMoving")
    for i in range(6):
        x=(i-2.5)*.28
        splinter=base.box("Charred plank scar",(x,-.083,.72+(i%3)*.20),(.012,.009,.29), "Dark oak",0,
                         (0,base.RNG.uniform(-.12,.12),0))
        base.parent_at(splinter,moving)
    for side in [-1,1]:
        for i in range(3):
            base.box("Pillar fracture",(side*1.12,-.247,.68+i*.45),(.27,.009,.013),"Dark oak",0,(0,0,0))


base.finish = finish
base.load_materials = load_materials
base.snow_floor = snow_floor
base.bank = bank
base.rune_gate = rune_gate

if __name__ == "__main__":
    base.main()
