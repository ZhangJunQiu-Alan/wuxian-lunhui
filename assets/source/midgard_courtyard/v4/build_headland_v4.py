from math import atan2, cos, hypot, pi, radians, sin, tau
from pathlib import Path
from random import Random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from model_props import PROPS, RUNTIME, SOURCE, empty, material, mesh, point, stone

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
rng = Random(482)
root = empty("Fimbulwinter winter headland")
terrain = empty("Terrain", root)
architecture = empty("Winter timber and stone", root)
rocks = empty("Shore scree", root)
anchors = empty("Collision anchors", root)
snow = material("Wind packed snow", (.68,.76,.85), image_name="snowfield")
basalt = material("Winter basalt", (.18,.21,.25), image_name="basalt")
oak = material("Weathered oak", (.19,.12,.077), image_name="oak")
collision_count = 0
library = {}



def copy_asset(name, parent, location, rotation=0, scale=(1,1,1), label=None):
    if name not in library:
        path = PROPS / f"{name}.blend"
        with bpy.data.libraries.load(str(path), link=False) as (available, loaded):
            loaded.objects = available.objects
        original = next(obj for obj in loaded.objects if obj.parent is None and obj.name == name)
        by_parent = {}
        for obj in loaded.objects:
            by_parent.setdefault(obj.parent, []).append(obj)
        library[name] = (original, by_parent)
    original,children = library[name]

    def duplicate(old, into):
        obj = old.copy()
        bpy.context.collection.objects.link(obj)
        obj.parent = into
        for child in children.get(old,[]):
            duplicate(child,obj)
        return obj

    placed=duplicate(original,parent)
    placed.name=label or name
    placed.location=point(location)
    placed.rotation_euler.z=rotation
    placed.scale=scale
    return placed


def collider(x,z,radius):
    global collision_count
    anchor=empty(f"Collider_{collision_count:03d}",anchors,(x,0,z))
    anchor.scale=(radius,)*3
    collision_count+=1


def wall(chain, *, scale=1.0, variant=0, solid=True):
    for index, ((ax,az),(bx,bz)) in enumerate(zip(chain,chain[1:])):
        length=hypot(bx-ax,bz-az)
        count=max(1,round(length/1.62))
        width=length/count
        angle=atan2(az-bz,bx-ax)
        for i in range(count):
            t=(i+.5)/count
            x,z=ax+(bx-ax)*t,az+(bz-az)*t
            name="low_wall_b" if (index+i+variant)%3 == 0 else "low_wall"
            copy_asset(name,architecture,(x,0,z),angle+rng.uniform(-.047,.045),
                       (width/1.81,rng.uniform(.82,1.12),scale*rng.uniform(.89,1.10)))
        if solid:
            count=max(1,int(length/.43+.5))
            for i in range(count+1):
                if index and i==0:
                    continue
                t=i/count
                collider(ax+(bx-ax)*t,az+(bz-az)*t,.28*max(.93,scale))


# Perspective follows across successive widening terraces. Coordinates are in game metres.
rim=[(-28.16,-3.53),(-27.05,-4.52),(-25.44,-4.61),(-24.21,-5.15),(-22.53,-5.17),(-21.17,-5.56),(-19.45,-5.22),
     (-18.1,-4.90),(-16.62,-4.79),(-15.35,-5.03),(-13.38,-5.22),(-12.37,-4.51),(-10.92,-4.18),(-9.79,-4.31),
     (-8.01,-4.42),(-6.83,-4.63),(-6.07,-5.45),(-5.01,-6.80),(-3.67,-7.68),(-2.23,-8.32),(-.63,-8.12),
     (1.49,-8.55),(3.31,-8.06),(5.07,-7.27),(6.23,-6.26),(7.52,-4.89),(9.02,-4.82),(10.96,-4.93),
     (12.28,-4.42),(13.58,-4.79),(14.88,-4.35),(15.76,-3.25),(16.03,-1.13),(15.69,.39),(16.18,2.34),
     (15.64,3.93),(14.52,4.96),(12.88,4.36),(10.94,4.63),(8.87,4.63),(7.80,4.15),(6.52,5.19),(5.30,6.26),
     (4.00,7.22),(2.37,7.65),(.35,7.93),(-1.44,7.75),(-3.00,7.51),(-4.58,7.02),(-5.48,6.22),
     (-6.72,5.09),(-7.71,4.80),(-9.01,4.42),(-10.57,4.70),(-11.37,5.08),(-13.08,4.61),(-14.15,4.85),
     (-15.85,4.85),(-17.42,4.72),(-19.26,5.16),(-20.62,4.92),(-21.96,5.30),(-23.57,5.19),(-25.18,4.69),
     (-26.91,4.60),(-27.88,3.48),(-28.25,1.04),(-28.11,-.98)]
