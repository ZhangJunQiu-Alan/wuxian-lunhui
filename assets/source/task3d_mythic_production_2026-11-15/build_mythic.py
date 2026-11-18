from pathlib import Path
import sys,math,json
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
B='Ancient brass'; K='Cold inlay'

def foundation(radius=1.4):
    art.ring_blocks('Segmented sacred stone base',.08,radius,-.12,.24,16)
    torus('Worn brass perimeter',(0,0,.145),radius-.09,.018,B,segments=48)

def raven(loc,scale=1):
    x,y,z=loc
    tube('Raven body',[(x,y,z),(x,y-.10*scale,z+.15*scale),(x,y-.13*scale,z+.32*scale)],[.10*scale,.14*scale,.07*scale],I,12)
    tube('Raven beak',[(x,y-.15*scale,z+.31*scale),(x,y-.34*scale,z+.29*scale)],[.05*scale,.003],E,8)
    tube('Raven tail',[(x,y+.08*scale,z+.08*scale),(x,y+.30*scale,z-.04*scale)],[.055*scale,.008*scale],I,10)
    for side in [-1,1]:
        cylinder('Raven leg',(x+side*.04*scale,y+.025*scale,z-.045*scale),.012*scale,.14*scale,E,12)
        cylinder('Raven eye',(x+side*.067*scale,y-.16*scale,z+.32*scale),.010*scale,.008*scale,'Ancient brass',12,rot=(0,math.pi/2,0))
        tube('Folded raven wing',[(x+side*.07*scale,y,z+.18*scale),(x+side*.16*scale,y+.10*scale,z-.07*scale)],[.07*scale,.015*scale],E,8)

def odin_portal():
    for side in [-1,1]:
        box('Temple threshold footing',(side*1.72,0,.12),(1.04,1.15,.24),S,.045,.01)
        for row in range(7): box('Temple dressed pier',(side*1.72,0,.49+row*.43),(.73,.85,.405),S,.028,.007)
        box('Oak temple post',(side*1.15,.07,2.02),(.23,.28,3.76),W,.015,.002)
        for z in [.45,1.25,2.4,3.58]:
            box('Carved iron post cuff',(side*1.15,-.085,z),(.29,.048,.13),I,.006)
            bolt(side*1.15,-.12,z,.023,'Y')
        rune_mark((side*1.72,-.435,1.7),.19,B)
        box('Raven front corbel',(side*1.72,-.60,3.48),(.38,.38,.08),S,.015,.004)
        raven((side*1.72,-.68,3.64),1.15)
    for z in [3.65,3.97]: box('Layered sanctuary lintel',(0,0,z),(4.43,1.03,.25),W,.026,.003)
    for side in [-1,1]:
        beam('Pitched gable beam',(0,0,5.05),(side*2.32,0,4.03),.22,.65,W)
        beam('Gable iron lining',(0,-.34,4.96),(side*2.24,-.34,3.98),.055,.025,I)
    for i in range(9):
        x=(i-4)*.33; height=1.01-abs(x)*.44
        box('Gable infill plank',(x,.03,4.12+height/2),(.31,.19,height),W,.008)
    torus('Odin single eye seal',(0,-.145,4.47),.20,.024,B,(math.pi/2,0,0),40)
    box('Threshold stone',(0,0,.045),(2.60,1.12,.14),S,.03,.008)
    art.marker('EntryAnchor',(0,-.85,.13)); art.marker('ExitAnchor',(0,.85,.13)); art.marker('RewardSignAnchor',(0,-.43,3.47))

