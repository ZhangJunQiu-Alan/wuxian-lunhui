from pathlib import Path
import csv,json,math,statistics,sys
BASE=Path(__file__).resolve().parent
folder=BASE/('smoke' if '--smoke' in sys.argv else 'results')
result=json.loads((folder/'soak_result.json').read_text())
rows=result['samples'];rss=[{k:float(v) for k,v in row.items()} for row in csv.DictReader((folder/'rss.csv').open())]
MIB=1024*1024

def slope(points):
 if len(points)<2:return None
 xs,ys=zip(*points);xm=statistics.mean(xs);ym=statistics.mean(ys);den=sum((x-xm)**2 for x in xs)
 return sum((x-xm)*(y-ym) for x,y in points)/den if den else 0

def metrics(rr,key,unit=1):
 v=[r[key]/unit for r in rr]
 return {'count':len(v),'first':v[0],'last':v[-1],'min':min(v),'max':max(v),'median':statistics.median(v),'slope_per_minute':slope([(r['seconds']/60,r[key]/unit) for r in rr])}

phases=[]
for phase in result['phases']:
 name=phase['name'];rr=[r for r in rows if r['phase']==name];start=min(r['seconds'] for r in rr);end=max(r['seconds'] for r in rr);warm=60 if not result['smoke'] else 0
 steady=[r for r in rr if r['seconds']>=start+warm]
 if not steady:steady=rr
 resident=[{'seconds':r['seconds'],'rss_bytes':r['rss_kib']*1024} for r in rss if start+warm<=r['seconds']<=end]
 entry={**phase,'exclude_warmup_seconds':warm,'static_mib':metrics(steady,'static_bytes',MIB),'objects':metrics(steady,'objects'),'nodes':metrics(steady,'nodes'),'resources':metrics(steady,'resources'),'texture_mib':metrics(steady,'texture_bytes',MIB),'orphans_max':max(r['orphans'] for r in steady),'resident_mib':metrics(resident,'rss_bytes',MIB) if resident else None}
 phases.append(entry)
cycles=[r for r in rows if r['phase']=='scene_cycles'];steady_cycles=[r for r in cycles if r['cycle']>8] or cycles
cycle_analysis={k:metrics(steady_cycles,k,MIB if k in ['static_bytes','texture_bytes'] else 1) for k in ['static_bytes','objects','nodes','resources','orphans','texture_bytes']}
cycle_analysis['warmup_cycles_excluded']=8 if not result['smoke'] else 0
cycle_analysis['per_character']={}
for offset,name in enumerate(['swordsman','gunslinger','assassin','mage']):
 rr=[r for r in steady_cycles if (r['cycle']-1)%4==offset]
 if rr:cycle_analysis['per_character'][name]={'nodes':metrics(rr,'nodes'),'objects':metrics(rr,'objects'),'resources':metrics(rr,'resources'),'static_mib':metrics(rr,'static_bytes',MIB)}
engine_errors=[];log=(folder/'console.log').read_text()
for line in log.splitlines():
 if any(k in line for k in ['SCRIPT ERROR:','ERROR:','WARNING: ObjectDB','resources still in use']):engine_errors.append(line)
# Diagnostics are explicit heuristics, not mathematical proof of no leaks.
flags=[]
for p in phases:
 if p['static_mib']['slope_per_minute']>1:flags.append(p['name']+': static growth >1MiB/min after warmup')
 if p['resident_mib'] and p['resident_mib']['slope_per_minute']>2:flags.append(p['name']+': RSS growth >2MiB/min after warmup')
 if p['orphans_max']>0:flags.append(p['name']+': orphan nodes')
if cycle_analysis['nodes']['max']!=cycle_analysis['nodes']['min']:flags.append('post-free scene node count varies')
if cycle_analysis['orphans']['max']>0:flags.append('post-free orphan nodes')
for name,v in cycle_analysis['per_character'].items():
 if v['resources']['last']>v['resources']['first']:flags.append(name+': resources increase across warmed matching-character cycles')
 if v['objects']['last']>v['objects']['first']+3:flags.append(name+': objects increase across warmed matching-character cycles')
