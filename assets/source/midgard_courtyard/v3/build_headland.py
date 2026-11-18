from collections import defaultdict
from math import atan2, cos, pi, radians, sin, tau
from pathlib import Path
from random import Random

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[4]
SOURCE = Path(__file__).resolve().parent
OUTPUT = ROOT / 'assets/models/midgard/courtyard/v3'
RNG = Random(172)
bpy.ops.wm.read_factory_settings(use_empty=True)
buckets = defaultdict(lambda: ([], []))


def material(name, color, roughness=0.93, texture=None):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1.0)
    result.use_nodes = True
    shader = result.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1.0)
    shader.inputs['Roughness'].default_value = roughness
    if texture is not None and texture.exists():
        image = result.node_tree.nodes.new('ShaderNodeTexImage')
        image.image = bpy.data.images.load(str(texture), check_existing=True)
        image.image.pack()
        result.node_tree.links.new(image.outputs['Color'], shader.inputs['Base Color'])
    return result


limestone = material('Sunlit weathered limestone', (.61, .54, .42), texture=OUTPUT / 'limestone.png')
basalt = material('Blue-black basalt', (.047, .055, .062))
slate = material('Broken graphite slabs', (.105, .116, .119))
moss = material('Rock-root moss', (.066, .103, .043))
fern = material('Ink green undergrowth', (.046, .115, .058))
grass = material('Sunlit alpine grass', (.155, .234, .073))
ice = material('Spare weathered rime', (.52, .61, .65))
bronze = material('Tarnished bronze', (.175, .115, .055), .68)
wood = material('Deep charred timber', (.067, .042, .026), .84)
ember = material('Banked coals', (.57, .16, .017), .7)
emits = ember.node_tree.nodes.get('Principled BSDF')
emits.inputs['Emission Color'].default_value = (.80, .21, .025, 1.0)
emits.inputs['Emission Strength'].default_value = .32


def coords(x, y, z):
    return (x, -z, y)


