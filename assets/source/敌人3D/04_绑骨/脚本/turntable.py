"""Blender -b --python turntable.py -- <glb> <frames dir> <count> [size]
Renders <count> evenly spaced views around the model (orthographic, slight elevation) to <dir>/f###.png."""
import bpy, sys, math, os
from mathutils import Vector

glb, out, count = sys.argv[sys.argv.index("--") + 1:][:3]
size = int(sys.argv[sys.argv.index("--") + 4]) if len(sys.argv) > sys.argv.index("--") + 4 else 700
count = int(count)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.context.view_layer.update()
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
top = max(p.z for p in pts); bottom = min(p.z for p in pts)
span = max(max(abs(p.x) for p in pts), max(abs(p.y) for p in pts)) * 2
world = bpy.data.worlds.new("w"); scene.world = world
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.42, 0.44, 0.47, 1)
for name, rot, energy in [("key", (50, 0, 35), 3.0), ("fill", (60, 0, -140), 1.2)]:
    d = bpy.data.lights.new(name, "SUN"); d.energy = energy
    o = bpy.data.objects.new(name, d); o.rotation_euler = [math.radians(a) for a in rot]
    scene.collection.objects.link(o)
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.render.resolution_x = size
scene.render.resolution_y = int(size * 4 / 3)
scene.render.film_transparent = False
cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"
cam_data.ortho_scale = max(top - bottom, span * 4 / 3) * 1.08
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
centre = Vector((0, 0, (top + bottom) / 2))
os.makedirs(out, exist_ok=True)
for i in range(count):
    a = 2 * math.pi * i / count
    v = Vector((math.sin(a), -math.cos(a), 0.18)).normalized()
    cam.location = centre + v * 10
    cam.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(out, f"f{i:03d}.png")
    bpy.ops.render.render(write_still=True)
