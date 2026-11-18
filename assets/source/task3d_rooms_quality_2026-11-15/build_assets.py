from pathlib import Path
import bpy, math, random, json, hashlib, struct, sys
from mathutils import Vector

BATCH=Path(__file__).resolve().parent
ROOT=BATCH.parents[2]
GATE=ROOT/'assets/source/task3d_gate_quality_2026-11-15'
MODELS=ROOT/'assets/models/midgard/quality'
MATERIAL_NAMES=['Weathered basalt','Aged oak','Oxidised forged iron','Worn iron edges','Thin old frost','Ember inlay','Charcoal']
ENTRIES=[
 ('snow_floor','冻裂石板地面','场地','3.2 米拼接地块，分块石板、错缝、破裂板角、薄霜与接缝碎屑。','雪村、遗迹、石阵','',1),
 ('void_causeway','残破木石断桥','虚空','悬崖断面、独立横板、底部承重木梁、锻铁接头与断口碎石；两侧保留真实空洞。','墓丘、支路、精英房','',1),
 ('spike_trap','锻铁升降地刺','陷阱','九根带底座的棱锥尖刺、导向孔、铆接边框、可见升降架和传动支柱。','战斗房通道','spike',32),
 ('rune_trap','破损符文祭盘','陷阱','分段砌筑的石环、下沉中心、锻铁辐条、凹槽与嵌入式余烬符文。','墓丘、奥丁石阵','',1),
 ('pressure_plate','配重压力踏板','机关','分体石板、金属边框、导向柱、弹簧与独立下压踏面。','机关房、安全支路','press',1),
 ('lever','棘轮锁链拉杆','机关','石基、棘轮齿盘、带包箍的木柄、横轴、支架与悬垂链条。','机关房、出口侧道','activate',1),
 ('brazier','铆接锻铁火盆','道具','有厚度的凹形铁盆、卷边盆口、支撑腿、侧环、铆钉和余烬炭块。','出口、营火房、遗迹','',1)
]
objects=[]; rigs=[]; root=None; mats={}; rng=None

