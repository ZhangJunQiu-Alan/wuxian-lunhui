"""Blender -b --python preview_glb.py -- <glb> <out_prefix> [height_m] [lift_m] [--ref <swordsman glb>]
Normalises the model (feet at lift, height, centred), prints stats, renders front/side/back/3-4/game views.
"""
import bpy, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ref = None
if "--ref" in argv:
    i = argv.index("--ref"); ref = argv[i + 1]; del argv[i:i + 2]
glb, out = argv[0], argv[1]
height = float(argv[2]) if len(argv) > 2 else 0.0
lift = float(argv[3]) if len(argv) > 3 else 0.0

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    return [o for o in bpy.data.objects if o not in before], meshes


def bounds(meshes):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def normalise(objs, meshes, h, z0, x_off=0.0):
    roots = [o for o in objs if o.parent is None]
    lo, hi = bounds(meshes)
    s = h / (hi.z - lo.z) if h > 0 else 1.0
    for r in roots:
        r.scale *= s
    bpy.context.view_layer.update()
    lo, hi = bounds(meshes)
    c = (lo + hi) / 2
    for r in roots:
        r.location += Vector((x_off - c.x, -c.y, z0 - lo.z))
    bpy.context.view_layer.update()
    for o in meshes:
        for m in o.data.materials:
            if m:
                m.use_backface_culling = False
    return bounds(meshes)


objs, meshes = load(glb)
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
verts = sum(len(o.data.vertices) for o in meshes)
import bmesh
parts = 0
for o in meshes:
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.verts.index_update()
    seen = set()
    for v in bm.verts:
        if v.index in seen:
            continue
        parts += 1
        stack = [v]
        while stack:
            x = stack.pop()
            if x.index in seen:
                continue
            seen.add(x.index)
            stack.extend(e.other_vert(x) for e in x.link_edges)
    bm.free()
lo0, hi0 = bounds(meshes)
lo, hi = normalise(objs, meshes, height, lift)
size = hi - lo
print(f"STATS tris={tris} verts={verts} parts(by-vertex)={parts} meshes={len(meshes)} "
      f"materials={sorted({m.name for o in meshes for m in o.data.materials if m})} "
      f"raw={tuple(round(v, 3) for v in (hi0 - lo0))} size={tuple(round(v, 3) for v in size)}")

rmeshes = []
if ref:
    robjs, rmeshes = load(ref)
    normalise(robjs, rmeshes, 1.8, 0.0, x_off=size.x / 2 + 0.7)
for o in rmeshes:
    o.hide_render = True

world = bpy.data.worlds.new("w"); scene.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.42, 0.44, 0.47, 1); bg.inputs[1].default_value = 0.9
for name, rot, energy in [("key", (50, 0, 35), 3.0), ("fill", (60, 0, -140), 1.2)]:
    d = bpy.data.lights.new(name, "SUN"); d.energy = energy
    o = bpy.data.objects.new(name, d); o.rotation_euler = [math.radians(a) for a in rot]
    scene.collection.objects.link(o)
bpy.ops.mesh.primitive_plane_add(size=20)
floor = bpy.context.object
fm = bpy.data.materials.new("floor"); fm.diffuse_color = (0.3, 0.31, 0.33, 1)
fm.use_nodes = True; fm.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0.3, 0.31, 0.33, 1)
floor.data.materials.append(fm)

scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 900, 1200
scene.render.image_settings.file_format = "PNG"
cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
centre = Vector((0, 0, (lo.z + hi.z) / 2))
span = max(size.z, size.x * 1.33) * 1.12
views = {"正面": (0, -1, 0), "侧面": (1, 0, 0), "背面": (0, 1, 0), "四分之三": (0.75, -1, 0.15)}
for name, d in views.items():
    v = Vector(d).normalized()
    cam.location = centre + v * 10
    cam.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
    cam_data.ortho_scale = span
    scene.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)
for o in rmeshes:
    o.hide_render = False
# game view: steep oblique, wide, with the reference swordsman alongside
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
v = Vector((0.35, -1, 1.25)).normalized()
gc = Vector(((size.x / 2 + 0.7) / 2 if ref else 0, 0, 0.9))
cam.location = gc + v * 12
cam.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
cam_data.ortho_scale = 5.0
scene.render.filepath = f"{out}_游戏视角.png"
bpy.ops.render.render(write_still=True)
