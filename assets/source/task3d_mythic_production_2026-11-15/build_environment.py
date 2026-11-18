from pathlib import Path
import sys,math,json
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *


def rock(name,loc,size):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1,location=loc)
    o=bpy.context.object
    for v in o.data.vertices:
        factor=1+art.rng.uniform(-.07,.07)+.08*math.sin(v.co.x*7+v.co.z*4)
        v.co*=factor
    o.scale=size
    art.finish(o,name,S)
    for p in o.data.polygons:p.use_smooth=True
    return o

def rock_snow(o):
    threshold=max(v.co.z for v in o.data.vertices)*.67
    faces=[tuple(p.vertices) for p in o.data.polygons if all(o.data.vertices[j].co.z>threshold for j in p.vertices)]
    assert faces
    mesh=bpy.data.meshes.new('Surface following snow mesh')
    bpy.context.view_layer.update()
    mesh.from_pydata([tuple(o.matrix_world@Vector((v.co.x,v.co.y,v.co.z+.014))) for v in o.data.vertices],[],faces)
    cap=bpy.data.objects.new('Surface following old snow',mesh);bpy.context.collection.objects.link(cap)
    art.finish(cap,'Surface following old snow',F)
    for face in cap.data.polygons:face.use_smooth=True

def snow_cap(x,y,z,rx,ry):
    points=[(x+math.cos(j*math.tau/12)*rx*art.rng.uniform(.82,1.0),y+math.sin(j*math.tau/12)*ry*art.rng.uniform(.82,1.0)) for j in range(12)]
    slab('Irregular old snow crust',points,z-.015,z+.025,F,.008,.001)

def rocks():
    for i,(loc,size) in enumerate([((-.65,.18,.67),(.83,.64,.77)),((.43,.21,.91),(.73,.74,1.00)),((1.07,-.19,.40),(.48,.52,.48)),((-.15,-.61,.28),(.64,.41,.34))]):
        o=rock('Fractured snow rock',loc,size)
        o.rotation_euler.z=art.rng.uniform(-.3,.3)
        rock_snow(o)
    art.rubble(-.80,-.61,.07,22,.50)
    art.marker('ObstacleOrigin',(0,0,.70))


def dead_tree():
    tube('Wind twisted trunk',[(0,0,.10),(.10,.03,.85),(-.02,.02,1.70),(.21,.03,2.58),(.31,.02,3.39),(.18,.01,4.03)],[.26,.22,.17,.12,.075,.012],W,20)
    for side in [-1,1]:
        for j in range(3):
            z=1.45+j*.70;x=.10+j*.07
            end=(x+side*(1.20-j*.18),.15*(j-1),z+.64)
            points=[(x,0,z),(x+side*.45,.05,z+.28),end]
            tube('Bare winter branch',points,[.085-j*.016,.05-j*.010,.006],W,12)
            tube('Forked branch twig',[tuple(Vector(points[1]).lerp(Vector(end),.5)),(end[0]-side*.17,end[1]+.23,end[2]+.38)],[.025,.003],W,10)
    for j in range(6):
        a=j*math.tau/6
        tube('Exposed tree root',[(0,0,.23),(.37*math.cos(a),.37*math.sin(a),.08),(.62*math.cos(a),.62*math.sin(a),.035)],[.11,.07,.008],W,12)
    art.frost_patch(.24,-.10,.065,.20)
    art.marker('FootAnchor',(0,0,0))


def burial_mound():
    rock('Low burial mound',(0,0,.18),(1.32,1.00,.30))
    for row in range(3):
        count=18-row*3
        for j in range(count):
            a=j*math.tau/count;r=1.40-row*.25
            rock('Cairn fieldstone',(r*math.cos(a),r*.76*math.sin(a),.18+row*.21),(.26,.21,.18))
    slab('Grave capstone',[(-.65,-.44),(.69,-.40),(.57,.43),(-.59,.46)],.79,.94,S,.025,.006)
    box('Head grave marker',(0,.73,.93),(.60,.26,1.13),S,.045,.014)
    rune_mark((0,.585,1.12),.15,I)
    for x,y,z in [(-.74,-.55,.62),(.71,.42,.70)]: snow_cap(x,y,z,.33,.18)
    art.marker('EncounterAnchor',(0,-1.9,0))