def reset(asset_id):
    global objects,rigs,root,mats,rng
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng=random.Random(820+sum(map(ord,asset_id)))
    with bpy.data.libraries.load(str(GATE/'rune_gate.blend'),link=False) as (src,dst):
        dst.materials=list(MATERIAL_NAMES)
    mats=dict(zip(MATERIAL_NAMES,dst.materials))
    frost_shader=next(n for n in mats['Thin old frost'].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    frost_shader.inputs['Base Color'].default_value=(.10,.135,.16,1)
    if asset_id=='lever':
        worn=next(n for n in mats['Worn iron edges'].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        worn.inputs['Base Color'].default_value=(.045,.052,.062,1)
        worn.inputs['Metallic'].default_value=.68
        worn.inputs['Roughness'].default_value=.72
    objects=[]; rigs=[]
    root=bpy.data.objects.new('quality_'+asset_id,None); bpy.context.collection.objects.link(root)
    root['asset_id']='quality_'+asset_id
    root['units']='metres'
    bpy.context.scene.render.fps=30
    bpy.context.scene.frame_end=100

def finish(o,name,mat,bevel=0,damage=0):
    o.name=name
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Worn bevel','BEVEL'); m.width=bevel; m.segments=2
        bpy.ops.object.modifier_apply(modifier=m.name)
    if damage:
        m=o.modifiers.new('Chipped facets','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=m.name)
        for v in o.data.vertices: v.co+=Vector([rng.uniform(-damage,damage) for _ in range(3)])
    o.data.materials.clear(); o.data.materials.append(mats[mat])
    o.data.update()
    for layer in list(o.data.uv_layers): o.data.uv_layers.remove(layer)
    uv=o.data.uv_layers.new(name='UVMap')
    offset=(rng.random()*4,rng.random()*4)
    for poly in o.data.polygons:
        axis=max(range(3),key=lambda a:abs(poly.normal[a]))
        for li in poly.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co
            coords=(v.y,v.z) if axis==0 else (v.x,v.z) if axis==1 else (v.x,v.y)
            uv.data[li].uv=(coords[1]*.6+offset[0],coords[0]*.3+.08) if mat==W else (coords[0]*.72+offset[0],coords[1]*.72+offset[1])
    o.parent=root; objects.append(o)
    return o

S='Weathered basalt'; W='Aged oak'; I='Oxidised forged iron'; E='Worn iron edges'; F='Thin old frost'; R='Ember inlay'; C='Charcoal'

def box(name,loc,size,mat=S,bevel=.015,damage=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.dimensions=size
    return finish(o,name,mat,bevel,damage)

def mesh(name,verts,faces,mat=S,bevel=.008,damage=0):
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o)
    return finish(o,name,mat,bevel,damage)

def slab(name,points,bottom,top,mat=S,bevel=.015,damage=.003):
    if sum(points[i][0]*points[(i+1)%len(points)][1]-points[(i+1)%len(points)][0]*points[i][1] for i in range(len(points))) < 0: points=list(reversed(points))
    n=len(points); verts=[(x,y,z) for z in [bottom,top] for x,y in points]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,mat,bevel,damage)

def cylinder(name,loc,r,depth,mat=I,vertices=24,rot=(0,0,0),bevel=.006):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc,rotation=rot)
    o=finish(bpy.context.object,name,mat,bevel)
    for p in o.data.polygons:
        if abs(p.normal.z)<.8: p.use_smooth=True
    return o

def cone(name,loc,r,depth,mat=E,vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=.006,depth=depth,location=loc)
    return finish(bpy.context.object,name,mat,.004)

def torus(name,loc,r,tube,mat=E,rot=(0,0,0),segments=32):
    bpy.ops.mesh.primitive_torus_add(major_segments=segments,minor_segments=8,major_radius=r,minor_radius=tube,location=loc,rotation=rot)
    o=finish(bpy.context.object,name,mat)
    for p in o.data.polygons: p.use_smooth=True
    return o

def line(name,points,radius=.008,mat=E):
    d=bpy.data.curves.new(name,'CURVE'); d.dimensions='3D'; d.bevel_depth=radius; d.bevel_resolution=1
    s=d.splines.new('POLY'); s.points.add(len(points)-1)
    for p,co in zip(s.points,points): p.co=(*co,1)
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.convert(target='MESH')
    return finish(o,name,mat)

def beam(name,a,b,width,depth,mat=W):
    delta=Vector(b)-Vector(a)
    o=box(name,(Vector(a)+Vector(b))/2,(width,depth,delta.length),mat,.009)
    o.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    return o

def bolt(x,y,z,r=.026,axis='Z'):
    return cylinder('Forged hex bolt',(x,y,z),r,.026,E,6,(math.pi/2,0,0) if axis=='Y' else (0,0,0),.002)

def frost_patch(x,y,z,r):
    for j in range(18):
        cx=x+rng.uniform(-r,r); cy=y+rng.uniform(-r*.30,r*.30)
        size=rng.uniform(.013,.041)
        points=[(cx+math.cos(i*math.tau/6)*size*rng.uniform(.6,1),cy+math.sin(i*math.tau/6)*size*.45) for i in range(6)]
        slab('Fine frost deposits',points,z-.001,z+rng.uniform(.002,.006),F,.001,0)

def rubble(x,y,z,count=8,r=.25):
    for _ in range(count):
        o=box('Masonry spall',(x+rng.uniform(-r,r),y+rng.uniform(-r,r),z),[rng.uniform(.035,.11),rng.uniform(.04,.15),rng.uniform(.035,.07)],S,.012,.006)
        o.rotation_euler.z=rng.random()*math.tau

def rig(name,loc=(0,0,0)):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=loc; o.parent=root; rigs.append(o)
    return o

def attach(moving,start):
    bpy.context.view_layer.update()
    for o in objects[start:]:
        world=o.matrix_world.copy(); o.parent=moving; o.matrix_world=world

def animate(o,name,property,index,keys):
    for frame,value in keys:
        getattr(o,property)[index]=value
        o.keyframe_insert(data_path=property,index=index,frame=frame)
    o.animation_data.action.name=name
    bpy.context.scene.frame_set(1)

def marker(name,loc):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.parent=root; o.location=loc
    o['role']=name
    return o

def ring_blocks(name,inner,outer,z,height,count=16):
    for i in range(count):
        a=i*math.tau/count+.014; b=(i+1)*math.tau/count-.014
        points=[(r*math.cos(t),r*math.sin(t)) for r,t in [(inner,a),(outer,a),(outer,b),(inner,b)]]
        slab(name,points,z,z+height,S,.017,.004)

def floor():
    box('Masonry undercourse',(0,0,-.18),(3.19,3.19,.28),S,.014,.003)
    for row in range(4):
        for col in range(4):
            x=-1.59+col*.8; y=-1.59+row*.8
            a=x+.018; b=x+.78; c=y+.018; d=y+.78
            dx=rng.uniform(-.05,.05); dy=rng.uniform(-.04,.04)
            pts=[(max(-1.59,min(1.59,px)),max(-1.59,min(1.59,py))) for px,py in [(a,c),(b,c+dy),(b-dx,d),(a,d)]]
            if (row,col) in [(0,1),(2,2),(3,0)]:
                cut=.035
                slab('Split flagstone A',[pts[0],pts[1],(a+.46,d-cut)],-.055,.065,S,.014,.004)
                slab('Split flagstone B',[(a+.43,d),pts[2],pts[3]],-.055,.058,S,.014,.004)
            else: slab('Worn flagstone',pts,-.055,.06+rng.uniform(-.009,.009),S,.018,.004)
    for x,y in [(-1.1,-1.17),(.8,.81),(-1.18,1.21)]: rubble(x,y,.08,5,.14)
    for x,y in [(-1.28,1.34),(1.35,.92),(-.45,-1.38)]: frost_patch(x,y,.085,.23)
    marker('TileOrigin',(0,0,0)); root['tile_pitch']=3.2

def causeway():
    for side in [-1,1]:
        points=[(side*x,y) for x,y in [(1.25,-1.57),(2.84,-1.57),(2.84,1.57),(1.28,1.57),(1.42,.80),(1.24,.1),(1.39,-.72)]]
        if side<0: points.reverse()
        slab('Fractured cliff bank',points,-1.10,-.05,S,.035,.024)
        for ix in range(2):
            for iy in range(4):
                box('Bank capstone',(side*(1.65+ix*.78),-.12+(iy-1.5)*.76,.015),(.75,.73,.16),S,.025,.009)
        for j in range(9):
            x=side*rng.uniform(1.24,1.44); y=rng.uniform(-1.4,1.4)
            o=box('Exposed cliff strata',(x,y,rng.uniform(-.9,-.25)),(.25,rng.uniform(.3,.6),.22),S,.025,.015)
            o.rotation_euler.z=rng.uniform(-.25,.25)
        rubble(side*1.42,1.03,.13,8,.22)
    for y in [-.43,.43]:
        beam('Longitudinal bridge bearer',(-1.65,y,-.25),(1.65,y,-.25),.17,.23,W)
        for x in [-1.28,1.28]:
            box('Bearer iron shoe',(x,y,-.15),(.27,.30,.095),I,.012)
            bolt(x,y,-.089)
    for j in range(13):
        x=(j-6)*.23
        length=1.0+rng.uniform(-.05,.05)
        o=box('Uneven bridge deck plank',(x,rng.uniform(-.012,.012),-.015),(.213,length,.17),W,.013,.002)
        o.rotation_euler.z=rng.uniform(-.018,.018)
        for y in [-.39,.39]: bolt(x,y,.087,.017)
        if j in [1,7,10]: line('Timber split',[(x-.04,-.46,.073),(x-.025,-.2,.076),(x-.035,.09,.075)],.0025,C)
    for x in [-1.52,1.52]:
        for y in [-.62,.62]:
            box('Broken balustrade foot',(x,y,.24),(.17,.17,.55),W,.012,.006)
            box('Iron post collar',(x,y,.10),(.20,.20,.10),I,.01)
            bolt(x,y,.16,.024)
    for y in [-.45,.45]: beam('Underslung angled brace',(-1.5,y,-.68),(0,y,-.26),.10,.14,W)
    marker('VoidVolume',(0,0,-.60)); marker('EntryAnchor',(-2.8,0,.1)); marker('ExitAnchor',(2.8,0,.1))

def spike():
    box('Deep trap casing',(0,0,-.30),(1.91,1.91,.68),I,.025)
    box('Recess shadow bed',(0,0,.035),(1.75,1.75,.07),C,.012)
    for side in [-1,1]:
        box('Stone surround',(side*1.035,0,.04),(.23,2.30,.22),S,.03,.008)
        box('Stone surround',(0,side*1.035,.04),(1.83,.23,.22),S,.03,.008)
        box('Forged frame',(side*.88,0,.12),(.13,1.86,.10),I,.011)
        box('Forged frame',(0,side*.88,.12),(1.86,.13,.10),I,.011)
        for t in [-.72,-.36,0,.36,.72]:
            bolt(side*.88,t,.187,.022); bolt(t,side*.88,.187,.022)
    for x in [-.52,0,.52]:
        for y in [-.52,0,.52]:
            cylinder('Spike aperture sleeve',(x,y,.07),.155,.09,I,24)
            cylinder('Dark guide opening',(x,y,.122),.125,.01,C,24)
            torus('Worn guide lip',(x,y,.132),.133,.012,E,segments=24)
    carrier=rig('SpikeCarrier'); start=len(objects)
    box('Moving lifting rack',(0,0,-.59),(1.64,1.64,.10),I,.018)
    for x in [-.52,0,.52]:
        for y in [-.52,0,.52]:
            cone('Faceted steel spike',(x,y,-.20),.109,.78,E,8)
            cylinder('Spike socket',(x,y,-.57),.16,.09,I,16)
    for x in [-.68,.68]:
        for y in [-.68,.68]: cylinder('Moving piston rod',(x,y,-.83),.043,.48,E,16)
    attach(carrier,start)
    animate(carrier,'spike','location',2,[(1,-.11),(18,-.11),(26,.69),(43,.69),(59,-.11),(90,-.11)])
    marker('DamageOrigin',(0,0,.65))

def rune_trap():
    ring_blocks('Broken outer altar kerb',1.02,1.35,-.07,.24,16)
    ring_blocks('Inner carved ring',.56,.99,.02,.13,12)
    cylinder('Sunken central bed',(0,0,-.11),.58,.10,C,48)
    torus('Iron inner lip',(0,0,.017),.56,.035,I,segments=48)
    for i in range(12):
        a=i*math.tau/12
        x,y=.81*math.cos(a),.81*math.sin(a)
        tangent=Vector((-math.sin(a),math.cos(a),0)); radial=Vector((math.cos(a),math.sin(a),0))
        center=Vector((x,y,.164))
        for p,q in [(-tangent*.08+radial*.08,tangent*.07-radial*.08),(-radial*.09,radial*.10)]:
            beam('Inlaid ember mark',center+p,center+q,.009,.010,R)
        if i%2==0:
            beam('Recessed radial iron rib',(.14*math.cos(a),.14*math.sin(a),-.023),(.53*math.cos(a),.53*math.sin(a),-.023),.032,.035,I)
    cylinder('Black central seal',(0,0,-.014),.18,.04,I,24)
    for i in range(5):
        a=i*math.tau/5
        box('Charred seal shard',(.11*math.cos(a),.11*math.sin(a),.02),(.06,.07,.045),C,.012,.004)
    rubble(.94,-.88,.14,9,.23)
    marker('BlastOrigin',(0,0,.12)); marker('TelegraphOrigin',(0,0,.17))
    root['telegraph_radius']=1.35

def pressure():
    box('Pressure frame stone',(0,0,-.11),(1.66,1.66,.30),S,.035,.008)
    box('Mechanism recess',(0,0,.052),(1.40,1.40,.045),C,.012)
    for side in [-1,1]:
        box('Plate guide frame',(side*.72,0,.102),(.105,1.54,.13),I,.012)
        box('Plate guide frame',(0,side*.72,.102),(1.54,.105,.13),I,.012)
        for t in [-.56,0,.56]: bolt(side*.72,t,.183,.023); bolt(t,side*.72,.183,.023)
    for x in [-.5,.5]:
        for y in [-.5,.5]:
            cylinder('Fixed spring seat',(x,y,.08),.086,.06,I,20)
            points=[(x+.065*math.cos(t),y+.065*math.sin(t),.10+t/math.tau*.026) for t in [j*math.tau/16 for j in range(65)]]
            line('Compression spring',points,.009,E)
    moving=rig('MovingPlate'); start=len(objects)
    box('Moving underside pan',(0,0,.215),(1.28,1.28,.08),I,.014)
    for side in [-1,1]:
        slab('Split pressure slab',[(side*.017,-.60),(side*.60,-.60),(side*.60,.60),(side*.04,.60)],.252,.34,S,.015,.004)
    for x in [-.53,.53]:
        box('Pressure plate binding',(x,0,.351),(.07,1.16,.025),I,.005)
        for y in [-.49,.49]: bolt(x,y,.375,.019)
    for a,b in [((-.15,-.11,.353),(0,.13,.353)),((0,.13,.353),(.15,-.11,.353)),((-.11,-.065,.353),(.11,-.065,.353))]: beam('Inset plate mark',a,b,.012,.012,E)
    attach(moving,start)
    animate(moving,'press','location',2,[(1,0),(20,0),(32,-.13),(62,-.13),(80,0)])
    marker('TriggerOrigin',(0,0,.38))

def lever():
    box('Chipped lever plinth',(0,0,.12),(1.05,.91,.24),S,.05,.008)
    box('Riveted base shoe',(0,0,.265),(.76,.64,.09),I,.015)
    for x in [-.29,.29]:
        for y in [-.23,.23]: bolt(x,y,.329,.028)
    for x in [-.24,.24]:
        box('Axle cheek support',(x,0,.57),(.11,.38,.57),I,.02)
        cylinder('Axle bearing',(x,0,.81),.13,.13,I,32,rot=(0,math.pi/2,0))
    cylinder('Solid pivot axle',(0,0,.81),.065,.79,E,24,rot=(0,math.pi/2,0))
    for x in [-.40,.40]: cylinder('Axle end nut',(x,0,.81),.085,.045,E,6,rot=(0,math.pi/2,0))
    cylinder('Ratchet wheel',(.325,0,.81),.25,.045,I,32,rot=(0,math.pi/2,0))
    profile=[]
    for i in range(16):
        a=i*math.tau/16
        profile.extend([(.22*math.cos(a),.81+.22*math.sin(a)),(.285*math.cos(a+.09),.81+.285*math.sin(a+.09)),(.283*math.cos(a+.14),.81+.283*math.sin(a+.14)),(.22*math.cos(a+.36),.81+.22*math.sin(a+.36))])
    n=len(profile)
    vertices=[(x,y,z) for x in [.293,.357] for y,z in profile]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh('Asymmetric ratchet teeth',vertices,faces,E,.003)
    beam('Locking pawl',(.36,.15,.46),(.36,.10,.61),.055,.07,E)
    pivot=rig('HandlePivot',(0,0,.81)); start=len(objects)
    beam('Reinforced oak lever',(0,0,.81),(0,-.18,1.70),.082,.095,W)
    for z in [1.02,1.37,1.63]:
        y=-(z-.81)*.18/.89
        box('Lever grip ferrule',(0,y,z),(.105,.12,.055),I,.006)
    cylinder('Crosswise grip',(0,-.19,1.72),.055,.37,W,24,rot=(0,math.pi/2,0))
    for x in [-.175,.175]: cylinder('Grip end ferrule',(x,-.19,1.72),.063,.035,I,20,rot=(0,math.pi/2,0))
    attach(pivot,start)
    for j in range(10): torus('Hanging chain',(-.33,-.10,.69-j*.048),.035,.008,E,(math.pi/2,0,math.pi/2 if j%2 else 0),16)
    animate(pivot,'activate','rotation_euler',0,[(1,-.25),(14,-.25),(48,.72),(82,.72)])
    marker('InteractAnchor',(0,-.50,.65))

def lathe(name,profile,segments=48,mat=I):
    verts=[]
    for r,z in profile:
        for j in range(segments): verts.append((r*math.cos(j*math.tau/segments),r*math.sin(j*math.tau/segments),z))
    faces=[]
    for row in range(len(profile)-1):
        for j in range(segments): faces.append((row*segments+j,row*segments+(j+1)%segments,(row+1)*segments+(j+1)%segments,(row+1)*segments+j))
    o=mesh(name,verts,faces,mat,.004)
    for p in o.data.polygons: p.use_smooth=True
    return o

def brazier():
    box('Brazier flagstone base',(0,0,.07),(1.12,1.12,.14),S,.035,.008)
    lathe('Thick forged iron bowl',[(.12,.64),(.30,.68),(.50,.87),(.53,1.04),(.49,1.055),(.46,.89),(.28,.74),(.12,.72),(.12,.64)],48,I)
    torus('Rolled bowl rim',(0,0,1.042),.51,.032,E,segments=48)
    torus('Lower reinforcing hoop',(0,0,.79),.403,.022,I,segments=40)
    for i in range(4):
        a=math.pi/4+i*math.pi/2
        c,s=math.cos(a),math.sin(a)
        beam('Splayed iron leg',(.38*c,.38*s,.16),(.28*c,.28*s,.71),.07,.09,I)
        box('Flat leg shoe',(.39*c,.39*s,.17),(.17,.17,.045),I,.01)
        beam('Bowl cradle',(.28*c,.28*s,.70),(.50*c,.50*s,.98),.04,.07,E)
        cylinder('Leg anchor washer',(.39*c,.39*s,.202),.041,.015,E,16)
        bolt(.39*c,.39*s,.222,.023)
    for i in range(16):
        a=i*math.tau/16
        cylinder('Bowl rivet',(.495*math.cos(a),.495*math.sin(a),.974),.019,.022,E,12,rot=(0,math.pi/2,a),bevel=.002)
    for side in [-1,1]:
        torus('Carry ring',(side*.55,0,.90),.10,.014,E,(math.pi/2,0,0),24)
        box('Ring mounting lug',(side*.50,0,.96),(.09,.09,.10),I,.009)
    for i in range(21):
        a=rng.random()*math.tau; r=rng.uniform(.03,.36)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=rng.uniform(.055,.105),location=(r*math.cos(a),r*math.sin(a),rng.uniform(.84,.94)))
        o=finish(bpy.context.object,'Smouldering charcoal',R if i%5==0 else C,.004)
        o.scale=(1.4,.8,.65); o.rotation_euler.z=a
    marker('FireOrigin',(0,0,1.03)); marker('LightOrigin',(0,0,1.24))