# The bridgehead comes out of a wooded shoulder; the sea opens on the visible, broken side.
rim=[(x-(3.2*max(0.0,min(1.0,(-x-25.0)/3.0))),z-(1.85*max(0.0,min(1.0,-z/4))))
     for x,z in rim]
coast=[]
for i,(x,z) in enumerate(rim):
    a,b=rim[(i+1)%len(rim)]
    dx,dz=a-x,b-z
    coast.append((x,z))
    for t in (.31,.64):
        relief=rng.uniform(-.13,.19)
        coast.append((x+dx*t+dz*relief,z+dz*t-dx*relief))
count=len(coast)
vertices=[]
section=[(.002,0),(-.12,.065),(-.32,.17),(-.62,.14),(-.82,.32),(-1.28,.44),(-1.95,.55),
         (-2.30,.68),(-3.14,.82),(-3.58,1.02),(-4.31,1.44),(-5.20,1.64),(-5.92,1.72)]
stripes=[rng.uniform(.72,1.37) for _ in coast]
for row,(height,out) in enumerate(section):
    for i,(x,z) in enumerate(coast):
        a,c=coast[i-1],coast[(i+1)%count]
        turn=atan2(c[1]-a[1],c[0]-a[0])-pi/2
        distance=out*stripes[i]+rng.uniform(-.08,.09)*min(row,1)+.26*sin(row*.85+i*.41)*min(1,row*.4)
        fracture=.1*sin(i*2.1+row*.91)+.072*cos(i*.87+row*1.87)
        vertices.append((x+cos(turn)*distance,height+fracture*min(1,row*.44),z+sin(turn)*distance))
faces=[tuple(reversed(range(count)))]
for row in range(len(section)-1):
    for i in range(count):
        a,b=row*count+i,row*count+(i+1)%count
        faces.extend(((a,b,b+count),(a,b+count,a+count)))
faces.append(tuple(range((len(section)-1)*count,len(vertices))))
mesh(terrain,"Riven cliff",vertices,faces,basalt)

# Continuous living boundaries, left open only at the two doors.
north=[(-6.78,-4.38),(-5.90,-5.31),(-4.66,-6.32),(-2.72,-6.83),(-.44,-7.19),
       (2.32,-7.28),(4.31,-6.40),(5.81,-5.42),(7.78,-3.58),(10.13,-3.42),(12.81,-3.29),(14.87,-3.03)]
south=[(-6.75,3.80),(-5.41,5.23),(-3.51,6.41),(-.94,6.93),(1.61,6.93),(3.89,6.21),
       (5.25,5.33),(6.19,4.29),(8.10,3.55),(11.55,3.45),(13.85,3.57),(15.01,3.12)]
wall(north,scale=.89)
wall(south,scale=.74,variant=1)
wall([(-6.72,-4.38),(-6.72,-2.74)],scale=1.1)
wall([(-6.72,-.55),(-6.72,1.81),(-6.50,4.37)],scale=1.0)
wall([(-8.17,-.12),(-8.01,1.11),(-7.91,2.32),(-7.77,3.59)],scale=1.1,variant=1)
for chain in [
    [(-27.05,-3.47),(-24.77,-3.20),(-23.16,-3.32)],
    [(-25.78,3.75),(-24.07,3.80),(-22.25,3.18)],
    [(-21.38,-3.74),(-19.47,-3.36),(-17.96,-3.42)],
    [(-18.55,3.77),(-16.76,3.58),(-15.12,3.11)],
    [(-16.25,-3.67),(-14.69,-3.31),(-12.21,-2.90)],
    [(-13.93,3.75),(-12.24,3.57),(-11.03,2.95),(-9.65,2.52)],
    [(-10.74,-3.94),(-8.77,-3.55),(-7.44,-3.70)],
]:
    wall(chain,scale=rng.uniform(.70,.97),variant=1)

for i,(x,z,h) in enumerate([(-26.2,-3.34,.75),(-21.99,-2.8,.96),(-18.61,3.43,.54),(-14.69,-3.32,.80),
                            (-10.12,-3.38,.76),(-4.96,-5.65,.99),(4.34,-5.66,1.01),
                            (9.78,-3.07,.78),(13.65,3.10,.62)]):
    angle=rng.uniform(-.39,.25)
    copy_asset("rune_stone_a" if i%2 else "rune_stone_b",architecture,(x,0,z),angle,(.79,.81,h))
    collider(x,z,.37)

