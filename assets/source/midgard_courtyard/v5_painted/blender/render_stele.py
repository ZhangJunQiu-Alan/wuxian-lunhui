"""Render the saved viewport model with its orthographic game camera."""
from pathlib import Path

import bpy

scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'SINGLE'
scene.display.shading.single_color = (0.55, 0.61, 0.72)
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = 'BOTH'
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.filepath = str(Path(bpy.data.filepath).with_name('stele-game-guide.png'))
bpy.ops.render.render(write_still=True)
