"""Blender -b <anim.blend> --python animprev_enemy.py -- <rig> <out dir> <keys,> [spear.glb] [lift]"""
import bpy, sys, os, math
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:]
rig, out, keys = args[0], args[1], args[2].split(",")
spear = args[3] if len(args) > 3 and args[3] != "-" else None
lift = float(args[4]) if len(args) > 4 else 0.0
sc = bpy.context.scene
arm = bpy.data.objects[rig]
arm.location.z += lift
if spear:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=spear)
    for o in [o for o in bpy.data.objects if o not in before and o.type == "MESH"]:
        o.parent = arm; o.parent_type = "BONE"; o.parent_bone = "spear"; o.matrix_parent_inverse.identity()
        o.location = (0, -arm.data.bones["spear"].length, 0); o.rotation_euler = (0, 0, 0)
        o.scale = (1 / arm.matrix_world.to_scale()[0],) * 3
for o in bpy.data.objects:
    if o.type == "MESH":
        for m in o.data.materials:
            if m: m.use_backface_culling = False
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
next(n for n in w.node_tree.nodes if n.type == "BACKGROUND").inputs[0].default_value = (0.42, 0.44, 0.47, 1)
for name, rot, e in [("k", (50, 0, 35), 3.0), ("f", (60, 0, -140), 1.2)]:
    d = bpy.data.lights.new(name, "SUN"); d.energy = e
    o = bpy.data.objects.new(name, d); o.rotation_euler = [math.radians(a) for a in rot]; sc.collection.objects.link(o)
bpy.ops.mesh.primitive_plane_add(size=30)
fl = bpy.context.object; fm = bpy.data.materials.new("fl"); fm.use_nodes = True
next(n for n in fm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs[0].default_value = (0.3, 0.31, 0.33, 1); fl.data.materials.append(fm)
sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = int(os.environ.get("CAMW", 480)), 540
sc.render.fps = 30
cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"; cd.ortho_scale = 3.4 * max(1, int(os.environ.get("CAMW", 480)) / 540)
cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
v = Vector(tuple(map(float, os.environ.get("CAMV", "0.75,-1,0.55").split(",")))).normalized()
cam.location = Vector((0, float(os.environ.get("CAMY", 0)), 1.15 + lift)) + v * 12
cam.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
ad = arm.animation_data
for t in ad.nla_tracks: t.mute = True
for key in keys:
    act = bpy.data.actions[key]; ad.action = act
    try: ad.action_slot = act.slots[0]
    except Exception: pass
    f0, f1 = map(int, act.frame_range)
    d = os.path.join(out, key); os.makedirs(d, exist_ok=True)
    for f in range(f0, f1 + 1):
        sc.frame_set(f); sc.render.filepath = os.path.join(d, f"f{f - f0:03d}.png")
        bpy.ops.render.render(write_still=True)
    print("DONE", key, f1 - f0 + 1)
