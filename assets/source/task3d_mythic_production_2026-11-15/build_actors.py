from pathlib import Path
import sys,math,json,struct,hashlib,random
import bpy,numpy as np
from mathutils import Vector,Matrix,Euler
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
rig=None; bindings={}; custom_weights={}
CLOTH='Woven charcoal'; RED='Oxblood cloth'; LEATHER='Oiled leather'; BONE='Old ivory'; FUR='Winter fur'; STEEL='Tempered steel'; DARK='Face shadow'; BLUE='Spirit cloth'

def texture_material(name,color,kind='cloth'):
    size=512
    yy,xx=np.mgrid[0:size,0:size]; randoms=np.random.default_rng(42)
    noise=randoms.random((size,size))
    if kind=='fur': pattern=.86+.035*np.sin(xx*2.1+yy*.035)+.07*noise
    elif kind=='leather': pattern=.72+.28*noise+.04*np.sin(xx*.07)*np.sin(yy*.08)
    else: pattern=.86+.025*(np.sin(xx*1.57)*np.sin(yy*1.57))+.06*noise
    mat=material(name,color,0,.83); m=art.mats[mat]; shader=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    for kind_map in ['albedo','normal','roughness']:
        pixels=np.ones((size,size,4),dtype=np.float32)
        if kind_map=='albedo': pixels[:,:,:3]=pattern[:,:,None]*np.array(color)[None,None,:]
        elif kind_map=='roughness': pixels[:,:,:3]=(.68+.25*noise)[:,:,None]
        else:
            gy,gx=np.gradient(pattern); pixels[:,:,0]=.5-gx*.35; pixels[:,:,1]=.5-gy*.35; pixels[:,:,2]=1
        image=bpy.data.images.new(name+'_'+kind_map,width=size,height=size,alpha=False)
        if kind_map!='albedo': image.colorspace_settings.name='Non-Color'
        image.pixels.foreach_set(pixels.ravel()); image.file_format='PNG'; image.filepath_raw=str(BATCH/'textures'/(image.name+'.png')); image.save(); image.pack()
        node=m.node_tree.nodes.new('ShaderNodeTexImage'); node.image=image
        if kind_map=='normal':
            normal=m.node_tree.nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=.35
            m.node_tree.links.new(node.outputs[0],normal.inputs['Color']); m.node_tree.links.new(normal.outputs[0],shader.inputs['Normal'])
        else: m.node_tree.links.new(node.outputs[0],shader.inputs['Base Color' if kind_map=='albedo' else 'Roughness'])
    return mat

def palette():
    texture_material(CLOTH,(.055,.070,.085))
    texture_material(RED,(.22,.022,.019))
    texture_material(LEATHER,(.105,.060,.034),'leather')
    texture_material(BONE,(.61,.58,.48),'leather')
    texture_material(FUR,(.16,.18,.19),'fur')
    texture_material(BLUE,(.065,.14,.18))
    texture_material(STEEL,(.12,.14,.17),'leather')
    steel=next(n for n in art.mats[STEEL].node_tree.nodes if n.type=='BSDF_PRINCIPLED'); steel.inputs['Metallic'].default_value=.85
    material(DARK,(.001,.002,.003),0,.98)


