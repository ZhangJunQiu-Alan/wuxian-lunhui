from pathlib import Path
import hashlib,json,os,wave,datetime
from PIL import Image

B=Path(__file__).resolve().parents[1]
R=B.parents[2]
A=R/'assets'
CHAR=A/'sprites/characters'
WP=A/'sprites/weapons'
FX=A/'sprites/effects/weapons/swordsman'
UI=A/'sprites/ui/weapons/swordsman'
SFX=A/'audio/sfx'
FPS=dict(off_attack=16,idle=8,move=8,attack=16,hurt=12,death=8,spin=12,heavy=16,sheathe=16,iai_stance=8,iai_dash=16,thrust=16,throw=16,drink=12)
COUNTS=dict(off_attack=6,idle=4,move=6,attack=6,hurt=2,death=6,spin=4,heavy=5,sheathe=4,iai_stance=4,iai_dash=3,thrust=4,throw=4,drink=6)
ITEMS=[
 ('katana','太刀','初始','旧剑士动作条内拆出','初始武器，平时收于腰间，攻击时拔出。'),
 ('muramasa','村正','第一关','千子村正打刀，互目乱刃纹。','连杀加速，断连后进入「渴」。'),
 ('monohoshizao','物干竿','第一关','相传为佐佐木小次郎所持的三尺长刀。','只有最外三分之一的刀尖区打出全额伤害。'),
 ('duanshui','断水','第一关','越王勾践剑形制，黑菱暗纹与蓝绿剑格。','挥斩留下水壁，停留其中的敌人受伤。'),
 ('higekiri','髭切','第一关','平安太刀与毛拔形刀柄。','鬼化强化连斩，鬼气耗尽进入脱力。'),
 ('ganjiang_moye','干将莫邪','第二关','《吴越春秋》阳作龟文，阴作漫理。','雌剑可掷出插地，与雄剑之间的连线扫敌，再召回。'),
 ('zhuxian','诛仙四剑','第二关','《封神演义》通天教主的诛、戮、陷、绝四剑。','轮换四剑，分别表现厚重斩击、流血、贴符定身、斩杀。'),
 ('qinglong','青龙偃月刀','第二关','关羽的偃月刀，龙头吞口与新月阔刃。','按住旋转加速，松手重劈，可进入青龙附体。'),
 ('excalibur','湖中剑','第三关','《亚瑟王之死》湖中剑与更为珍贵的剑鞘。','收剑护体并蓄力，拔剑冲刺后整段刀痕爆开。'),
 ('riyue','日月双刀','第三关','《水浒传》扈三娘双刀，以日轮与月牙区分。','可换手，日刀横扫放日轮，月刀窄刺放月牙。'),
 ('chunyang','纯阳剑','第三关','吕洞宾道家长剑，北斗纹、太极格与酒葫芦。','饮酒叠加醉意，展示一醉剑气到三醉醉步。'),
]
GROUNDS=dict(雪地='midgard/snow_trampled.png',冥界='helheim/fog_ground.png',焦土='vigrid/scorched_01.png')
def rel(p): return os.path.relpath(p,B)
def load(p,default):
    return json.loads(p.read_text()) if p.is_file() else default
def asset(p):
    out=dict(file=rel(p),path=str(p.relative_to(R)),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
    if p.suffix=='.png':
        out['size']=Image.open(p).size
    if p.suffix=='.wav':
        with wave.open(str(p)) as f: out['seconds']=round(f.getnframes()/f.getframerate(),3)
    return out
def publish_katana():
    path=WP/'manifest.json'
    with path.open('x') as f:
        json.dump([dict(id='katana', **{'class':'swordsman'},idle_hold='stow',
            main=dict(file='swordsman/katana.png',grip=[3,2],tip=[20,1],base_deg=0),
            stow='hip',stow_file='swordsman/katana_stow.png',stow_grip=[5,3],stow_base_deg=0,
            icon='swordsman/katana_icon.png')],f,indent=2)
def build():
    weapons=load(WP/'manifest.json',[])
    sockets=load(CHAR/'swordsman_sockets.json',{'actions':{}})
    effects=load(FX/'manifest.json',[])
    audio=load(B/'records/audio.json',[])
    ui=load(B/'records/ui.json',[])
    reports=load(B/'records/qa.json',{})
    data=dict(updated=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).strftime('%Y-%m-%d %H:%M SGT'),
        items=[],weapons={v['id']:v for v in weapons},actions={},files={},effects=effects,audio=audio,ui=ui,
        sockets=sockets['actions'],qa=reports,grounds={k:rel(A/'sprites/ground'/v) for k,v in GROUNDS.items()})
    def add(p):
        if p.is_file(): data['files'][p.name if p.suffix=='.wav' else p.stem]=asset(p)
    for act,frames in sockets['actions'].items():
        p=CHAR/f'swordsman_bare_{act}.png'
        if not p.is_file(): continue
        add(p)
        props=dict(file=rel(p),fps=FPS[act],frames=len(frames))
        if (CHAR/f'swordsman_{act}.png').is_file():
            props.update(original=rel(CHAR/f'swordsman_{act}.png'),diff=f'previews/bare_diff_{act}.png')
        data['actions'][act]=props
    for i,n,g,lore,rule in ITEMS:
        item=dict(id=i,name=n,group=g,lore=lore,rule=rule,concept=f'originals/{i}.png' if (B/'originals'/f'{i}.png').is_file() else None)
        for key,dir,ext in [('video','previews','.webm'),('shot','previews','.png')]:
            path=B/dir/f'{i}{ext}'
            if path.is_file(): item[key]=rel(path)
        data['items'].append(item)
    for folder in (WP/'swordsman',FX,UI):
        for p in sorted(folder.glob('*.png')): add(p)
    for e in effects:
        if e.get('reused'): add(A/e['file'])
        if e['id'] in data['files']: data['files'][e['id']]['frames']=e['frames']
    for e in audio: add(SFX/f"{e['id']}.wav")
    for weapon in weapons:
        for v in weapon.get('legacy_layers',{}).values():
            data['files'][Path(v['file']).stem]['frames']=v['frames']
    for a,e in data['actions'].items(): data['files'][f'swordsman_bare_{a}']['frames']=e['frames']
    data['waistFrames']=sockets.get('waist_frames',{})
    data['waistBodies']={}
    for act,name in sockets.get('waist_bodies',{}).items():
        p=A/name
        add(p)
        data['files'][p.stem]['frames']=data['actions'][act]['frames']
        data['waistBodies'][act]=rel(p)
    data['carryVisual']=load(B/'records/carry-visual.json',{})
    data['vfxVisual']=load(B/'records/vfx-visual.json',{})
    data['weaponBase']=rel(WP)
    data['assetBase']=rel(A)
    data['stage']=load(B/'records/stage.json',{'num':1,'text':'空手分层、挂点与太刀首轮合成'})
    (B/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    template=(B/'records/page.html').read_text()
    temp=B/'index.tmp'
    temp.write_text(template.replace('/*INLINE_DATA*/',json.dumps(data,ensure_ascii=False).replace('</','<\\/')))
    temp.replace(B/'index.html')
if __name__=='__main__': build()
