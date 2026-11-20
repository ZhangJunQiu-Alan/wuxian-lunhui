"""Blender -b draugr_anim.blend --python spear_solve.py -- <out.blend> <butt m> <keys,>
Adds bone 'spear' (child of RightHand, head at the right palm, +Y along the spear) and, per frame, keys the spear
direction that stays out of the body: body = capsules around bones (radius from the skinned verts), cost =
penetration + deviation from the right->left hand line + change from the previous frame."""
import bpy, sys, math, json
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree
args = sys.argv[sys.argv.index("--") + 1:]
out_blend, BUTT, keys = args[0], float(args[1]), args[2].split(",")
LEN = 2.3
sc = bpy.context.scene
arm = bpy.data.objects["draugr_rig"]; body = bpy.data.objects["draugr_body"]; sock = bpy.data.objects["weapon_r"]
ad = arm.animation_data
CAPS = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg",
        "RightFoot", "LeftShoulder", "RightShoulder", "LeftArm", "RightArm"]
CAPS = ["mixamorig:" + c for c in CAPS]

# --- capsule radii at rest (armature space), from vertices mostly weighted to each bone ---
ad.action = None
for pb in arm.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)
sc.frame_set(1)
gi = {g.name: g.index for g in body.vertex_groups}
to_arm = arm.matrix_world.inverted() @ body.matrix_world
def seg_dist(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length
radius = {}
for c in CAPS:
    bone = arm.data.bones[c]; a, b = bone.head_local, bone.tail_local
    ds = []
    for v in body.data.vertices:
        w = next((g.weight for g in v.groups if g.group == gi.get(c, -1)), 0)
        if w > 0.5:
            ds.append(seg_dist(to_arm @ v.co, a, b))
    ds.sort()
    radius[c] = (ds[int(len(ds) * 0.6)] if ds else 2.0) * arm.matrix_world.to_scale()[0]
# head / hips capsules are short; keep them reasonable
names = {g.index: g.name for g in body.vertex_groups}
def dom(v): return names[max(v.groups, key=lambda g: g.weight).group] if len(v.groups) else ""
handv = {v.index for v in body.data.vertices if "Hand" in dom(v)}
keep_polys = [i for i, p in enumerate(body.data.polygons) if not any(k in handv for k in p.vertices)]
def body_bvh():
    dg = bpy.context.evaluated_depsgraph_get(); ev = body.evaluated_get(dg); me = ev.to_mesh()
    mw = body.matrix_world; vs = [mw @ v.co for v in me.vertices]
    t = BVHTree.FromPolygons(vs, [tuple(me.polygons[i].vertices) for i in keep_polys]); ev.to_mesh_clear(); return t
def mesh_hits(bvh, o, d, lp):
    up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    x = d.cross(up).normalized(); y = x.cross(d).normalized(); n = 0
    for off in (Vector(), x * 0.026, -x * 0.026, y * 0.026, -y * 0.026):
        a = o + off - d * BUTT; dist = BUTT + LEN - BUTT
        while dist > 0:
            loc, _, _, t = bvh.ray_cast(a, d, dist)
            if loc is None: break
            sv = (loc - o).dot(d)
            if abs(sv) > 0.12 and (loc - lp).length > 0.12: n += 1
            a = loc + d * 0.002; dist -= t + 0.002
    return n
info = {"radius": {k.split(":")[1]: round(v, 3) for k, v in radius.items()}}

# --- spear bone ---
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones.new("spear")
eb.parent = arm.data.edit_bones["mixamorig:RightHand"]
inv = arm.matrix_world.inverted()
sm = inv @ sock.matrix_world
eb.head = sm.translation; eb.tail = sm.translation + sm.to_3x3() @ Vector((0, 0.3, 0))
eb.align_roll(sm.to_3x3() @ Vector((0, 0, 1)))
eb.use_deform = False
bpy.ops.object.mode_set(mode="OBJECT")
spb = arm.pose.bones["spear"]; spb.rotation_mode = "QUATERNION"
REL = arm.data.bones["mixamorig:RightHand"].matrix_local.inverted() @ arm.data.bones["spear"].matrix_local

def P(n): return arm.matrix_world @ arm.pose.bones[n].head
def T(n): return arm.matrix_world @ arm.pose.bones[n].tail
samples = [-BUTT + i * 0.05 for i in range(int(LEN / 0.05) + 1)]
def penetration(o, d, caps, lp=None):
    pen = 0.0
    for s in samples:
        if abs(s) < 0.12: continue  # inside the fist
        p = o + d * s
        if lp is not None and (p - lp).length < 0.12: continue  # left grip
        if p.z < 0.03: pen += 0.03 - p.z
        for a, b, r in caps:
            k = r + 0.02 - seg_dist(p, a, b)
            if k > 0: pen += k
    return pen
def left_palm():
    h = P("mixamorig:LeftHand"); m = P("mixamorig:LeftHandMiddle1")
    return h + (m - h) * 0.55
IKW = ("mixamorig:LeftArm", "mixamorig:LeftForeArm")
def rot_about(pb, pivot, q):
    pb.matrix = Matrix.Translation(pivot) @ q.to_matrix().to_4x4() @ Matrix.Translation(-pivot) @ pb.matrix
    bpy.context.view_layer.update()
def key_rot(pb, f):
    pb.keyframe_insert("rotation_quaternion" if pb.rotation_mode == "QUATERNION" else "rotation_euler", frame=f)
def right_palm(): return sock.matrix_world.translation.copy()
ARMS = {"L": ("mixamorig:LeftArm", "mixamorig:LeftForeArm", left_palm), "R": ("mixamorig:RightArm", "mixamorig:RightForeArm", right_palm)}
def two_bone(side, tgt_palm):
    """move the palm of one arm to tgt_palm (world) with analytic two-bone IK, keeping the elbow's bend plane"""
    inv = arm.matrix_world.inverted(); un, fn, palm = ARMS[side]
    A, F = arm.pose.bones[un], arm.pose.bones[fn]
    for _ in range(3):
        lp = palm(); wrist = arm.matrix_world @ F.tail
        T = inv @ (tgt_palm - (lp - wrist)); S, E, W = A.head.copy(), A.tail.copy(), F.tail.copy()
        a, b = (E - S).length, (W - E).length
        dist = max(abs(a - b) + 1e-4, min(a + b - 1e-4, (T - S).length))
        u = (T - S).normalized(); pole = E - S; v = pole - u * pole.dot(u)
        if v.length < 1e-6: break
        v.normalize()
        ca = (a * a + dist * dist - b * b) / (2 * a * dist); sa = max(0.0, 1 - ca * ca) ** 0.5
        E2 = S + u * a * ca + v * a * sa
        rot_about(A, S, (E - S).rotation_difference(E2 - S))
        E3, W3 = F.head.copy(), F.tail.copy()
        rot_about(F, E3, (W3 - E3).rotation_difference(T - E3))
def key_arm(side, f):
    key_rot(arm.pose.bones[ARMS[side][0]], f); key_rot(arm.pose.bones[ARMS[side][1]], f)
def ik_left(o, d, f):
    # pull the left palm onto the spear line, fading out when the hand clearly lets go
    lp = left_palm(); s = (lp - o).dot(d)
    if not (0.15 < s < 1.7): return None
    gap = (o + d * s - lp).length
    w = 1.0 if gap < 0.2 else max(0.0, (0.35 - gap) / 0.15)
    if w <= 0: return gap
    for _ in range(2):
        lp = left_palm(); s = (lp - o).dot(d); two_bone("L", lp + (o + d * s - lp) * w)
    key_arm("L", f); curl("L", o, d, w, f)
    return gap
CURL = {"Index": (55, 65, 45), "Middle": (55, 65, 45), "Ring": (55, 65, 45), "Pinky": (55, 65, 45), "Thumb": (0, 20, 25)}
SIGN = {}
def line_dist(p, o, d): return (p - (o + d * (p - o).dot(d))).length
def curl(side, o, d, w, f):
    """close the fingers of one hand around the shaft (additive local-X curl); sign picked so the tips approach the shaft"""
    pre = "mixamorig:" + ("Left" if side == "L" else "Right") + "Hand"
    if side not in SIGN:
        tip = arm.pose.bones[pre + "Middle3"]; best = None
        for sg in (1, -1):
            saved = {}
            for j in (1, 2, 3):
                pb = arm.pose.bones[pre + "Middle%d" % j]; saved[pb] = pb.rotation_quaternion.copy()
                pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion((1, 0, 0), math.radians(60 * sg))
            bpy.context.view_layer.update()
            dd = line_dist(arm.matrix_world @ tip.tail, o, d)
            for pb, q in saved.items(): pb.rotation_quaternion = q
            bpy.context.view_layer.update()
            if best is None or dd < best[0]: best = (dd, sg)
        SIGN[side] = best[1]
    for fn, angs in CURL.items():
        for j, a in zip((1, 2, 3), angs):
            if not a: continue
            pb = arm.pose.bones.get(pre + fn + str(j))
            if pb is None: continue
            pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion((1, 0, 0), math.radians(a * w * SIGN[side]))
            pb.keyframe_insert("rotation_quaternion", frame=f)
    bpy.context.view_layer.update()
def shift_hands(caps, f):
    """if the straight hand-to-hand line hits the body, move both palms away from the torso (smallest shift that clears it)"""
    rp, lp = right_palm(), left_palm()
    if (lp - rp).length < 0.15: return 0.0
    mid = (rp + lp) / 2; chest = P("mixamorig:Spine1")
    away = mid - chest; away.z = 0
    if away.length < 1e-3: return 0.0
    away.normalize(); bvh = body_bvh(); d = (lp - rp).normalized()
    def bad(dl): return 400 * penetration(rp + dl, d, caps, lp + dl) + 30 * mesh_hits(bvh, rp + dl, d, lp + dl)
    if bad(Vector()) == 0: return 0.0
    best = None
    for k in range(1, 7):
        for up in (0.0, 0.04, 0.08):
            dl = away * 0.03 * k + Vector((0, 0, up)); c = bad(dl) + 2 * dl.length
            if best is None or c < best[0]: best = (c, dl)
    dl = best[1]
    two_bone("R", rp + dl); two_bone("L", lp + dl); key_arm("R", f); key_arm("L", f)
    return dl.length
def ang(a, b): return math.degrees(a.angle(b)) if a.length and b.length else 0.0
# candidate directions around a base: cone rings
def cands(d0):
    up = Vector((0, 0, 1)) if abs(d0.z) < 0.9 else Vector((1, 0, 0))
    x = d0.cross(up).normalized(); y = x.cross(d0).normalized()
    out = [d0]
    for t in (8, 16, 25, 35, 50, 65, 80):
        tr = math.radians(t)
        for k in range(16):
            ph = 2 * math.pi * k / 16
            out.append((d0 * math.cos(tr) + (x * math.cos(ph) + y * math.sin(ph)) * math.sin(tr)).normalized())
    for k in range(24):  # flat on the ground (lying down)
        for e in (0.0, 0.08):
            out.append(Vector((math.cos(2 * math.pi * k / 24), math.sin(2 * math.pi * k / 24), e)).normalized())
    return out
for key in keys:
    act = bpy.data.actions[key]; ad.action = act; ad.action_slot = act.slots[0]
    f0, f1 = map(int, act.frame_range)
    prev = None; before = after = 0; worst = 0.0; devs = []; gaps = []; shifts = []
    for f in range(f0, f1 + 1):
        spb.rotation_quaternion = (1, 0, 0, 0)
        sc.frame_set(f)
        caps = [(P(c), T(c), radius[c]) for c in CAPS]
        shifts.append(shift_hands(caps, f)); caps = [(P(c), T(c), radius[c]) for c in CAPS]
        bvh = body_bvh()
        o = arm.matrix_world @ spb.head
        r, l = o, left_palm()
        rest_d = (arm.matrix_world.to_3x3() @ (arm.pose.bones["mixamorig:RightHand"].matrix @ REL).to_3x3() @ Vector((0, 1, 0))).normalized()
        d0 = (l - r).normalized() if (l - r).length > 0.15 else rest_d
        p0 = penetration(o, d0, caps, l)
        best = None
        for d in cands(d0):
            if d.z < -0.8: continue  # never straight into the floor
            c = 400 * penetration(o, d, caps, l) + 30 * mesh_hits(bvh, o, d, l) + 0.25 * ang(d, d0) + (0.6 * ang(d, prev) if prev else 0)
            if best is None or c < best[0]: best = (c, d)
        d = best[1]
        p1 = penetration(o, d, caps, l) + 0.02 * mesh_hits(bvh, o, d, l)
        before += p0 > 0.01; after += p1 > 0.01; worst = max(worst, p1); devs.append(ang(d, d0))
        prev = d
        # pose: bone +Y = d, bone +Z ~ world up
        y = d; xax = y.cross(Vector((0, 0, 1)))
        if xax.length < 1e-3: xax = y.cross(Vector((1, 0, 0)))
        xax.normalize(); z = xax.cross(y).normalized()
        Mw = Matrix((xax, y, z)).transposed().to_4x4(); Mw.translation = o
        spb.matrix = arm.matrix_world.inverted() @ Mw
        bpy.context.view_layer.update()
        spb.keyframe_insert("rotation_quaternion", frame=f, group="spear")
        curl("R", o, d, 1.0, f)
        g = ik_left(o, d, f); gaps.append(round(g, 2) if g is not None else None)
    devs.sort()
    info[key] = {"frames": f1 - f0 + 1, "clipping_before": before, "clipping_after": after, "worst_cm": round(worst * 100, 1),
                 "deviation_median_deg": round(devs[len(devs) // 2]), "deviation_max_deg": round(devs[-1]), "hands_shift_max_cm": round(max(shifts) * 100), "left_off_spear": sum(1 for g in gaps if g is None or g >= 0.35)}
ad.action = None
spb.rotation_quaternion = (1, 0, 0, 0); spb.scale = (1, 1, 1); spb.location = (0, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
print("SOLVE", json.dumps(info))
