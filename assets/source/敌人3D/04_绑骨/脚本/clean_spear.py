"""Blender -b --python clean_spear.py -- <raw glb> <out dir> <length m> <grip from butt m>
Weapon socket convention (same as the katana): Blender +Y = toward the tip, +Z = blade width side, grip at origin."""
import bpy, bmesh, sys, os
from mathutils import Vector, Matrix

src, out_dir, length, grip = sys.argv[sys.argv.index("--") + 1:][:4]
length, grip = float(length), float(grip)
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
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
co = [v.co.copy() for v in bm.verts]
ext = [max(c[i] for c in co) - min(c[i] for c in co) for i in range(3)]
ax = ext.index(max(ext))
others = [i for i in range(3) if i != ax]
lo, hi = min(c[ax] for c in co), max(c[ax] for c in co)
def width(near_hi, i):
    band = [c for c in co if (c[ax] > hi - 0.15 * (hi - lo)) == near_hi and (c[ax] > hi - 0.15 * (hi - lo) or c[ax] < lo + 0.15 * (hi - lo))]
    return max(c[i] for c in band) - min(c[i] for c in band)
tip_hi = max(width(True, i) for i in others) > max(width(False, i) for i in others)
wide = max(others, key=lambda i: width(tip_hi, i))
print(f"AXIS long={'XYZ'[ax]} tip_at={'+' if tip_hi else '-'} blade_width_axis={'XYZ'[wide]} ext={[round(e, 3) for e in ext]}")
# basis: new Y = long axis toward tip, new Z = blade width axis
ny = Vector([0, 0, 0]); ny[ax] = 1 if tip_hi else -1
nz = Vector([0, 0, 0]); nz[wide] = 1
nx = ny.cross(nz)
rot = Matrix((nx, ny, nz))  # rows: project old coords onto new axes
s = length / (hi - lo)
butt = lo if tip_hi else hi
centre = Vector([0, 0, 0])
for i in others:
    centre[i] = (min(c[i] for c in co) + max(c[i] for c in co)) / 2
centre[ax] = butt
for v in bm.verts:
    p = rot @ (v.co - centre) * s
    v.co = Vector((p.x, p.y - grip, p.z))
bm.to_mesh(me); bm.free()
if me.has_custom_normals:
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
for p in me.polygons:
    p.use_smooth = True
obj.name = me.name = "draugr_spear"
for m in me.materials:
    m.use_backface_culling = False
    m.name = "draugr_spear"
d = obj.dimensions
print(f"DIMS {d.x:.3f} x {d.y:.3f} x {d.z:.3f}  tris={sum(len(p.vertices) - 2 for p in me.polygons)}")
os.makedirs(out_dir, exist_ok=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "长矛.blend"))
for img in bpy.data.images:
    if img.size[0] > 1024:
        img.scale(1024, 1024)
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "长矛.glb"), export_format="GLB",
                          export_image_format="JPEG", export_jpeg_quality=90)
