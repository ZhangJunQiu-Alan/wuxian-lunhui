from pathlib import Path
import json,subprocess,wave,html,hashlib,collections
import numpy as np
R=Path(__file__).resolve().parent;P=R/'previews';P.mkdir(exist_ok=True);SR=44100

def decode(p,ch=1):return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ar',str(SR),'-ac',str(ch),'-f','f32le','-']),'<f4').copy().reshape(-1,ch)
def wav(p,x,ch=1):
    with wave.open(str(p),'wb') as w:w.setnchannels(ch);w.setsampwidth(2);w.setframerate(SR);w.writeframes(np.round(np.clip(x,-1,1)*32767).astype('<i2').tobytes())
def preview():
    sfx=json.loads((R/'records/sfx_measured.json').read_text());music=json.loads((R/'records/music_recipes.json').read_text());rows=[]
    groups=collections.defaultdict(list)
    for r in sfx:
        if r['frequent']:groups[r['id'][:-3]].append(r)
    for g,rr in groups.items():
        out=P/(g+'_60s.wav');a=[decode(R/r['file']).ravel() for r in sorted(rr,key=lambda x:x['id'])];x=np.zeros(60*SR);rate=8 if g in ['pickup_xp','enemy_hit'] else 4
        rng=np.random.default_rng(20261017);gain=10**((-18 if g=='pickup_xp' else -12)/20)
        for k in range(60*rate):
            start=round(k*SR/rate);clip=a[int(rng.integers(0,len(a)))];n=min(len(clip),len(x)-start);x[start:start+n]+=clip[:n]*gain
        wav(out,x);rows.append({'id':g+'_60s','file':str(out.relative_to(R)),'duration_s':60,'event_rate_hz':rate,'preview_gain_db':-18 if g=='pickup_xp' else -12,'listening_status':'pending','purpose':'one-minute fatigue audition; this gain is for preview only'})
    for r in music:
        if not r['loop']:continue
        out=P/(r['id']+'_3loops.flac');x=decode(R/r['file'],2)
        subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac','2','-i','-','-c:a','flac',str(out)],input=np.tile(x,(3,1)).astype('<f4').tobytes(),check=True)
        rows.append({'id':r['id']+'_3loops','file':str(out.relative_to(R)),'duration_s':len(x)/SR*3,'loop_join_times_s':[len(x)/SR,len(x)/SR*2],'listening_status':'pending','purpose':'three repetitions of decoded candidate, no crossfade added between repetitions'})
    (R/'records/preview_manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))

def delivery():
    sfx=json.loads((R/'records/sfx_measured.json').read_text());music=json.loads((R/'records/music_recipes.json').read_text());aud=json.loads((R/'records/sfx_audit.json').read_text());pre=json.loads((R/'records/preview_manifest.json').read_text());sources=json.loads((R/'records/sfx_source_packs.json').read_text())+json.loads((R/'records/music_downloads.json').read_text())
    for name in ['firearm_download.json','freesound_downloads.json']:
        p=R/'records'/name
        if p.exists():
            v=json.loads(p.read_text());sources+=v if isinstance(v,list) else [v]
    for r in sfx+music:
        details=[]
        for rel in r['sources']:
            matching=[]
            for entry in sources:
                if entry.get('raw_file')==rel or rel in entry.get('files',[]) or (entry.get('selected_files') and rel.startswith('originals/firearm/')):matching.append(entry)
            assert matching,('Missing source license',r['id'],rel)
            e=matching[0];details.append({'file':rel,'author':e.get('author'),'page':e.get('page'),'license':e.get('license'),'commercial':True,'attribution_required':False})
        r['source_details']=details
        r['original_sound_design']='Self-authored DSP/layering as described in recipe; no external AI audio service used' if r['kind']=='sfx' else 'Licensed composition edit only, not a new original composition claim'
    for r in music:
        bounds={'hub':(90,180),'midgard':(120,180),'boss':(90,120),'helheim':(120,180),'victory':(5,10),'defeat':(4,8)}[r['id']]
        fmt=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-show_streams','-show_format','-of','json',str(R/r['file'])]));st=fmt['streams'][0]
        r['technical_checks']={'vorbis_44100_stereo':st['codec_name']=='vorbis' and st['sample_rate']=='44100' and st['channels']==2,'duration_in_range':bounds[0]<=r['duration_s']<=bounds[1],'loudness_minus16_plusminus1':abs(r['loudness_lufs']+16)<=1,'true_peak_below_minus1':r['true_peak_dbtp']<=-1}
        if r['loop']:r['technical_checks']['seam_delta_below_normal_p999']=bool(np.all(np.array(r['seam_sample_delta'])<=np.array(r['normal_diff_p999'])))
        r['listening_checks']={k:'pending' for k in ['mood_and_identity','nordic_instrumentation','chapter_timbre_coherence','musical_phrase_complete']}
        if r['loop']:r['listening_checks']['three_repetitions_inaudible_seam']='pending'
        r['peak_dbfs']=float(20*np.log10(np.max(np.abs(decode(R/r['file'],2)))))
    files=sfx+music
    source_files=[]
    for rel in sorted(set(p for r in files for p in r['sources'])):
        p=R/rel;source_files.append({'file':rel,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    manifest={'task':'B','date':'2026-10-17','status':'in_progress_candidates_pending_audition','expected_sfx_count':54,'expected_music_count':6,'candidate_sfx_count':len(sfx),'candidate_music_count':len(music),'runtime_files_published':[],'missing_sfx':aud['missing_sfx'],'technical_failed_sfx':aud['technical_failed'],'subjective_audition':'not_performed; no listening-capable tool available in this session','game_test':'not_performed; integration agent responsibility','tools':{'processing':'Python 3 standard library; NumPy 2.4.3; FFmpeg 8.1.1','browser':'Google Chrome through native CUA','ai_generation_used':False},'license_default':'CC0-1.0; source composition/layers retained as separately listed provenance; no third-party exclusivity claim','sources':sources,'used_source_files':source_files,'files':files,'previews':pre}
    (R/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
    rows=[]
    for r in files+pre:
        name=html.escape(r['id']);url=html.escape(r['file'],quote=True);kind=r.get('kind','preview')
        peak=f"{r['peak_dbfs']:.2f} dBFS" if 'peak_dbfs'in r else '—';lufs=f"{r.get('loudness_lufs'):.2f}" if r.get('loudness_lufs')is not None else '—'
        metric='LUFS（短音为补静音至 1 秒的测量窗）' if kind=='sfx' and r['duration_s']<.4 else 'LUFS-I'
        checks=r.get('technical_checks',{});bad=[k for k,v in checks.items() if not v]
        state='技术检查未通过：'+','.join(bad) if bad else ('技术检查通过；听感待验收' if checks else '试听测试文件；尚未实际试听')
        detail=html.escape(r.get('recipe',r.get('processing',r.get('purpose',''))))
        extra=''
        if 'loop_join_times_s'in r:extra=' 接缝时间：'+', '.join(f'{t:.2f}s' for t in r['loop_join_times_s'])
        rows.append(f'<tr data-kind="{kind}"><td>{name}<small>{detail}{extra}</small></td><td>{r["duration_s"]:.3f}s</td><td>{peak}<br>{lufs} {metric}</td><td><audio controls preload="none" src="{url}"></audio><br><a href="{url}">打开文件</a></td><td>{html.escape(state)}</td></tr>')
    document='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>任务 B 音频候选试听</title><style>body{background:#111b23;color:#e5edf2;font:15px/1.6 system-ui;margin:36px auto;max-width:1400px;padding:0 24px}h1{font-size:28px}a{color:#8edbcf}table{border-collapse:collapse;width:100%}td,th{padding:14px 10px;border-bottom:1px solid #34434e;text-align:left}small{display:block;color:#9fb1bd;max-width:430px}audio{max-width:290px}button{padding:8px 16px;margin:0 8px 16px 0;background:#233944;color:inherit;border:1px solid #54717b;cursor:pointer}.notice{padding:18px;background:#25323a;border-left:4px solid #d8ba78}td:last-child{max-width:220px;color:#d8ba78}</style><h1>任务 B · 音效与音乐试听候选</h1><p class="notice">音频尚未完成主观听感验收，未写入自动接入目录。技术数据不能替代试听；未声称做过游戏内实测。页面默认试听音量 25%，同时只播放一条。</p><p><a href="manifest.json">manifest.json</a> · <a href="README.md">实际检查与剩余事项</a> · <a href="records/sfx_audit.json">音效技术审计</a></p><button onclick="filter('all')">全部</button><button onclick="filter('sfx')">单条音效</button><button onclick="filter('music')">音乐</button><button onclick="filter('preview')">一分钟与三遍循环</button><button onclick="document.querySelectorAll('audio').forEach(a=>a.pause())">停止播放</button><table><thead><tr><th>文件与处理方式</th><th>时长</th><th>峰值与响度</th><th>试听</th><th>验收状态</th></tr></thead><tbody>'''+''.join(rows)+'''</tbody></table><script>const players=[...document.querySelectorAll('audio')];players.forEach(a=>{a.volume=.25;a.addEventListener('play',()=>players.forEach(b=>{if(b!==a)b.pause()}))});function filter(v){document.querySelectorAll('tr[data-kind]').forEach(r=>r.hidden=v!=='all'&&r.dataset.kind!==v)}</script></html>'''
    (R/'gallery.html').write_text(document)
    print('Candidate files:',len(files),'Previews:',len(pre),'Missing:',aud['missing_sfx']);print('Music technical failures:',{r['id']:[k for k,v in r['technical_checks'].items() if not v] for r in music if not all(r['technical_checks'].values())})
if __name__=='__main__':preview();delivery()
