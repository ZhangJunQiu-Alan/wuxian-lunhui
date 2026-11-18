import bpy

def export_gate(path):
    root=bpy.data.objects['quality_rune_gate']
    gate=bpy.data.objects['GateMoving']
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    groups={}
    for o in root.children_recursive:
        if o.type=='MESH':
            key=(o.parent==gate,o.data.materials[0].name)
            groups.setdefault(key,[]).append(o)
    merged=[]
    for (moving,material),parts in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        copies=[]
        for original in parts:
            copy=original.copy(); copy.data=original.data.copy()
            bpy.context.collection.objects.link(copy)
            world=original.matrix_world.copy(); copy.parent=None; copy.matrix_world=world
            copy.select_set(True); copies.append(copy)
        bpy.context.view_layer.objects.active=copies[0]
        bpy.ops.object.join()
        joined=bpy.context.object
        joined.name=('Gate_' if moving else 'Masonry_')+material
        world=joined.matrix_world.copy(); joined.parent=gate if moving else root; joined.matrix_world=world
        merged.append(joined)
    bpy.ops.object.select_all(action='DESELECT')
    for o in merged+[root,gate]: o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_image_format='AUTO',use_selection=True,export_extras=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True)
    for o in merged: bpy.data.objects.remove(o,do_unlink=True)
