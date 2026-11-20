"""Blender -b <anim.blend> --python face_fix.py -- <rig> <out.blend> key=mode ...  mode: body | spear | hands
Rotate a clip about the vertical axis through the origin (via the Hips root bone) so it faces -Y:
body = mean shoulder facing; spear = right->left hand at max reach; hands = hand midpoint from hips at max reach."""
import bpy, sys, math, json
from mathutils import Vector, Matrix, Quaternion
from bpy_extras import anim_utils
args = sys.argv[sys.argv.index("--") + 1:]
rig, out_blend = args[0], args[1]
modes = dict(a.split("=") for a in args[2:])
sc = bpy.context.scene; arm = bpy.data.objects[rig]; ad = arm.animation_data
hb = arm.data.bones["mixamorig:Hips"]; pbh = arm.pose.bones["mixamorig:Hips"]
def P(n): return arm.matrix_world @ arm.pose.bones[n].head
def yaw_of(v): return math.degrees(math.atan2(v.x, -v.y))
def measure(mode, f0, f1):
    vals, best = [], None
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        right = P("mixamorig:RightShoulder") - P("mixamorig:LeftShoulder"); right.z = 0
        vals.append(yaw_of(Vector((0, 0, 1)).cross(right)))
        l, r, h = P("mixamorig:LeftHand"), P("mixamorig:RightHand"), P("mixamorig:Hips")
        mid = (l + r) / 2
        reach = (mid - h).xy.length
        v = (l - r) if mode == "spear" else (mid - h)
        if best is None or reach > best[0]:
            best = (reach, yaw_of(Vector((v.x, v.y, 0))))
    if mode in ("spear", "hands"): return best[1]
    sx = sum(math.sin(math.radians(a)) for a in vals); cy = sum(math.cos(math.radians(a)) for a in vals)
    return math.degrees(math.atan2(sx, cy))
B = (arm.matrix_world @ hb.matrix_local).to_3x3()
info = {}
for key, mode in modes.items():
    act = bpy.data.actions[key]; ad.action = act; ad.action_slot = act.slots[0]
    f0, f1 = map(int, act.frame_range)
    phi = measure(mode, f0, f1)
    R = Matrix.Rotation(math.radians(-phi), 3, "Z")
    C = B.inverted() @ R @ B
    Cq = C.to_quaternion()
    cb = anim_utils.action_get_channelbag_for_slot(act, act.slots[0])
    path_r = 'pose.bones["mixamorig:Hips"].rotation_quaternion'; path_l = 'pose.bones["mixamorig:Hips"].location'
    rot = sorted([fc for fc in cb.fcurves if fc.data_path == path_r], key=lambda c: c.array_index)
    loc = sorted([fc for fc in cb.fcurves if fc.data_path == path_l], key=lambda c: c.array_index)
    frames = sorted({int(round(k.co.x)) for k in rot[0].keyframe_points})
    qs = {f: Quaternion([rot[i].evaluate(f) for i in range(4)]) for f in frames}
    ls = {f: Vector([loc[i].evaluate(f) for i in range(3)]) for f in frames} if loc else {}
    # rest head offset rotates too: rotate the whole hip world position about the origin
    head = arm.matrix_world @ hb.head_local
    for f in frames:
        q = Cq @ qs[f]
        for i in range(4):
            kp = next(k for k in rot[i].keyframe_points if int(round(k.co.x)) == f)
            kp.co.y = q[i]; kp.handle_left.y = q[i]; kp.handle_right.y = q[i]
        if loc:
            wpos = head + B @ ls[f]
            wnew = R @ wpos
            lnew = B.inverted() @ (wnew - head)
            for i in range(3):
                kp = next(k for k in loc[i].keyframe_points if int(round(k.co.x)) == f)
                kp.co.y = lnew[i]; kp.handle_left.y = lnew[i]; kp.handle_right.y = lnew[i]
    for fc in rot + loc: fc.update()
    info[key] = [round(phi), round(measure(mode, f0, f1))]
ad.action = None
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
print("FACEFIX before/after", json.dumps(info))
