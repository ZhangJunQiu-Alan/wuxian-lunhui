from pathlib import Path
import bpy, sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from export_game import export_gate
batch=Path(__file__).resolve().parent
for filename in ['rune_gate.blend','room_assembly.blend']:
    bpy.ops.wm.open_mainfile(filepath=str(batch/filename))
    for im in bpy.data.images:
        if im.type!='IMAGE': continue
        im.scale(1024,1024)
        im.file_format='PNG'
        im.filepath_raw=str(batch/'textures'/f'{im.name}.png')
        im.save()
        im.pack()
    if filename=='rune_gate.blend':
        root=bpy.data.objects['quality_rune_gate']
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        for o in root.children_recursive: o.select_set(True)
        bpy.context.view_layer.objects.active=root
        bpy.context.scene.frame_set(1)
        export_gate(batch.parents[2]/'assets/models/midgard/quality/rune_gate.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(batch/filename))
print('EXPORT_NORMALIZED',flush=True)
