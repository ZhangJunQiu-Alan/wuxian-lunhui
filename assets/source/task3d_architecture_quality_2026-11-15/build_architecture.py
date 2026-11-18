from pathlib import Path
import sys, math, json
import bpy, bmesh
from mathutils import Vector
BATCH=Path(__file__).resolve().parent
PREVIOUS=BATCH.parent/'task3d_rooms_quality_2026-11-15'
sys.path.insert(0,str(PREVIOUS))
import build_assets as art
art.BATCH=BATCH
S,W,I,E,F,R,C=art.S,art.W,art.I,art.E,art.F,art.R,art.C
box,beam,cylinder,bolt,slab,line,torus=art.box,art.beam,art.cylinder,art.bolt,art.slab,art.line,art.torus


original_finish=art.finish
def finish_with_grain(o,name,mat,bevel=0,damage=0):
    o=original_finish(o,name,mat,bevel,damage)
    if mat==W:
        extents=[max(v.co[a] for v in o.data.vertices)-min(v.co[a] for v in o.data.vertices) for a in range(3)]
        grain=max(range(3),key=lambda a:extents[a])
        offset=art.rng.random()*3
        layer=o.data.uv_layers.active
        for polygon in o.data.polygons:
            normal_axis=max(range(3),key=lambda a:abs(polygon.normal[a]))
            u=grain if grain!=normal_axis else (normal_axis+1)%3
            v=next(a for a in range(3) if a not in [normal_axis,u])
            for li in polygon.loop_indices:
                point=o.data.vertices[o.data.loops[li].vertex_index].co
                layer.data[li].uv=(point[u]*.6+offset,point[v]*.3+.08)
    return o
art.finish=finish_with_grain


def wall():
    box('Wall footing',(0,0,.11),(3.17,.88,.22),S,.035,.008)
    for row in range(6):
        boundaries=sorted(set([-1.56,1.56]+[max(-1.56,min(1.56,-1.56+j*.625+(row%2)*.3125)) for j in range(7)]))
        for left,right in zip(boundaries,boundaries[1:]):
            if right-left<.12: continue
            x=(left+right)/2
            height=6 if abs(x)<.65 else 5 if x<.9 else 4
            if row>=height: continue
            z=.24+row*.393+.185
            o=box('Bonded weathered ashlar',(x,art.rng.uniform(-.013,.013),z),(right-left-.023,.60,.37),S,.027,.008)
            o.rotation_euler.z=art.rng.uniform(-.009,.009)
            if row==height-1:
                box('Broken crest stone',(x,.015,z+.235),(right-left-.01,.68,.10),S,.023,.010)
    for side in [-1,1]:
        for row in range(4):
            box('Bonded wall end pier',(side*1.37,0,.24+row*.43+.20),(.39,.81,.41),S,.028,.008)
    for x in [-.86,.86]:
        box('Rear repair upright',(x,.40,1.01),(.105,.14,1.73),W,.012,.002)
        for z in [.40,1.35]:
            box('Repair strap',(x,.486,z),(.17,.025,.11),I,.006)
            bolt(x,.512,z,.026,'Y')
    beam('Rear diagonal repair',(-.84,.47,.42),(.84,.47,1.68),.10,.12,W)
    art.rubble(1.02,-.48,.09,12,.30)
    art.rubble(-.94,.47,.08,9,.27)
    art.marker('SnapLeft',(-1.6,0,0)); art.marker('SnapRight',(1.6,0,0))
    art.root['module_pitch']=3.2


def pillar():
    box('Pillar foundation',(0,0,.11),(.95,.95,.22),S,.05,.012)
    box('Pillar dressed plinth',(0,0,.36),(.72,.72,.30),S,.04,.008)
    box('Heavy oak upright',(0,0,1.86),(.42,.42,2.77),W,.017,.003)
    for z in [.55,.76,2.65,3.14]:
        for side in [-1,1]:
            box('Pier iron band',(0,side*.226,z),(.48,.036,.10),I,.007)
            box('Pier iron band',(side*.226,0,z),(.036,.48,.10),I,.007)
            for x in [-.15,.15]: bolt(x,side*.252,z,.024,'Y')
    box('Carved capital block',(0,0,3.31),(.63,.57,.18),W,.022,.003)
    box('Crossbeam seat',(0,0,3.48),(1.49,.42,.19),W,.016,.003)
    for side in [-1,1]:
        beam('Knee brace',(side*.18,0,2.65),(side*.65,0,3.35),.16,.19,W)
        cylinder('Brace timber peg',(side*.27,-.111,2.79),.032,.04,E,12,rot=(math.pi/2,0,0))
        cylinder('Crossbeam end peg',(side*.56,-.23,3.48),.035,.05,I,12,rot=(math.pi/2,0,0))
    for x in [-.09,.07]:
        line('Vertical oak split',[(x,-.214,.92),(x+.012,-.215,1.48),(x-.009,-.214,2.16)],.0025,C)
    art.marker('FootAnchor',(0,0,0)); art.marker('BeamAnchor',(0,0,3.58))


