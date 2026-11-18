from pathlib import Path
import sys, random
import bpy
from mathutils import Vector
BATCH=Path(__file__).resolve().parent
sys.path.insert(0,str(BATCH))
import build_architecture as architecture
art=architecture.art
PREVIOUS=architecture.PREVIOUS
bpy.ops.wm.read_factory_settings(use_empty=True)

def append_asset(asset_id,loc,source=None,frame=1,rotation=0):
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
    root.location=Vector(loc); root.rotation_euler.z=rotation
    return root

def duplicate_tree(original,loc):
    mapping={}
    for o in [original]+list(original.children_recursive):
        c=o.copy(); bpy.context.collection.objects.link(c); mapping[o]=c
    for o,c in mapping.items():
        if o.parent in mapping: c.parent=mapping[o.parent]
    mapping[original].location=Vector(loc)
    return mapping[original]

floor=append_asset('snow_floor',(-3.2,-3.2,0),PREVIOUS/'snow_floor.blend')
for x in [-3.2,0,3.2]:
    for y in [-3.2,0,3.2]:
        if (x,y)!=(-3.2,-3.2): duplicate_tree(floor,(x,y,0))
duplicate_tree(floor,(0,4.8,.96))
for x in [-3.2,3.2]: append_asset('ruined_wall',(x,4.73,.08))
for x in [-3.48,3.48]: append_asset('timber_pillar',(x,2.25,.08))
append_asset('stone_stairs',(0,2.35,.08))
append_asset('barricade',(-2.62,-2.5,.08))
append_asset('supply_chest',(2.65,-2.5,.08),frame=60)
append_asset('runestone',(-3.23,-.35,.08))
append_asset('rune_gate',(0,5.35,.99),art.GATE/'rune_gate.blend')
append_asset('brazier',(2.50,-.15,.08),PREVIOUS/'brazier.blend')
for o in bpy.data.objects:
    if o.type=='MESH':
        for slot in o.material_slots:
            if slot.material:
                base=slot.material.name.split('.')[0]
                if base in art.MATERIAL_NAMES and bpy.data.materials.get(base): slot.material=bpy.data.materials[base]
art.mats={name:bpy.data.materials[name] for name in art.MATERIAL_NAMES}
art.root=bpy.data.objects.new('ReviewStageGeometry',None); bpy.context.collection.objects.link(art.root)
art.objects=[]; art.rng=random.Random(601)
art.box('Review landing support',(0,4.8,.47),(3.17,3.17,.94),art.S,.018,.004)
scene=art.studio(Vector((-5,-5,-.4)),Vector((5,6.4,5.9)))
scene.cycles.samples=28
scene.render.resolution_x=1800; scene.render.resolution_y=1500
camera=scene.camera; camera.location=(12,-16,15)
camera.rotation_euler=(Vector((0,.9,1.65))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=17.2
scene.render.filepath=str(BATCH/'previews/room_assembly.png')
d=bpy.data.lights.new('Brazier warm pool','POINT'); d.energy=50; d.color=(1,.30,.075); d.shadow_soft_size=.5
o=bpy.data.objects.new(d.name,d); bpy.context.collection.objects.link(o); o.location=(2.5,-.15,1.35)
from pack_sources import purge_unused
purge_unused()
bpy.ops.wm.save_as_mainfile(filepath=str(BATCH/'room_assembly.blend'))
bpy.ops.render.render(write_still=True)
print('ARCHITECTURE_ASSEMBLY_DONE',flush=True)
