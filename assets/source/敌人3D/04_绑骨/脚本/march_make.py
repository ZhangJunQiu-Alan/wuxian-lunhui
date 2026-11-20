"""Blender -b draugr_anim.blend --python march_make.py -- <out.blend> new=src ...
Spear-advance walk: legs/torso from a walk clip, arms re-posed by two-bone IK each frame so the spear is levelled forward
(right fist beside the right hip, left fist ahead along the spear, tip slightly raised). Character faces -Y, right = -X."""
import bpy, sys, math
from mathutils import Vector, Matrix
args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]; pairs = [a.split("=") for a in args[1:]]
sc = bpy.context.scene; arm = bpy.data.objects["draugr_rig"]; sock = bpy.data.objects["weapon_r"]; ad = arm.animation_data
F, RT, UP = Vector((0, -1, 0)), Vector((-1, 0, 0)), Vector((0, 0, 1))
RSIDE, RFWD, RUP, GRIP, PITCH = 0.22, 0.18, 0.10, 0.40, 8
def P(n): return arm.matrix_world @ arm.pose.bones[n].head
def left_palm():
    h = P("mixamorig:LeftHand"); m = P("mixamorig:LeftHandMiddle1"); return h + (m - h) * 0.55
def right_palm(): return sock.matrix_world.translation.copy()
ARMS = {"L": ("mixamorig:LeftArm", "mixamorig:LeftForeArm", left_palm), "R": ("mixamorig:RightArm", "mixamorig:RightForeArm", right_palm)}
def rot_about(pb, pivot, q):
    pb.matrix = Matrix.Translation(pivot) @ q.to_matrix().to_4x4() @ Matrix.Translation(-pivot) @ pb.matrix
    bpy.context.view_layer.update()
def two_bone(side, tgt, pole_hint):
    inv = arm.matrix_world.inverted(); un, fn, palm = ARMS[side]; A, Fb = arm.pose.bones[un], arm.pose.bones[fn]
    for _ in range(4):
        lp = palm(); wrist = arm.matrix_world @ Fb.tail
        T = inv @ (tgt - (lp - wrist)); S, E = A.head.copy(), A.tail.copy(); W = Fb.tail.copy()
        a, b = (E - S).length, (W - E).length
        dist = max(abs(a - b) + 1e-4, min(a + b - 1e-4, (T - S).length))
        u = (T - S).normalized(); pole = (inv.to_3x3() @ pole_hint); v = pole - u * pole.dot(u)
        if v.length < 1e-6: break
        v.normalize()
        ca = (a * a + dist * dist - b * b) / (2 * a * dist); sa = max(0.0, 1 - ca * ca) ** 0.5
        E2 = S + u * a * ca + v * a * sa
        rot_about(A, S, (E - S).rotation_difference(E2 - S))
        E3, W3 = Fb.head.copy(), Fb.tail.copy()
        rot_about(Fb, E3, (W3 - E3).rotation_difference(T - E3))
    for pb in (A, Fb): pb.keyframe_insert("rotation_quaternion", frame=sc.frame_current)
d = (F * math.cos(math.radians(PITCH)) + UP * math.sin(math.radians(PITCH))).normalized()
for new, src in pairs:
    if new in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[new])
    act = bpy.data.actions[src].copy(); act.name = new; act.use_fake_user = True; ad.action = act; ad.action_slot = act.slots[0]
    f0, f1 = map(int, act.frame_range); err = 0.0
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        hips = P("mixamorig:Hips")
        rp = hips + RT * RSIDE + F * RFWD + UP * RUP
        lp = rp + d * GRIP + RT * -0.10
        two_bone("R", rp, RT * 1 + UP * -0.3 + F * -0.6)   # right elbow out and back
        two_bone("L", lp, RT * -1 + UP * -0.8)              # left elbow down and out
        err = max(err, (right_palm() - rp).length, (left_palm() - lp).length)
    print("MARCH", new, src, f1 - f0 + 1, "max_err_cm", round(err * 100, 1))
ad.action = None
bpy.ops.wm.save_as_mainfile(filepath=out)
