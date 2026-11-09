from pathlib import Path
import math, wave, json
import numpy as np

B=Path(__file__).resolve().parents[1]
SFX=B.parents[2]/'assets/audio/sfx'
SR=44100
TAU=math.tau
rng=np.random.default_rng(41383)

def time(d):
    return np.arange(round(d*SR))/SR
def env(t,d,attack=.003,release=.04):
    return np.clip(t/attack,0,1)*np.clip((d-t)/release,0,1)
def tone(d,f=340,end=None,decay=5,vibrato=0,index=0):
    t=time(d);end=f if end is None else end
    phase=TAU*(f*t+(end-f)*t*t/(2*d))
    return np.sin(phase+index*np.sin(phase*1.68)+vibrato*np.sin(TAU*11*t))*np.exp(-decay*t/d)*env(t,d)
def noise(d,lo,hi,attack=.008,release=.05,decay=1.2,reverse=False):
    t=time(d);x=rng.normal(0,1,len(t)); spec=np.fft.rfft(x);f=np.fft.rfftfreq(len(x),1/SR)
    spec*=np.clip(f/max(lo,1),0,1)**3/(1+(f/hi)**6)
    x=np.fft.irfft(spec,n=len(t));x/=np.max(np.abs(x))
    e=env(t,d,attack,release)*np.exp(-decay*t/d)
    return (x*e)[::-1] if reverse else x*e
def mix(d,*parts):
    out=np.zeros(round(d*SR))
    for at,gain,x in parts:
        j=round(at*SR);l=min(len(out)-j,len(x))
        if l>0:out[j:j+l]+=gain*x[:l]
    return out
def metal(d,f,bright=1):
    return mix(d,(0,.49,tone(d,f,decay=3)),(0,.26,tone(d,2.13*f,decay=5)),(.002,.15*bright,tone(d,3.71*f,decay=6)),
        (0,.12*bright,noise(min(d,.09),1800,5800,decay=8)))
def spin(d):
    t=time(d); f=np.fft.rfftfreq(len(t),1/SR)
    spec=np.fft.rfft(rng.standard_normal(len(t)));spec*=np.clip(f/80,0,1)**4/(1+(f/1000)**5)
    wind=np.fft.irfft(spec,n=len(t))
    phase=t/d*TAU
    return (.35+.65*(.5+.5*np.cos(phase*4))**2)*wind + .033*np.cos(phase*4)*np.sin(phase*61)
def ring(d,f1,f2):
    return mix(d,(0,.5,metal(d,f1,.55)),(.023,.42,metal(d-.023,f2,.45)))

spec=[]
def add(id,wp,label,x,loop=False,offset=0):
    spec.append((id,wp,label,x,loop,offset))