def tree_altar():
    foundation(1.55)
    tube('World tree split trunk',[(0,0,.10),(.12,.04,.8),(-.10,.05,1.5),(.04,0,2.2),(-.18,.02,2.8)],[.43,.36,.32,.23,.15],W,20)
    for i in range(7):
        a=i*math.tau/7; c,s=math.cos(a),math.sin(a)
        tube('Twisting tree root',[(.12*c,.12*s,.61),(.55*c,.55*s,.30),(.98*c,1.02*s,.15),(1.39*c,1.33*s,.11)],[.19,.15,.10,.025],W,12)
        if i%2==0:
            tube('Bare crown branch',[(0,0,1.64),(.35*c,.35*s,2.26),(.74*c,.62*s,2.75),(1.02*c,.8*s,3.02)],[.14,.10,.055,.008],W,12)
    for side in [-1,1]:
        tube('Crown fork',[(-.10,0,2.2),(side*.39,.08,2.78),(side*.60,.12,3.28)],[.14,.08,.01],W,12)
    for z in [.66,1.05]: torus('Binding ring',(0,0,z),.34,.016,B,segments=40)
    rune_mark((-.03,-.345,1.5),.17,K)
    art.marker('BlessingOrigin',(0,-.65,.95)); art.marker('InteractAnchor',(0,-1.9,.6))

def fate_well():
    art.ring_blocks('Well foundation ring',.54,1.34,-.08,.20,18)
    for row in range(3):
        for i in range(16):
            a=(i+(row%2)*.5)*math.tau/16; b=a+math.tau/16-.022
            points=[(r*math.cos(t),r*math.sin(t)) for r,t in [(.62,a),(1.10,a),(1.10,b),(.62,b)]]
            slab('Well bonded masonry',points,.12+row*.25,.35+row*.25,S,.018,.004)
    art.ring_blocks('Coping stone',.58,1.16,.87,.14,16)
    cylinder('Dark water mirror',(0,0,.25),.61,.03,'Still dark water',64,bevel=.001)
    for i in range(3):
        a=i*math.tau/3+math.pi/6; x,y=1.40*math.cos(a),1.40*math.sin(a)
        box('Norn witness stone',(x,y,.83),(.28,.36,1.76),S,.045,.013)
        rune_mark((x,y-.19,1.0),.11,B)
    beam('Well crossbar',(-1.34,.25,1.98),(1.34,.25,1.98),.12,.13,W)
    for x in [-1.25,1.25]: box('Well support',(x,.25,1.0),(.14,.14,2.0),W,.012)
    chain('Well chain',(0,.25,1.97),(0,.25,.51),20,.035)
    art.marker('InteractAnchor',(0,-1.7,.7)); art.marker('WaterOrigin',(0,0,.28))

def bifrost_bridge():
    box('Bridge underside',(0,0,-.22),(2.39,3.19,.36),S,.025,.006)
    for row in range(4):
        for col in range(3): box('Bridge deck slab',((col-1)*.73,(row-1.5)*.79,-.005),(.71,.77,.15),S,.020,.004)
    for side in [-1,1]:
        box('Bridge edge kerb',(side*1.14,0,.15),(.15,3.19,.23),S,.025,.006)
        box('Bifrost narrow inlay',(side*.89,0,.09),(.022,3.17,.008),K,.002)
        for y in [-1.35,0,1.35]:
            box('Bridge socket',(side*1.14,y,.35),(.22,.25,.18),I,.014)
            bolt(side*1.14,y,.456,.025)
        beam('Under arch bracing',(side*.8,-1.53,-.36),(side*.8,0,-.62),.12,.15,I)
        beam('Under arch bracing',(side*.8,0,-.62),(side*.8,1.53,-.36),.12,.15,I)
    art.marker('SnapEntry',(0,-1.6,0)); art.marker('SnapExit',(0,1.6,0)); art.root['module_pitch']=3.2

def guardian_pillar():
    box('Guardian base',(0,0,.12),(1.14,1.14,.24),S,.045,.010)
    for row in range(7): box('Guardian pillar course',(0,0,.47+row*.40),(.70,.70,.38),S,.028,.007)
    box('Guardian cornice',(0,0,3.12),(.98,.93,.17),S,.026,.008)
    for z in [.62,1.23,1.84,2.45]: rune_mark((0,-.366,z),.16,K)
    for side in [-1,1]: beam('Guardian angled cap',(0,0,3.73),(side*.52,0,3.25),.12,.42,I)
    cylinder('Beacon bowl',(0,0,3.28),.24,.13,I,32)
    art.marker('BeaconOrigin',(0,0,3.46)); art.marker('FootAnchor',(0,0,0))

