import bpy, sys, json, mathutils
from bpy_extras import anim_utils
args = sys.argv[sys.argv.index("--") + 1:]
out_blend = args[0]; keys = args[1].split(",")
arm = bpy.data.objects["swordsman_rig"]; sc = bpy.context.scene
ad = arm.animation_data; hb = arm.data.bones["mixamorig:Hips"]
to_bone = hb.matrix_local.to_3x3().inverted() @ arm.matrix_world.inverted().to_3x3()
info = {}
for k in keys:
    act = bpy.data.actions[k]; ad.action = act; ad.action_slot = act.slots[0]
    fcs = anim_utils.action_get_channelbag_for_slot(act, act.slots[0]).fcurves
    loc = {fc.array_index: fc for fc in fcs if fc.data_path == 'pose.bones["mixamorig:Hips"].location'}
    f0, f1 = map(int, act.frame_range)
    pos = {}
    for f in range(f0, f1 + 1):
        sc.frame_set(f); pos[f] = arm.matrix_world @ arm.pose.bones["mixamorig:Hips"].head
    rest = arm.matrix_world @ hb.head_local
    for f in range(f0, f1 + 1):
        d = to_bone @ mathutils.Vector((pos[f].x - rest.x, pos[f].y - rest.y, 0))
        for i, fc in loc.items():
            for kp in fc.keyframe_points:
                if int(round(kp.co.x)) == f:
                    kp.co.y -= d[i]; kp.handle_left.y -= d[i]; kp.handle_right.y -= d[i]
    for fc in loc.values(): fc.update()
    info[k] = round(max((p - rest).xy.length for p in pos.values()), 2)
ad.action = None
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
print("INPLACE max_xy_before", json.dumps(info))