def dock():
    for x in [-1.20,1.20]:
        for y in [-1.28,1.28]:
            cylinder('Dock timber piling',(x,y,-.51),.145,1.55,W,20)
            torus('Piling iron collar',(x,y,.12),.15,.015,I,segments=28)
            torus('Piling lower collar',(x,y,-.20),.15,.015,I,segments=28)
        beam('Dock longitudinal bearer',(x,-1.60,-.15),(x,1.60,-.15),.16,.20,W)
    for row in range(13):
        y=(row-6)*.245
        o=box('Worn dock deck board',(0,y,.015),(2.98,.23,.15),W,.012,.002)
        for x in [-1.20,1.20]:bolt(x,y,.104,.018)
    for side in [-1,1]:
        beam('Dock under brace',(side*1.2,-1.25,-.83),(side*1.2,1.25,-.18),.105,.13,W)
    for x,y in [(-1.20,-1.28),(1.20,1.28)]:
        cylinder('Low dock safety post',(x,y,.40),.12,.59,W,20)
        torus('Safety post band',(x,y,.62),.126,.012,I,segments=24)
    art.marker('SnapEntry',(0,-1.6,.09));art.marker('SnapExit',(0,1.6,.09));art.root['module_pitch']=3.2


def bollard():
    box('Mooring footing',(0,0,.08),(.90,.82,.16),S,.026,.006)
    cylinder('Stout mooring post',(0,0,.53),.18,.88,W,28)
    for z in [.25,.84]:torus('Post iron hoop',(0,0,z),.188,.020,I,segments=32)
    cylinder('Mooring cross pin',(0,0,.72),.061,.71,I,24,rot=(0,math.pi/2,0))
    points=[]
    for j in range(181):
        a=j/180*math.tau*5
        points.append((.215*math.cos(a),.215*math.sin(a),.31+j/180*.25))
    tube('Coiled mooring rope',points,[.020]*len(points),W,8)
    tube('Loose rope tail',[(.21,0,.33),(.40,-.08,.17),(.51,-.23,.115),(.64,-.30,.12)],[.020,.020,.018,.015],W,8)
    for x in [-.30,.30]:
        for y in [-.25,.25]:bolt(x,y,.18,.025)
    art.marker('MooringAnchor',(0,0,.73))


def campfire():
    for j in range(14):
        a=j*math.tau/14
        rock('Campfire ring stone',(.66*math.cos(a),.66*math.sin(a),.11),(.18,.14,.14))
    cylinder('Ash bed',(0,0,.028),.57,.045,C,48,bevel=.001)
    for j in range(4):
        a=j*math.pi/4
        tube('Charred firewood',[(-.44*math.cos(a),-.44*math.sin(a),.14),(.44*math.cos(a),.44*math.sin(a),.14)],[.065,.061],W,14)
    for j in range(15):
        a=art.rng.random()*math.tau;r=art.rng.random()*.36
        rock_piece=rock('Cold ember charcoal',(r*math.cos(a),r*math.sin(a),.09),(.065,.05,.035))
        rock_piece.data.materials.clear();rock_piece.data.materials.append(art.mats[R if j%4==0 else C])
    for x,y in [(-.75,-.35),(.66,.44)]:art.rubble(x,y,.035,5,.15)
    art.marker('FireOrigin',(0,0,.22));art.marker('RestAnchor',(0,-1.2,.05))

ENTRIES=[
('snow_rocks','寒原·积雪岩群','自然环境','不规则岩体、风化石面、碎石与局部旧雪，可组成边界或掩体。','雪村、墓丘、冰湖边缘','',1),
('dead_tree','寒林·风折枯树','自然环境','扭曲树干、分叉枝条、外露树根与风化木面。','雪村边缘、营火房','',1),
('burial_mound','古墓·石垒墓丘','主题场景','低矮墓丘、环绕垒石、厚盖石、墓碑和积雪。','古老墓丘、精英遭遇','',1),
('fjord_dock','峡湾·木桩码头段','主题场景','3.2 米节距，独立甲板、深木桩、铁箍、底梁与斜撑。','峡湾码头、岸边通路','',1),
('mooring_bollard','峡湾·缆绳系船桩','场景设施','木桩、横向系船销、金属包箍与连续盘绕缆绳。','码头侧缘、营地','',1),
('campfire_ring','旅人·石圈营火','场景设施','不规则石圈、灰床、交错木柴和静态余烬。','安全补给房、旅人营火','',1)
]
if __name__=='__main__':
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for entry,builder in zip(ENTRIES,[rocks,dead_tree,burial_mound,dock,bollard,campfire]):
        if not wanted or entry[0] in wanted:finish_entry(entry,builder)
    print('ENVIRONMENT_BATCH_DONE',flush=True)
