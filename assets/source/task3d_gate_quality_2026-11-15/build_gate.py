from pathlib import Path
import bpy, math, random, json, hashlib, sys
from mathutils import Vector
import numpy as np

BATCH = Path(__file__).resolve().parent
ROOT = BATCH.parents[2]
OUT = ROOT / 'assets/models/midgard/quality/rune_gate.glb'
rng = random.Random(513)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def material(name, asset=None, tint=(1,1,1), metallic=0, rough=.8, emission=None):
    m=bpy.data.materials.new(name); m.use_nodes=True
    m.node_tree.nodes.clear()
    p=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    output=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(p.outputs['BSDF'],output.inputs['Surface'])
    p.inputs['Metallic'].default_value=metallic
    p.inputs['Roughness'].default_value=rough
    p.inputs['Base Color'].default_value=(*tint,1)
    if asset:
        for kind, socket in [('albedo','Base Color'),('roughness','Roughness'),('normal',None)]:
            im=bpy.data.images.load(str(BATCH/'textures'/f'{asset}_{kind}.jpg'),check_existing=False)
            im.name=f'{name}_{kind}'; im.scale(1024,1024)
            if kind!='albedo': im.colorspace_settings.name='Non-Color'
            if kind=='albedo':
                pixels=np.array(im.pixels[:],dtype=np.float32).reshape(-1,4)
                pixels[:,:3] *= np.array(tint)
                im.pixels.foreach_set(pixels.ravel()); im.update()
                p.inputs['Base Color'].default_value=(1,1,1,1)
            im.file_format='PNG'
            im.filepath_raw=str(BATCH/'textures'/f'{name}_{kind}.png')
            im.save()
            im.pack()
            n=m.node_tree.nodes.new('ShaderNodeTexImage'); n.image=im
            if kind=='normal':
                normal=m.node_tree.nodes.new('ShaderNodeNormalMap')
                normal.inputs['Strength'].default_value=.65
                m.node_tree.links.new(n.outputs['Color'],normal.inputs['Color'])
                m.node_tree.links.new(normal.outputs['Normal'],p.inputs['Normal'])
            else: m.node_tree.links.new(n.outputs['Color'],p.inputs[socket])
    if emission:
        p.inputs['Emission Color'].default_value=(*emission,1)
        p.inputs['Emission Strength'].default_value=2.0
    return m

stone=material('Weathered basalt','rock_face_03',(.59,.68,.76))
wood=material('Aged oak','weathered_brown_planks',(.44,.42,.39))
iron=material('Oxidised forged iron','rust_coarse_01',(.43,.43,.44),.72)
edge=material('Worn iron edges',tint=(.09,.10,.11),metallic=.85,rough=.53)
frost=material('Thin old frost',tint=(.39,.46,.49),rough=.92)
rune=material('Ember inlay',tint=(.15,.047,.012),metallic=.2,emission=(.65,.16,.025))
coal=material('Charcoal',tint=(.014,.017,.02))
objects=[]

