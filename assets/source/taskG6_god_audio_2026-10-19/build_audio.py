from pathlib import Path
import numpy as np
import subprocess,json,wave,hashlib,shutil,math

R=Path(__file__).resolve().parent
B=R.parent/'taskB_audio_2026-10-17'
SR=44100
JOBS=json.loads((R/'records/browser_jobs.json').read_text())
CACHE={}
USED=[]
TARGET_RMS={'god_choose':-15,'path_choose':-15,'awaken':-15,'fusion':-15,'hammer_throw':-16,'hammer_catch':-17,'static_zap':-21,'spear_throw':-16.5,'rune_detonate':-18,'raven_dive':-18,'wolf_bite':-18,'wolf_breath':-18,'decoy_spawn':-17,'feather_launch':-17,'cat_pounce':-17,'chariot_charge':-16.5,'light_beam':-16,'light_spear':-16,'light_burst':-21,'light_flash':-14.5,'net_throw':-17,'net_close':-17,'wave_push':-16.5,'wave_crash':-15,'sword_hit':-16.8,'boar_charge':-16,'ice_arrow':-17,'ice_snipe':-17,'ice_shatter':-17,'heal_pickup':-17}

def decode(p):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ar',str(SR),'-ac','1','-']),dtype='<f4').astype(float)

def normalized(x):
 x=x-x.mean();pk=max(abs(x));return x/(pk+1e-12)

def trim(x):
 ix=np.flatnonzero(abs(x)>max(abs(x))*.004)
 return x[max(0,int(ix[0])-22):int(ix[-1])+1] if len(ix) else x

def filt(x,cut=5000,hp=55):
 # Zero-pad before the frequency filter to avoid wrapping the tail into the attack.
 n=len(x);pad=4096;z=np.pad(x,(pad,pad));f=np.fft.rfftfreq(len(z),1/SR);g=1/(1+(f/cut)**8)*(1-np.exp(-(f/hp)**4));return np.fft.irfft(np.fft.rfft(z)*g,n=len(z))[pad:pad+n]

def pitch(x,ratio):return np.interp(np.arange(0,len(x),ratio),np.arange(len(x)),x)
def fit(x,dur,ratio=1):
 x=pitch(x,ratio);n=round(dur*SR);return np.pad(x[:n],(0,max(0,n-len(x))))

