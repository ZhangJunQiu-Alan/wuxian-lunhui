import bpy, sys, os, json, mathutils

args = sys.argv[sys.argv.index("--") + 1:]
rig_fbx, act_dir, out_blend = args[0], args[1], args[2]
S = 1.8
ACTS = [("idle", "待机"), ("run", "跑步"), ("dash", "冲刺"), ("attack", "攻击"), ("hit", "受击"), ("death", "死亡")]
info = {}

body = bpy.data.objects["swordsman_body"]
before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=rig_fbx)
new = [o for o in bpy.data.objects if o not in before]
arm = next(o for o in new if o.type == "ARMATURE")
src = next(o for o in new if o.type == "MESH")
arm.name = "swordsman_rig"
arm.scale = (arm.scale[0] * S,) * 3
bpy.context.view_layer.update()

# --- weights: transfer from Tripo's skinned mesh ---
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
unweighted = sum(1 for v in body.data.vertices if not v.groups)
info["groups"] = len(body.vertex_groups); info["unweighted_verts"] = unweighted

bpy.data.objects.remove(src)
mw = body.matrix_world.copy()
body.parent = arm; body.matrix_world = mw
am = body.modifiers.new("Armature", "ARMATURE"); am.object = arm

# --- sockets ---
def bone_w(n):
    return arm.matrix_world @ arm.data.bones[n].head_local
def socket(name, bone, loc, ydir, zhint):
    e = bpy.data.objects.new(name, None); e.empty_display_type = "ARROWS"; e.empty_display_size = 0.08
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm; e.parent_type = "BONE"; e.parent_bone = bone
    y = ydir.normalized(); x = y.cross(zhint).normalized(); z = x.cross(y).normalized()
    mat = mathutils.Matrix((x, y, z)).transposed().to_4x4(); mat.translation = loc
    bpy.context.view_layer.update(); e.matrix_world = mat
    return e
hand = bone_w("mixamorig:RightHand"); mid = bone_w("mixamorig:RightHandMiddle1"); th = bone_w("mixamorig:RightHandThumb2")
f = (mid - hand).normalized(); t = th - hand; blade = (t - f * t.dot(f)).normalized()
palm = hand.lerp(mid, 0.6)
socket("weapon_r", "mixamorig:RightHand", palm, blade, f)
hips = bone_w("mixamorig:Hips")
socket("sheath_l", "mixamorig:Hips", mathutils.Vector((0.19, 0.0, hips.z + 0.06)),
       mathutils.Vector((0.0, 0.5, -0.87)), mathutils.Vector((1, 0, 0)))  # tip points back-down ~30 deg
info["hand"] = [round(v, 3) for v in hand]; info["hips"] = [round(v, 3) for v in hips]

# --- actions ---
arm.animation_data_create()
for key, cn in ACTS:
    p = os.path.join(act_dir, cn + ".fbx")
    before = set(bpy.data.objects); acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=p)
    for o in [o for o in bpy.data.objects if o not in before]:
        bpy.data.objects.remove(o)
    act = next(a for a in bpy.data.actions if a not in acts_before)
    act.name = key; act.use_fake_user = True
    tr = arm.animation_data.nla_tracks.new(); tr.name = key
    st = tr.strips.new(key, int(act.frame_range[0]), act)
    try:
        if act.slots: st.action_slot = act.slots[0]
    except Exception as ex:
        info.setdefault("slot_err", []).append(str(ex))
    tr.mute = True
    info[key] = [round(x, 1) for x in act.frame_range]
for a in list(bpy.data.actions):
    if a.name not in dict(ACTS) and a.users == 0:
        bpy.data.actions.remove(a)
for me in [me for me in bpy.data.meshes if me.users == 0]:
    bpy.data.meshes.remove(me)
for im in [im for im in bpy.data.images if im.users == 0]:
    bpy.data.images.remove(im)
for mt in [mt for mt in bpy.data.materials if mt.users == 0]:
    bpy.data.materials.remove(mt)
info["actions"] = [a.name for a in bpy.data.actions]
info["images"] = [i.name for i in bpy.data.images]
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
print("RIG", json.dumps(info, ensure_ascii=False))