def ellipsoid(name,loc,radii,mat,segments=24,rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
    o=bpy.context.object; o.scale=radii; art.finish(o,name,mat)
    for p in o.data.polygons: p.use_smooth=True
    return o

def bind_new(start,bone):
    for o in art.objects[start:]: bindings[o]=bone

def part(name,loc,radii,mat,bone):
    o=ellipsoid(name,loc,radii,mat); bindings[o]=bone; return o

def limb(name,a,b,radii,mat,bone):
    o=tube(name,[a,tuple(Vector(a).lerp(Vector(b),.35)),b],radii,mat,20); bindings[o]=bone; return o

def create_rig(bones):
    global rig
    data=bpy.data.armatures.new('Deform skeleton'); rig=bpy.data.objects.new('Rig',data); bpy.context.collection.objects.link(rig); rig.parent=art.root
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig; bpy.ops.object.mode_set(mode='EDIT')
    for name,head,tail,parent in bones:
        b=data.edit_bones.new(name); b.head=head; b.tail=tail
        if parent: b.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT'); rig.show_in_front=True
    return rig

def skin():
    bpy.context.view_layer.update()
    for o,bone in bindings.items():
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        if bone=='nearest':
            candidates=[b for b in rig.data.bones if b.name not in ['root','jaw']]
            groups={b.name:o.vertex_groups.new(name=b.name) for b in candidates}
            for vertex in o.data.vertices:
                ranked=[]
                for b in candidates:
                    a=b.head_local; d=b.tail_local-a; t=max(0,min(1,(vertex.co-a).dot(d)/d.length_squared))
                    ranked.append(((vertex.co-(a+d*t)).length,b.name))
                ranked.sort(); closest=ranked[:2]; values=[1/(d+.035)**4 for d,_ in closest]; total=sum(values)
                for (_,name),value in zip(closest,values): groups[name].add([vertex.index],value/total,'REPLACE')
        elif bone=='cape':
            a=o.vertex_groups.new(name='cape'); b=o.vertex_groups.new(name='cape_tip')
            for v in o.data.vertices:
                w=max(0,min(1,(1.22-v.co.z)/.40)); a.add([v.index],1-w,'REPLACE'); b.add([v.index],w,'REPLACE')
        elif bone=='torso':
            groups={n:o.vertex_groups.new(name=n) for n in ['pelvis','spine','chest']}
            for v in o.data.vertices:
                if v.co.z<1.15:
                    w=max(0,min(1,(v.co.z-1.0)/.15)); groups['pelvis'].add([v.index],1-w,'REPLACE'); groups['spine'].add([v.index],w,'REPLACE')
                else:
                    w=max(0,min(1,(v.co.z-1.15)/.22)); groups['spine'].add([v.index],1-w,'REPLACE'); groups['chest'].add([v.index],w,'REPLACE')
        else:
            group=o.vertex_groups.new(name=bone); group.add(list(range(len(o.data.vertices))),1.0,'REPLACE')
        mod=o.modifiers.new('Skin deformation','ARMATURE'); mod.object=rig
    art.root['rigged']=True


def cloak(bone='cape',mat=RED,short=False):
    verts=[]; faces=[]; rows=15; cols=15
    bottom=.86 if short else .50
    for row in range(rows):
        t=row/(rows-1); z=1.48*(1-t)+bottom*t
        for col in range(cols):
            u=col/(cols-1)*2-1; width=.24+.13*t
            zz=z-(.015*math.sin(col*1.7) if row==rows-1 else 0)
            verts.append((u*width,.14+.10*t+.018*math.cos(u*math.pi*4)*(t+.2),zz))
    for row in range(rows-1):
        for col in range(cols-1):
            i=row*cols+col; faces.append((i,i+1,i+1+cols,i+cols))
    o=art.mesh('Tattered woven mantle',verts,faces,mat)
    bpy.context.view_layer.objects.active=o
    m=o.modifiers.new('Cloth thickness','SOLIDIFY'); m.thickness=.008; bpy.ops.object.modifier_apply(modifier=m.name)
    m=o.modifiers.new('Soft cloth folds','SUBSURF'); m.levels=1; bpy.ops.object.modifier_apply(modifier=m.name)
    for p in o.data.polygons: p.use_smooth=True
    bindings[o]=bone


def hood():
    verts=[]; faces=[]; segments=24
    for z,r in [(1.48,.125),(1.61,.146),(1.76,.148),(1.85,.10),(1.88,.035)]:
        for j in range(segments+1):
            a=-math.pi/4+j/segments*math.pi*1.5
            verts.append((r*math.cos(a),r*.90*math.sin(a),z))
    for row in range(4):
        for j in range(segments):
            k=row*(segments+1)+j; faces.append((k,k+1,k+segments+2,k+segments+1))
    o=art.mesh('Layered cloth hood',verts,faces,CLOTH)
    bpy.context.view_layer.objects.active=o; m=o.modifiers.new('Hood lining thickness','SOLIDIFY'); m.thickness=.011; bpy.ops.object.modifier_apply(modifier=m.name)
    for p in o.data.polygons: p.use_smooth=True
    m=o.modifiers.new('Soft hood folds','SUBSURF'); m.levels=1; bpy.ops.object.modifier_apply(modifier=m.name)
    bindings[o]='head'


def sword_geometry():
    start=len(art.objects)
    verts=[]
    for z,w in [(.22,.041),(.78,.033),(1.02,.020),(1.12,.001)]: verts.extend([(-w,0,z),(0,-.009,z),(w,0,z),(0,.009,z)])
    faces=[(3,2,1,0),(12,13,14,15)]
    for row in range(3):
        for j in range(4): faces.append((row*4+j,row*4+(j+1)%4,(row+1)*4+(j+1)%4,(row+1)*4+j))
    art.mesh('Diamond section steel blade',verts,faces,STEEL,.001)
    box('Recessed blade fuller',(0,-.010,.58),(.009,.003,.60),I,.001)
    for side in [-1,1]:
        beam('Curved steel crossguard',(0,0,.208),(side*.13,0,.19),.027,.026,I)
        part('Crossguard finial',(side*.14,0,.18),(.024,.024,.033),I,'hand.R')
    cylinder('Leather sword grip',(0,0,.117),.023,.15,LEATHER,24)
    for z in [.05,.07,.09,.11,.13,.15,.17]: torus('Grip wrapping',(0,0,z),.024,.004,LEATHER,segments=20)
    ellipsoid('Engraved sword pommel',(0,0,.023),(.037,.022,.034),I)
    return art.objects[start:]

def scabbard_geometry():
    start=len(art.objects)
    tube('Leather sheath sleeve',[(0,0,.045),(0,0,.22),(0,0,.77),(0,0,.94)],[.016,.043,.046,.049],LEATHER,16)
    for z in [.11,.66,.91]:
        box('Scabbard iron ferrule',(0,0,z),(.107,.056,.055),I,.010)
    cylinder('Scabbard mouth shadow',(0,0,.972),.041,.008,DARK,24)
    for z in [.62,.78]:
        torus('Carry suspension ring',(.065,0,z),.027,.006,I,(math.pi/2,0,0),20)
    return art.objects[start:]


def human(enemy=False):
    bones=[('root',(0,0,0),(0,0,.18),None),('pelvis',(0,0,.92),(0,0,1.10),'root'),('spine',(0,0,1.10),(0,0,1.29),'pelvis'),('chest',(0,0,1.29),(0,0,1.48),'spine'),('neck',(0,0,1.48),(0,0,1.58),'chest'),('head',(0,0,1.58),(0,0,1.83),'neck'),('cape',(0,.16,1.47),(0,.23,1.04),'chest'),('cape_tip',(0,.23,1.04),(0,.28,.53),'cape')]
    for side,sign in [('L',-1),('R',1)]:
        bones += [('thigh.'+side,(sign*.105,0,.97),(sign*.12,-.015,.55),'pelvis'),('shin.'+side,(sign*.12,-.015,.55),(sign*.13,0,.16),'thigh.'+side),('foot.'+side,(sign*.13,0,.16),(sign*.13,-.18,.09),'shin.'+side),('upper_arm.'+side,(sign*.23,0,1.43),(sign*.34,0,1.14),'chest'),('forearm.'+side,(sign*.34,0,1.14),(sign*.39,-.035,.90),'upper_arm.'+side),('hand.'+side,(sign*.39,-.035,.90),(sign*.40,-.05,.79),'forearm.'+side)]
    create_rig(bones)
    cloth=BLUE if enemy else CLOTH
    part('Padded hip underlayer',(0,0,.97),(.19,.115,.15),cloth,'pelvis')
    torso=tube('Tailored padded torso',[(0,0,1.01),(0,0,1.14),(0,0,1.37),(0,0,1.47)],[.15,.19,.235,.17],cloth,28); torso.scale.y=.58; bindings[torso]='torso'
    for side,sign in [('L',-1),('R',1)]:
        limb('Heavy cloth thigh',(sign*.105,0,.96),(sign*.12,-.015,.56),[.10,.105,.075],cloth,'thigh.'+side)
        limb('Wrapped lower leg',(sign*.12,-.015,.55),(sign*.13,0,.16),[.075,.074,.055],LEATHER,'shin.'+side)
        part('Shaped leather boot',(sign*.13,-.07,.10),(.075,.133,.085),LEATHER,'foot.'+side)
        part('Armored boot toe',(sign*.13,-.15,.095),(.076,.065,.048),STEEL,'foot.'+side)
        part('Worn knee plate',(sign*.12,-.065,.56),(.075,.034,.075),STEEL,'shin.'+side)
        limb('Upper sleeve',(sign*.235,0,1.42),(sign*.34,0,1.14),[.088,.085,.065],cloth,'upper_arm.'+side)
        limb('Leather vambrace',(sign*.34,0,1.14),(sign*.39,-.035,.90),[.066,.064,.051],LEATHER,'forearm.'+side)
        part('Iron forearm guard',(sign*.37,-.082,1.02),(.055,.035,.107),STEEL,'forearm.'+side)
        part('Gloved palm',(sign*.40,-.036,.845),(.052,.040,.072),LEATHER,'hand.'+side)
        for j in range(4):
            finger=part('Separate glove finger',(sign*(.369+j*.020),-.045,.790),(.009,.017,.033),LEATHER,'hand.'+side)
        part('Glove thumb',(sign*.35,-.066,.83),(.015,.022,.032),LEATHER,'hand.'+side)
        for i in range(3):
            part('Overlapping shoulder lame',(sign*(.244+i*.022),.005,1.45-i*.036),(.108,.126,.048),STEEL,'upper_arm.'+side)
        start=len(art.objects)
        for z in [.29,.43]:
            box('Shin armor strap',(sign*.13,-.069,z),(.14,.035,.047),I,.006)
            bolt(sign*.13,-.094,z,.012,'Y')
        bind_new(start,'shin.'+side)
    start=len(art.objects)
    belt=tube('Continuous leather sword belt',[(0,0,.995),(0,0,1.065)],[.194,.194],LEATHER,48); belt.scale.y=.62
    box('Belt buckle',(0,-.139,1.03),(.087,.024,.065),I,.008)
    for j in range(5):
        for i in range(5):
            x=(i-2)*.064
            box('Layered waist armor',(x,-.111-abs(x)*.04,.95-j*.052),(.061,.028,.064),STEEL,.007)
    bind_new(start,'pelvis')
    if not enemy:
        start=len(art.objects)
        for row in range(4):
            for j in range(9):
                x=(j-4)*.026; y=-.11*math.sqrt(max(.1,1-(x/.16)**2))
                torus('Visible chainmail link',(x,y,1.41+row*.016),.010,.0025,I,(math.pi/2,0,0),10)
        bind_new(start,'chest')
    verts=[]; faces=[]; count=24
    for z,rx,ry in [(1.13,.158,.14),(1.25,.212,.17),(1.40,.217,.16),(1.47,.164,.123)]:
        for j in range(count+1):
            a=math.pi+j/count*math.pi
            verts.append((rx*math.cos(a),ry*math.sin(a)-.008,z))
    for row in range(3):
        for j in range(count):
            k=row*(count+1)+j; faces.append((k,k+1,k+count+2,k+count+1))
    breast=art.mesh('Curved forged breastplate',verts,faces,STEEL,.002)
    bpy.context.view_layer.objects.active=breast
    m=breast.modifiers.new('Plate thickness','SOLIDIFY'); m.thickness=.012; bpy.ops.object.modifier_apply(modifier=m.name)
    for polygon in breast.data.polygons: polygon.use_smooth=True
    bindings[breast]='chest'
    start=len(art.objects)
    for side in [-1,1]:
        beam('Breastplate raised seam',(side*.15,-.104,1.20),(side*.075,-.139,1.43),.010,.012,E)
        for z in [1.22,1.32,1.40]: bolt(side*.125,-.13,z,.008,'Y')
    bind_new(start,'chest')
    if enemy:
        part('Weathered draugr skull',(0,-.008,1.68),(.105,.09,.142),BONE,'head')
        part('Deep brow shadow',(0,-.09,1.71),(.085,.016,.04),DARK,'head')
        part('Separate lower jaw',(0,-.03,1.575),(.078,.068,.044),BONE,'head')
        for side in [-1,1]: part('Icy dead eye',(side*.038,-.106,1.712),(.015,.006,.008),'Cold inlay','head')
        start=len(art.objects)
        box('Broken brow band',(0,-.091,1.762),(.205,.027,.040),I,.006)
        for x in [-.075,0,.075]: bolt(x,-.11,1.762,.009,'Y')
        bind_new(start,'head')
        cloak('cape',BLUE,True)
    else:
        part('Dark iron face mask',(0,-.026,1.68),(.102,.081,.134),STEEL,'head')
        part('Narrow eye recess',(0,-.102,1.724),(.080,.013,.016),DARK,'head')
        for side in [-1,1]: part('Subtle eye glint',(side*.036,-.115,1.725),(.004,.003,.003),BONE,'head')
        start=len(art.objects)
        beam('Mask nose guard',(0,-.115,1.745),(0,-.127,1.637),.015,.012,E)
        for side in [-1,1]: beam('Mask brow edge',(side*.082,-.098,1.738),(0,-.118,1.75),.011,.013,E)
        bind_new(start,'head')
        hood(); cloak()
    if enemy:
        start=len(art.objects)
        beam('Draugr axe haft',(.40,-.05,.91),(.45,-.18,.30),.035,.035,W)
        art.mesh('Chipped iron axe',[(.43,-.21,.30),(.43,-.27,.18),(.61,-.25,.20),(.65,-.18,.39),(.59,-.12,.42),(.43,-.13,.39),(.47,-.18,.31)],[(0,1,2,3,4,5),(0,5,6),(1,0,6),(2,1,6),(3,2,6),(4,3,6),(5,4,6)],I,.006)
        bind_new(start,'hand.R')
    else:
        parts=sword_geometry(); transform=Matrix.Translation((.40,-.08,1.0))@Euler((math.pi-.6,0,0)).to_matrix().to_4x4()
        for o in parts: o.matrix_world=transform@o.matrix_world; bindings[o]='hand.R'
        parts=scabbard_geometry(); transform=Matrix.Translation((-.255,.35,.12))@Euler((.35,0,0)).to_matrix().to_4x4()
        for o in parts: o.matrix_world=transform@o.matrix_world; bindings[o]='pelvis'
    skin()
    socket=art.marker('WeaponSocket',(.40,-.05,.87)); bpy.context.view_layer.update(); world=socket.matrix_world.copy(); socket.parent=rig; socket.parent_type='BONE'; socket.parent_bone='hand.R'; socket.matrix_world=world


def wolf(boss=False):
    scale=1.9 if boss else 1.0
    def p(co): return tuple(v*scale for v in co)
    bones=[('root',p((0,0,0)),p((0,0,.15)),None),('pelvis',p((0,.32,.61)),p((0,.10,.65)),'root'),('spine',p((0,.10,.65)),p((0,-.28,.70)),'pelvis'),('neck',p((0,-.28,.70)),p((0,-.53,.87)),'spine'),('head',p((0,-.53,.87)),p((0,-.86,.82)),'neck'),('jaw',p((0,-.56,.80)),p((0,-.86,.73)),'head'),('tail',p((0,.42,.61)),p((0,.68,.43)),'pelvis'),('tail_tip',p((0,.68,.43)),p((0,.94,.30)),'tail')]
    for side,sign in [('L',-1),('R',1)]:
        for label,y in [('front',-.30),('back',.32)]:
            a=(sign*.16,y,.64); b=(sign*.18,y-.06 if label=='front' else y-.14,.35); c=(sign*.18,y+.02 if label=='front' else y+.07,.13)
            bones.extend([(label+'_upper.'+side,p(a),p(b),'spine' if label=='front' else 'pelvis'),(label+'_lower.'+side,p(b),p(c),label+'_upper.'+side),(label+'_paw.'+side,p(c),p((sign*.18,c[1]-.12,.07)),label+'_lower.'+side)])
    create_rig(bones)
    fur=FUR
    if boss:
        texture_material('Eclipse fur',(.07,.08,.09),'fur'); fur='Eclipse fur'
    start=len(art.objects)
    ellipsoid('Canine ribcage',p((0,-.04,.65)),p((.18 if not boss else .25,.43,.19)),fur)
    ellipsoid('Powerful canine chest',p((0,-.28,.70)),p((.25 if boss else .185,.23,.25 if boss else .205)),fur)
    ellipsoid('Canine hips',p((0,.30,.60)),p((.19,.22,.21)),fur)
    ellipsoid('Canine neck',p((0,-.43,.80)),p((.16,.20,.20)),fur)
    ellipsoid('Canine skull',p((0,-.61,.87)),p((.119,.19,.135)),fur)
    ellipsoid('Tapered upper muzzle',p((0,-.81,.80)),p((.069,.17,.063)),fur)
    tube('Long furred tail',[p((0,.42,.62)),p((0,.68,.45)),p((0,.95,.31))],[.095*scale,.075*scale,.015*scale],fur,16)
    for sign in [-1,1]:
        for label,y in [('front',-.30),('back',.32)]:
            a=p((sign*.16,y,.63)); b=p((sign*.18,y-.06 if label=='front' else y-.14,.35)); c=p((sign*.18,y+.02 if label=='front' else y+.07,.13))
            tube('Canine leg',[a,b,c],[.09*scale,.065*scale,.04*scale],fur,16)
            ellipsoid('Canine paw',p((sign*.18,c[1]/scale-.06,.085)),p((.056,.10,.046)),fur)
        verts=[p((sign*.07,-.59,.97)),p((sign*.165,-.57,.99)),p((sign*.13,-.56,1.18)),p((sign*.11,-.49,1.01))]
        art.mesh('Erect pointed ear',verts,[(0,1,2),(0,2,3),(2,1,3),(0,3,1)],fur,.003)
    fur_parts=art.objects[start:]
    bpy.ops.object.select_all(action='DESELECT')
    for o in fur_parts: o.select_set(True)
    bpy.context.view_layer.objects.active=fur_parts[0]; bpy.ops.object.join(); body=bpy.context.object
    art.objects[start:]=[body]
    m=body.modifiers.new('Organic continuous anatomy','REMESH'); m.mode='VOXEL'; m.voxel_size=.014*scale; bpy.ops.object.modifier_apply(modifier=m.name)
    m=body.modifiers.new('Anatomy surface smoothing','SMOOTH'); m.factor=.55; m.iterations=4; bpy.ops.object.modifier_apply(modifier=m.name)
    m=body.modifiers.new('Game surface density','DECIMATE'); m.ratio=.65; bpy.ops.object.modifier_apply(modifier=m.name)
    art.objects.remove(body); art.finish(body,'Continuous furred anatomy',fur)
    for f in body.data.polygons: f.use_smooth=True
    bindings[body]='nearest'
    part('Lower canine jaw',p((0,-.77,.722)),p((.065,.16,.030)),fur,'jaw')
    part('Dark nose',p((0,-.936,.81)),p((.048,.030,.034)),DARK,'head')
    for sign in [-1,1]:
        part('Deep canine eye socket',p((sign*.102,-.70,.913)),p((.020,.030,.018)),DARK,'head')
        part('Predator eye',p((sign*.110,-.714,.918)),p((.005,.012,.005)),R if boss else BONE,'head')
        for y in [-.79,-.87]:
            start=len(art.objects); art.cone('Long canine fang',p((sign*.067,y,.736)),.015*scale,.080*scale,BONE,10); art.objects[-1].rotation_euler.x=math.pi; bind_new(start,'head')
        for y,label in [(-.34,'front'),(.33,'back')]:
            for j in [-1,0,1]:
                start=len(art.objects); art.cone('Curved paw claw',p((sign*.18+j*.025,y-.12,.048)),.012*scale,.05*scale,DARK,8); art.objects[-1].rotation_euler.x=math.pi/2; bind_new(start,label+'_paw.'+('L' if sign<0 else 'R'))
    if boss:
        start=len(art.objects)
        for side in [-1,1]:
            for j in range(18):
                y=-.45+j*.033
                tube('Eclipse mane lock',[p((side*.17,y,.86)),p((side*.235,y+.045,.77)),p((side*.27,y+.075,.64))],[.026*scale,.018*scale,.002*scale],fur,10)
        bind_new(start,'spine')
        start=len(art.objects)
        for i in range(12):
            a=i*math.tau/12; o=box('Runed collar lamella',p((.20*math.cos(a),-.43,.81+.20*math.sin(a))),p((.066,.035,.038)),I,.008); o.rotation_euler.y=-a
        for side in [-1,1]:
            beam('Eclipse cheek scar',p((side*.125,-.65,.96)),p((side*.137,-.73,.87)),.009*scale,.012*scale,R)
        bind_new(start,'neck')
    skin()
    art.marker('BiteOrigin',p((0,-1.0,.79))); art.marker('BackAnchor',p((0,0,.89)))


def spirit():
    bones=[('root',(0,0,0),(0,0,.2),None),('pelvis',(0,0,.66),(0,0,1.04),'root'),('spine',(0,0,1.04),(0,0,1.37),'pelvis'),('chest',(0,0,1.37),(0,0,1.53),'spine'),('head',(0,0,1.53),(0,0,1.91),'chest'),('cape',(0,.12,1.47),(0,.20,1.03),'chest'),('cape_tip',(0,.20,1.03),(0,.25,.50),'cape')]
    for side,sign in [('L',-1),('R',1)]: bones.extend([('upper_arm.'+side,(sign*.24,0,1.43),(sign*.42,-.08,1.18),'chest'),('forearm.'+side,(sign*.42,-.08,1.18),(sign*.50,-.20,1.10),'upper_arm.'+side),('hand.'+side,(sign*.50,-.20,1.10),(sign*.52,-.26,1.05),'forearm.'+side)])
    create_rig(bones)
    cloak('cape',BLUE)
    verts=[]; faces=[]; segments=48
    profile=[(.38,.29),(.63,.26),(1.02,.20),(1.33,.20),(1.49,.16)]
    for row,(z,radius) in enumerate(profile):
        for j in range(segments):
            angle=j*math.tau/segments
            r=radius+.017*math.cos(angle*10)*(1-row/8)
            zz=z+(.07*math.sin(angle*7)+.025*math.cos(angle*11) if row==0 else 0)
            verts.append((r*math.cos(angle),r*.69*math.sin(angle),zz))
    for row in range(len(profile)-1):
        for j in range(segments):
            k=row*segments+j; faces.append((k,row*segments+(j+1)%segments,(row+1)*segments+(j+1)%segments,k+segments))
    torso=art.mesh('Folded tattered spirit shroud',verts,faces,BLUE)
    bpy.context.view_layer.objects.active=torso
    mod=torso.modifiers.new('Shroud hem thickness','SOLIDIFY'); mod.thickness=.006; bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=torso.modifiers.new('Flowing cloth','SUBSURF'); mod.levels=1; bpy.ops.object.modifier_apply(modifier=mod.name)
    for polygon in torso.data.polygons: polygon.use_smooth=True
    bindings[torso]='torso'
    mantle=tube('Layered spirit shoulder mantle',[(0,0,1.33),(0,0,1.43),(0,0,1.52)],[.30,.27,.16],BLUE,40); mantle.scale.y=.62; bindings[mantle]='chest'
    part('Hollow spirit face',(0,-.025,1.69),(.105,.08,.15),DARK,'head'); hood()
    for sign in [-1,1]:
        part('Spirit eye',(sign*.037,-.11,1.72),(.006,.004,.005),'Cold inlay','head')
        side='L' if sign<0 else 'R'
        limb('Ragged spirit sleeve',(sign*.24,0,1.43),(sign*.43,-.08,1.18),[.10,.09,.06],BLUE,'upper_arm.'+side)
        limb('Bound spirit forearm',(sign*.43,-.08,1.18),(sign*.50,-.20,1.10),[.055,.045,.026],I,'forearm.'+side)
        part('Spirit claw hand',(sign*.51,-.23,1.07),(.045,.065,.027),I,'hand.'+side)
        for j in range(4):
            start=len(art.objects); tube('Long spirit finger',[(sign*(.48+j*.018),-.25,1.07),(sign*(.49+j*.019),-.32,1.03)],[.009,.003],I,8); bind_new(start,'hand.'+side)
    start=len(art.objects)
    for j in range(5):
        a=j*math.tau/5
        art.cone('Suspended frost shard',(.225*math.cos(a),.16*math.sin(a),.78),.014,.080,'Cold inlay',6)
    bind_new(start,'pelvis')
    skin(); art.marker('CastOrigin',(0,-.6,1.35))


def clips(kind):
    names=['idle','run','attack_1','attack_2','dodge','hit','death'] if kind=='hero' else ['idle','run','attack','hit','death'] if kind in ['draugr','wolf'] else ['idle','run','bite','charge','howl','hit','death'] if kind=='boss' else ['idle','float','cast','hit','death']
    for name in names:
        action=bpy.data.actions.new(name); rig.animation_data_create(); rig.animation_data.action=action
        duration=60 if name=='idle' else 32 if name in ['run','float'] else 42
        for frame in range(1,duration+2,4):
            t=min(1,(frame-1)/duration); wave=math.sin(t*math.tau); attack=math.sin(t*math.pi)
            for b in rig.pose.bones:
                b.rotation_mode='XYZ'; b.rotation_euler=(0,0,0); b.location=(0,0,0); b.scale=(1,1,1)
            root=rig.pose.bones['root']; root.location.z=.009*wave
            if name=='idle':
                if rig.pose.bones.get('chest'): rig.pose.bones['chest'].rotation_euler.x=.022*wave
                if rig.pose.bones.get('head'): rig.pose.bones['head'].rotation_euler.z=.025*wave
            elif name in ['run','float','charge']:
                root.location.z=abs(math.sin(t*math.tau*2))*.025
                for b in rig.pose.bones:
                    if b.name.startswith(('thigh.','front_upper.','back_upper.','upper_arm.')):
                        sign=1 if b.name.endswith('L') else -1
                        b.rotation_euler.x=wave*sign*(.62 if 'upper_arm' not in b.name else .35)
                    if b.name.startswith(('shin.','front_lower.','back_lower.')): b.rotation_euler.x=max(0,wave*(1 if b.name.endswith('L') else -1))*.65
                if name=='charge': root.location.y=-.6*attack; root.location.z=.03*attack
            elif name in ['attack','attack_1','attack_2','cast']:
                if rig.pose.bones.get('upper_arm.R'):
                    rig.pose.bones['upper_arm.R'].rotation_euler.x=-1.45*attack
                    rig.pose.bones['forearm.R'].rotation_euler.x=-.65*math.sin(t*math.pi*2)
                    rig.pose.bones['chest'].rotation_euler.z=.45*math.sin(t*math.tau)
                    if name in ['attack_2','cast']: rig.pose.bones['upper_arm.L'].rotation_euler.x=-1.2*attack
                if rig.pose.bones.get('jaw'): rig.pose.bones['jaw'].rotation_euler.x=.45*attack; rig.pose.bones['neck'].rotation_euler.x=.20*attack
            elif name in ['bite','howl']:
                rig.pose.bones['jaw'].rotation_euler.x=.55*attack
                rig.pose.bones['neck'].rotation_euler.x=(-.45 if name=='howl' else .15)*attack
            elif name=='dodge': root.location.y=-.55*attack; rig.pose.bones['spine'].rotation_euler.x=.40*attack
            elif name=='hit': root.rotation_euler.x=-.12*attack
            elif name=='death': root.rotation_euler.y=min(1,t*1.8)*1.35; root.location.z=.08*min(1,t*1.8)
            if rig.pose.bones.get('cape'): rig.pose.bones['cape'].rotation_euler.x=.08*wave+(abs(wave)*.15 if name=='run' else 0)
            if rig.pose.bones.get('cape_tip'): rig.pose.bones['cape_tip'].rotation_euler.x=.12*math.sin(t*math.tau+.5)
            if rig.pose.bones.get('tail'): rig.pose.bones['tail'].rotation_euler.z=.18*wave
            for b in rig.pose.bones:
                b.keyframe_insert(data_path='rotation_euler',frame=frame)
                if b.name=='root': b.keyframe_insert(data_path='location',frame=frame)
        rig.animation_data.action=None
        track=rig.animation_data.nla_tracks.new(); track.name=name
        strip=track.strips.new(name,1,action); track.mute=True
    rig.animation_data.action=bpy.data.actions['idle']; bpy.context.scene.frame_set(1)
    return names


def export_actor(id):
    originals=list(bindings)
    bpy.ops.object.select_all(action='DESELECT'); copies=[]
    for o in originals:
        c=o.copy(); c.data=o.data.copy(); bpy.context.collection.objects.link(c); c.select_set(True); copies.append(c)
    bpy.context.view_layer.objects.active=copies[0]; bpy.ops.object.join(); merged=bpy.context.object; merged.name='SkinnedCharacter'
    bpy.ops.object.select_all(action='DESELECT'); merged.select_set(True); rig.select_set(True); art.root.select_set(True)
    for o in art.root.children_recursive:
        if o.type=='EMPTY': o.select_set(True)
    path=art.MODELS/(id+'.glb')
    with runtime_maps():
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_image_format='AUTO',use_selection=True,export_extras=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_skins=True)
    bpy.data.objects.remove(merged,do_unlink=True)
    return path


