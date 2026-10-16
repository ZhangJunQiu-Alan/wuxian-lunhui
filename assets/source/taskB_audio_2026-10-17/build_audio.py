from pathlib import Path
import numpy as np
import subprocess, json, wave, hashlib, re, math
R=Path(__file__).resolve().parent
SR=44100
OUT=R/'candidates/sfx';OUT.mkdir(parents=True,exist_ok=True)
CACHE={}; USED=[]; ITEMS=[]
def decode(p,channels=1):
    return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ar',str(SR),'-ac',str(channels),'-']),dtype='<f4').copy().reshape(-1,channels).squeeze()
def src(pack,name):
    paths=list((R/'originals'/pack).rglob(name+'.*'))
    assert len(paths)==1,(pack,name,paths)
    p=paths[0];rel=str(p.relative_to(R))
    if rel not in USED:USED.append(rel)
    if rel not in CACHE:
        x=decode(p).astype(np.float64);x-=x.mean();pk=np.max(np.abs(x));active=np.flatnonzero(np.abs(x)>pk*.006)
        x=x[max(0,int(active[0])-22):int(active[-1])+1] if len(active) else x
        CACHE[rel]=x/(np.max(np.abs(x))+1e-12)
    return CACHE[rel].copy()
def filt(x,cut=6000,hp=45):
    n=len(x);f=np.fft.rfftfreq(n,1/SR);g=1/(1+(f/cut)**8);g*=1-np.exp(-(f/hp)**4)
    return np.fft.irfft(np.fft.rfft(x)*g,n=n)
def pitch(x,ratio=1):return np.interp(np.arange(0,len(x),ratio),np.arange(len(x)),x)
def fit(x,dur,ratio=1):
    x=pitch(x,ratio);n=round(dur*SR);x=x[:n];return np.pad(x,(0,max(0,n-len(x))))
