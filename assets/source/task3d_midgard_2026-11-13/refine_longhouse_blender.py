"""Build the review material variant in Blender and export the Godot model."""
import importlib.util
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector


BATCH = Path(__file__).resolve().parent
MODELS = BATCH.parents[1] / "models" / "midgard"
TILE = 256
PADDING = 12
COLUMNS = 6
RNG = np.random.default_rng(1613)


def load_palette():
    spec = importlib.util.spec_from_file_location("longhouse_geometry", BATCH / "build_longhouse.py")
    source = importlib.util.module_from_spec(spec)
    import sys
    sys.dont_write_bytecode = True
    spec.loader.exec_module(source)
    return [(group, source.palette[group][variant]) for group, variant in source.surfaces]


def noise(width, height):
    grid = RNG.random((height, width))
    x = np.linspace(0, width - 1, TILE)
    y = np.linspace(0, height - 1, TILE)
    rows = np.array([np.interp(x, np.arange(width), row) for row in grid])
    return np.array([np.interp(y, np.arange(height), col) for col in rows.T]).T


def paint(group, hex_color):
    x, y = np.meshgrid(np.linspace(0, 1, TILE), np.linspace(0, 1, TILE))
    broad = noise(7, 7) - .5
    fine = noise(68, 71) - .5
    if group in {"Timber", "Dark oak", "Red shield"}:
        warp = noise(4, 5) - .5
        grain = noise(81, 9) - .5
        lines = (0.5 + 0.5 * np.sin(126 * x + 10 * warp)) ** 9
        knot = np.hypot((x - .37) * 2.6, (y - .63) * 1.4)
        rings = np.sin(knot * 142 + warp * 3) * np.exp(-knot * 5)
        tint = .96 + .22*broad + .25*grain - .15*lines + .19*rings + .12*fine
        height = .10*grain - .045*lines + .08*rings + .02*fine
    elif group == "Roof":
        streak = noise(39, 8) - .5
        chips = np.maximum(0, fine - .23)
        tint = .94 + .32*broad + .20*streak + .34*chips + .08*np.sin(y * 22)
        height = .075*broad + .055*streak - .045*chips + .025*fine
    elif group == "Stone":
        grit = noise(24, 23) - .5
        tint = .91 + .35*broad + .23*grit + .17*fine
        height = .11*broad + .09*grit + .04*fine
    elif group == "Snow":
        crystals = np.maximum(fine - .22, 0)
        tint = .94 + .13*broad + .18*crystals
        height = .07*broad + .05*crystals + .014*fine
    elif group == "Iron":
        tint = .86 + .25*broad + .18*fine
        height = .03*broad + .024*fine
    else:
        tint = .94 + .13*broad
        height = np.zeros_like(tint)
    color = np.array(list(bytes.fromhex(hex_color))) / 255
    colors = np.clip(color * tint[..., None], 0, 1)
    dy, dx = np.gradient(height)
    normal = np.stack((-dx * 6, -dy * 6, np.ones_like(dx)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    return colors, normal * .5 + .5


def make_atlas(palette):
    rows = math.ceil(len(palette) / COLUMNS)
    pixels = [np.ones((rows*TILE, COLUMNS*TILE, 4), dtype=np.float32) for _ in range(2)]
    for index, (group, color) in enumerate(palette):
        row, col = divmod(index, COLUMNS)
        for canvas, tile in zip(pixels, paint(group, color)):
            canvas[row*TILE:(row+1)*TILE, col*TILE:(col+1)*TILE, :3] = tile
    images = []
    for canvas, name, space in zip(pixels, ("Midgard Albedo", "Midgard Normal"), ("sRGB", "Non-Color")):
        image = bpy.data.images.new(name, width=canvas.shape[1], height=canvas.shape[0], alpha=True)
        image.colorspace_settings.name = space
        image.pixels.foreach_set(canvas.ravel())
        image.update()
        image.pack()
        images.append(image)
    return images, rows


def material_for(group, images):
    material = bpy.data.materials.new(group)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    albedo = nodes.new("ShaderNodeTexImage")
    albedo.image = images[0]
    albedo.location = (-520, 180)
    links.new(albedo.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = {"Snow": .82, "Iron": .54, "Amber glass": .41}.get(group, .88)
    shader.inputs["Metallic"].default_value = .55 if group == "Iron" else 0
    if group == "Amber glass":
        shader.inputs["Emission Color"].default_value = (.66, .26, .037, 1)
        shader.inputs["Emission Strength"].default_value = .75
    else:
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = images[1]
        texture.location = (-520, -110)
        normal = nodes.new("ShaderNodeNormalMap")
        normal.location = (-240, -110)
        normal.inputs["Strength"].default_value = .33 if group == "Snow" else .52
        links.new(texture.outputs["Color"], normal.inputs["Color"])
        links.new(normal.outputs["Normal"], shader.inputs["Normal"])
    return material


def project(position, normal, group):
    x, y, z = position
    if group in {"Roof", "Snow"}:
        return .5 + x*.32, .5 + y*.46
    if abs(normal.z) > .85:
        return .5 + x*.32, .5 + y*.46
    return (.5 + x*.32 if abs(normal.y) >= abs(normal.x) else .5 + y*.44), .12 + z*.43


def apply_materials(obj, palette, images, rows):
    mesh = obj.data
    uv = mesh.uv_layers.active.data
    groups = list(dict.fromkeys(group for group, _ in palette))
    indices = {group: i for i, group in enumerate(groups)}
    face_swatches = [min(len(palette)-1, int(uv[face.loop_start].uv.x * len(palette))) for face in mesh.polygons]
    mesh.materials.clear()
    for group in groups:
        mesh.materials.append(material_for(group, images))
    span = TILE - 2*PADDING
    for face, index in zip(mesh.polygons, face_swatches):
        group, _ = palette[index]
        face.material_index = indices[group]
        row, col = divmod(index, COLUMNS)
        for loop in face.loop_indices:
            point = mesh.vertices[mesh.loops[loop].vertex_index].co
            u, v = project(point, face.normal, group)
            uv[loop].uv = ((col*TILE + PADDING + u*span) / (COLUMNS*TILE),
                           (row*TILE + PADDING + v*span) / (rows*TILE))


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def light(name, point, power, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size, data.color = power, "DISK", size, color
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = point
    aim(obj, (0, 0, .75))


def studio():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 20
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1440, 1050
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new("Winter studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes.get("Background").inputs["Color"].default_value = (.20, .23, .27, 1)
    scene.world.node_tree.nodes.get("Background").inputs["Strength"].default_value = .65
    bpy.ops.mesh.primitive_plane_add(size=200)
    floor = bpy.context.object
    floor.name = "Review floor"
    floor.location.z = -.018
    material = bpy.data.materials.new("Studio slate")
    material.diffuse_color = (.088, .125, .15, 1)
    floor.data.materials.append(material)
    light("Warm key", (-3, -4.5, 5.5), 530, 4, (1, .84, .72))
    light("Cool fill", (3.8, -1.5, 3), 270, 4, (.66, .82, 1))
    light("Roof rim", (1.8, 3.5, 4.5), 570, 3, (.73, .86, 1))
    bpy.ops.object.camera_add(location=(3.1, -5.2, 3.9))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.95
    aim(camera, (0, 0, .84))
    scene.camera = camera
    return scene


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / "midgard_longhouse.glb"))
    obj, = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    palette = load_palette()
    images, rows = make_atlas(palette)
    apply_materials(obj, palette, images, rows)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(MODELS / "midgard_longhouse_material.glb"),
                              export_format="GLB", use_selection=True)
    scene = studio()
    scene.render.filepath = "//previews/midgard-longhouse-material-detail.png"
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_perspective = "CAMERA"
    bpy.ops.wm.save_as_mainfile(filepath=str(BATCH / "midgard_longhouse_material.blend"))
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
