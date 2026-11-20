import bpy, sys, os, json
args = sys.argv[sys.argv.index("--") + 1:]
out_dir = args[0]
# chosen action -> exported name; dash/death can be swapped to the Tripo versions via args
pick = {"idle": "mx_idle", "run": "mx_run", "dash": "mx_dash", "attack": "mx_attack",
        "attack2": "mx_attack2", "hit": "mx_hit", "death": "mx_death"}
for a in args[1:]:
    k, v = a.split("="); pick[k] = v
sc = bpy.context.scene
arm = bpy.data.objects["swordsman_rig"]; body = bpy.data.objects["swordsman_body"]
ad = arm.animation_data
# keep the Tripo originals under tripo_* names, chosen ones under final names
for a in list(bpy.data.actions):
    if a.name in ("idle", "run", "dash", "attack", "hit", "death"):
        a.name = "tripo_" + a.name
from bpy_extras import anim_utils
for k, v in pick.items():
    src = v if v.startswith("mx_") else "tripo_" + v.replace("tripo_", "")
    act = bpy.data.actions[src]; act.name = k
    if not v.startswith("mx_"):  # Tripo actions are 24 fps; stretch to 30 fps keeping real-time speed
        f = 30 / 24
        for fc in anim_utils.action_get_channelbag_for_slot(act, act.slots[0]).fcurves:
            for kp in fc.keyframe_points:
                for pt in (kp.co, kp.handle_left, kp.handle_right):
                    pt.x = 1 + (pt.x - 1) * f
            fc.update()
for t in list(ad.nla_tracks): ad.nla_tracks.remove(t)
ad.action = None
for k in pick:
    act = bpy.data.actions[k]; act.use_fake_user = True
    tr = ad.nla_tracks.new(); tr.name = k
    st = tr.strips.new(k, int(act.frame_range[0]), act)
    st.action_slot = act.slots[0]
for pb in arm.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)
sc.render.fps = 30
for im in bpy.data.images:
    if im.source == "FILE" and not im.packed_file: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "swordsman_rigged.blend"))
for im in bpy.data.images:
    if im.size[0] > 2048: im.scale(2048, 2048)
bpy.ops.object.select_all(action="DESELECT")
for o in (arm, body, bpy.data.objects["weapon_r"], bpy.data.objects["sheath_l"]): o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "swordsman_rigged.glb"), export_format="GLB",
    use_selection=True, export_image_format="JPEG", export_skins=True, export_animations=True,
    export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_def_bones=False,
    export_optimize_animation_size=True)
print("EXP", json.dumps({k: [list(bpy.data.actions[k].frame_range)] for k in pick}))
