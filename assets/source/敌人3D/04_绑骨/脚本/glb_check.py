import bpy, sys
p = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=p)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
print("CHK objs", [(o.name, o.type, o.parent.name if o.parent else None, o.parent_bone) for o in bpy.data.objects])
print("CHK actions", [(a.name, tuple(map(int, a.frame_range))) for a in bpy.data.actions])
print("CHK bones", len(arm.data.bones), "spear" in arm.data.bones)
mesh = [o for o in bpy.data.objects if o.type == "MESH"]
print("CHK tris", {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in mesh}, "imgs", [(i.name, tuple(i.size)) for i in bpy.data.images])
import mathutils
for o in mesh:
    bb = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    print("CHK bbox", o.name, [round(min(v[i] for v in bb), 2) for i in range(3)], [round(max(v[i] for v in bb), 2) for i in range(3)])
