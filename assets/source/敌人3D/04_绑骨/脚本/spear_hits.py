"""Blender -b draugr_spear.blend --python spear_hits.py -- <keys,>: per frame, ray-cast the spear (axis + 4 offset lines, r=2.5cm)
against the deformed body; report frames with hits and which bone region was hit, ignoring the hands' grip zones."""
import bpy, sys, json
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from collections import Counter
keys = sys.argv[sys.argv.index("--") + 1].split(",")
sc = bpy.context.scene; arm = bpy.data.objects["draugr_rig"]; body = bpy.data.objects["draugr_body"]; ad = arm.animation_data
names = {g.index: g.name.split(":")[-1] for g in body.vertex_groups}
BUTT, TIP, R = 0.45, 1.85, float(sys.argv[sys.argv.index("--") + 2]) if len(sys.argv) > sys.argv.index("--") + 2 else 0.025
out = {}
for key in keys:
    act = bpy.data.actions[key]; ad.action = act; ad.action_slot = act.slots[0]
    f0, f1 = map(int, act.frame_range); frames = {}
    for f in range(f0, f1 + 1):
        sc.frame_set(f); dg = bpy.context.evaluated_depsgraph_get()
        ev = body.evaluated_get(dg); me = ev.to_mesh()
        mw = body.matrix_world
        verts = [mw @ v.co for v in me.vertices]; polys = [tuple(p.vertices) for p in me.polygons]
        bvh = BVHTree.FromPolygons(verts, polys)
        M = arm.matrix_world @ arm.pose.bones["spear"].matrix
        o = M.translation; d = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
        ax = (M.to_3x3() @ Vector((1, 0, 0))).normalized(); az = (M.to_3x3() @ Vector((0, 0, 1))).normalized()
        lh = arm.matrix_world @ arm.pose.bones["mixamorig:LeftHand"].head
        hits = Counter()
        for off in (Vector(), ax * R, -ax * R, az * R, -az * R):
            a = o + off - d * BUTT; dist = BUTT + TIP
            while dist > 0:
                loc, n, idx, t = bvh.ray_cast(a, d, dist)
                if loc is None: break
                s = (loc - o).dot(d)
                near_hand = abs(s) < 0.12 or (loc - lh).length < 0.12
                if not near_hand:
                    p = me.polygons[idx]; vi = max(p.vertices, key=lambda i: max((g.weight for g in me.vertices[i].groups), default=0))
                    g = me.vertices[vi].groups
                    hits[names[max(g, key=lambda x: x.weight).group] if len(g) else "?"] += 1
                a = loc + d * 0.002; dist -= t + 0.002
        ev.to_mesh_clear()
        if hits: frames[f] = dict(hits)
    out[key] = {"n": len(frames), "frames": frames}
print("HITS", json.dumps(out))