def finish(o,name,mat,bevel=0,damage=0):
    o.name=name
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Hand worn edge','BEVEL'); m.width=bevel; m.segments=2
        bpy.ops.object.modifier_apply(modifier=m.name)
    if damage:
        m=o.modifiers.new('Stone facets','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=m.name)
        for v in o.data.vertices:
            v.co += Vector((rng.uniform(-damage,damage),rng.uniform(-damage,damage),rng.uniform(-damage,damage)))
    o.data.materials.append(mat)
    uv=o.data.uv_layers.new(name='UVMap')
    offset=(rng.random()*3,rng.random()*3)
    scale=.72 if mat==stone else .65
    for poly in o.data.polygons:
        n=poly.normal; axis=max(range(3),key=lambda a:abs(n[a]))
        for li in poly.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co
            coords=(v.y,v.z) if axis==0 else (v.x,v.z) if axis==1 else (v.x,v.y)
            uv.data[li].uv=(coords[0]*scale+offset[0],coords[1]*scale+offset[1])
    objects.append(o)
    return o

def box(name,loc,size,mat,bevel=.01,damage=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object; o.dimensions=size
    return finish(o,name,mat,bevel,damage)

def cyl(name,loc,r,depth,mat,vertices=16,rot=(math.pi/2,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc,rotation=rot)
    return finish(bpy.context.object,name,mat,.006)

def beam(name,a,b,width,depth,mat):
    d=Vector(b)-Vector(a)
    o=box(name,(Vector(a)+Vector(b))/2,(width,depth,d.length),mat,.008)
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return o

def curve(name,points,radius,mat):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.resolution_u=1
    c.bevel_depth=radius; c.bevel_resolution=2
    s=c.splines.new('POLY'); s.points.add(len(points)-1)
    for v,p in zip(s.points,points): v.co=(*p,1)
    o=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    bpy.ops.object.convert(target='MESH'); o.select_set(False)
    return finish(o,name,mat)

# Physical masonry, with an open arch behind the independent gate.
for side in [-1,1]:
    box('Foundation stone',(side*1.59,0,.13),(1.08,1.03,.30),stone,.06,.015)
    for row in range(6):
        z=.32+row*.43+.215
        o=box('Chipped jamb ashlar',(side*(1.46+rng.uniform(-.02,.02)),rng.uniform(-.025,.025),z),(.68,.79,.408),stone,.045,rng.uniform(.007,.018))
        o.rotation_euler.z=rng.uniform(-.013,.013)
    box('Impost ledge',(side*1.44,0,2.96),(.89,.94,.19),stone,.035,.01)
    # Chiselled inset and angular original motif, cut-looking dark grooves.
    box('Jamb recessed field',(side*1.46,-.409,1.60),(.34,.016,1.42),coal,.007)
    for j in range(3):
        z=1.1+j*.44; x=side*1.46
        for a,b in [((x-.10,-.43,z-.14),(x+.10,-.43,z+.12)),((x,-.43,z-.15),(x,-.43,z+.17)),((x-.10,-.43,z+.12),(x+.10,-.43,z-.04))]:
            beam('Weathered iron rune',a,b,.016,.014,iron)
# Voussoirs, actual wedge-shaped stones.
for i in range(13):
    a=i*math.pi/13+.012; b=(i+1)*math.pi/13-.012
    verts=[]
    for y in [-.41,.41]:
        for r,t in [(1.10,a),(1.77,a),(1.77,b),(1.10,b)]:
            verts.append((r*math.cos(t),y,2.94+r*math.sin(t)))
    mesh=bpy.data.meshes.new('Radial arch block'); mesh.from_pydata(verts,[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    o=bpy.data.objects.new('Arch voussoir %02d'%i,mesh); bpy.context.collection.objects.link(o)
    finish(o,o.name,stone,.027,.007)
# Keystone has a separate, low ember symbol, not a glowing toy medallion.
for a,b in [((-.12,-.454,4.38),(0,-.454,4.58)),((0,-.454,4.58),(.12,-.454,4.38)),((0,-.454,4.58),(0,-.454,4.28))]:
    beam('Keystone ember groove',a,b,.024,.014,rune)

bpy.ops.object.empty_add(); gate=bpy.context.object; gate.name='GateMoving'
moving_start=len(objects)
# Individual timbers shaped to the arch, recessed behind its front face.
for i in range(9):
    x=(i-4)*.234
    top=2.94+math.sqrt(max(0,1.075**2-x*x))-.035
    o=box('Gate oak plank %02d'%i,(x,.055,(top+.15)/2),(.224,.24,top-.15),wood,.014,.003)
    # Visible splits, end grain chips, edge reinforcing straps.
    if i%2==0:
        curve('Split in timber',[(x+.06,-.072,.4),(x+.045,-.074,.75),(x+.058,-.074,1.15)],.0035,coal)
for z in [.52,1.57,2.63]:
    box('Forged horizontal binding',(0,-.096,z),(2.16,.075,.115),iron,.015)
    for i in range(9):
        cyl('Hammered rivet',((i-4)*.234,-.153,z),.026,.027,edge,12)
for side in [-1,1]:
    for z in [1.06,2.11]:
        box('Iron hinge strap',(side*.90,-.146,z),(.35,.08,.12),iron,.014)
        cyl('Hinge barrel',(side*1.035,-.13,z),.043,.23,iron,16,rot=(0,0,0))
    cyl('Ring escutcheon',(side*.18,-.125,1.79),.085,.04,iron,20)
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=(side*.18,-.195,1.68),rotation=(math.pi/2,0,0),major_radius=.105,minor_radius=.017)
    finish(bpy.context.object,'Forged pull ring',edge)
# Diagonal bracing on reverse side.
for side in [-1,1]:
    beam('Back diagonal brace',(side*.96,.23,.55),(0,.23,2.59),.12,.09,wood)
bpy.context.view_layer.update()
for o in objects[moving_start:]:
    world=o.matrix_world.copy(); o.parent=gate; o.matrix_world=world
# Portal chain guides.
for side in [-1,1]:
    for j in range(22):
        bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=6,major_radius=.046,minor_radius=.009,location=(side*1.125,-.12,2.18+j*.072),rotation=(math.pi/2,0,0 if j%2 else math.pi/2))
        finish(bpy.context.object,'Guide chain',edge)
# Footing and fallen fragments belong to the model.
for i in range(22):
    side=rng.choice([-1,1]); x=side*rng.uniform(1.14,2.02); y=rng.uniform(-.68,.56)
    o=box('Broken masonry fragment',(x,y,.06),tuple(rng.uniform(.08,.22) for _ in range(3)),stone,.025,.014)
    o.rotation_euler=(rng.uniform(-.35,.35),rng.uniform(-.35,.35),rng.random()*6.28)
for side in [-1,1]:
    for j in range(4):
        box('Trapped frost',(side*(1.23+j*.12),-.41,.294),(.11,.17,.012),frost,.003,.002)

root=bpy.data.objects.new('quality_rune_gate',None); bpy.context.collection.objects.link(root)
for o in objects:
    if o.parent is None: o.parent=root
root['asset_id']='quality_rune_gate'; root['purpose']='Exit gate art-quality sample'
gate.parent=root
for f,z in [(1,0),(18,0),(70,3.92)]:
    gate.location.z=z; gate.keyframe_insert(data_path='location',frame=f)
gate.animation_data.action.name='open'
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for o in objects+[root,gate]: o.select_set(True)
bpy.context.view_layer.objects.active=root
sys.path.insert(0,str(BATCH))
from export_game import export_gate
export_gate(OUT)
# Studio is only in editable sources / previews.
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.samples=40
scene.cycles.use_denoising=True
scene.render.resolution_x=1600; scene.render.resolution_y=1500; scene.render.resolution_percentage=100
scene.world.color=(.12,.12,.12)
scene.world.use_nodes=True
scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.12,.16,.21,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'

def light(name,loc,color,power,size,target=(0,0,2)):
    d=bpy.data.lights.new(name,'AREA'); d.energy=power; d.color=color; d.shape='DISK'; d.size=size
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); o.location=loc
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()

ground=box('Review ground',(0,0,-.1),(200,200,.12),coal,.01)
objects.remove(ground)
light('Cold key',(-3,-4,7),(.62,.76,1),1500,4)
light('Warm raking fill',(4,-1,3),(1,.63,.35),700,3)
light('Cold rim',(0,3,6),(.45,.67,1),1700,3)
bpy.ops.object.camera_add(location=(5,-9,5.5)); camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,2.13))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'; camera.data.ortho_scale=5.7; scene.camera=camera
scene.render.filepath=str(BATCH/'previews/rune_gate.png')
bpy.ops.wm.save_as_mainfile(filepath=str(BATCH/'rune_gate.blend'))
bpy.ops.render.render(write_still=True)
# In-context view using simple ruin floor, honest scale and same model.
for ix in range(-4,5):
    for iy in range(-4,2):
        o=box('Courtyard paving',(ix*.68,iy*.73-.2,-.035),(.655,.70,.12),stone,.018,.005)
        o.rotation_euler.z=rng.uniform(-.012,.012)
for side in [-1,1]:
    for row in range(3):
        for j in range(3):
            box('Broken flanking wall',(side*(2.13+j*.52),.14,row*.34+.17),(.50,.65,.32),stone,.025,.008)
camera.location=(6,-9,9)
camera.rotation_euler=(Vector((0,-.55,1.7))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=9.1
scene.render.resolution_x=1600; scene.render.resolution_y=1200
scene.render.filepath=str(BATCH/'previews/room_assembly.png')
bpy.ops.wm.save_as_mainfile(filepath=str(BATCH/'room_assembly.blend'))
bpy.ops.render.render(write_still=True)
print('QUALITY_GATE_DONE',flush=True)