def shield_wall():
    box('Hall wall plinth',(0,0,.17),(3.17,.57,.34),S,.026,.005)
    for i in range(12): box('Hall vertical oak plank',((i-5.5)*.26,0,1.38),(.245,.18,2.15),W,.012,.002)
    for z in [.49,2.34]: box('Hall cross rail',(0,.04,z),(3.19,.26,.18),W,.014)
    for x in [-1.05,0,1.05]:
        cylinder('Shield oak body',(x,-.22,1.43),.48,.075,W,48,rot=(math.pi/2,0,0))
        torus('Shield iron rim',(x,-.27,1.43),.47,.025,I,(math.pi/2,0,0),48)
        for a in [0,math.pi/2]:
            beam('Shield front iron band',(x+.40*math.cos(a),-.279,1.43+.40*math.sin(a)),(x-.40*math.cos(a),-.279,1.43-.40*math.sin(a)),.035,.025,I)
        cylinder('Shield boss',(x,-.315,1.43),.13,.11,I,32,rot=(math.pi/2,0,0))
        for j in range(8):
            a=j*math.tau/8; bolt(x+.40*math.cos(a),-.306,1.43+.40*math.sin(a),.017,'Y')
    art.marker('SnapLeft',(-1.6,0,0)); art.marker('SnapRight',(1.6,0,0)); art.root['module_pitch']=3.2

def thor_shrine():
    foundation(1.21)
    box('Hammer shrine pedestal',(0,0,.70),(.95,.83,1.11),S,.05,.010)
    box('Shrine capstone',(0,0,1.32),(1.24,1.08,.15),S,.025,.006)
    box('Mjolnir iron head',(0,0,1.75),(1.08,.48,.47),I,.06)
    for x in [-.53,.53]: box('Hammer edge binding',(x,0,1.75),(.10,.53,.43),B,.02)
    cylinder('Hammer oak haft',(0,0,1.26),.065,.65,W,24)
    for z in [.98,1.11,1.24,1.37]: torus('Haft binding',(0,0,z),.069,.008,I,segments=24)
    rune_mark((0,-.43,.75),.22,R)
    art.marker('BlessingOrigin',(0,-.6,1.46)); art.marker('InteractAnchor',(0,-1.6,.5))

def skadi_shrine():
    foundation(1.20)
    box('Hunt shrine standing slab',(0,0,.97),(.84,.58,1.63),S,.045,.009)
    for side in [-1,1]:
        tube('Antler main beam',[(side*.16,0,1.65),(side*.52,.03,2.04),(side*.73,.05,2.52),(side*.89,.08,2.78)],[.075,.057,.034,.006],E,12)
        for i in range(3):
            z=2.02+i*.19; x=side*(.50+i*.10)
            tube('Antler tine',[(x,.03,z),(x+side*.22,.035,z+.25)],[.034,.004],E,10)
    beam('Crossed hunting arrow',(-.29,-.32,.60),(.26,-.32,1.52),.018,.018,E)
    beam('Crossed hunting arrow',(.29,-.32,.60),(-.26,-.32,1.52),.018,.018,E)
    rune_mark((0,-.31,1.09),.15,K)
    art.marker('BlessingOrigin',(0,-.55,1.4)); art.marker('InteractAnchor',(0,-1.6,.5))

