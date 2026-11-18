from pathlib import Path
import bpy
BATCH=Path(__file__).resolve().parent

def purge_unused():
    for material in list(bpy.data.materials):
        if material.users==0: bpy.data.materials.remove(material)
    for image in list(bpy.data.images):
        if image.type=='IMAGE' and image.users==0: bpy.data.images.remove(image)
    for mesh in list(bpy.data.meshes):
        if mesh.users==0: bpy.data.meshes.remove(mesh)

if __name__=='__main__':
    bpy.context.preferences.filepaths.save_version=0
    for path in BATCH.glob('*.blend'):
        bpy.ops.wm.open_mainfile(filepath=str(path))
        purge_unused()
        bpy.ops.wm.save_as_mainfile(filepath=str(path))
        print('PACKED_SOURCE',path.name,flush=True)
