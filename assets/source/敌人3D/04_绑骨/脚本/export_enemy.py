"""Blender -b <anim.blend> --python export_enemy.py -- <rig> <body> <out.blend> <out.glb> <spear.glb|-> final=src ...
Keep only the chosen clips (renamed), one NLA track each, rest pose reset; optional spear mesh on bone 'spear'; export GLB."""
import bpy, sys, json
from mathutils import Matrix
args = sys.argv[sys.argv.index("--") + 1:]
rig, body, out_blend, out_glb, spear = args[:5]
pick = dict(a.split("=") for a in args[5:])
arm = bpy.data.objects[rig]; ad = arm.animation_data; sc = bpy.context.scene
keep = {}
for final, src in pick.items():
    keep[final] = bpy.data.actions[src]
for a in list(bpy.data.actions):
    if a not in keep.values(): bpy.data.actions.remove(a)
for final, act in keep.items(): act.name = final; act.use_fake_user = True
for t in list(ad.nla_tracks): ad.nla_tracks.remove(t)
ad.action = None
for final, act in keep.items():
    tr = ad.nla_tracks.new(); tr.name = final
    st = tr.strips.new(final, int(act.frame_range[0]), act); st.action_slot = act.slots[0]
for pb in arm.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
sel = [arm, bpy.data.objects[body]]
if spear != "-":
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=spear)
    for o in [o for o in bpy.data.objects if o not in before]:
        if o.type != "MESH": bpy.data.objects.remove(o); continue
        sbone = arm.data.bones["spear"]; sbone.use_deform = True
        o.parent = None
        o.matrix_world = arm.matrix_world @ sbone.matrix_local @ Matrix.Scale(1 / arm.matrix_world.to_scale()[0], 4)
        bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        vg = o.vertex_groups.new(name="spear"); vg.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
        o.parent = arm; o.matrix_parent_inverse = arm.matrix_world.inverted()
        md = o.modifiers.new("Armature", "ARMATURE"); md.object = arm
        o.name = "spear"; sel.append(o)
if "weapon_r" in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects["weapon_r"])
sc.render.fps = 30
for im in bpy.data.images:
    if im.source == "FILE" and not im.packed_file: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
for im in bpy.data.images:
    if im.size[0] > 2048: im.scale(2048, 2048)
bpy.ops.object.select_all(action="DESELECT")
for o in sel: o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_image_format="JPEG",
    export_skins=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
    export_def_bones=False, export_optimize_animation_size=True)
print("EXP", json.dumps({k: list(map(int, a.frame_range)) for k, a in keep.items()}), "objs", [o.name for o in sel])
