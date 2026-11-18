from pathlib import Path
import bpy, sys, json
from mathutils import Vector
BATCH=Path(__file__).resolve().parent
sys.path.insert(0,str(BATCH))
import build_assets as art
bpy.ops.wm.read_factory_settings(use_empty=True)


def append_asset(asset_id,loc,source=None,frame=1):
    source=source or BATCH/(asset_id+'.blend')
    with bpy.data.libraries.load(str(source),link=False) as (src,dst): dst.objects=list(src.objects)
    imported=[o for o in dst.objects if o]
    for o in imported: bpy.context.collection.objects.link(o)
    root=next(o for o in imported if o.get('asset_id')=='quality_'+asset_id)
    kept=[root]+list(root.children_recursive)
    bpy.context.scene.frame_set(frame); bpy.context.view_layer.update()
    for o in kept:
        if o.animation_data: o.animation_data_clear()
    for o in imported:
        if o not in kept: bpy.data.objects.remove(o,do_unlink=True)
    root.location+=Vector(loc)
    return root


def copy_tree(original,loc):
    mapping={}
    for o in [original]+list(original.children_recursive):
        c=o.copy(); bpy.context.collection.objects.link(c); mapping[o]=c
    for o,c in mapping.items():
        if o.parent in mapping: c.parent=mapping[o.parent]
    mapping[original].location=Vector(loc)
    return mapping[original]

floor=append_asset('snow_floor',(-3.2,-3.2,0))
for x in [-3.2,0,3.2]:
    for y in [-3.2,0,3.2]:
        if (x,y) not in [(-3.2,-3.2),(0,0)]: copy_tree(floor,(x,y,0))
append_asset('void_causeway',(0,0,.09))
append_asset('spike_trap',(-3.25,-1.70,.08),frame=32)
append_asset('pressure_plate',(0,-3.3,.07))
append_asset('lever',(3.20,-1.85,.08))
append_asset('rune_trap',(3.1,2.7,.07))
append_asset('brazier',(-2.20,3.68,.08))
append_asset('brazier',(2.20,3.68,.08))
append_asset('rune_gate',(0,4.78,.04),art.GATE/'rune_gate.blend')
# Deduplicate appended materials while preserving separate editable meshes.
for o in bpy.data.objects:
    if o.type=='MESH':
        for slot in o.material_slots:
            if slot.material:
                base=slot.material.name.split('.')[0]
                if base=='Worn iron edges' and next(n for n in slot.material.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Roughness'].default_value>.7: continue
                if base in art.MATERIAL_NAMES and bpy.data.materials.get(base): slot.material=bpy.data.materials[base]
art.mats={name:bpy.data.materials[name] for name in art.MATERIAL_NAMES}
art.root=bpy.data.objects.new('ReviewGroundRoot',None); bpy.context.collection.objects.link(art.root)
art.objects=[]
art.rng=__import__('random').Random(7)
scene=art.studio(Vector((-5,-5,-1.2)),Vector((5,5.4,4.85)))
scene.cycles.samples=32
scene.render.resolution_x=1800; scene.render.resolution_y=1400
camera=scene.camera; camera.location=(10,-14,14)
camera.rotation_euler=(Vector((0,.25,1.0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=15.8
scene.render.filepath=str(BATCH/'previews/room_assembly.png')
# Local warm pools make the braziers legible without hiding surface detail.
for x in [-2.2,2.2]:
    d=bpy.data.lights.new('Brazier warm pool','POINT'); d.energy=55; d.color=(1,.30,.075); d.shadow_soft_size=.5
    o=bpy.data.objects.new(d.name,d); bpy.context.collection.objects.link(o); o.location=(x,3.68,1.4)
bpy.ops.wm.save_as_mainfile(filepath=str(BATCH/'room_assembly.blend'))
bpy.ops.render.render(write_still=True)
print('QUALITY_ASSEMBLY_DONE',flush=True)