def env(x,attack=.0007,release=.04):
 x=x.copy();a=min(round(attack*SR),len(x)//4);b=min(round(release*SR),len(x)//2)
 if a:x[:a]*=np.linspace(0,1,a)**1.2
 if b:x[-b:]*=np.linspace(1,0,b)**2
 x[0]=x[-1]=0;return x

def mix(parts,dur):
 y=np.zeros(round(dur*SR))
 for at,x,gain in parts:
  k=round(at*SR);n=min(len(x),len(y)-k)
  if n>0:y[k:k+n]+=x[:n]*gain
 return y

def control_energy(y,j):
 target=TARGET_RMS[j['id']];t=np.arange(len(y))/SR;onsets=[0.]
 if j['id'] in ['god_choose','path_choose','heal_pickup']:
  speed=j['params']['p_arp_speed'];onsets.append(((1-speed)**2*20000+32)/SR)
 def rms(z):return 20*np.log10(np.sqrt(np.mean(z*z))/(max(abs(z))+1e-15)*10**(-1/20)+1e-15)
 if rms(y)<=target:return y,{'target_rms_dbfs':target,'action':'already below target; no extra shaping','rms_before_dbfs':rms(y)}
 best=None
 for tau in np.geomspace(.001,2,240):
  pulses=np.zeros(len(y))
  for at in onsets:
   delta=t-at;attack=np.minimum(np.maximum(delta,0)/.002,1) if at else np.ones(len(y));pulse=np.where(delta>=0,np.exp(-np.maximum(delta,0)/tau)*attack,0);pulses=np.maximum(pulses,pulse)
  z=y*(.025+.975*pulses);value=rms(z);error=abs(value-target)
  if best is None or error<best[0]:best=(error,z,{'target_rms_dbfs':target,'rms_before_dbfs':rms(y),'rms_after_dbfs':value,'exponential_tau_seconds':float(tau),'body_floor':.025,'pulse_onsets_seconds':onsets,'purpose':'Reduce sustained event energy while preserving -1dBFS peak; not a subjective loudness pass'})
 return best[1],best[2]

def source(pack,name,dur,ratio=1):
 if pack=='new':p=R/'originals'/name
 else:
  ps=list((B/'originals'/pack).rglob(name+'.*'));assert len(ps)==1,(pack,name,ps);original=ps[0];p=R/'originals/reused'/pack/original.name;p.parent.mkdir(parents=True,exist_ok=True)
  if not p.exists():shutil.copy2(original,p)
 rel=str(p.relative_to(R));USED.append(rel)
 if rel not in CACHE:CACHE[rel]=normalized(trim(decode(p)))
 return env(fit(CACHE[rel],dur,ratio),release=min(.05,dur*.3))

def raw(stem):
 p=R/'originals'/f'{stem}_v01_browser.wav';USED.append(str(p.relative_to(R)));return normalized(trim(decode(p)))

def compose(j):
 id=j['id'];v=(j['variant'] or 2)-2;ratio=1+v*.025;x=raw(j['stem']);d=len(x)/SR;parts=[(0,x,1.)];desc=[];cut=5000
 def add(pack,name,dur,gain=.35,at=0,rate=ratio):parts.append((at,source(pack,name,dur,rate),gain));desc.append(f'{pack}/{name} @{at:.3f}s gain={gain} speed={rate:.3f}')
 if id=='god_choose':
  add('fantasy','item_gem_02',.16,.10);parts.append((.045,fit(x,.30,1.5),.14));d=.43;cut=5200
 elif id=='path_choose':
  add('rpg','metalClick',.08,.12);parts.append((.10,fit(x,.32,1.5),.14));d=.49;cut=5000
 elif id=='awaken':
  parts=[(0,fit(x,1.5),.9),(.015,fit(x,1.48,1.5),.38),(.04,fit(x,1.46,2),.22)];add('impact','impactSoft_heavy_000',.4,.40);add('fantasy','metal_02',.5,.11);d=1.5;cut=3400;desc.append('Browser low chord in root/fifth/octave; no choir or real instrument claim')
 elif id=='fusion':
  parts.append((.06,fit(raw('light_beam'),.7,.75),.35));parts.append((.03,fit(raw('wave_push'),.75),.20));add('fantasy','item_gem_04',.20,.08);d=.90;cut=4800;desc.append('Blend independently generated tonal light and noisy water layers')
 elif id=='hammer_throw':add('rpg','cloth4',.30,.65,rate=.85);add('fantasy','metal_01',.12,.12);cut=3300
 elif id=='hammer_catch':add('impact','impactMetal_medium_002',.17,.70,rate=.85);add('rpg','metalClick',.07,.30);cut=3900
 elif id=='static_zap':
  parts=[(0,x*np.exp(-np.arange(len(x))/SR*32),1.)];add('impact','impactGlass_light_000',.045,.07);cut=4200
 elif id=='spear_throw':add('rpg','knifeSlice',.20,.55,rate=1.4);add('fantasy','spell_01',.18,.18);cut=4900
 elif id=='rune_detonate':add('fantasy','spell_02',.21,.40,rate=1.3*ratio);add('impact','impactSoft_medium_002',.09,.22);cut=4200
 elif id=='raven_dive':
  parts=[(0,x*.2,.8)]
  for t in [0,.065,.13]:add('rpg','cloth1',.085,.65*(1-t*2),at=t,rate=1.3)
  d=.25;cut=3100;desc.append('Three short fabric/air wingbeats; no downloaded crow call used')
 elif id=='wolf_bite':add('fantasy','creature_monster_01',.18,.24,rate=1.2*ratio);add('fantasy','spell_fire_03',.18,.40);add('impact','impactPunch_medium_000',.07,.38);cut=3100
 elif id=='wolf_breath':add('fantasy','spell_fire_05',.65,.60,rate=.85);add('fantasy','creature_roar_03',.27,.13);cut=2800
 elif id=='decoy_spawn':add('fantasy','spell_fire_06',.30,.65,rate=1.2);add('rpg','cloth4',.20,.20,rate=1.4);cut=3900
 elif id=='feather_launch':
  add('rpg','drawKnife2',.16,.30,rate=1.7)
  for t in [0,.025,.05]:add('rpg','cloth4',.14,.24,at=t,rate=1.8)
  cut=4800
 elif id=='cat_pounce':add('rpg','knifeSlice2',.16,.50,rate=1.6*ratio);add('impact','impactPunch_medium_001',.08,.32);cut=4200;desc.append('Fast dry claw/air impact; no downloaded cat voice used')
 elif id=='chariot_charge':
  for t in [0,.09,.18,.27,.36]:add('rpg','footstep08',.085,.25,at=t,rate=1.4)
  add('fantasy','wood_02',.48,.14,rate=1.2);add('rpg','cloth4',.48,.35,rate=.8);cut=3300
 elif id=='light_beam':parts=[(0,x,1.),(.018,fit(x,d,2),.12)];cut=5400
 elif id=='light_spear':add('rpg','cloth1',.18,.12,rate=1.7);parts.append((.012,fit(x,d,1.5),.08));cut=5400
 elif id=='light_burst':parts=[(0,x*np.exp(-np.arange(len(x))/SR*15),1.)];add('fantasy','item_gem_02',.09,.07,rate=1.3*ratio);cut=5000
 elif id=='light_flash':parts.extend([(.012,fit(x,.7,1.5),.20),(.03,fit(x,.68,2),.13)]);add('fantasy','item_gem_04',.20,.09);d=.74;cut=5500
 elif id=='net_throw':add('rpg','clothBelt',.29,.60,rate=1.1);add('fantasy','creature_slime_02',.19,.12);cut=3100
 elif id=='net_close':add('rpg','clothBelt2',.28,.65,rate=.9);add('fantasy','creature_slime_02',.21,.18,at=.06);cut=3000
 elif id=='wave_push':add('fantasy','creature_slime_03',.60,.15,rate=.8);parts=[(at,z*(.55+.45*np.sin(np.linspace(0,np.pi,len(z)))) if at==0 else z,g) for at,z,g in parts];cut=2700
 elif id=='wave_crash':add('fantasy','creature_slime_04',.70,.18,rate=.7);add('impact','impactSoft_heavy_000',.30,.25);cut=3000
 elif id=='sword_hit':add('fantasy','blade_01',.14,.38,rate=1.5*ratio);add('impact','impactMetal_light_001',.11,.26,rate=1.2*ratio);cut=4800
 elif id=='boar_charge':
  add('new','boar_voice_CC0.ogg',.55,.65,at=.015,rate=1)
  for t,name in [(0,'footstep00'),(.105,'footstep03'),(.21,'footstep00'),(.315,'footstep03')]:add('rpg',name,.10,.32,at=t,rate=.85)
  cut=3000
 elif id=='ice_arrow':add('fantasy','item_gem_03',.15,.21,rate=1.4*ratio);add('rpg','cloth1',.11,.20,rate=1.9*ratio);cut=5200
 elif id=='ice_snipe':add('fantasy','item_gem_04',.24,.30,rate=1.35);add('rpg','cloth1',.16,.40,rate=1.4);cut=5000
 elif id=='ice_shatter':
  add('impact','impactGlass_heavy_003',.36,.65,rate=1.2)
  for t in [.03,.09,.16]:add('impact','impactGlass_light_001',.16,.18,at=t,rate=1.2+t)
  cut=5200
 elif id=='heal_pickup':add('fantasy','item_gem_01',.17,.09);parts.append((.028,fit(x,.21,1.5),.10));cut=5000
 y=mix(parts,d);y=filt(y,cut);y=trim(y)
 if j['frequent']:y=y[:round(.28*SR)]
 if id=='awaken':y=fit(y,1.5)
 y=env(y,release=min(.08,len(y)/SR*.30));y,energy=control_energy(y,j);y*=10**(-1/20)/(max(abs(y))+1e-12);pcm=np.rint(y*32767).astype('<i2');pcm[0]=pcm[-1]=0
 return pcm,desc,cut,energy

def main():
 records=[]
 for j in JOBS:
  USED.clear();pcm,desc,cut,energy=compose(j);p=R/'candidates'/j['filename']
  with wave.open(str(p),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
  records.append(dict(id=j['id'],stem=j['stem'],version='v02',variant=j['variant'],purpose=j['purpose'],frequent=j['frequent'],candidate=str(p.relative_to(R)),sources=list(dict.fromkeys(USED)),browser_record=f"records/browser_{j['stem']}_v01.json",processing=dict(recipe=desc,energy_envelope=energy,lowpass_hz=cut,highpass_hz=55,peak_target_dbfs=-1,attack_fade_ms=.7,release_fade='quadratic, min(80ms,30% of duration)',notes='Only browser-rendered audio and explicitly licensed local sample layers; no new offline oscillator synthesis.'),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),status='candidate_pending_subjective_listening'))
 (R/'records/processing_recipes.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
 bm=json.loads((B/'manifest.json').read_text());(R/'licenses/prior_taskB_sources.json').write_text(json.dumps(bm['sources'],ensure_ascii=False,indent=2))
 for pack in ['rpg','impact']:
  shutil.copy2(B/'originals'/pack/'License.txt',R/'licenses'/f'{pack}_CC0_License.txt')
 print('Built',len(records),'candidate WAVs; no runtime publication')

if __name__=='__main__':main()