def env(x,attack=.0007,release=.05):
    x=x.copy();a=min(round(attack*SR),len(x)//3);b=min(round(release*SR),len(x)//2)
    if a:x[:a]*=np.linspace(0,1,a)
    if b:x[-b:]*=np.linspace(1,0,b)**1.6
    x[0]=0;x[-1]=0;return x
def mix(*parts,dur=None):
    n=round(dur*SR) if dur else max(round(t*SR)+len(x) for t,x,g in parts);y=np.zeros(n)
    for t,x,g in parts:
        k=round(t*SR);count=min(len(x),n-k)
        if count>0:y[k:k+count]+=x[:count]*g
    return y
def echo(x,tail=.3,gain=.15):
    y=np.pad(x,(0,round(tail*SR)))
    for d,g in [(.037,gain),(.081,gain*.7),(.149,gain*.4),(.233,gain*.2)]:
        k=round(d*SR);n=min(len(x),len(y)-k);y[k:k+n]+=x[:n]*g
    return y
def tones(notes,dur=.8,step=.15):
    parts=[]
    for i,f in enumerate(notes):
        t=np.arange(round((dur-i*step)*SR))/SR
        x=(np.sin(2*np.pi*f*t)+.24*np.sin(2*np.pi*f*2.01*t)+.08*np.sin(2*np.pi*f*3.96*t))*np.exp(-t*9)
        parts.append((i*step,env(x,.002,.06),1))
    return mix(*parts,dur=dur)
def drum(f=72,d=.7):
    t=np.arange(round(d*SR))/SR;rng=np.random.default_rng(round(f*100))
    phase=2*np.pi*(f*t+f*.6*.018*(1-np.exp(-t/.018)))
    return env(np.sin(phase)*np.exp(-t*9)+filt(rng.normal(size=len(t)),1200,130)*np.exp(-t*45)*.25,.0005,.08)
def wind(d=.3,seed=1):
    rng=np.random.default_rng(seed);t=np.arange(round(d*SR))/SR
    return env(filt(rng.normal(size=len(t)),4200,300)*np.exp(-t*8),.001,.06)
def save(name,x,desc,frequent=False,cut=6000,release=.045):
    global USED
    source_paths=USED[:];USED=[]
    x=filt(x,cut);pk=np.max(np.abs(x));idx=np.flatnonzero(np.abs(x)>pk*.003)
    if len(idx):x=x[max(0,int(idx[0])-20):]
    x=env(x,release=release);x*=10**(-1/20)/(np.max(np.abs(x))+1e-12)
    pcm=np.round(x*32767).astype('<i2');pcm[0]=pcm[-1]=0
    p=OUT/(name+'.wav')
    with wave.open(str(p),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
    ITEMS.append({'id':name,'kind':'sfx','file':str(p.relative_to(R)),'sources':source_paths,'recipe':desc,'frequent':frequent,'lowpass_hz':cut,'status':'candidate_pending_listening'})
    print(name,round(len(x)/SR,3),flush=True)

def main():
    save('ui_click',fit(src('interface','click_003'),.075),'界面机械轻触，裁短，低通',cut=4000,release=.02)
    save('ui_open',fit(src('rpg','bookOpen'),.22),'书页展开与布料感',cut=4500)
    save('level_up',echo(tones([523.25,659.25,783.99],.85,.14),.15),'原创上行三音冰晶提示，短混响',cut=6500)
    save('card_pick',mix((0,fit(src('rpg','metalClick'),.10),.45),(0,tones([659.25,987.77],.32,.06),.18),dur=.32),'锁扣确认与原创双音',cut=5000)
    save('ult_ready',tones([220,440],.65,.24),'原创间隔双音，与升级三音节奏区分',cut=5000)
    save('dash',mix((0,fit(src('rpg','cloth4'),.20,1.3),.7),(0,wind(.20,7),.2),dur=.20),'布料掠过与短风声',cut=5000)
    save('player_hurt',fit(src('impact','impactPunch_medium_000'),.22),'物理闷击，无人声',cut=2200)
    save('player_death',mix((0,fit(src('impact','impactSoft_heavy_000'),.7,.72),.6),(.03,drum(48,2),.5),(.12,fit(src('impact','impactWood_heavy_001'),.5,.8),.2),dur=2),'沉重倒地，低鼓余音，无人声',cut=2800,release=.15)
    save('revive',echo(mix((0,tones([392,587.33,783.99],.9,.07),.6),(0,wind(.5,2),.15),dur=.9),.3),'原创明亮和声与扩散气流',cut=6500)
    for i in range(3):
        save(f'pickup_xp_{i+1:02}',fit(src('fantasy','item_gem_01'),.14,1+i*.035),'同源水晶样本的小幅变调，短尾，抑制高频',True,4800,.055)
        save(f'katana_slash_{i+1:02}',fit(src('fantasy','blade_02'),.23,1.03+i*.04),'同源刀刃样本的小幅变调，干净短促破空',True,5200,.055)
        save(f'blades_slash_{i+1:02}',fit(src('rpg','knifeSlice'),.15,1.45+i*.07),'刀片破空变速，快于太刀',True,5600,.035)
        save(f'lightning_{i+1:02}',mix((0,fit(src('impact','impactGlass_medium_000'),.22,1.12+i*.03),.5),(0,wind(.18,20+i),.15),(0,drum(105+i*7,.22),.25),dur=.22),'玻璃裂纹、短电弧噪声和低频雷击',True,6000,.06)
        save(f'enemy_hit_{i+1:02}',fit(src('impact',f'impactPunch_medium_{i:03}'),.12,1.15),'三种独立闷击，短干低通',True,2800,.035)
        save(f'enemy_death_{i+1:02}',mix((0,fit(src('fantasy','stones_03'),.24,1.14+i*.04),.6),(.01,fit(src('impact','impactGlass_light_000'),.22,1+i*.03),.2),dur=.25),'同源石块与冰裂小幅变调，短衰减',True,4800,.065)
    save('chest_open',mix((0,fit(src('rpg','creak1'),.55,1.1),.55),(.07,fit(src('fantasy','wood_02'),.3),.18),(.25,tones([392,587.33],.6,.08),.15),dur=.9),'木箱开启、木件活动与原创晶光',cut=5500)
    save('revolver_reload',mix((0,fit(src('rpg','metalLatch'),.18),.7),(.11,fit(src('rpg','metalClick'),.1,1.12),.5),(.24,fit(src('rpg','metalLatch'),.15,.88),.6),dur=.4),'机械锁扣临时候选；待真实左轮转轮录音替换',cut=5000)
    save('nova_cast',echo(mix((0,fit(src('fantasy','spell_02'),.65,.8),.7),(0,wind(.65,4),.35),(0,drum(65,.65),.25),dur=.65),.25),'低频魔法能量与冰冷扩散',cut=5500)
    save('rune_bolt',mix((0,fit(src('fantasy','spell_01'),.22,1.4),.5),(0,wind(.2,5),.2),dur=.22),'魔法样本变速与轻风',cut=5000)
    save('feather_hit',fit(src('rpg','drawKnife2'),.19,1.55),'轻金属划动',cut=5000)
    save('fire_burn',fit(src('fantasy','spell_fire_03'),.24,1.2),'火焰颗粒裁短，抑制尖锐高频',cut=3200)
    save('ult_swordsman',mix((0,fit(src('fantasy','blade_02'),.65,.55),.7),(0,wind(1.5,10),.5),(.015,drum(48,1.5),.8),(.1,fit(src('impact','impactMetal_medium_002'),1.3,.65),.2),dur=1.5),'厚重低频破空、刀锋与空间余音',cut=5000,release=.18)
    save('ult_assassin',mix((0,drum(58,.9),.8),(.24,drum(70,.7),.5),(0,wind(1.4,18),.35),dur=1.4),'原创低皮鼓双击与阴冷风声',cut=3800,release=.18)
    save('ult_mage',echo(mix((0,fit(src('impact','impactMining_001'),.8,.65),.65),(.02,fit(src('fantasy','stones_03'),1,.65),.4),(0,drum(39,1.4),.85),dur=1.4),.4),'重石落地、岩屑与低频轰鸣',cut=4000,release=.2)
    save('big_death',mix((0,fit(src('impact','impactSoft_heavy_001'),.5,.72),.65),(.03,fit(src('fantasy','wood_03'),.7,.7),.35),(0,drum(44,1.1),.4),dur=1.1),'大型躯体倒地与木石碎屑',cut=3200,release=.15)
    save('ice_shot',mix((0,fit(src('fantasy','item_gem_04'),.22,1.2),.45),(0,wind(.22,11),.5),dur=.22),'水晶颗粒与短风',cut=5800)
    save('arrow_shot',mix((0,fit(src('rpg','cloth1'),.16,1.8),.5),(0,tones([150],.16),.12),dur=.16),'紧短布料弓弦与原创低拨弦',cut=4500)
    save('golem_split',mix((0,fit(src('fantasy','stones_01'),.65,1.2),.55),(.04,fit(src('fantasy','metal_01'),.5,1.15),.35),(.11,fit(src('fantasy','stones_04'),.5,1.3),.25),dur=.7),'硬片错落散开',cut=5200)
    save('boss_windup',mix((0,tones([110,103.83],.55,.16),.5),(0,wind(.55,12)[::-1],.3),dur=.55),'原创不稳定低音与逆向风，短危险提示',cut=4000)
    save('boss_slam',mix((0,fit(src('impact','impactMining_002'),.7,.7),.6),(.02,fit(src('fantasy','stones_04'),.7,.8),.3),(0,drum(36,1.3),.7),dur=1.3),'砸地、碎石与低频震动',cut=4000,release=.18)
    save('boss_block',mix((0,fit(src('impact','impactPlate_heavy_002'),.55,.85),.6),(0,fit(src('impact','impactGlass_heavy_001'),.5,.9),.4),dur=.6),'金属盾与冰层碰撞',cut=5400)
    save('ice_pillar',mix((0,fit(src('impact','impactGlass_heavy_003'),.65,.8),.6),(.05,fit(src('fantasy','stones_02'),.65,.9),.4),(0,drum(58,.8),.25),dur=.8),'冰层破裂与破土石屑',cut=5400)
    save('boss_death',mix((0,fit(src('impact','impactMining_003'),.9,.6),.7),(.15,fit(src('fantasy','stones_03'),1.4,.55),.5),(.48,fit(src('fantasy','wood_05'),1.3,.7),.25),(0,drum(34,3),.8),dur=3),'连续岩木倒塌与三秒低频衰减',cut=4000,release=.3)
    save('quest_start',echo(tones([196,293.66],.65,.18),.2),'原创空五度神秘提示',cut=5000)
    save('quest_fail',tones([196,174.61,146.83],.9,.22),'原创低沉下行三音',cut=3800)
    # Horn phrase boundaries are candidates selected by amplitude, not a claim of musical audition.
    h=src('music','war_horns');n=round(2*SR);energy=np.convolve(h[::441]**2,np.ones(200),mode='valid');start=int(np.argmax(energy))*441
    horn=h[start:start+n]
    save('boss_warning',fit(horn,2,.8),'CC0号角最强能量段，降调、两秒衰减；待试听段落',cut=3500,release=.3)
    src('music','war_horns')
    save('quest_done',fit(horn,.85,1.35),'同一号角的短高音变体；待试听旋律完整性',cut=4200,release=.14)
    # Full original phrases remain in originals; these are documented gameplay edits.
    global ITEMS
    ITEMS=[r for r in ITEMS if r['id']!='revolver_reload']
    save('revolver_reload',src('freesound','722902__tkane0512__revolver-reload-break-2'),'CC0真实左轮开膛、快速装弹与闭合录音，完整保留顺序',cut=5000,release=.07)
    save('boss_howl',src('freesound','398430__naturestemper__wolf-howl'),'作者自制狼嚎，保留整句，去低频直流与过亮高频；未伪称野狼实录',cut=5500,release=.1)
    for i in range(3):
        x=src('firearm','V_27P');idx=np.flatnonzero(abs(x)>max(abs(x))*.28);start=max(0,int(idx[0])-44);shot=x[start:start+round(.25*SR)]
        save(f'revolver_shot_{i+1:02}',fit(shot,.25,.97+i*.03),'CC0 .38左轮第一发近距离录音，保留起爆、裁短尾音，小幅变调',True,4800,.07)
    x=src('firearm','V_27P');idx=np.flatnonzero(abs(x)>max(abs(x))*.28);start=max(0,int(idx[0])-44);shot=env(fit(x[start:],.25),release=.07)
    t=np.arange(round(.9*SR))/SR
    twang=(np.sin(2*np.pi*(146.83*t+2.8*(1-np.exp(-t*8))))+.36*np.sin(2*np.pi*293.66*t)+.14*np.sin(2*np.pi*440.49*t))*np.exp(-t*6)
    save('ult_gunslinger',mix(*[(i*.12,shot,.55) for i in range(5)],(.68,env(twang,.001,.12),.35),dur=1.6),'同源左轮五连发与原创低拨弦滑音收尾，西部音色目标待试听',cut=5000,release=.15)
    (R/'records/sfx_recipes.json').write_text(json.dumps(ITEMS,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
