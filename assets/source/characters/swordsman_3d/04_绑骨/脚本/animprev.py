import bpy, sys, os, math, json, mathutils
args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]; mode = args[1]  # "stills" or "video"
keys = args[2].split(",")
sc = bpy.context.scene
arm = bpy.data.objects["swordsman_rig"]
cam = bpy.data.objects["cam"]; tgt = bpy.data.objects["tgt"]
for c in cam.constraints: c.target = tgt
# placeholder katana on weapon_r
if "proxy_katana" not in bpy.data.objects:
    bpy.ops.mesh.primitive_cube_add(size=1)
    k = bpy.context.active_object; k.name = "proxy_katana"
    k.scale = (0.012, 0.95, 0.03); bpy.ops.object.transform_apply(scale=True)
    for v in k.data.vertices: v.co.y += 0.275
    mat = bpy.data.materials.new("proxy"); mat.diffuse_color = (0.85, 0.85, 0.9, 1)
    k.data.materials.append(mat)
    k.parent = bpy.data.objects["weapon_r"]; k.matrix_parent_inverse.identity(); k.location = (0, 0, 0); k.rotation_euler = (0, 0, 0)
os.makedirs(out, exist_ok=True)
stats = {}
for key in keys:
    act = bpy.data.actions[key]
    ad = arm.animation_data
    for t in ad.nla_tracks: t.mute = True
    ad.action = act
    try: ad.action_slot = act.slots[0]
    except Exception: pass
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    sc.frame_start, sc.frame_end = f0, f1
    hips = arm.pose.bones["mixamorig:Hips"]
    pts = []
    for f in range(f0, f1 + 1, 2):
        sc.frame_set(f); pts.append(arm.matrix_world @ hips.head)
    stats[key] = {"frames": [f0, f1], "hips_x": [round(min(p.x for p in pts), 2), round(max(p.x for p in pts), 2)],
                  "hips_y": [round(min(p.y for p in pts), 2), round(max(p.y for p in pts), 2)],
                  "hips_z": [round(min(p.z for p in pts), 2), round(max(p.z for p in pts), 2)]}
    if mode == "stills":
        n = 6; frames = [round(f0 + (f1 - f0) * i / (n - 1)) for i in range(n)]
        sc.render.resolution_x, sc.render.resolution_y = 512, 640
    else:
        step = 1 if f1 - f0 < 80 else 2
        frames = list(range(f0, f1 + 1, step))
        sc.render.resolution_x, sc.render.resolution_y = 600, 720
        stats[key]["step"] = step
    cam.data.ortho_scale = 2.5; cam.data.sensor_fit = "VERTICAL"
    for i, f in enumerate(frames):
        sc.frame_set(f)
        hp = arm.matrix_world @ hips.head
        tgt.location = (hp.x, hp.y, 0.95)
        a, e = math.radians(-35), math.radians(15)
        cam.location = (hp.x + 10 * math.sin(a) * math.cos(e), hp.y - 10 * math.cos(a) * math.cos(e), 0.95 + 10 * math.sin(e))
        sc.render.filepath = os.path.join(out, f"{key}_{i:03d}.png")
        bpy.ops.render.render(write_still=True)
print("ANIM", json.dumps(stats))
