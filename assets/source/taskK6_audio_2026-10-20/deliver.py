from pathlib import Path
import json,hashlib,wave,subprocess,shutil
import numpy as np
B=Path(__file__).resolve().parent;ROOT=B.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):(B/p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
checks=[]
def ck(n,ok,detail=None):checks.append(dict(check=n,passed=bool(ok),detail=detail))
sfx=json.loads((B/'records/sfx_recipes.json').read_text());music=json.loads((B/'records/music_measurements.json').read_text());sources=json.loads((B/'records/used_sources.json').read_text());assets=[]
source_names={'jormungandr_hiss':['spell_fire_05','cloth4'],'fenrir_swallow':['creature_monster_01','impactSoft_heavy_000','cloth4'],'gleipnir_tension':['cloth4','metal_02','spell_02'],'surtr_gate':['spell_fire_05','creature_roar_03','spell_02']}
for r in sfx:
 p=B/r['file']
 with wave.open(str(p),'rb') as w:channels,width,sr,n=w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getnframes();x=np.frombuffer(w.readframes(n),'<i2')
 ck(r['id']+':monoPCM16_44100',(channels,width,sr)==(1,2,44100));ck(r['id']+':peak',abs(r['peak_dbfs']+1)<.01);ck(r['id']+':onset',r['onset_ms']<=10);ck(r['id']+':boundary0',x[0]==0 and x[-1]==0);ck(r['id']+':noclip',int(max(abs(x.astype(int))))<32767);ck(r['id']+':duration',.3<r['duration_s']<=1);ck(r['id']+':hash',sha(p)==r['sha256'])
 r['formal_path']='assets/audio/sfx/'+p.name;r['listening']='accepted_by_user';r['sources']=list({s['local']:s for s in sources if Path(s['local']).stem in source_names[r['id']]}.values());assets.append(r)
p=B/music['file'];probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(p)]))['streams'][0];ck('music:Vorbis44100stereo',probe['codec_name']=='vorbis' and int(probe['sample_rate'])==44100 and probe['channels']==2);ck('music:LUFS',abs(music['loudness_lufs']+16)<=1);ck('music:truepeak',music['true_peak_dbtp']<-1);ck('music:seam_vs_normal_diff',all(a<b for a,b in zip(music['seam_sample_delta'],music['normal_diff_p999'])));ck('music:source_whole_loop',abs(music['duration_s']-92.08)<.1);ck('music:hash',sha(p)==music['sha256']);music['formal_path']='assets/audio/music/vigrid.ogg';music['musical_three_loop_listening']='accepted_by_user';music['source']=json.loads((B/'records/music_source.json').read_text());assets.append(music)
for source in {s['local']:s for s in sources}.values():ck('source:'+source['local'],sha(B/source['local'])==source['sha256'] and sha(ROOT/source['path'])==source['sha256'])
events=json.loads((ROOT/'assets/source/taskK0_vigrid_plan_2026-10-20/audio_events.json').read_text())['events'];mapping={'jormungandr_poison_release':'jormungandr_hiss','fenrir_gulp':'fenrir_swallow','gleipnir_bind':'gleipnir_tension','surtr_gate':'surtr_gate'}
for e in events:
 if e['event'] in mapping:e.update(decision='new_delivered',proposed_call_id=mapping[e['event']],files=[dict(path='assets/audio/sfx/'+mapping[e['event']]+'.wav',sha256=next(a['sha256'] for a in assets if a['id']==mapping[e['event']]))],new_file_count=1)
 elif e['event']=='battlefield_ambience':e.update(decision='omitted_v1',new_file_count=0,files=[],note='no always-on environmental loop; dedicated music and sparse old fire events')
 else:
  for f in e['files']:ck('reuse:'+e['event']+':'+f['path'],sha(ROOT/f['path'])==f['sha256'])
 e['runtime_status']='not_integrated';e['subjective_and_runtime_acceptance']='new5audioaccepted_by_user; existingeventmix_not_tested' if e['event'] in mapping else 'existingasset_not_new_review; eventmix_not_tested'
ck('25eventcoverage',len(events)==25 and sum(e['decision']=='new_delivered' for e in events)==4 and sum(e['decision']=='omitted_v1' for e in events)==1);dump('audio_events.json',dict(events=events,new_sfx=4,reused_events=20,omitted_optional_events=1,game_acceptance='not_tested'))
acceptance=dict(scope='four newSFX and music complete three-loop listening only',evidence='user response in current Codex conversation on2026-10-20',exact_user_response='已听完整套和音乐三遍，均合适',agent_personal_listening_claim=False,files=[dict(file=a['file'],sha256=a['sha256']) for a in assets],previews=[dict(file=str(p.relative_to(B)),sha256=sha(p)) for p in [B/'previews/four_sfx_sequence.wav',B/'previews/vigrid_three_loops.wav',B/'previews/vigrid_three_loops.ogg']],game_mix='not_tested');dump('records/listening_acceptance.json',acceptance)
base=json.loads((ROOT/'assets/source/taskK_contract_2026-10-20/records/baseline.json').read_text());changed=[p for p,h in base.items() if p.startswith('assets/') and sha(ROOT/p)!=h];ck('baseline_assets_includingG6_unchanged',not changed,changed)
audit=dict(task='K6',checks=len(checks),failures=sum(not c['passed'] for c in checks),items=checks,scope='technical measurements and integrity; listening from user evidence, no game run');dump('records/final_audit.json',audit)
if audit['failures']:raise SystemExit(str([c for c in checks if not c['passed']]))
for a in assets:
 p=ROOT/a['formal_path'];p.parent.mkdir(parents=True,exist_ok=True)
 if p.exists() and sha(p)!=a['sha256']:raise SystemExit('refuse overwrite '+str(p))
 if not p.exists():shutil.copyfile(B/a['file'],p)
 shutil.copyfile(B/a['file'],B/'approved'/p.name)
 ck('published:'+a['id'],sha(p)==sha(B/'approved'/p.name)==a['sha256'])
audit.update(checks=len(checks),failures=sum(not c['passed'] for c in checks));dump('records/final_audit.json',audit);dump('manifest.json',dict(task='K6',status='delivered_user_listening_accepted_not_game_integrated',formal_ogg=1,formal_wav=4,assets=assets,self_check='passed',game_acceptance='not_tested'));dump('completion.json',dict(task='K6',production='complete',formal_ogg=1,formal_wav=4,self_check='passed',checks=len(checks),listening='user accepted complete4SFX and three musicloops',game_integration='not_implemented',game_acceptance='not_tested',remaining=['25 event calls','LevelDB music','dense gameplay mixing','music transition and full third-level loop'],git_commit=False,git_push=False));dump('source_inventory.json',[dict(path=str(p.relative_to(B)),sha256=sha(p)) for p in sorted(B.rglob('*')) if p.is_file() and p.name!='source_inventory.json']);print(json.dumps(dict(checks=len(checks),failures=audit['failures'],formal_audio=5)))
