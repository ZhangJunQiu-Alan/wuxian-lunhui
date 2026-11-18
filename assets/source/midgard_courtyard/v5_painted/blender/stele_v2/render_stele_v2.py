import bpy, sys
out = sys.argv[sys.argv.index('--')+1]
s = bpy.context.scene
s.render.resolution_x = s.render.resolution_y = 2048
s.render.film_transparent = True
s.render.image_settings.file_format = 'PNG'
s.render.image_settings.color_mode = 'RGBA'
s.render.filepath = out + '/game.png'
bpy.ops.render.render(write_still=True)
s.render.engine = 'BLENDER_WORKBENCH'
sh = s.display.shading
sh.light = 'STUDIO'; sh.color_type = 'SINGLE'; sh.single_color = (0.55, 0.61, 0.72)
sh.show_cavity = True; sh.cavity_type = 'BOTH'
s.render.filepath = out + '/structure.png'
bpy.ops.render.render(write_still=True)
