"""Blender -b <clean.blend> --python rig_enemy.py -- <tripo rig.fbx> <rig name> <scale> <out.blend> [spear]
Bring in Tripo's skeleton, scale it onto the cleaned mesh, transfer Tripo's weights (nearest face interp,
max 4 bones, normalised), parent with an Armature modifier, add weapon_r on the right palm if 'spear'."""
import bpy, sys, json, mathutils
args = sys.argv[sys.argv.index("--") + 1:]
rig_fbx, rig_name, S, out_blend = args[0], args[1], float(args[2]), args[3]
spear = "spear" in args[4:]
info = {}
body = next(o for o in bpy.data.objects if o.type == "MESH")
before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=rig_fbx)
new = [o for o in bpy.data.objects if o not in before]
arm = next(o for o in new if o.type == "ARMATURE")
src = next(o for o in new if o.type == "MESH")
for o in new:
    if o not in (arm, src):
        bpy.data.objects.remove(o)
arm.name = rig_name; arm.data.name = rig_name
arm.scale = (arm.scale[0] * S,) * 3
bpy.context.view_layer.update()
pts = [src.matrix_world @ v.co for v in src.data.vertices]
info["src_height"] = round(max(p.z for p in pts) - min(p.z for p in pts), 3)
info["body_height"] = round(body.dimensions.z, 3)
for g in list(body.vertex_groups):
    body.vertex_groups.remove(g)
m = body.modifiers.new("wt", "DATA_TRANSFER")
m.object = src; m.use_vert_data = True; m.data_types_verts = {"VGROUP_WEIGHTS"}
m.vert_mapping = "POLYINTERP_NEAREST"; m.use_object_transform = True
m.layers_vgroup_select_src = "ALL"; m.layers_vgroup_select_dst = "NAME"
bpy.ops.object.select_all(action="DESELECT"); body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.datalayout_transfer(modifier=m.name)
bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
info["groups"] = len(body.vertex_groups)
info["unweighted_verts"] = sum(1 for v in body.data.vertices if not v.groups)
bpy.data.objects.remove(src)
mw = body.matrix_world.copy()
body.parent = arm; body.matrix_world = mw
am = body.modifiers.new("Armature", "ARMATURE"); am.object = arm

def bone_w(n):
    return arm.matrix_world @ arm.data.bones[n].head_local
if spear:
    hand = bone_w("mixamorig:RightHand"); mid = bone_w("mixamorig:RightHandMiddle1"); th = bone_w("mixamorig:RightHandThumb2")
    f = (mid - hand).normalized(); t = th - hand; blade = (t - f * t.dot(f)).normalized()
    palm = hand.lerp(mid, 0.6)
    e = bpy.data.objects.new("weapon_r", None); e.empty_display_type = "ARROWS"; e.empty_display_size = 0.08
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm; e.parent_type = "BONE"; e.parent_bone = "mixamorig:RightHand"
    y = blade; x = y.cross(f).normalized(); z = x.cross(y).normalized()
    mat = mathutils.Matrix((x, y, z)).transposed().to_4x4(); mat.translation = palm
    bpy.context.view_layer.update(); e.matrix_world = mat
    info["palm"] = [round(v, 3) for v in palm]
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
arm.animation_data_create()
for me in [me for me in bpy.data.meshes if me.users == 0]:
    bpy.data.meshes.remove(me)
for mt in [mt for mt in bpy.data.materials if mt.users == 0]:
    bpy.data.materials.remove(mt)
for im in [im for im in bpy.data.images if im.users == 0]:
    bpy.data.images.remove(im)
info["images"] = [i.name for i in bpy.data.images]
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
print("RIG", json.dumps(info, ensure_ascii=False))
