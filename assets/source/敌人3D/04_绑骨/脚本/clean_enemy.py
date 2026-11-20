"""Blender -b --python clean_enemy.py -- <raw glb> <out dir> <name> <height m>
Merge UV-seam duplicates, front -Y, feet at origin, scale to height, apply transforms, double-sided,
smooth normals; report loose parts; save <name>_base.blend (packed) and export <name>_base.glb (2048 textures)."""
import bpy, bmesh, sys, os
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out_dir, name, height = args[:4]
stem = args[4] if len(args) > 4 else f"{name}_base"
height = float(height)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.parent = None
for o in list(bpy.data.objects):
    if o is not obj:
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

me = obj.data
bm = bmesh.new(); bm.from_mesh(me)
before = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
# loose parts
bm.verts.ensure_lookup_table()
seen, parts = set(), []
for v in bm.verts:
    if v.index in seen:
        continue
    comp, stack = [], [v]
    while stack:
        x = stack.pop()
        if x.index in seen:
            continue
        seen.add(x.index); comp.append(x.index)
        stack.extend(e.other_vert(x) for e in x.link_edges)
    parts.append(comp)
lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
s = height / (hi.z - lo.z)
c = (lo + hi) / 2
for v in bm.verts:
    v.co = Vector(((v.co.x - c.x) * s, (v.co.y - c.y) * s, (v.co.z - lo.z) * s))
bm.to_mesh(me); bm.free()
print(f"VERTS {before} -> {len(me.vertices)}  tris={sum(len(p.vertices) - 2 for p in me.polygons)}")
parts.sort(key=len, reverse=True)
for comp in parts:
    xs = [me.vertices[i].co for i in comp]
    pl = Vector((min(p.x for p in xs), min(p.y for p in xs), min(p.z for p in xs)))
    ph = Vector((max(p.x for p in xs), max(p.y for p in xs), max(p.z for p in xs)))
    m = (pl + ph) / 2
    print(f"PART verts={len(comp)} centre=({m.x:.2f},{m.y:.2f},{m.z:.2f}) size={tuple(round(v, 3) for v in ph - pl)}")

if me.has_custom_normals:
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
for p in me.polygons:
    p.use_smooth = True
obj.name = me.name = f"{name}_body"
for i, m in enumerate(me.materials):
    m.use_backface_culling = False
    m.name = f"{name}_body" if i == 0 else f"{name}_body_{i}"
dims = obj.dimensions
print(f"DIMS {dims.x:.3f} x {dims.y:.3f} x {dims.z:.3f}")

os.makedirs(out_dir, exist_ok=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, f"{stem}.blend"))
for img in bpy.data.images:
    if img.size[0] > 2048:
        img.scale(2048, 2048)
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, f"{stem}.glb"), export_format="GLB",
                          export_image_format="JPEG", export_jpeg_quality=90, use_selection=False)