def hel_gate():
    for side in [-1,1]:
        box('Hel gate footing',(side*1.38,0,.12),(.93,.98,.24),S,.05,.012)
        for j in range(7):
            box('Hel leaning pier',(side*(1.38-j*.025),0,.43+j*.41),(.55,.70,.39),S,.03,.009)
        rune_mark((side*1.28,-.37,1.45),.18,K)
        chain('Bound gate chain',(side*1.15,-.16,2.85),(side*.58,-.16,2.20),12,.044)
    beam('Hel arch left',(-1.23,0,3.05),(0,0,3.62),.38,.67,S)
    beam('Hel arch right',(0,0,3.62),(1.23,0,3.05),.38,.67,S)
    torus('Boundary iron seal',(0,-.38,3.21),.22,.028,I,(math.pi/2,0,0),32)
    box('Hel threshold',(0,0,.02),(2.33,.88,.14),S,.025,.006)
    art.marker('EntryAnchor',(0,-.72,.10)); art.marker('ExitAnchor',(0,.72,.10))

def offering_table():
    for x in [-.73,.73]:
        box('Altar foot',(x,0,.12),(.66,.87,.24),S,.035,.007)
        box('Altar support',(x,0,.58),(.44,.64,.83),S,.035,.008)
        rune_mark((x,-.332,.65),.13,B)
    box('Offering table slab',(0,0,1.08),(2.20,1.15,.23),S,.04,.009)
    for side in [-1,1]:
        box('Altar front iron band',(0,side*.587,1.07),(2.06,.025,.08),I,.006)
        for x in [-.83,-.42,0,.42,.83]: bolt(x,side*.612,1.07,.019,'Y')
    art.lathe('Offering bowl',[(.08,1.20),(.26,1.25),(.34,1.39),(.31,1.40),(.23,1.29),(.08,1.25),(.08,1.20)],40,I)
    for i in range(7): cylinder('Small offering coin',(-.62+(i%3)*.09,-.16+(i//3)*.08,1.21),.043,.009,B,20,bevel=.001)
    art.marker('InteractAnchor',(0,-1.0,.7)); art.marker('OfferingOrigin',(0,0,1.4))

ENTRIES=[
('odin_portal','奥丁·渡鸦神殿门廊','神话建筑','双渡鸦、独眼徽记、层叠木构山墙、分块石柱与符文铁件。','神殿入口、奖励房','',1),
('yggdrasil_altar','世界树·盘根祭坛','神话建筑','多股树根、分叉树干、环形石台、绑缚金属环与幽蓝符文。','神恩房、章节地标','',1),
('norn_well','诺伦·命运之井','神话建筑','错缝井壁、三座见证立石、横梁、悬链与下沉暗水。','命运事件、恢复房','',1),
('bifrost_bridge','彩虹桥·符光桥段','神话建筑','3.2 米桥段、窄幅冷光嵌线、护缘、连接座和底部支撑。','章节通路、虚空房','',1),
('bifrost_pillar','彩虹桥·守望门柱','神话建筑','层叠石柱、嵌入符号、尖拱金属冠与信标底座。','桥头、出口标记','',1),
('valhalla_wall','英灵殿·列盾墙段','神话建筑','3.2 米木构墙段、圆盾、铁箍、盾脐和铆接支撑。','英灵殿回廊、战斗房边界','',1),
('thor_shrine','托尔·雷锤祭坛','神话建筑','石质台座、锻铁雷锤、铜色包边、缠绕握柄与余烬符文。','雷霆神恩选择','',1),
('skadi_shrine','斯卡蒂·猎誓祭坛','神话建筑','分叉角冠、交叉猎箭、风化石台与寒光嵌线。','寒冰神恩选择','',1),
('hel_gate','赫尔·冥界界门','神话建筑','倾收石柱、折线拱顶、悬链、铁封印与冷色符文。','章节边界、精英房','',1),
('offering_table','古老·誓约供奉台','神话建筑','分体承重石座、厚石台面、铆接铁带、供奉碗与钱币。','事件房、交换奖励','',1)
]
if __name__=='__main__':
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    builders=[odin_portal,tree_altar,fate_well,bifrost_bridge,guardian_pillar,shield_wall,thor_shrine,skadi_shrine,hel_gate,offering_table]
    for entry,builder in zip(ENTRIES,builders):
        if not wanted or entry[0] in wanted: finish_entry(entry,builder)
    print('MYTHIC_BUILD_DONE',flush=True)