def group(name, at=(0, 0, 0), angle=0.0, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = coords(*at)
    obj.rotation_euler.z = angle
    return obj


def mesh(parent, mat, vertices, faces):
    verts, polys = buckets[parent, mat]
    offset = len(verts)
    verts.extend(coords(*vertex) for vertex in vertices)
    polys.extend(tuple(index+offset for index in face) for face in faces)


def stone(parent, mat, at, size, angle=0.0, damage=0.08):
    x, y, z = at
    w, h, d = (v*.5 for v in size)
    outline = [(-.74,-1),(.74,-1),(1,-.70),(1,.72),(.73,1),(-.73,1),(-1,.70),(-1,-.70)]
    offsets = [(RNG.uniform(-damage, damage), RNG.uniform(-damage, damage)) for _ in outline]
    verts = []
    for level, scale in [(-h,.86),(-h*.80,1.0),(h*.76,1.0),(h,.89)]:
        for (u,v),(du,dv) in zip(outline, offsets):
            px = (u*w + du)*scale
            pz = (v*d + dv)*scale
            verts.append((x+px*cos(angle)+pz*sin(angle), y+level+RNG.uniform(-damage,damage)*.22,
                          z-px*sin(angle)+pz*cos(angle)))
    sides = [(i*8+j, i*8+(j+1)%8, (i+1)*8+(j+1)%8, (i+1)*8+j) for i in range(3) for j in range(8)]
    mesh(parent, mat, verts, [tuple(range(8)), *sides, tuple(reversed(range(24,32)))])


def rock(parent, mat, at, size, sides=8):
    x, y, z = at
    w, h, d = size
    sides = max(sides, 22 if max(w, h, d) > 0.46 else 10)
    turn = RNG.uniform(0, tau)
    grain = RNG.uniform(0, tau)
    profile = [1.0 + .12*sin(i*tau/sides*4 + grain) + .075*sin(i*tau/sides*9-grain)
               + RNG.uniform(-.046, .046) for i in range(sides)]
    layers = [(0,.71,0),(.085,.97,.024),(.17,1.0,.037),(.29,.96,.072),(.40,.98,.09),
              (.52,.86,.13),(.62,.89,.155),(.71,.70,.214),(.82,.69,.225),(.93,.44,.30),(1,.26,.34)]
    verts = []
    for row,(level,radius,drift) in enumerate(layers):
        for i in range(sides):
            angle=i*tau/sides + turn
            rift=.046*sin(i*tau/sides*13 + grain + row*.82) + RNG.uniform(-.036,.036)
            shelf = radius * profile[i] + rift
            shift = .035*sin(grain + row*.69) + drift
            high=.038*sin(i*tau/sides*5+grain)+RNG.uniform(-.020,.020)
            verts.append((x+cos(angle)*w*shelf+shift*w, y+(level+high)*h,
                          z+sin(angle)*d*shelf-shift*d*.52))
    faces = [tuple(reversed(range(sides)))]
    for row in range(len(layers)-1):
        for i in range(sides):
            a,b=row*sides+i,row*sides+(i+1)%sides
            faces.extend([(a,b,b+sides),(a,b+sides,a+sides)])
    faces.append(tuple(range((len(layers)-1)*sides,len(layers)*sides)))
    mesh(parent, mat, verts, faces)


def anchor(x, z, radius):
    obj = group(f'Collider_{len(collisions):03}', (x,0,z), parent=collisions_root)
    obj.scale = (radius, radius, radius)
    collisions.append(obj)


def lintel(parent, at, size, damage=.10):
    x,y,z=at
    w,h,d=size
    stone(parent, basalt, (x,y-h*.40,z), (w*.98,h*.27,d*.92), damage=damage)
    stone(parent, limestone, (x,y,z), (w,h,d), damage=damage)
    stone(parent, limestone, (x,y+h*.45,z), (w*1.01,h*.12,d*.97), damage=damage*.55)


def standing_stone(parent, x, z, height, tilt=0.0):
    pier = group('Carved sandstone monolith', (x,0,z), tilt, parent)
    stone(pier, basalt, (0,.20,0), (1.28,.42,1.07), damage=.13)
    stone(pier, limestone, (0,.43,0), (1.11,.23,.88), damage=.066)
    for y in range(4):
        size = .92 - y*.06
        stone(pier, limestone, (0,.54+(y+.5)*(height-.54)/4,0),
              (size,(height-.54)/4+.015,size*.81), damage=.073)
    stone(pier, slate, (0,height*.66,.398), (.31,.72,.027), damage=.013)
    for i in range(3):
        stone(pier, bronze, (-.060,height*.66+(i-1)*.17,.417), (.185,.028,.024), radians(28), .004)
    return pier


def wall_mesh(parent, points, *, wall_height=.47, width=.74, blocking=True):
    for (ax,az),(bx,bz) in zip(points,points[1:]):
        dx,dz=bx-ax,bz-az
        length=(dx*dx+dz*dz)**.5
        yaw=-atan2(dz,dx)
        n=max(1,round(length/.53))
        for i in range(n):
            u=(i+.5)/n
            x,z=ax+dx*u,az+dz*u
            if blocking:
                anchor(x,z,max(.34,width*.44))
            height=wall_height*RNG.uniform(.65,1.14)
            stone(parent, basalt, (x,height*.24,z), (length/n*1.02,height*.56,width), yaw,.07)
            if i%7!=6:
                top = limestone if i%5 != 2 else slate
                stone(parent,top,(x,height*.73,z),(length/n*.96,height*.52,width*.85),yaw,.079)
            if i%7==2:
                rock(parent,moss,(x,.01,z+.23),(.27,.11,.27),7)


def arch_curve(parent, mat, a, b, inner, outer, depth):
    vertices=[(r*cos(q),1.59+r*sin(q),z) for z in (-depth*.5,depth*.5) for r,q in ((inner,a),(outer,a),(outer,b),(inner,b))]
    mesh(parent,mat,vertices,[(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)])


def door(name, at, restored, leaf=None):
    portal=group(name, at, radians(-60), architecture)
    for side in (-1,1):
        x=side*1.105
        stone(portal,basalt,(x,.16,0),(1.06,.33,1.12),damage=.075)
        stone(portal,limestone,(x,.40,0),(.86,.19,.91),damage=.056)
        for i in range(4):
            mat = limestone if restored or i==2 else slate
            stone(portal,mat,(x,.55+(i+.5)*.264,0),(.595,.267,.73),damage=.056 if restored else .105)
        stone(portal,limestone,(x,1.59,0),(.753,.148,.86),damage=.056)
        stone(portal,basalt,(x,1.00,.396),(.259,.89,.045),damage=.012)
        for i in range(4):
            y=.71+i*.171
            stone(portal,bronze,(x,y,.425),(.118,.027,.015),radians(4*i),.004)
    for i in range(15):
        a,b=i*pi/15+.012,(i+1)*pi/15-.012
        outer=1.396+RNG.uniform(-.042,.034)
        if not restored and i in (2,3,10,12):
            outer-=.23
        arch_curve(portal,limestone if restored or i%4==1 else slate,a,b,.837,outer,.76)
        if restored or i%3==1:
            arch_curve(portal,bronze,a,b,.849,.883,.799)
    if restored:
        lintel(portal,(0,3.032,-.043),(.81,.24,.81),.055)
    if leaf:
        shutter=group(leaf,parent=portal)
        for i in range(9):
            x=(i-4)*.174
            h=1.59+max(0,.824**2-(abs(x)+.086)**2)**.50
            stone(shutter,wood,(x,h*.501,0),(.172,h,.150),damage=.009)
        for y in (.355,1.10,1.58):
            stone(shutter,basalt,(0,y,.113),(1.52,.092,.049),damage=.009)
            for x in (-.51,-.14,.17,.53):
                stone(shutter,bronze,(x,y,.142),(.063,.051,.025),damage=.007)
    return portal


def tuft(parent,x,z,scale):
    mat=RNG.choice((fern,grass,grass,moss))
    count=RNG.randint(5,11)
    for _ in range(count):
        yaw=RNG.uniform(0,tau)
        h=RNG.uniform(.14,.37)*scale
        width=RNG.uniform(.027,.061)*scale
        dx,dz=cos(yaw),sin(yaw)
        offx=RNG.uniform(-.13,.13)*scale
        offz=RNG.uniform(-.13,.13)*scale
        x0,z0=x+offx,z+offz
        pts=[(x0-width*dz,0.01,z0+width*dx),(x0+width*dz,.01,z0-width*dx),
             (x0+dx*h*.29+width*.42*dz,h*.58,z0+dz*h*.29-width*.42*dx),
             (x0+dx*h*.76,h,z0+dz*h*.76),
             (x0+dx*h*.29-width*.42*dz,h*.58,z0+dz*h*.29+width*.42*dx)]
        mesh(parent,mat,pts,[(0,1,2,4),(4,2,3),(4,2,1,0),(3,2,4)])


art=group('Fimbulwinter headland')
architecture=group('Ruins',parent=art)
scenery=group('Basalt shelves and scree',parent=art)
foliage=group('Ground cover',parent=art)
collisions_root=group('Collision anchors',parent=art)
collisions=[]

# Contour shared by the sealed court and the narrow trail around it.
north_edge=[(-6.65,-4.03),(-5.58,-5.65),(-3.52,-7.03),(-1.4,-7.23),(1.50,-7.39),(3.26,-6.91),(4.80,-5.94),(6.50,-4.25),(8.2,-3.45),(14.77,-3.45)]
south_edge=[(-6.67,3.60),(-5.05,5.41),(-3.11,6.52),(-.81,6.90),(2.25,6.77),(4.51,5.83),(6.00,4.15),(8.17,3.57),(14.72,3.57)]
# The top extends into natural terraces beyond the enclosing remains.
rim=[(-28.0,-3.31),(-26.95,-4.79),(-25.53,-4.63),(-24.43,-4.95),(-22.53,-5.25),(-21.17,-5.36),(-19.27,-5.02),(-18.1,-5.00),
     (-16.72,-4.46),(-15.35,-4.91),(-13.38,-5.16),(-12.38,-4.45),(-10.77,-4.27),(-9.59,-4.46),(-7.55,-4.7),(-6.86,-4.46),
     (-6.04,-5.72),(-5.11,-6.80),(-3.68,-7.79),(-2.21,-8.41),(-.64,-8.05),(1.60,-8.63),(3.36,-8.04),(5.14,-7.21),
     (6.59,-5.85),(7.46,-4.94),(9.04,-4.74),(10.97,-5.02),(12.31,-4.5),(13.48,-4.89),(14.95,-4.29),
     (15.8,-3.23),(15.93,-.54),(15.42,1.00),(16.02,2.36),(15.49,3.95),(14.45,4.97),(12.86,4.33),(10.96,4.58),
     (8.89,4.63),(7.86,4.24),(6.38,5.18),(5.22,6.36),(4.06,7.16),(2.82,7.49),(1.64,7.65),(.32,7.91),
     (-1.24,7.76),(-2.82,7.47),(-4.49,7.13),(-5.44,6.28),(-6.52,5.12),(-7.61,4.97),(-9.0,4.51),(-10.43,4.71),
     (-11.42,4.99),(-12.97,4.72),(-14.13,4.73),(-15.89,4.91),(-17.45,4.74),(-19.29,5.17),(-20.54,4.86),(-22.02,5.23),
     (-23.47,5.13),(-25.14,4.68),(-26.82,4.60),(-27.82,3.61),(-28.18,1.03),(-28.03,-.91)]
n=len(rim)
vertices=[]
for level, expand in [(0,0),(-.24,.13),(-.62,.21),(-1.14,.40),(-2.09,.77),(-3.24,1.15),(-4.53,1.73),(-5.37,1.97)]:
    for i,(x,z) in enumerate(rim):
        a,c=rim[i-1],rim[(i+1)%n]
        angle=atan2(c[1]-a[1],c[0]-a[0])-pi/2
        b=RNG.uniform(.49,1.19)*expand
        vertices.append((x+cos(angle)*b,level+RNG.uniform(-.14,.14)*min(1,expand),z+sin(angle)*b))
faces=[tuple(reversed(range(n)))]
for i in range(7):
    for j in range(n):
        a,b=i*n+j,i*n+(j+1)%n
        faces.extend([(a,b,b+n),(a,b+n,a+n)])
faces.append(tuple(range(7*n,8*n)))
terrain=group('Terrain',parent=art)
mesh(terrain,basalt,vertices,faces)

wall_mesh(architecture,north_edge,wall_height=.40,width=.64)
wall_mesh(architecture,south_edge,wall_height=.39,width=.62)
wall_mesh(architecture,[(-6.72,-4.34),(-6.72,-2.74)],wall_height=.77)
wall_mesh(architecture,[(-6.72,-.55),(-6.72,4.37)],wall_height=.83)
wall_mesh(architecture,[(-8.17,-.12),(-8.01,1.14),(-7.90,2.38),(-7.80,3.69)],wall_height=.98)
wall_mesh(architecture,[(7.50,-3.39),(7.33,-2.41),(7.15,-1.40),(6.97,-.45)],wall_height=.71)
for pts in [[(-26.98,-3.54),(-25.97,-3.41),(-24.86,-3.40)], [(-24.07,3.84),(-23.20,3.22),(-22.21,3.01)],
            [(-20.95,-3.78),(-19.41,-3.53),(-18.20,-3.33)], [(-16.8,3.46),(-15.70,3.17)],
            [(-14.6,-3.37),(-13.42,-2.90),(-12.27,-2.89)], [(-11.3,3.45),(-10.31,2.73),(-9.66,2.54)]]:
    wall_mesh(architecture,pts,wall_height=RNG.uniform(.3,.68),width=.65)

for x,z,h,r in [(-25.42,-2.92,1.78,.57),(-21.97,-2.79,2.42,.53),(-18.64,3.40,1.52,.50),(-14.3,-2.88,1.77,.57),
                 (-10.05,-3.04,1.46,.49),(-4.91,-5.57,2.21,.54),(4.24,-5.42,1.93,.52),
                 (9.78,-2.81,2.0,.49),(13.60,2.90,1.64,.51)]:
    standing_stone(architecture,x,z,h,RNG.uniform(-.38,.38))
    anchor(x,z,r)

# A single ruined frontage gives the broad court a landmark and frames the water.
for x,h in [(-2.79,3.02),(-1.09,3.20),(1.16,3.44),(2.82,3.26)]:
    standing_stone(architecture,x,-6.33,h,.05)
    anchor(x,-6.33,.55)
lintel(architecture,(-1.96,3.29,-6.36),(2.8,.47,.88))
lintel(architecture,(2.1,3.49,-6.36),(3.00,.50,.93))
rock(scenery,slate,(-3.33,0,-6.79),(1.22,1.07,.78))
rock(scenery,basalt,(3.72,-.04,-6.96),(1.42,1.23,1.03))

# Low, irregular cover clusters placed clear of the central combat surface.
# Split outcrops below the headland break the continuous cliff silhouette.
for x,z,y,w,h,d in [(-27,-3.4,-5.0,1.7,3.5,1.25),(-28.5,.18,-5.1,1.28,2.92,1.45),
                     (-25.2,4.94,-5.0,1.81,3.72,1.23),(-20.7,5.47,-4.83,1.4,3.89,.9),
                     (-18.75,-5.79,-5.03,1.99,3.69,.94),(-13.68,5.08,-5.2,1.79,3.30,.85),
                     (-7.32,-5.43,-4.95,1.32,3.09,1.52),(-3.9,-8.31,-4.96,1.48,3.43,1.40),
                     (1.15,8.25,-5.07,1.81,4.01,1.16),(5.74,6.62,-5.26,1.20,3.11,1.13),
                     (9.73,-4.83,-5.12,1.39,3.25,1.07),(12.44,4.98,-5.04,1.47,3.17,1.04),
                     (15.88,1.39,-4.98,1.72,3.53,1.47),(15.16,-4.36,-4.98,1.56,3.37,1.38)]:
    rock(scenery,basalt,(x,y,z),(w,h,d),21)
    rock(scenery,slate,(x+.61,y-.11,z+.26),(w*.69,h*.61,d*.78),15)

for x,z,angle in [(-3.18,2.53,-.32),(3.60,2.77,.42)]:
    group_cover=group('Collapsed wayside shrine', (x,0,z),angle,architecture)
    rock(group_cover,basalt,(-.66,-.04,.07),(.56,.76,.55),9)
    stone(group_cover,limestone,(.14,.37,-.08),(1.70,.41,.74),angle,.158)
    rock(group_cover,slate,(.78,0,.16),(.47,.55,.46),7)
    for shift in (-.58,.04,.58):
        anchor(x+shift,z,.44)

for p in [(-6.72,-2.68),(-6.72,-.63),(11.90,.29),(12.94,2.18)]:
    anchor(*p,.38)
door('EntranceGate',(-6.72,0,-1.65),True,'EntranceShutter')
door('DormantGate',(12.42,0,1.24),False,'GateShutter')
door('AwakenedGate',(12.42,0,1.24),True)

# Shelf boulders outside the path and natural rock groupings at the coast edge.
for x,z,w,h,d in [(-27.50,-2.98,.84,1.44,1.22),(-24.93,4.55,1.31,.82,.76),(-23.68,-4.33,.88,1.56,.67),
                  (-19.11,4.65,1.58,.81,.86),(-16.18,-4.3,1.25,1.55,.92),(-13.72,4.5,1.56,.87,.80),
                  (-11.55,-3.7,1.18,1.17,.72),(-8.79,-4.02,1.05,1.28,.82),(-6.05,4.67,1.19,.95,.91),
                  (-5.86,-5.74,.83,1.03,.79),(-3.37,7.07,1.48,.95,.94),(1.48,7.44,1.72,1.28,1.13),
                  (5.77,-5.52,1.32,1.52,1.11),(7.27,4.79,1.13,.77,.83),(11.25,-4.18,1.16,1.64,.78),
                  (14.21,4.03,1.15,1.08,.72),(15.50,-1.43,1.07,2.37,1.22)]:
    rock(scenery,basalt,(x,0,z),(w,h,d),9)
    rock(scenery,moss,(x-.24,-.015,z+.21),(w*.45,h*.12,d*.41),7)
    if abs(z) < 4.25:
        anchor(x,z,w*.62)
    for i in range(5):
        px,pz=x+RNG.uniform(-1.4,1.4),z+RNG.uniform(-.72,.55)
        g=RNG.uniform(.17,.38)
        rock(scenery,RNG.choice((slate,basalt,limestone)),(px,-.025,pz),(g,g*.53,g*.69),7)

for x,z,angle in [(-23.58,2.87,.25),(-13.73,-2.51,0.0),(-6.98,-3.44,-.20),(-3.62,-5.23,.10), (10.98,-1.83,-.14)]:
    hearth=group('Ritual coal basin',(x,0,z),angle,architecture)
    stone(hearth,basalt,(0,.16,0),(.48,.32,.44),damage=.022)
    stone(hearth,bronze,(0,.35,0),(.61,.145,.53),damage=.022)
    for i in range(8):
        px,pz=RNG.uniform(-.15,.15),RNG.uniform(-.12,.12)
        rock(hearth,RNG.choice((ember,slate)),(px,.41,pz),(.092,.061,.081),6)
    anchor(x,z,.24)

for x,z,extent,count in [(-26.0,3.66,1.4,52),(-23.6,-3.74,1.38,63),(-20.7,3.72,2.15,82),(-18.2,-3.82,1.20,54),
                         (-15.0,3.48,1.57,64),(-13.2,-3.7,1.84,71),(-10.79,3.25,1.05,53),(-8.9,-3.79,1.36,68),
                         (-5.07,-4.65,1.50,77),(-3.79,3.87,1.23,68),(-.03,-5.89,2.46,96),(-.24,5.61,2.26,85),
                         (4.24,3.95,1.38,65),(5.48,-4.42,1.21,62),(7.61,3.47,1.32,54),(9.48,-3.26,1.62,63),(12.48,3.48,1.32,65)]:
    for j in range(count):
        yaw=RNG.uniform(0,tau)
        d=RNG.random()**.56*extent
        tuft(foliage,x+cos(yaw)*d,z+sin(yaw)*d*.66,RNG.uniform(.35,.86))

# Meshes sharing a material and logical parent are baked together in the export.
for (parent,mat),(verts,faces) in buckets.items():
    data=bpy.data.meshes.new(parent.name+' / '+mat.name)
    data.from_pydata(verts,[],faces)
    data.update()
    edit=bmesh.new()
    edit.from_mesh(data)
    bmesh.ops.recalc_face_normals(edit,faces=list(edit.faces))
    bmesh.ops.triangulate(edit,faces=list(edit.faces))
    edit.to_mesh(data)
    edit.free()
    data.update()
    obj=bpy.data.objects.new(data.name,data)
    bpy.context.collection.objects.link(obj)
    obj.parent=parent
    data.materials.append(mat)
    uv=data.uv_layers.new(name='Stone projection')
    for face in data.polygons:
        axis=max(range(3),key=lambda j:abs(face.normal[j]))
        for index in face.loop_indices:
            x,y,z=data.vertices[data.loops[index].vertex_index].co
            u,v=((y,z),(x,z),(x,y))[axis]
            uv.data[index].uv=(.57*u+.11,.57*v+.28)

bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'headland.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUTPUT/'headland.glb'), export_yup=True)
