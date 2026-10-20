from pathlib import Path
import numpy as np
import subprocess,json,re,wave,hashlib,shutil
B=Path(__file__).resolve().parent;ROOT=B.parents[2];SR=44100
sources=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def decode(p,channels=1):return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ar',str(SR),'-ac',str(channels),'-f','f32le','-']),'<f4').copy().reshape(-1,channels).astype(float)
def src(pack,name):
 ps=list((ROOT/'assets/source/taskB_audio_2026-10-17/originals'/pack).rglob(name+'.*'));assert len(ps)==1,ps
 p=ps[0];target=B/'originals'/pack/p.name;target.parent.mkdir(parents=True,exist_ok=True)
 if not target.exists():shutil.copyfile(p,target)
 sources.append(dict(path=str(p.relative_to(ROOT)),local=str(target.relative_to(B)),sha256=sha(p),license='CC0-1.0',author='Kenney' if pack in ['rpg','impact'] else 'rubberduck',page={'rpg':'https://kenney.nl/assets/rpg-audio','impact':'https://kenney.nl/assets/impact-sounds','fantasy':'https://opengameart.org/content/80-cc0-rpg-sfx'}[pack]))
 x=decode(p)[:,0];active=np.flatnonzero(abs(x)>max(abs(x))*.004);x=x[max(0,active[0]-44):active[-1]+1];x-=x.mean();return x/(max(abs(x))+1e-12)
def clip(x,dur,rate=1):
 x=np.interp(np.arange(0,len(x),rate),np.arange(len(x)),x);n=round(dur*SR);return np.pad(x[:n],(0,max(0,n-len(x))))
def filt(x,low,high):
 n=len(x);z=np.pad(x,(4096,4096));f=np.fft.rfftfreq(len(z),1/SR);g=(1-np.exp(-(f/low)**4))/(1+(f/high)**8);return np.fft.irfft(np.fft.rfft(z)*g,n=len(z))[4096:4096+n]