add('muramasa_thirst','muramasa','连杀断开 · 低心跳',mix(.42,(0,.83,tone(.15,82,49,4,index=.18)),(.13,.55,tone(.2,64,43,5)),(0,.24,noise(.24,40,140,decay=4))))
add('monohoshizao_tip','monohoshizao','刀尖命中 · 清亮高音',mix(.28,(0,.7,metal(.27,1440)),(.009,.32,tone(.11,2730,1810,7))))
add('duanshui_scar','duanshui','水壁留下 · 短促劈水',mix(.43,(0,.76,noise(.27,300,3700,.024,.1,1.2)),(.09,.23,tone(.12,504,203,4,index=.5)),(.14,.17,tone(.17,295,144,3,index=.35)),(.19,.28,noise(.2,750,5400,.006,.1,2))))
add('higekiri_oni_on','higekiri','鬼化 · 低吼与刀鸣',mix(.81,(0,.64,tone(.7,71,38,2,vibrato=.7,index=2.2)),(.04,.48,noise(.62,100,1050,.085,.23)),(.17,.36,metal(.61,873,.67))))
add('higekiri_oni_off','higekiri','主动收手 · 短收刀',mix(.24,(0,.45,noise(.13,1100,4900,.015,.027,2)),(.096,.7,metal(.13,428,.35)),(.112,.25,tone(.08,166,72,6))))
add('higekiri_exhaust','higekiri','鬼气耗尽 · 喘息',mix(.84,(0,.64,noise(.52,185,1050,.16,.12,.7)),(.19,.29,tone(.37,83,71,1.4,vibrato=.52,index=.65)),(.47,.38,noise(.32,290,1700,.045,.12,2))))
add('moye_throw','ganjiang_moye','掷出莫邪 · 破风',mix(.4,(0,.74,noise(.32,260,3900,.014,.06,1.2,True)),(.12,.29,tone(.24,915,338,2,index=.4))))
add('moye_return','ganjiang_moye','飞回入手 · 金属嗡鸣',mix(.62,(0,.41,tone(.51,261,1087,.65,vibrato=.2,index=.38)),(.08,.28,noise(.42,400,2800,.06,.07,2,True)),(.46,.56,metal(.15,593))))
add('ganjiang_link','ganjiang_moye','剑气命中 · 轻双音',ring(.24,588,882),offset=-7)
add('zhuxian_xian','zhuxian','符箓贴上 · 封印',mix(.45,(0,.52,noise(.105,750,5000,.003,.05,3)),(.052,.64,tone(.38,148,86,2.5,index=.68)),(.066,.16,tone(.21,305,170,5))))
add('zhuxian_jue','zhuxian','处决 · 刀斩与墨溅',mix(.43,(0,.66,noise(.16,460,5100,.004,.052,2.5)),(.01,.4,metal(.19,700,.42)),(.07,.44,noise(.28,110,1450,.012,.1,2)),(.098,.2,tone(.19,160,49,6))))
add('qinglong_spin_loop','qinglong','偃月风暴 · 无缝循环',spin(1.2),loop=True,offset=-4)
add('qinglong_heavy','qinglong','松手重劈 · 落地回响',mix(.92,(0,.47,noise(.23,180,3300,.035,.07,1.2)),(.17,.76,tone(.49,85,39,4,index=.46)),(.19,.55,noise(.43,55,1100,.004,.18,3)),(.31,.3,tone(.5,56,31,3)),(.42,.13,noise(.45,95,480,.02,.18,4))))
add('qinglong_avatar','qinglong','青龙附体 · 龙吟',mix(1.37,(0,.78,tone(1.26,105,64,1.25,vibrato=.65,index=1.73)),(.05,.53,noise(1.22,110,1650,.22,.25,.95)),(.18,.2,tone(1.1,204,95,2.4,vibrato=.8,index=.8)),(.39,.15,metal(.9,441,.48))))
add('excalibur_sheathe','excalibur','收剑 · 鞘口咔哒',mix(.42,(0,.55,noise(.27,590,2500,.015,.06,.65)),(.086,.27,tone(.19,435,277,2,index=.6)),(.226,.72,metal(.18,547,.47)),(.24,.22,noise(.11,330,2600,decay=6))))
add('excalibur_charge_full','excalibur','蓄满 · 明亮共鸣',mix(.82,(0,.55,metal(.78,659,.45)),(.044,.41,metal(.74,988,.35)),(.13,.28,tone(.64,1318,decay=3)),(.18,.21,tone(.54,1976,decay=4))))
add('excalibur_iai','excalibur','拔剑 · 长音接爆斩',mix(.78,(0,.47,tone(.45,1230,511,2,index=.48)),(0,.36,noise(.31,640,6100,.016,.1,1.5)),(.31,.65,noise(.38,190,6000,.006,.13,2.1)),(.316,.5,tone(.38,176,48,4.3,index=.39)),(.33,.25,metal(.37,1046,.52))))
add('riyue_swap','riyue','日月换手 · 双刀相击',mix(.49,(0,.63,metal(.39,832)),(.054,.48,metal(.42,1140)),(.016,.27,noise(.14,430,2900,decay=3))))
add('chunyang_drink','chunyang','饮酒 · 咕嘟',mix(.53,(0,.27,noise(.38,120,1080,.024,.08,.8)),(.065,.64,tone(.16,187,342,1.6,index=.75)),(.15,.72,tone(.24,234,109,2.1,index=.82)),(.25,.31,tone(.18,177,239,3.5,index=.48))))
def rms(x):
    n=min(len(x),int(.1*SR)); stride=n//4
    return max(float(np.sqrt(np.mean(x[i:i+n]**2))) for i in range(0,max(1,len(x)-n+1),stride))
def main():
    with wave.open(str(SFX/'katana_slash_01.wav')) as w:
        ref=np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(float)/32768
    target=rms(ref)
    rows=[]
    for id,wp,label,x,loop,offset in spec:
        x=x-np.mean(x) if loop else x*env(time(len(x)/SR),len(x)/SR,.001,.006)
        x=x*min(target*10**(offset/20)/max(.001,rms(x)),.89/np.max(np.abs(x)))
        path=SFX/f'{id}.wav'
        payload=np.round(x*32767).astype('<i2').tobytes()
        with path.open('xb') as f:
            with wave.open(f,'wb') as w:
                w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(payload)
        (B/'approved'/path.name).write_bytes(path.read_bytes())
        rows.append(dict(id=id,weapon=wp,label=label,loop=loop,seconds=round(len(x)/SR,3),rms_dbfs=round(20*math.log10(rms(x)),1)))
    (B/'records/audio.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    print(len(rows),'WAV',round(20*math.log10(target),1),'dBFS reference RMS')
if __name__=='__main__':main()