copy_asset("longhouse_ruin",architecture,(-1.82,0,-6.38),radians(8),(1.03,1,.99))
copy_asset("longhouse_ruin_b",architecture,(2.33,-.02,-7.12),radians(13),(.64,.86,.75))
for x,z in [(-4.0,-6.35),(-2.6,-6.16),(-.60,-6.43),(.48,-6.30),(2.08,-6.91),(3.76,-7.03)]:
    collider(x,z,.39)

copy_asset("entry_shutter",architecture,(-6.72,0,-1.65),radians(-72),label="EntranceGate")
exit_at=(8.93,0,1.24)
copy_asset("exit_gate",architecture,exit_at,radians(-70),label="Winter exit")
for x,z in [(-6.72,-2.78),(-6.72,-.52),(8.54,.118),(9.32,2.36)]:
    collider(x,z,.36)
wall([(8.52,-.13),(8.21,-1.65),(8.22,-3.61)],scale=.68,variant=1)
wall([(9.41,2.47),(9.33,3.64)],scale=.71)

for i,(x,z,t,angle) in enumerate([(-24.72,-4.35,.7,.19),(-19.32,4.33,.70,-.43),(-16.78,-4.15,.82,.24),
                                (-12.98,3.76,.71,-.21),(-8.84,-4.13,.86,-.24),(-5.67,4.71,.75,.43),
                                (-3.27,2.76,.76,-.40),(3.69,2.95,.63,.38),(5.66,-5.01,.83,-.54),
                                (9.43,3.57,.52,.37),(13.97,-3.81,.72,-.37),(15.36,3.22,.93,.37)]):
    copy_asset("basalt_rocks" if i%2 else "basalt_rocks_b",rocks,(x,-.025,z),angle,(t,t,t))
    collider(x,z,.54*t)
    if i in (6,7):
        collider(x-.53,z,.27)
        collider(x+.51,z-.10,.28)

for i in range(0,len(coast),3):
    x,z=coast[i]
    turn=rng.uniform(-pi,pi)
    scale=rng.uniform(.49,.88)
    copy_asset("basalt_rocks_b" if i%2 else "basalt_rocks",rocks,
               (x,rng.uniform(-4.77,-2.07),z),turn,(scale,scale,rng.uniform(1.4,2.4)))

# Local snow banks and grit along the geometry of the enclosure, never in combat lanes.
for chain in (north,south):
    for i,((ax,az),(bx,bz)) in enumerate(zip(chain,chain[1:])):
        for j in range(4):
            t=rng.uniform(.03,.97)
            x,z=ax+(bx-ax)*t,az+(bz-az)*t+rng.uniform(-.42,.43)
            stone(rocks,"Snow drift at masonry",(rng.uniform(.37,.86),rng.uniform(.06,.18),rng.uniform(.28,.61)),
                  snow,levels=4,seed=i*17+j,at=(x,-.014,z))

# Two distant wreck fragments sit below the traversable shelf and break the surface in silhouette.
distant=empty("Fjord landmarks",root)
for index,(x,z,length,angle) in enumerate([(-23.0,10.9,3.1,.28),(4.7,13.7,4.3,-.48)]):
    wreck=empty("Wrecked keel",distant,(x,-5.10,z))
    wreck.rotation_euler.z=angle
    verts=[]
    for i in range(23):
        t=i/22
        flare=sin(pi*t)**.76
        for sign,y in [(-1,.08),(-1,.43),(1,.43),(1,.08)]:
            verts.append(((t-.5)*length,y+.73*abs(2*t-1)**3,sign*.5*flare))
    polys=[]
    for i in range(22):
        for j in (0,1,2,3):
            polys.append((4*i+j,4*i+(j+1)%4,4*i+4+(j+1)%4,4*i+4+j))
    mesh(wreck,"Split hull",verts,polys,oak)
    for j in range(5):
        x=-.75+j*.27
        mesh(wreck,"Broken rib",[(x,.18,-.44),(x+.06,.18,-.44),(x+.14,.97,-.28),(x+.08,.99,-.28)],
             [(0,1,2,3)],oak)

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"headland_v4.blend"),compress=True)
bpy.ops.export_scene.gltf(filepath=str(RUNTIME/"headland.glb"),export_yup=True,export_image_format="NONE")
print("V4_HEADLAND_COLLIDERS",collision_count)
