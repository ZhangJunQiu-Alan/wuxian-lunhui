from pathlib import Path
import hashlib
import json
import math
import re

B=Path(__file__).parent
ROOT=B.parents[3]
summary={"production_integration":True,"full_release_acceptance":False,"suites":[],"long_runs":{},"issues":[]}
counts=[]
for ident in ['m_art','vigrid','combat','acceptance','cards','boss','combat_art','quest']:
    path=B/'logs'/f'final_{ident}.log'
    text=path.read_text()
    marker=next(x for x in reversed(text.splitlines()) if 'RESULT' in x or 'QUEST ART CHECKS' in x)
    count=int(re.search(r'(?:checks=|RESULT(?: J ART)?[ :]+|CHECKS )([0-9]+)',marker,re.I).group(1))
    errors=[line for line in text.splitlines() if 'SCRIPT ERROR' in line or 'ERROR:' in line or 'leaked at exit' in line]
    assert not errors,(ident,errors)
    counts.append(count)
    summary['suites'].append({'id':ident,'checks':count,'failures':0,'marker':marker,'log':str(path.relative_to(B)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
summary['assertions_total']=sum(counts)

for name in ['soak_final','realtime_meta_final','controlled_render_final','controlled_render_capture']:
    path=B/'results'/name/('soak.json' if name=='soak_final' else 'playthrough.json')
    if not path.exists():
        summary['long_runs'][name]={'complete':False}
        continue
    data=json.loads(path.read_text())
    if name=='soak_final':
        result={'complete':data.get('completed',False),'wall_seconds':data.get('wall_seconds'),'violations':data.get('violations',[]),'stages':[],'reentries':len(data.get('reentry',[]))}
        for stage in data['stages']:
            samples=stage['samples']
            stats={}
            for key in ['rss_mb','static_mb','nodes','resources','orphans']:
                values=[x[key] for x in samples]
                stats[key]={'first':values[0],'last':values[-1],'min':min(values),'max':max(values)}
            result['stages'].append({'boss':stage['boss'],'wall_seconds':stage['wall_seconds'],'unpaused_seconds':stage['unpaused_seconds'],'p50_ms':stage['p50_ms'],'p95_ms':stage['p95_ms'],'p99_ms':stage['p99_ms'],'max_ms':stage['max_ms'],'max_enemies':stage['max_enemies'],'trend':stats})
        hubs=data.get('reentry',[])
        result['hub_residue']=[{k:s[k] for k in ['round','nodes','resources','orphans','rss_mb','enemies_left','hazards_left','fragments_left']} for s in hubs]
        if hubs:
            for key in ['nodes','resources','orphans','rss_mb']:
                result['hub_'+key+'_range']=[min(s[key] for s in hubs),max(s[key] for s in hubs)]
        if any(x['p95_ms']>33.33 for x in result['stages']):summary['issues'].append('350-enemy stress has p95 above33.33ms; no stable30/60fps acceptance')
        if any(x['max_ms']>100 for x in result['stages']):summary['issues'].append('Stress includes >100ms frame spikes with capture/sampling overhead; stable60fps release acceptance not established')
        summary['long_runs'][name]=result
    else:
        result={k:data[k] for k in ['headless','wall_seconds','level_seconds','invincible','damage_events','meta_profile','frame_ms_p50','frame_ms_p95','frame_ms_p99','frame_ms_max','result']}
        result['complete']=bool(data.get('result'))
        result['milestones']=[e for e in data['events'] if e['event'] in ['boss_spawn','boss_gone','surtr_phase','ending_shown','fate','result']]
        result['three_boss_clear']=any(e['event']=='result' and e.get('cleared_vigrid') for e in data['events'])
        if not result['three_boss_clear']:summary['issues'].append(name+' bot ended in death; natural-clear acceptance not achieved')
        summary['long_runs'][name]=result
    log=B/'logs'/f'{name}.log'
    if log.exists():
        bad=[s for s in log.read_text().splitlines() if 'SCRIPT ERROR' in s or 'ERROR:' in s or 'leaked at exit' in s]
        summary['long_runs'][name]['errors']=bad
        if bad:summary['issues'].append(name+' final log has errors')

snapshot=json.loads((B/'final_snapshot_hashes.json').read_text())
changes=[p for p,h in snapshot.items() if not (ROOT/p).exists() or hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
summary['snapshot_files']=len(snapshot)
summary['gameplay_snapshot_changes']=[p for p in changes if not p.startswith('tools/')]
summary['expected_fixture_changes']=[p for p in changes if p=='tools/acceptance_vigrid_run.gd']
summary['snapshot_vs_current_changes']=changes
if summary['gameplay_snapshot_changes']:summary['issues'].append('Production gameplay changed after frozen candidate; see explicit files')
(B/'results/final_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(json.dumps({'assertions':summary['assertions_total'],'long_runs':{k:v.get('complete') for k,v in summary['long_runs'].items()},'issues':summary['issues']},ensure_ascii=False))