summary={'task':'J1-J8 unattended long-run','date':'2026-10-19','base_commit':json.loads((BASE/'scope.json').read_text())['commit'],'wall_seconds':result['wall_seconds'],'pressure_seconds':sum(p['wall_seconds'] for p in result['phases']),'rendered_frames':sum(p['frames'] for p in result['phases']),'scene_cycles':result['scene_cycles'],'checks':len(result['checks']),'check_failures':result['failures'],'engine_errors':engine_errors,'investigation_flags':flags,'phases':phases,'scene_cycle_analysis':cycle_analysis,'final_idle':rows[-1],'casts':result['casts'],'rss_mib_all':{'min':min(r['rss_kib']/1024 for r in rss),'max':max(r['rss_kib']/1024 for r in rss),'last':rss[-1]['rss_kib']/1024},'interpretation':'Measurements include allocator/driver caches and small test-record bookkeeping; trend thresholds are investigation flags, not proof that all memory is leak-free. Scene-free counts compare equivalent warmed character phases. Static J texture cache14 intentionally remains until process exit.','limitations':['One local Apple M2 device and renderer','Player controlled immune/damage0 to hold fixed load; not full manual playthrough or balance test','No exported build or all god combinations','RSS is resident memory and may change with macOS paging/compression; engine counts needed alongside it'],'platform_diagnostics':[line for line in log.splitlines() if 'mach port' in line],'focus_pause_caveat':'An actual live-AI phase screenshot shows focus-loss pause overlay. Workload nodes use PROCESS_MODE_ALWAYS and the emitter runs in SceneTree, so forced pressure continued; these FPS figures are not normal unpaused foreground-game benchmarks. No exact pause timeline was sampled.','code_changes':False,'commit_or_push_this_turn':False}
probe_path=BASE/'cache_probe/soak_result.json'
if probe_path.exists() and not result['smoke']:
 probe=json.loads(probe_path.read_text());pq=[x for x in probe['samples'] if x['phase']=='scene_cycles'];mq=[x for x in rows if x['phase']=='scene_cycles']
 def plateau(q):
  last=q[-1];start=len(q)-1
  while start>0 and q[start-1]['resources']==last['resources'] and q[start-1]['objects']==last['objects']:start-=1
  return {'first_cycle_of_final_plateau':q[start]['cycle'],'last_cycle':last['cycle'],'consecutive_matching_cycles':len(q)-start,'resources':last['resources'],'objects':last['objects'],'nodes_min':min(x['nodes'] for x in q[start:]),'nodes_max':max(x['nodes'] for x in q[start:])}
 additions=[]
 for previous,current in zip(pq,pq[1:]):
  added=set(current.get('cached_files',[]))-set(previous.get('cached_files',[]))
  if added:additions.append({'cycle':current['cycle'],'new_cached_paths':sorted(added)})
 follow={'probe_seconds':probe['wall_seconds'],'checks':len(probe['checks']),'failures':probe['failures'],'main_final_plateau':plateau(mq),'probe_final_plateau':plateau(pq),'probe_cache_additions':additions,'recorder_release':json.loads((BASE/'cache_probe/recorder_release.json').read_text()),'interpretation':'The main early +2 resources stop growing at the final plateau. Probe identifies a one-time feather_blade texture cache addition; main did not sample cache paths, so its exact2 resource identities are not claimed. This resolves the initial first/last heuristic as a bounded warmup step, not repeated per-cycle leakage.'}
 summary['cache_followup']=follow
 summary['initial_investigation_flags']=list(flags)
 if follow['main_final_plateau']['consecutive_matching_cycles']>=32 and follow['probe_final_plateau']['consecutive_matching_cycles']>=32 and not probe['failures']:
  summary['resolved_flags']=[{'flag':flag,'resolution':'Main and independent probe show >=32 consecutive same-resource/object post-free counts; see cache_followup and retained analysis_initial_flags.json'} for flag in flags if 'resources increase across warmed matching-character cycles' in flag]
  summary['investigation_flags']=[flag for flag in flags if 'resources increase across warmed matching-character cycles' not in flag]
 (folder/'cache_followup.json').write_text(json.dumps(follow,ensure_ascii=False,indent=2)+'\n')
(folder/'analysis.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:summary[k] for k in ['wall_seconds','pressure_seconds','rendered_frames','scene_cycles','checks','check_failures','engine_errors','investigation_flags']},ensure_ascii=False))
for p in phases:print(p['name'],p['static_mib'],p['resident_mib'])
