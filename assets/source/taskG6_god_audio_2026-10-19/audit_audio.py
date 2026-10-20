from pathlib import Path
import json,wave,hashlib,subprocess,re
import numpy as np

R=Path(__file__).resolve().parent
SR=44100
def db(x):return float(20*np.log10(max(float(x),1e-12)))
def load(p):
 with wave.open(str(p),'rb') as w:
  info=dict(channels=w.getnchannels(),sample_width_bytes=w.getsampwidth(),sample_rate=w.getframerate(),compression=w.getcomptype());data=w.readframes(w.getnframes())
 return np.frombuffer(data,dtype='<i2'),info,data

def meter(data):
 r=subprocess.run(['ffmpeg','-v','info','-f','s16le','-ar',str(SR),'-ac','1','-i','-','-af','apad=whole_dur=1,ebur128=peak=true','-f','null','-'],input=data,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
 s=r.stderr.decode();i=re.findall(r'I:\s*(-?[\d.]+) LUFS',s);tp=re.findall(r'Peak:\s*(-?[\d.]+) dBFS',s)
 return dict(lufs_padded_window=float(i[-1]) if i else None,true_peak_dbfs=float(tp[-1]) if tp else None,lufs_method='FFmpeg EBU R128; zero-pad short events to1 second. This is a comparison window, not event-only/music integrated loudness.')

def measure(p):
 pcm,info,data=load(p);x=pcm.astype(float)/32768;peak=max(abs(x));active=np.flatnonzero(abs(x)>=.001);freq=np.fft.rfftfreq(len(x),1/SR);power=abs(np.fft.rfft(x))**2
 return dict(**info,duration_seconds=len(x)/SR,sample_peak_dbfs=db(peak),rms_dbfs=db(np.sqrt(np.mean(x*x))),onset_above_minus60dbfs_ms=float(active[0]*1000/SR) if len(active) else None,first_sample=int(pcm[0]),last_sample=int(pcm[-1]),last10ms_rms_dbfs=db(np.sqrt(np.mean(x[-441:]**2))),full_scale_sample_count=int(np.sum(abs(pcm.astype(int))>=32767)),high_frequency_energy_above8khz=float(power[freq>=8000].sum()/max(power.sum(),1e-30)),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),**meter(data))

def main():
 recipes=json.loads((R/'records/processing_recipes.json').read_text());rows=[];errors=[];groups={}
 for e in recipes:
  p=R/e['candidate'];m=measure(p);checks=dict(pcm16_mono44100=m['channels']==1 and m['sample_width_bytes']==2 and m['sample_rate']==44100 and m['compression']=='NONE',peak_minus1dbfs=abs(m['sample_peak_dbfs']+1)<.01,onset_within10ms=m['onset_above_minus60dbfs_ms'] is not None and m['onset_above_minus60dbfs_ms']<=10,zero_boundaries=m['first_sample']==0 and m['last_sample']==0,no_fullscale_clipping=m['full_scale_sample_count']==0,quiet_last10ms=m['last10ms_rms_dbfs']<=-45,sha256_matches_recipe=m['sha256']==e['sha256'],all_sources_exist=all((R/s).is_file() for s in e['sources']),browser_record_exists=(R/e['browser_record']).is_file())
  if e['frequent']:checks['frequent_at_most300ms']=m['duration_seconds']<=.3
  if e['id']=='awaken':checks['awaken_about1500ms']=1.4<=m['duration_seconds']<=1.6
  errors.extend(f"{e['stem']}: {k}" for k,v in checks.items() if not v)
  rows.append(dict(stem=e['stem'],measurements=m,technical_checks=checks,status='technical_pass_subjective_pending' if all(checks.values()) else 'technical_failed'))
  if e['frequent']:groups.setdefault(e['id'],[]).append(rows[-1])
 group_results=[]
 for id,items in groups.items():
  rms=[e['measurements']['rms_dbfs'] for e in items];hashes=[e['measurements']['sha256'] for e in items];checks={'three_distinct_variants':len(items)==3 and len(set(hashes))==3,'rms_spread_at_most1_5db':max(rms)-min(rms)<=1.5}
  group_results.append(dict(id=id,checks=checks,rms_spread_db=max(rms)-min(rms),listening_60seconds='pending; not inferred from RMS'))
  errors.extend(f'{id}: {k}' for k,v in checks.items() if not v)
 refs=[]
 (R/'references').mkdir(exist_ok=True)
 for name in ['lightning_01','rune_bolt','fire_burn','feather_hit','arrow_shot']:
  p=R.parents[1]/'audio/sfx'/f'{name}.wav';q=R/'references'/p.name;q.write_bytes(p.read_bytes());refs.append(dict(id=name,file=str(q.relative_to(R)),copied_from=str(p),measurements=measure(q),comparison='reference captured; subjective timbre/loudness comparison pending'))
 out=dict(task='G6',status='pass' if not errors else 'failed',candidate_count=len(rows),expected=44,errors=errors,files=rows,variant_groups=group_results,references=refs,subjective_listening='not_performed; playback and numerical metrics are not hearing',game_test='not_performed')
 acceptance_path=R/'records/listening_acceptance.json'
 if acceptance_path.exists():
  acceptance=json.loads(acceptance_path.read_text());same_files=all(acceptance.get('accepted_candidate_sha256',{}).get(e['stem'])==e['measurements']['sha256'] for e in rows)
  if acceptance.get('all44_listened_and_accepted') and same_files:
   out['subjective_listening']={'assistant':'not_performed','user':'explicitly accepted full44 and7minute-long groups','evidence':'records/listening_acceptance.json'}
   for e in rows:e['status']='technical_pass_user_listening_accepted' if all(e['technical_checks'].values()) else 'technical_failed'
   for e in group_results:
    if e['id'] in acceptance.get('minute_groups_accepted',[]):e['listening_60seconds']='accepted_by_user; not inferred from RMS or browser timer'
   for e in refs:e['comparison']='Reference captured and made available next to candidates; full set accepted by user. No assistant subjective A/B claim.'
 (R/'records/audio_audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(out['status'],len(rows),'files;',len(group_results),'variant groups; errors',errors)
 if errors:raise SystemExit(1)

if __name__=='__main__':main()
