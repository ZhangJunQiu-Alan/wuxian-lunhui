"""Blender -b <rigged.blend> --python retarget_enemy.py -- <rig name> <act dir> <out.blend> <skip substrings,comma|-> key=file ...
Mixamo (mixamorig1:*) -> Tripo (mixamorig:*) per-frame world-space bone direction match, keeping only the fixed
roll difference (handles T-pose vs A-pose). Hips location scaled by hip-height ratio. Bones containing a skip
substring stay at rest (e.g. legs for the legless ice spirit)."""
import bpy, sys, os, json, mathutils
args = sys.argv[sys.argv.index("--") + 1:]
rig_name, act_dir, out_blend, skip = args[0], args[1], args[2], args[3]
skip = [] if skip == "-" else skip.split(",")
pairs = [a.split("=", 1) for a in args[4:]]
sc = bpy.context.scene
tgt = bpy.data.objects[rig_name]
info = {}
def suffix(n): return n.split(":", 1)[-1]
def order(arm):
    out = []
    def walk(b):
        out.append(b.name)
        for c in b.children: walk(c)
    for b in arm.data.bones:
        if b.parent is None: walk(b)
    return out
for key, fn in pairs:
    before = set(bpy.data.objects); acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=os.path.join(act_dir, fn))
    new = [o for o in bpy.data.objects if o not in before]
    src = next(o for o in new if o.type == "ARMATURE")
    sact = next(a for a in bpy.data.actions if a not in acts_before)
    src.animation_data.action = sact
    try: src.animation_data.action_slot = sact.slots[0]
    except Exception: pass
    smap = {suffix(b.name): b.name for b in src.data.bones}
    names = [n for n in order(tgt) if suffix(n) in smap and not any(s in n for s in skip)]
    sw = src.matrix_world; tw = tgt.matrix_world
    srot = sw.to_quaternion(); trot = tw.to_quaternion()
    s_rest = {n: srot @ src.data.bones[smap[suffix(n)]].matrix_local.to_quaternion() for n in names}
    t_rest = {n: trot @ tgt.data.bones[n].matrix_local.to_quaternion() for n in names}
    for n in names:
        ds = s_rest[n] @ mathutils.Vector((0, 1, 0)); dt = t_rest[n] @ mathutils.Vector((0, 1, 0))
        s_rest[n] = ds.rotation_difference(dt) @ s_rest[n]
    fix = {n: s_rest[n].inverted() @ t_rest[n] for n in names}
    s_hip0 = sw @ src.data.bones[smap["Hips"]].head_local
    t_hip0 = tw @ tgt.data.bones["mixamorig:Hips"].head_local
    ratio = t_hip0.z / s_hip0.z
    act = bpy.data.actions.new(key); act.use_fake_user = True
    tad = tgt.animation_data or tgt.animation_data_create(); tad.action = act
    slot = act.slots.new(id_type="OBJECT", name=tgt.name) if hasattr(act, "slots") else None
    if slot: tad.action_slot = slot
    f0, f1 = map(int, sact.frame_range)
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        M = {}
        for n in order(tgt):
            bone = tgt.data.bones[n]
            if n not in names:
                # untouched bones keep their rest offset from the (animated) parent
                if bone.parent is None:
                    M[n] = bone.matrix_local.copy()
                else:
                    M[n] = M[bone.parent.name] @ (bone.parent.matrix_local.inverted() @ bone.matrix_local)
                continue
            spb = src.pose.bones[smap[suffix(n)]]
            qt = (srot @ spb.matrix.to_quaternion()) @ fix[n]
            if bone.parent is None or suffix(n) == "Hips":
                hw = sw @ spb.head
                pos_w = mathutils.Vector((t_hip0.x + (hw.x - s_hip0.x) * ratio, t_hip0.y + (hw.y - s_hip0.y) * ratio, hw.z * ratio))
                pos = tw.inverted() @ pos_w
            else:
                pos = (M[bone.parent.name] @ (bone.parent.matrix_local.inverted() @ bone.matrix_local)).translation
            M[n] = mathutils.Matrix.Translation(pos) @ (trot.inverted() @ qt).to_matrix().to_4x4()
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
            if suffix(n) == "Hips":
                pb.location = l; pb.keyframe_insert("location", frame=f, group=n)
    tad.action = None
    for o in new: bpy.data.objects.remove(o)
    bpy.data.actions.remove(sact)
    info[key] = [f0, f1, round(ratio, 3), len(names)]
for pb in tgt.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)
bpy.ops.outliner.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
print("RT", json.dumps(info))
