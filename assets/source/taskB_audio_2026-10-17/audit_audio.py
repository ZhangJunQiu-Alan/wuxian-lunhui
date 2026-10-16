from pathlib import Path
import wave,json,hashlib,re,subprocess,concurrent.futures
import numpy as np
R=Path(__file__).resolve().parent
GROUPS=['pickup_xp','katana_slash','revolver_shot','blades_slash','lightning','enemy_hit','enemy_death']
SINGLE='ui_click ui_open level_up card_pick ult_ready dash player_hurt player_death revive chest_open revolver_reload nova_cast rune_bolt feather_hit fire_burn ult_swordsman ult_gunslinger ult_assassin ult_mage big_death ice_shot arrow_shot golem_split boss_warning boss_windup boss_slam boss_howl boss_block ice_pillar boss_death quest_start quest_done quest_fail'.split()
EXPECTED=SINGLE+[f'{g}_{i:02}' for g in GROUPS for i in range(1,4)]
def measure(row):
    p=R/row['file']
    with wave.open(str(p)) as w:
        sr=w.getframerate();ch=w.getnchannels();bits=w.getsampwidth()*8;x=np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(float)/32768
    pk=np.max(np.abs(x));rms=np.sqrt(np.mean(x*x));onset=np.flatnonzero(np.abs(x)>=pk*.001)
    # Integrated loudness on <400ms clips is undefined; label the measured padded window explicitly.
    short=len(x)/sr<.4;filter_=('apad=whole_dur=1,' if short else '')+'loudnorm=I=-16:TP=-1:LRA=11:print_format=json'
    raw=subprocess.run(['ffmpeg','-hide_banner','-i',str(p),'-af',filter_,'-f','null','-'],capture_output=True).stderr.decode()
    loud=json.loads(re.findall(r'\{[^{}]+\}',raw)[-1]);last_rms=np.sqrt(np.mean(x[-min(len(x),441):]**2))
    row.update(duration_s=len(x)/sr,peak_dbfs=float(20*np.log10(pk)),rms_dbfs=float(20*np.log10(rms)),onset_ms=float(onset[0]/sr*1000) if len(onset) else None,sample_rate=sr,channels=ch,bit_depth=bits,last_sample=float(x[-1]),tail_10ms_rms_dbfs=float(20*np.log10(max(1e-12,last_rms))),loudness_lufs=float(loud['input_i']) if loud['input_i'] not in ['-inf','inf'] else None,loudness_measurement='EBU R128 with silence padding to 1 second (not intrinsic short-event LUFS)' if short else 'EBU R128 integrated',true_peak_dbtp=float(loud['input_tp']),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
    row['technical_checks']={'pcm16_mono_44100':sr==44100 and ch==1 and bits==16,'onset_within_10ms':bool(len(onset) and onset[0]/sr<=.010),'last_sample_zero':bool(x[-1]==0),'no_clipped_samples':bool(pk<1),'peak_minus_1_dbfs':abs(row['peak_dbfs']+1)<.01,'frequent_under_300ms':not row['frequent'] or len(x)/sr<.3}
    row['listening_checks']={k:'pending' for k in ['no_click_or_unwanted_noise','natural_decay','intended_sound_identity','nordic_timbre','relative_loudness']}
    if row['frequent']:row['listening_checks']['one_minute_not_fatiguing']='pending'
    return row
if __name__=='__main__':
    rows=json.loads((R/'records/sfx_recipes.json').read_text())
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(measure,rows))
    groups={}
    for g in GROUPS:
        sub=[r for r in rows if re.fullmatch(g+r'_0[123]',r['id'])]
        spread=max(r['rms_dbfs'] for r in sub)-min(r['rms_dbfs'] for r in sub) if len(sub)==3 else None
        groups[g]={'rms_spread_db':spread,'all_three_exist':len(sub)==3,'rms_spread_within_1_5_db':spread is not None and spread<=1.5,'note':'RMS is an objective comparison only; perceived loudness remains pending'}
        for r in sub:r['technical_checks']['variant_rms_spread_within_1_5_db']=groups[g]['rms_spread_within_1_5_db']
    ids={r['id'] for r in rows};audit={'expected_sfx':len(EXPECTED),'present_sfx':len(rows),'missing_sfx':sorted(set(EXPECTED)-ids),'unexpected_sfx':sorted(ids-set(EXPECTED)),'technical_failed':{r['id']:[k for k,v in r['technical_checks'].items() if not v] for r in rows if not all(r['technical_checks'].values())},'variant_groups':groups,'subjective_audition':'not_performed','game_test':'not_performed'}
    (R/'records/sfx_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2));(R/'records/sfx_measured.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));print(json.dumps(audit,ensure_ascii=False,indent=2))