BUILDERS={'snow_floor':floor,'void_causeway':causeway,'spike_trap':spike,'rune_trap':rune_trap,'pressure_plate':pressure,'lever':lever,'brazier':brazier}

def export(asset_id):
    bpy.context.scene.frame_set(1); bpy.context.view_layer.update()
    groups={}
    for o in objects: groups.setdefault((o.parent.name,o.data.materials[0].name),[]).append(o)
    merged=[]
    for (parent_name,material),parts in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        copies=[]
        for original in parts:
            copy=original.copy(); copy.data=original.data.copy(); bpy.context.collection.objects.link(copy)
            world=original.matrix_world.copy(); copy.parent=None; copy.matrix_world=world
            copy.select_set(True); copies.append(copy)
        bpy.context.view_layer.objects.active=copies[0]; bpy.ops.object.join()
        joined=bpy.context.object; joined.name=parent_name+'_'+material
        world=joined.matrix_world.copy(); joined.parent=bpy.data.objects[parent_name]; joined.matrix_world=world
        merged.append(joined)
    bpy.ops.object.select_all(action='DESELECT')
    extras=[o for o in root.children_recursive if o.type=='EMPTY']
    for o in merged+[root]+extras: o.select_set(True)
    bpy.context.view_layer.objects.active=root
    path=MODELS/(asset_id+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_image_format='AUTO',use_selection=True,export_extras=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True)
    for o in merged: bpy.data.objects.remove(o,do_unlink=True)
    return path

