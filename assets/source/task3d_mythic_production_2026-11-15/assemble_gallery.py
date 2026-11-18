from pathlib import Path
import sys,random,math
import bpy
from mathutils import Vector
BATCH=Path(__file__).resolve().parent
sys.path.insert(0,str(BATCH))
from common import *
PREVIOUS=BATCH.parent/'task3d_rooms_quality_2026-11-15'

def append(id,loc,source=None):
    source=source or BATCH/(id+'.blend')
    with bpy.data.libraries.load(str(source),link=False) as (src,dst): dst.objects=list(src.objects)
    imported=[o for o in dst.objects if o]
    for o in imported: bpy.context.collection.objects.link(o)
    root=next(o for o in imported if o.get('asset_id')=='quality_'+id)
    keep=[root]+list(root.children_recursive)
    bpy.context.scene.frame_set(1); bpy.context.view_layer.update()
    for o in keep:
        if o.animation_data:o.animation_data_clear()
    for o in imported:
        if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
    root.location=loc
    return root

def clone_tree(original,loc):
    mapping={}
    for o in [original]+list(original.children_recursive):
        copy=o.copy(); bpy.context.collection.objects.link(copy); mapping[o]=copy
    for o,c in mapping.items():
        if o.parent in mapping:c.parent=mapping[o.parent]
    mapping[original].location=loc

def scene_setup(lo,hi):
    for o in bpy.data.objects:
        if o.type=='MESH':
            for slot in o.material_slots:
                if slot.material:
                    base=slot.material.name.split('.')[0]
                    if bpy.data.materials.get(base):slot.material=bpy.data.materials[base]
    art.mats={n:bpy.data.materials[n] for n in art.MATERIAL_NAMES if bpy.data.materials.get(n)}
    art.root=bpy.data.objects.new('ReviewStage',None);bpy.context.collection.objects.link(art.root);art.objects=[];art.rng=random.Random(44)
    scene=art.studio(Vector(lo),Vector(hi));scene.cycles.samples=24
    bpy.data.objects['Review ground'].location.z+=.034
    return scene

mode=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'mythic'
bpy.ops.wm.read_factory_settings(use_empty=True)
if mode=='mythic':
    floor=append('snow_floor',(-6.4,-3.2,0),PREVIOUS/'snow_floor.blend')
    for x in [-6.4,-3.2,0,3.2,6.4]:
        for y in [-3.2,0,3.2,6.4,9.6]:
            if (x,y)!=(-6.4,-3.2):clone_tree(floor,(x,y,0))
    for id,loc in [('odin_portal',(0,7.6,.08)),('yggdrasil_altar',(-4.8,3.9,.08)),('norn_well',(4.8,4.1,.08)),('bifrost_bridge',(0,1.6,.15)),('bifrost_pillar',(-1.80,1.6,.08)),('bifrost_pillar',(1.80,1.6,.08)),('valhalla_wall',(-5.4,8.8,.08)),('thor_shrine',(4.8,-.6,.08)),('skadi_shrine',(-4.8,-.6,.08)),('hel_gate',(5.3,8.8,.08)),('offering_table',(0,-2.8,.08))]:append(id,loc)
    scene=scene_setup((-8,-5,-.3),(8,11.2,5.1));scene.render.resolution_x=2000;scene.render.resolution_y=1600
    camera=scene.camera;camera.location=(18,-24,23);camera.rotation_euler=(Vector((0,3.5,1))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=25
    scene.render.filepath=str(BATCH/'previews/room_assembly.png');dest=BATCH/'room_assembly.blend'
elif mode=='environment':
    for id,loc in [('snow_rocks',(-3,1,0)),('dead_tree',(-3,2,0)),('burial_mound',(1.5,1.5,0)),('fjord_dock',(0,-2.4,0)),('mooring_bollard',(-.8,-2.4,.11)),('campfire_ring',(-2,-1,0))]:append(id,loc)
    scene=scene_setup((-5,-4,-1),(4,4,4.1));scene.render.resolution_x=1800;scene.render.resolution_y=1300
    camera=scene.camera;camera.location=(12,-17,13);camera.rotation_euler=(Vector((-.4,0,1))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=12.5
    scene.render.filepath=str(BATCH/'previews/environment_assembly.png');dest=BATCH/'environment_assembly.blend'
else:
    for id,x in [('hero_swordsman',-4.4),('enemy_draugr',-2.3),('enemy_winter_wolf',-.1),('boss_skoll',2.7),('enemy_ice_spirit',5.3)]:append(id,(x,0,0))
    # Palette for the display floor, kept out of the exported character files.
    with bpy.data.libraries.load(str(PREVIOUS/'snow_floor.blend'),link=False) as (src,dst):dst.materials=[n for n in art.MATERIAL_NAMES if n in src.materials]
    scene=scene_setup((-5.5,-1.5,0),(6.4,1.5,2.5));scene.render.resolution_x=2000;scene.render.resolution_y=1100
    camera=scene.camera;camera.location=(9,-18,8);camera.rotation_euler=(Vector((.4,0,1))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=14.5
    scene.render.filepath=str(BATCH/'previews/actors_assembly.png');dest=BATCH/'actors_assembly.blend'
from pack_sources import purge_unused
purge_unused();bpy.ops.wm.save_as_mainfile(filepath=str(dest));bpy.ops.render.render(write_still=True)
print('GALLERY_RENDERED',mode,flush=True)