def stairs():
    count=5; depth=.39; step=.18
    for row in range(count):
        y=-.78+row*depth; top=(row+1)*step
        for col in range(3):
            x=(col-1)*.73
            box('Stair structural block',(x,y,top/2),(.71,.375,top),S,.018,.004)
            box('Projecting stair tread',(x,y-.025,top+.027),(.73,.407,.065),S,.018,.006)
        for side in [-1,1]:
            box('Stepped stair cheek',(side*1.22,y,(top+.19)/2),(.23,.38,top+.19),S,.024,.006)
    for side in [-1,1]:
        box('Upper cheek cap',(side*1.22,.77,1.17),(.29,.43,.13),S,.025,.006)
    art.rubble(-.82,-.92,.065,8,.16)
    art.marker('LowerAnchor',(0,-.99,.035)); art.marker('UpperAnchor',(0,.99,.96))
    art.root['rise']=.90; art.root['run']=1.95


def barricade():
    for x in [-1.04,1.04]:
        beam('Barricade splayed foot',(x,-.48,.09),(x,.35,.64),.15,.18,W)
        beam('Barricade counter foot',(x,.45,.09),(x,-.22,.65),.15,.18,W)
        box('Ground iron shoe',(x,-.42,.065),(.29,.27,.09),I,.011)
        for y in [-.45,.37]: bolt(x,y,.119,.027)
    for x,z in [(-1.05,.78),(0,.83),(1.05,.73)]:
        box('Weathered barricade post',(x,0,z),(.16,.19,z*2),W,.014,.003)
        box('Post iron collar',(x,0,.39),(.20,.23,.12),I,.007)
    for z in [.57,1.09]:
        for side in [-1,1]:
            o=box('Split barricade rail',(side*.67,-.14,z),(1.29,.14,.21),W,.012,.003)
            o.rotation_euler.y=side*.025
        for x in [-1.05,0,1.05]:
            box('Riveted rail strap',(x,-.222,z),(.115,.025,.30),I,.006)
            for dz in [-.105,.105]: bolt(x,-.245,z+dz,.021,'Y')
    beam('Diagonal back brace',(-1.14,.13,.44),(1.14,.13,1.31),.12,.12,W)
    for j in range(3):
        x=-.75+j*.72
        line('Open grain split',[(x,-.216,.54),(x+.24,-.217,.552),(x+.43,-.216,.535)],.0028,C)
    art.marker('CoverAnchor',(0,-.70,0)); art.marker('ObstacleOrigin',(0,0,.65))


def chest():
    # The interior is open geometry, with individual wall and bottom boards.
    for col in range(6): box('Chest floor board',((col-2.5)*.255,0,.14),(.246,.89,.12),W,.009,.001)
    for side in [-1,1]:
        for col in range(6):
            box('Front and rear oak board',((col-2.5)*.255,side*.445,.46),(.246,.095,.60),W,.010,.001)
        for row in range(3): box('Chest end wall',(side*.765,0,.27+row*.195),(.10,.81,.186),W,.010,.001)
        for x in [-.64,.64]:
            box('Chest corner strap',(x,side*.501,.46),(.10,.025,.65),I,.008)
            for z in [.22,.48,.72]: bolt(x,side*.526,z,.019,'Y')
        for z in [.23,.66]:
            box('End binding',(side*.824,0,z),(.024,.89,.07),I,.006)
        torus('Chest carry ring',(side*.85,0,.49),.09,.013,E,(0,math.pi/2,0),24)
    box('Front lock receiver',(0,-.508,.66),(.20,.045,.18),I,.008)
    cylinder('Keyhole recess',(0,-.535,.68),.021,.008,C,16,rot=(math.pi/2,0,0),bevel=.001)
    box('Keyhole slot',(0,-.54,.654),(.013,.009,.028),C,.001)
    lid=art.rig('HingedLid',(0,.48,.78)); start=len(art.objects)
    for row in range(7):
        y=-.435+row*.145
        z=.827+.16*(1-(y/.52)**2)
        o=box('Vaulted lid board',(0,y,z),(1.64,.141,.095),W,.012,.001)
        o.rotation_euler.x=math.atan(-.32*y/(.52*.52))
    for side in [-1,1]:
        profile=[(-.51,.78),(.51,.78),(.51,.845),(.37,.925),(.18,.98),(0,1.0),(-.18,.98),(-.37,.925),(-.51,.845)]
        verts=[(side*.786+dx,y,z) for dx in [-.035,.035] for y,z in profile]
        n=len(profile); faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        art.mesh('Lid end cheek',verts,faces,W,.009)
    for x in [-.64,.64]:
        points=[(x,-.52,.808),(x,-.40,.91),(x,-.2,.974),(x,0,1.003),(x,.2,.974),(x,.4,.91),(x,.52,.808)]
        points=[(px,py,pz+.05) for px,py,pz in points]
        for a,b in zip(points,points[1:]): beam('Formed lid iron band',a,b,.072,.025,I)
        for y in [-.39,0,.39]: bolt(x,y,.915+.16*(1-(y/.52)**2),.018)
        cylinder('Rear hinge barrel',(x,.48,.78),.038,.23,I,24,rot=(0,math.pi/2,0))
    box('Lid lock hasp',(0,-.533,.794),(.13,.032,.19),I,.008)
    art.attach(lid,start)
    art.animate(lid,'open','rotation_euler',0,[(1,0),(12,0),(62,-math.radians(105)),(90,-math.radians(105))])
    art.marker('InteractAnchor',(0,-.85,.50)); art.marker('LootOrigin',(0,0,.53))