def bounds():
    bpy.context.view_layer.update()
    points=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
    lo=Vector([min(p[a] for p in points) for a in range(3)])
    hi=Vector([max(p[a] for p in points) for a in range(3)])
    return lo,hi

def light(name,loc,color,energy,size,target):
    data=bpy.data.lights.new(name,'AREA'); data.energy=energy; data.color=color; data.shape='DISK'; data.size=size
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o); o.location=loc
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()

def studio(lo,hi):
    scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
    scene.render.resolution_x=1280; scene.render.resolution_y=1120; scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Cold review environment'); scene.world.use_nodes=True
    nodes=scene.world.node_tree.nodes; nodes.clear()
    bg=nodes.new('ShaderNodeBackground'); bg.inputs[0].default_value=(.12,.16,.21,1); bg.inputs[1].default_value=.30
    out=nodes.new('ShaderNodeOutputWorld'); scene.world.node_tree.links.new(bg.outputs[0],out.inputs[0])
    scene.view_settings.view_transform='AgX'; scene.view_settings.look='AgX - Medium High Contrast'
    size=max(hi.x-lo.x,hi.y-lo.y,hi.z-lo.z,1)
    center=(lo+hi)/2
    ground=box('Review ground',(0,0,lo.z-.085),(80,80,.1),C,.001); objects.remove(ground); ground.parent=None
    light('Cold key',(-size,-size*1.25,size*2.2),(.62,.76,1),450*size,2*size,center)
    light('Raking warm fill',(size,-size*.3,size*.9),(1,.63,.35),160*size,1.5*size,center)
    light('Cool rim',(0,size,size*1.8),(.45,.67,1),420*size,1.6*size,center)
    bpy.ops.object.camera_add(location=center+Vector((size*.95,-size*1.35,size*1.35)))
    camera=bpy.context.object; camera.name='Review camera'; camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'; camera.data.ortho_scale=size*1.58; scene.camera=camera
    return scene