def envelope(x):
 x=x.copy();n=len(x);a=min(44,n//8);b=min(round(.055*SR),n//3);x[:a]*=np.linspace(0,1,a);x[-b:]*=np.linspace(1,0,b)**2;x[0]=x[-1]=0;return x
def wav(p,x):
 if x.ndim==1:x=x[:,None]
 with wave.open(str(p),'wb') as w:w.setnchannels(x.shape[1]);w.setsampwidth(2);w.setframerate(SR);w.writeframes(np.round(np.clip(x,-1,1)*32767).astype('<i2').tobytes())
def mix(dur,layers):
 y=np.zeros(round(dur*SR))
 for x,g,at in layers:
  i=round(at*SR);n=min(len(x),len(y)-i);y[i:i+n]+=x[:n]*g
 return y
recipes=[('jormungandr_hiss',.58,[(src('fantasy','spell_fire_05'),.75,0,.58,1.18),(src('rpg','cloth4'),.20,0,.25,1.20)],1100,6500,'dry high air hiss; no fire impact or wolf call'),('fenrir_swallow',.66,[(src('fantasy','creature_monster_01'),.55,0,.56,.73),(src('impact','impactSoft_heavy_000'),.85,.025,.24,.80),(src('rpg','cloth4'),.24,.015,.25,.60)],55,2100,'low organic contraction and damp impact, no long howl'),('gleipnir_tension',.72,[(src('rpg','cloth4'),.75,0,.54,.68),(src('fantasy','metal_02'),.18,.01,.60,1.12),(src('fantasy','spell_02'),.15,.08,.60,1.25)],160,4300,'braided tension with restrained magic resonance; no huge chain crash'),('surtr_gate',.90,[(src('fantasy','spell_fire_05'),.65,0,.90,.73),(src('fantasy','creature_roar_03'),.13,.01,.70,.55),(src('fantasy','spell_02'),.30,.045,.80,.72)],65,3600,'fire surge and low portal resonance; one cast, not persistent loop')]
items=[]
for name,dur,layers,low,high,desc in recipes:
 parts=[(clip(x,d,rate),gain,at) for x,gain,at,d,rate in layers];raw=mix(dur,parts);wav(B/f'originals/{name}_layer_mix.wav',raw*.7/(max(abs(raw))+1e-12));y=envelope(filt(raw,low,high));y=np.tanh(y/(max(abs(y))+1e-12)*3) if name=='gleipnir_tension' else y;t=np.arange(len(y))/SR;y*=.035+.965*np.exp(-t/(.20 if name=='surtr_gate' else .14));y=envelope(y);y*=10**(-1/20)/(max(abs(y))+1e-12);p=B/f'candidates/{name}.wav';wav(p,y);z=decode(p)[:,0];nz=np.flatnonzero(abs(z)>10**(-60/20));items.append(dict(id=name,file=str(p.relative_to(B)),duration_s=len(z)/SR,sample_rate=SR,channels=1,encoding='PCM16',peak_dbfs=float(20*np.log10(max(abs(z)))),rms_dbfs=float(20*np.log10(np.sqrt(np.mean(z*z)))),onset_ms=float(nz[0]/SR*1000),last_sample=float(z[-1]),first_sample=float(z[0]),fullscale_samples=int(np.count_nonzero(abs(z)>=1)),lowpass_hz=high,highpass_hz=low,identity=desc,loop=False,frequency_class='boss event; not highfrequency automatic attack',sha256=sha(p),listening='pending',game_acceptance='not_tested'))
source=B/'originals/cynicbattleloop_0.ogg';x=decode(source,2);wav(B/'records/music_working.wav',x)
af='highpass=f=35,lowpass=f=10500';mout=subprocess.run(['ffmpeg','-hide_banner','-i',str(B/'records/music_working.wav'),'-af',af+',loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json','-f','null','-'],capture_output=True).stderr.decode();m=json.loads(re.findall(r'\{[^{}]+\}',mout)[-1]);flt=af+f",loudnorm=I=-16:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true"
out=B/'candidates/vigrid.ogg';subprocess.run(['ffmpeg','-v','error','-y','-i',str(B/'records/music_working.wav'),'-af',flt,'-ar',str(SR),'-ac','2','-c:a','vorbis','-strict','-2','-q:a','6',str(out)],check=True)
z=decode(out,2);r=subprocess.run(['ffmpeg','-hide_banner','-i',str(out),'-af','loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json','-f','null','-'],capture_output=True).stderr.decode();measure=json.loads(re.findall(r'\{[^{}]+\}',r)[-1]);music=dict(id='vigrid',file='candidates/vigrid.ogg',duration_s=len(z)/SR,sample_rate=SR,channels=2,codec='vorbis',loudness_lufs=float(measure['input_i']),true_peak_dbtp=float(measure['input_tp']),sha256=sha(out),seam_sample_delta=np.abs(z[-1]-z[0]).tolist(),normal_diff_p999=np.percentile(abs(np.diff(z,axis=0)),99.9,axis=0).tolist(),processing='whole source loop, no phrase deletion; common35Hz/10.5kHz bus; two-pass loudness; no repair at repeat points',musical_three_loop_listening='pending',game_acceptance='not_tested');wav(B/'previews/vigrid_three_loops.wav',np.tile(z,(3,1)))
sequence=[]
for r in items:sequence.extend([decode(B/r['file'])[:,0],np.zeros(round(SR*.45))])
wav(B/'previews/four_sfx_sequence.wav',np.concatenate(sequence));
(B/'records/sfx_recipes.json').write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n');(B/'records/used_sources.json').write_text(json.dumps(sources,ensure_ascii=False,indent=2)+'\n');(B/'records/music_measurements.json').write_text(json.dumps(music,ensure_ascii=False,indent=2)+'\n');(B/'records/music_working.wav').unlink();print(json.dumps({'sfx':[(r['id'],r['duration_s'],r['onset_ms']) for r in items],'music':music},ensure_ascii=False))