def runestone():
    box('Runestone buried footing',(0,0,.09),(1.40,.91,.25),S,.07,.018)
    outline=[(-.51,.19),(.50,.19),(.57,1.22),(.42,2.48),(.14,2.85),(-.22,2.72),(-.54,2.39),(-.59,1.21)]
    n=len(outline)
    verts=[(x,y,z) for y in [-.255,.255] for x,z in outline]
    faces=[tuple(range(n)),tuple(range(n*2-1,n-1,-1))]+[(i,i+n,(i+1)%n+n,(i+1)%n) for i in range(n)]
    standing=art.mesh('Fractured standing stone',verts,faces,S,.035,.004)
    grooves=[]
    for z in [.78,1.26,1.74,2.22]:
        grooves.extend([[(-.13,z-.12),(.12,z+.14)],[(0,z-.17),(0,z+.19)],[(-.13,z+.13),(.12,z-.03)]])
    grooves.extend([[(-.35,.53),(-.38,1.23),(-.33,2.18)],[(-.33,2.18),(-.14,2.43),(.09,2.49),(.29,2.30)],[(.29,2.30),(.36,1.68),(.33,.58)]])
    for index,points in enumerate(grooves):
        cutter=line('Engraving cutter',[(x,-.255,z) for x,z in points],.018,E)
        bm=bmesh.new(); bm.from_mesh(cutter.data)
        bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
        bm.normal_update(); bm.to_mesh(cutter.data); bm.free()
        bpy.context.view_layer.objects.active=standing
        mod=standing.modifiers.new('Incised stone channel','BOOLEAN'); mod.operation='DIFFERENCE'; mod.solver='EXACT'; mod.object=cutter
        bpy.ops.object.modifier_apply(modifier=mod.name)
        art.objects.remove(cutter); bpy.data.objects.remove(cutter,do_unlink=True)
        line('Recessed rune inlay',[(x,-.240,z) for x,z in points],.0035,R if index in [1,7] else I)
    art.objects.remove(standing); art.finish(standing,'Engraved standing stone',S)
    art.rubble(.54,-.12,.14,14,.26)
    art.frost_patch(-.41,.26,.225,.17)
    art.marker('InteractAnchor',(0,-.82,1.0)); art.marker('BlessingOrigin',(0,-.33,1.55))

ENTRIES=[
 ('ruined_wall','破损砌石残墙','建筑','3.2 米墙段，独立风化砌块、破损墙冠、端部扶壁与背面木质修补结构。','战斗房边界、遗迹转角','',1),
 ('timber_pillar','铁箍承重木柱','建筑','石础、厚木柱、横梁托座、斜撑、锻铁包箍与连接木销。','长屋、回廊、房间分隔','',1),
 ('stone_stairs','冻裂石阶','建筑','五级独立踏步、凸出踏面、分块阶身、侧墙和破损边角。','入口、祭坛高台','',1),
 ('barricade','铁木战斗路障','掩体','交叉支脚、独立旧木横板、斜撑、铆接铁带与裂缝。','小规模遭遇战掩体、侧路','',1),
 ('supply_chest','铁箍补给箱','奖励','有内部空间的木箱、拱形分板箱盖、铁带、铰链、锁孔与侧环。','奖励房、营火房','open',1),
 ('runestone','刻槽符文立碑','地标','不规则断面石碑、真实刻槽、深嵌符文、碎石和薄霜。','祝福房、房间目标','',1)
]
art.ENTRIES=ENTRIES
art.BUILDERS=dict(zip([e[0] for e in ENTRIES],[wall,pillar,stairs,barricade,chest,runestone]))
if __name__=='__main__':
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for entry in ENTRIES:
        if not wanted or entry[0] in wanted: art.build_one(entry)
    result=[json.loads((BATCH/'records'/(e[0]+'.json')).read_text()) for e in ENTRIES if (BATCH/'records'/(e[0]+'.json')).exists()]
    (BATCH/'new-models.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('ARCHITECTURE_MODELS_DONE',len(result),flush=True)