def run(id,kind):
    global bindings,rig
    art.reset=original_reset
    reset(id); palette(); bindings={}; rig=None
    if kind in ['hero','draugr']: human(kind=='draugr')
    elif kind in ['wolf','boss']: wolf(kind=='boss')
    else: spirit()
    animations=clips(kind)
    path=export_actor(id)
    lo,hi=art.bounds(); scene=art.studio(lo,hi)
    scene.cycles.samples=24; scene.render.resolution_x=1280; scene.render.resolution_y=1500
    center=(lo+hi)/2; size=max(hi-lo)
    scene.camera.location=center+Vector((size*.95,-size*1.85,size*.65)); scene.camera.rotation_euler=(center-scene.camera.location).to_track_quat('-Z','Y').to_euler(); scene.camera.data.ortho_scale=size*1.48
    if kind in ['wolf','boss','spirit']:
        for light in bpy.data.lights: light.energy*=.55
    if kind in ['wolf','boss']:
        scene.render.resolution_x=1500; scene.render.resolution_y=1200
    scene.render.filepath=str(BATCH/'previews'/(id+'.png'))
    from pack_sources import purge_unused
    purge_unused(); bpy.ops.wm.save_as_mainfile(filepath=str(BATCH/(id+'.blend')))
    b=path.read_bytes(); g=json.loads(b[20:20+struct.unpack_from('<I',b,12)[0]])
    names={'hero_swordsman':'剑士·暗红披肩','enemy_draugr':'尸鬼·铁甲游荡者','enemy_winter_wolf':'冬狼·寒林猎手','boss_skoll':'斯库尔·蚀日巨狼','enemy_ice_spirit':'冰霜精魂·缚寒者'}
    entry={'id':'quality_'+id,'name':names[id],'category':'主角' if kind=='hero' else 'Boss' if kind=='boss' else '敌人','description':'可编辑分件、骨骼、蒙皮与动作首版；服装、护具或生物细节供逐件审核。','rooms':'首关战斗场景','status':'角色与动作首版待审核；尚未接入试玩','expected_clip':animations[0],'animations':[a['name'] for a in g.get('animations',[])],'blend':str((BATCH/(id+'.blend')).relative_to(ROOT)),'glb':str(path.relative_to(ROOT)),'preview':str((BATCH/'previews'/(id+'.png')).relative_to(ROOT)),'dimensions_blender_xyz':[round(x,3) for x in hi-lo],'triangles':sum(g['accessors'][p['indices']]['count']//3 for m in g['meshes'] for p in m['primitives']),'exported_meshes':len(g['meshes']),'skins':len(g.get('skins',[])),'bones':len(rig.data.bones),'sha256':hashlib.sha256(b).hexdigest(),'production_stage':'首版待审核','runtime_texture_limit':1024}
    (BATCH/'records'/(id+'.json')).write_text(json.dumps(entry,ensure_ascii=False,indent=2)+'\n')
    print('ACTOR_SAVED',id,'clips',entry['animations'],'skins',entry['skins'],flush=True)
    bpy.ops.render.render(write_still=True); print('ACTOR_RENDERED',id,flush=True)


def weapon(id):
    global bindings
    reset(id); palette(); bindings={}
    if id=='swordsman_sword': sword_geometry()
    else: scabbard_geometry()
    path=art.export(id); lo,hi=art.bounds(); scene=art.studio(lo,hi)
    scene.render.filepath=str(BATCH/'previews'/(id+'.png'))
    from pack_sources import purge_unused
    purge_unused(); bpy.ops.wm.save_as_mainfile(filepath=str(BATCH/(id+'.blend')))
    b=path.read_bytes(); g=json.loads(b[20:20+struct.unpack_from('<I',b,12)[0]])
    entry={'id':'quality_'+id,'name':'剑士·锻钢长剑' if id=='swordsman_sword' else '剑士·佩挂刀鞘','category':'武器','description':'独立武器零件，供角色装备与佩挂位置审核。','rooms':'剑士主武器','status':'武器首版待审核；装备逻辑待接','expected_clip':'static','animations':[],'blend':str((BATCH/(id+'.blend')).relative_to(ROOT)),'glb':str(path.relative_to(ROOT)),'preview':str((BATCH/'previews'/(id+'.png')).relative_to(ROOT)),'dimensions_blender_xyz':[round(x,3) for x in hi-lo],'triangles':sum(g['accessors'][p['indices']]['count']//3 for m in g['meshes'] for p in m['primitives']),'exported_meshes':len(g['meshes']),'sha256':hashlib.sha256(b).hexdigest(),'production_stage':'首版待审核'}
    (BATCH/'records'/(id+'.json')).write_text(json.dumps(entry,ensure_ascii=False,indent=2)+'\n')
    bpy.ops.render.render(write_still=True); print('WEAPON_RENDERED',id,flush=True)

if __name__=='__main__':
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for id,kind in [('hero_swordsman','hero'),('enemy_draugr','draugr'),('enemy_winter_wolf','wolf'),('boss_skoll','boss'),('enemy_ice_spirit','spirit')]:
        if not wanted or id in wanted: run(id,kind)
    for id in ['swordsman_sword','swordsman_scabbard']:
        if not wanted or id in wanted: weapon(id)
    print('ACTOR_BATCH_DONE',flush=True)
