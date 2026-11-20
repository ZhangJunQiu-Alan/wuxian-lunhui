import bpy, sys, os, json, mathutils

args = sys.argv[sys.argv.index("--") + 1:]
act_dir, out_blend = args[0], args[1]
ACTS = [("mx_idle", "待机"), ("mx_run", "跑步"), ("mx_dash", "冲刺"), ("mx_attack", "攻击"),
        ("mx_attack2", "攻击2"), ("mx_hit", "受击"), ("mx_death", "死亡")]
sc = bpy.context.scene
tgt = bpy.data.objects["swordsman_rig"]
info = {}

def order(arm):
    out = []
    def walk(b):
        out.append(b.name)
        for c in b.children: walk(c)
    for b in arm.data.bones:
        if b.parent is None: walk(b)
    return out

for key, cn in ACTS:
    before = set(bpy.data.objects); acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=os.path.join(act_dir, cn + ".fbx"))
    new = [o for o in bpy.data.objects if o not in before]
    src = next(o for o in new if o.type == "ARMATURE")
    sact = next(a for a in bpy.data.actions if a not in acts_before)
    src.animation_data.action = sact
    try: src.animation_data.action_slot = sact.slots[0]
    except Exception: pass
    names = [n for n in order(tgt) if n in src.data.bones]
    sw = src.matrix_world; tw = tgt.matrix_world
    srot = sw.to_quaternion(); trot = tw.to_quaternion()
    # rest rotations in world space
    s_rest = {n: srot @ src.data.bones[n].matrix_local.to_quaternion() for n in names}
    t_rest = {n: trot @ tgt.data.bones[n].matrix_local.to_quaternion() for n in names}
    # A-pose vs T-pose: align each source rest bone's direction to the target's first,
    # so only the roll difference is carried over (bones then point where the source points)
    for n in names:
        ds = (s_rest[n] @ mathutils.Vector((0, 1, 0))); dt = (t_rest[n] @ mathutils.Vector((0, 1, 0)))
        swing = ds.rotation_difference(dt)
        s_rest[n] = swing @ s_rest[n]
    fix = {n: s_rest[n].inverted() @ t_rest[n] for n in names}
    s_hip0 = (sw @ src.data.bones["mixamorig:Hips"].head_local)
    t_hip0 = (tw @ tgt.data.bones["mixamorig:Hips"].head_local)
    ratio = t_hip0.z / s_hip0.z
    act = bpy.data.actions.new(key); act.use_fake_user = True
    tad = tgt.animation_data; tad.action = act
    slot = act.slots.new(id_type="OBJECT", name=tgt.name) if hasattr(act, "slots") else None
    if slot: tad.action_slot = slot
    f0, f1 = map(int, sact.frame_range)
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        M = {}
        for n in names:
            spb = src.pose.bones[n]
            qs = srot @ spb.matrix.to_quaternion()
            qt = qs @ fix[n]  # fix[n] is a pure roll about the bone axis
            bone = tgt.data.bones[n]
            if bone.parent is None or n == "mixamorig:Hips":
                hw = sw @ spb.head
                pos_w = mathutils.Vector((t_hip0.x + (hw.x - s_hip0.x) * ratio, t_hip0.y + (hw.y - s_hip0.y) * ratio, hw.z * ratio))
                pos = tw.inverted() @ pos_w
            else:
                pm = M[bone.parent.name]
                rest_local = bone.parent.matrix_local.inverted() @ bone.matrix_local
                pos = (pm @ rest_local).translation
            q_arm = trot.inverted() @ qt
            M[n] = mathutils.Matrix.Translation(pos) @ q_arm.to_matrix().to_4x4()
        for n in names:
            bone = tgt.data.bones[n]; pb = tgt.pose.bones[n]
            if bone.parent is None:
                basis = bone.matrix_local.inverted() @ M[n]
            else:
                rest_local = bone.parent.matrix_local.inverted() @ bone.matrix_local
                basis = rest_local.inverted() @ M[bone.parent.name].inverted() @ M[n]
            pb.rotation_mode = "QUATERNION"
            l, r, _ = basis.decompose()
            pb.rotation_quaternion = r
            pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
            if n == "mixamorig:Hips":
                pb.location = l; pb.keyframe_insert("location", frame=f, group=n)
    tad.action = None
    for o in new: bpy.data.objects.remove(o)
    bpy.data.actions.remove(sact)
    info[key] = [f0, f1, round(ratio, 3)]
for pb in tgt.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)
bpy.ops.outliner.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
print("RT", json.dumps(info))
