from pathlib import Path
import numpy as np
import subprocess,json,re,hashlib,wave
R=Path(__file__).resolve().parent
SR=44100;OUT=R/'candidates/music';OUT.mkdir(parents=True,exist_ok=True)
def decode(p):return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ar',str(SR),'-ac','2','-']),'<f4').copy().reshape(-1,2)
def wav(p,x):
    with wave.open(str(p),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes(np.round(np.clip(x,-1,1)*32767).astype('<i2').tobytes())
def analyze(p):
    v=subprocess.run(['ffmpeg','-hide_banner','-i',str(p),'-af','loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json','-f','null','-'],capture_output=True).stderr.decode()
    return json.loads(re.findall(r'\{[^{}]+\}',v)[-1])
def crossloop(x,w=.5):
    n=round(w*SR);n=min(n,len(x)//8);a=np.linspace(0,1,n)[:,None]
    y=x[n:].copy();y[-n:]=x[-n:]*(1-a)+x[:n]*a
    return y
spec=[('hub','dream_ambience.wav',1,True,0,0),('midgard','opening.wav',2,True,0,0),('boss','boss_music.wav',1,True,0,0),('helheim','mysterious.wav',2,True,0,0),('victory','new_sunrise.wav',1,False,125,8),('defeat','lament.mp3',1,False,152,6)]
items=[]
for name,source,repeat,loop,start,dur in spec:
    p=R/'originals/music'/source;x=decode(p)
    if loop:
        energy=np.max(np.abs(x),axis=1);ix=np.flatnonzero(energy>np.max(energy)*.0005)
        x=x[max(0,ix[0]-220):min(len(x),ix[-1]+220)]
        unit=crossloop(x,.5 if name!='boss' else .15)
        x=np.tile(unit,(repeat,1))
    else:
        x=x[round(start*SR):round((start+dur)*SR)]
        a=min(round(.025*SR),len(x)//4);b=min(round(.65*SR),len(x)//3)
        x[:a]*=np.linspace(0,1,a)[:,None];x[-b:]*=np.linspace(1,0,b)[:,None]
    tmp=R/'records'/f'{name}_working.wav';wav(tmp,x*.8/(np.max(np.abs(x))+1e-9))
    bus='highpass=f=35,lowpass=f=10500'
    if name=='helheim':bus+=',equalizer=f=250:t=o:w=1:g=1.5,equalizer=f=2600:t=o:w=2:g=-2'
    measure=subprocess.run(['ffmpeg','-hide_banner','-i',str(tmp),'-af',bus+',loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json','-f','null','-'],capture_output=True).stderr.decode()
    m=json.loads(re.findall(r'\{[^{}]+\}',measure)[-1]);flt=bus+f",loudnorm=I=-16:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true"
    out=OUT/(name+'.ogg')
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(tmp),'-af',flt,'-ar',str(SR),'-ac','2','-c:a','vorbis','-strict','-2','-q:a','6',str(out)],check=True)
    tmp.unlink();result=analyze(out);decoded=decode(out)
    # These seam metrics expose discontinuities; they do not replace listening.
    seam=np.abs(decoded[-1]-decoded[0]);diff=np.abs(np.diff(decoded,axis=0));baseline=np.percentile(diff,99.9,axis=0)
    items.append({'id':name,'kind':'music','file':str(out.relative_to(R)),'sources':[str(p.relative_to(R))],'duration_s':len(decoded)/SR,'sample_rate':SR,'channels':2,'codec':'Vorbis','loop':loop,'source_repeat_count':repeat,'processing':'active-region trim and 0.5s overlap loop (boss 0.15s), or timed excerpt with fade; common 35Hz-10.5kHz bus; two-pass loudness normalization','excerpt_start_s':start if not loop else None,'loudness_lufs':float(result['input_i']),'true_peak_dbtp':float(result['input_tp']),'lra_lu':float(result['input_lra']),'seam_sample_delta':seam.tolist() if loop else None,'normal_diff_p999':baseline.tolist(),'status':'candidate_pending_listening','musical_cadence_review':'pending','sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
    print(name,round(len(decoded)/SR,3),'LUFS',result['input_i'],'TP',result['input_tp'],flush=True)
(R/'records/music_recipes.json').write_text(json.dumps(items,ensure_ascii=False,indent=2))