def build_one(entry):
    asset_id,name,category,description,rooms,clip,pose=entry
    reset(asset_id); BUILDERS[asset_id]()
    lo,hi=bounds(); dimensions=[round(v,3) for v in hi-lo]
    path=export(asset_id)
    bpy.context.scene.frame_set(pose); posed_lo,posed_hi=bounds()
    scene=studio(posed_lo,posed_hi)
    scene.render.filepath=str(BATCH/'previews'/(asset_id+'.png'))
    sys.path.insert(0,str(BATCH))
    from pack_sources import purge_unused
    purge_unused()
    bpy.ops.wm.save_as_mainfile(filepath=str(BATCH/(asset_id+'.blend')))
    blob=path.read_bytes(); n=struct.unpack_from('<I',blob,12)[0]; gltf=json.loads(blob[20:20+n])
    result={'id':'quality_'+asset_id,'name':name,'category':category,'description':description,'rooms':rooms,
      'status':('已导出 '+clip+' 动画，交互与伤害待接') if clip else '精细静态模型，碰撞与玩法待接',
      'expected_clip':clip or 'static','blend':str((BATCH/(asset_id+'.blend')).relative_to(ROOT)),
      'glb':str(path.relative_to(ROOT)),'preview':str((BATCH/'previews'/(asset_id+'.png')).relative_to(ROOT)),
      'dimensions_blender_xyz':dimensions,'dimensions_pose_xyz':[round(v,3) for v in posed_hi-posed_lo],
      'triangles':sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives']),
      'animations':[a['name'] for a in gltf.get('animations',[])],'exported_meshes':len(gltf['meshes']),
      'sha256':hashlib.sha256(blob).hexdigest(),'bytes':len(blob),'review_frame':pose}
    (BATCH/'records'/(asset_id+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('MODEL_SAVED',asset_id,result['triangles'],flush=True)
    bpy.ops.render.render(write_still=True)
    print('MODEL_RENDERED',asset_id,flush=True)
    return result

if __name__=='__main__':
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for entry in ENTRIES:
        if not wanted or entry[0] in wanted: build_one(entry)
    entries=[json.loads((BATCH/'records'/(entry[0]+'.json')).read_text()) for entry in ENTRIES if (BATCH/'records'/(entry[0]+'.json')).exists()]
    (BATCH/'manifest.json').write_text(json.dumps({'batch':BATCH.name,'models':entries},ensure_ascii=False,indent=2)+'\n')
    print('QUALITY_ROOM_ASSETS_DONE',len(entries),flush=True)
