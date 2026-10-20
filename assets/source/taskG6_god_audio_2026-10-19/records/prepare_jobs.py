from pathlib import Path
import json,math
R=Path(__file__).resolve().parent.parent
plan=json.loads((R/'records/production_plan.json').read_text())
BASE=dict(oldParams=True,wave_type=2,p_env_attack=.012,p_env_sustain=.16,p_env_punch=.05,p_env_decay=.25,p_base_freq=.35,p_freq_limit=0,p_freq_ramp=0,p_freq_dramp=0,p_vib_strength=0,p_vib_speed=0,p_arp_mod=0,p_arp_speed=0,p_duty=0,p_duty_ramp=0,p_repeat_speed=0,p_pha_offset=0,p_pha_ramp=0,p_lpf_freq=.5,p_lpf_ramp=0,p_lpf_resonance=0,p_hpf_freq=0,p_hpf_ramp=0,sound_vol=.1,sample_rate=44100,sample_size=16)
# type, initial Hz, approximate envelope length, slide, lowpass and per-sound controls.
DESIGNS={
 'god_choose':(2,521,.386,0,.85,dict(p_arp_mod=.609,p_arp_speed=.68,p_vib_strength=.02,p_vib_speed=.22)),
 'path_choose':(2,392,.48,.025,.55,dict(p_arp_mod=.73,p_arp_speed=.56,p_env_punch=.03)),
 'awaken':(1,146.8,1.5,.012,.27,dict(p_env_attack=.04,p_arp_mod=.61,p_arp_speed=.36,p_vib_strength=.035,p_vib_speed=.12)),
 'fusion':(2,220,.88,.07,.55,dict(p_arp_mod=.61,p_arp_speed=.38,p_pha_offset=.08,p_pha_ramp=-.05)),
 'hammer_throw':(3,340,.30,-.18,.30,dict(p_env_punch=.22,p_pha_ramp=-.18)),
 'hammer_catch':(1,130,.18,-.10,.29,dict(p_env_punch=.16,p_pha_offset=.12)),
 'static_zap':(3,1250,.11,-.08,.45,dict(p_env_punch=.05,p_repeat_speed=.78,p_pha_offset=.12)),
 'spear_throw':(3,650,.23,.12,.40,dict(p_pha_ramp=.10,p_hpf_freq=.07)),
 'rune_detonate':(2,310,.22,-.16,.50,dict(p_env_punch=.15,p_arp_mod=-.25,p_arp_speed=.80)),
 'raven_dive':(3,185,.24,-.08,.32,dict(p_repeat_speed=.72,p_pha_offset=.09)),
 'wolf_bite':(3,180,.19,-.13,.27,dict(p_env_punch=.13,p_pha_ramp=.10)),
 'wolf_breath':(3,110,.66,-.10,.30,dict(p_env_punch=.13,p_lpf_ramp=-.08)),
 'decoy_spawn':(3,280,.32,.14,.33,dict(p_pha_ramp=.20,p_repeat_speed=.56)),
 'feather_launch':(3,1200,.24,.08,.40,dict(p_repeat_speed=.70,p_hpf_freq=.08)),
 'cat_pounce':(3,380,.18,-.15,.34,dict(p_env_punch=.09,p_pha_offset=.08)),
 'chariot_charge':(3,180,.65,.11,.30,dict(p_repeat_speed=.55,p_env_punch=.13)),
 'light_beam':(2,784,.36,-.04,.65,dict(p_vib_strength=.02,p_vib_speed=.2)),
 'light_spear':(2,660,.24,.13,.65,dict(p_arp_mod=.3,p_arp_speed=.75)),
 'light_burst':(2,930,.16,-.13,.60,dict(p_env_punch=.02)),
 'light_flash':(2,523,.72,.06,.65,dict(p_arp_mod=.61,p_arp_speed=.72,p_env_punch=.1)),
 'net_throw':(3,230,.31,-.06,.25,dict(p_pha_ramp=.13)),
 'net_close':(3,380,.35,.08,.27,dict(p_pha_offset=.12,p_lpf_ramp=-.05)),
 'wave_push':(3,100,.63,.09,.28,dict(p_env_punch=.15,p_lpf_ramp=.05)),
 'wave_crash':(3,160,.79,-.10,.32,dict(p_env_punch=.3,p_lpf_ramp=-.08)),
 'sword_hit':(1,580,.15,-.11,.46,dict(p_pha_offset=.14,p_pha_ramp=-.05,p_env_punch=.2)),
 'boar_charge':(1,87,.64,-.04,.24,dict(p_vib_strength=.12,p_vib_speed=.28,p_repeat_speed=.48)),
 'ice_arrow':(3,1300,.18,.10,.49,dict(p_hpf_freq=.04,p_pha_ramp=.07)),
 'ice_snipe':(3,1000,.37,.15,.46,dict(p_env_punch=.19,p_pha_ramp=.10)),
 'ice_shatter':(3,1500,.40,-.04,.53,dict(p_repeat_speed=.62,p_pha_offset=.18,p_env_punch=.16)),
 'heal_pickup':(2,740,.24,.035,.65,dict(p_arp_mod=.609,p_arp_speed=.80,p_env_punch=.02)),
}
jobs=[]
for row in plan['sounds']:
 id=row['id'];wave,hz,dur,slide,lp,extra=DESIGNS[id]
 for k,file in enumerate(row['files']):
  variant=(k-1) if row['variants']==3 else 0;p=BASE.copy();p.update(wave_type=wave,p_base_freq=math.sqrt(hz*(1+variant*.035)/3528-.001),p_env_sustain=math.sqrt(dur*.28/2.2675737),p_env_decay=math.sqrt(dur*.72/2.2675737),p_freq_ramp=slide+variant*.006,p_lpf_freq=lp+variant*.012);p.update(extra)
  if id=='god_choose':p.update(p_env_attack=.02,p_env_sustain=.16,p_env_decay=.38,p_base_freq=.383,p_env_punch=.06)
  stem=file[:-4];jobs.append(dict(id=id,stem=stem,filename=file,purpose=row['purpose'],variant=k+1 if row['variants']==3 else None,frequent=row['variants']==3,params=p,tool='jsfxr free website in Chrome',website='https://sfxr.me/',status='planned',raw=f'originals/{stem}_v01_browser.wav'))
(R/'records/browser_jobs.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2))
print(len(jobs),'browser jobs')
