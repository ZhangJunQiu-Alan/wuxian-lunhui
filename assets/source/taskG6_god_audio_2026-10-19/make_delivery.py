from pathlib import Path
from html import escape
import json,hashlib,wave
import numpy as np

R=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')

def main():
 recipes=json.loads((R/'records/processing_recipes.json').read_text());audit=json.loads((R/'records/audio_audit.json').read_text());measures={e['stem']:e for e in audit['files']};prior=json.loads((R/'licenses/prior_taskB_sources.json').read_text());prior={e['id']:e for e in prior if 'id' in e};files=[];sources={}
 for e in recipes:
  for rel in e['sources']:
   if rel in sources:continue
   p=R/rel
   if rel.startswith('originals/reused/'):
    pack=Path(rel).parts[2];old=prior[pack];source=dict(file=rel,author=old['author'],license=old['license'],page=old['page'],origin='Previously downloaded and CC0 verified in taskB; copied unchanged for G6 processing')
   elif rel.endswith('boar_voice_CC0.ogg'):source=dict(file=rel,author='fvcalderan',license='CC0-1.0',page='https://opengameart.org/content/boar-0',origin='Chrome downloaded boar_0.ogg; author-made voice+EQ, not a wildlife recording')
   else:
    stem=Path(rel).name.removesuffix('_v01_browser.wav');rec=json.loads((R/'records'/f'browser_{stem}_v01.json').read_text());source=dict(file=rel,author='Project-created sound parameters rendered by jsfxr in Chrome',license='Unrestricted commercial output usage per official jsfxr site; software Unlicense is recorded separately',page='https://sfxr.me/',record=f'records/browser_{stem}_v01.json',origin=rec.get('export_method','Chrome native WAV download link clicked'))
   source['sha256']=sha(p);sources[rel]=source
  a=measures[e['stem']];files.append({**e,'measurement':a['measurements'],'technical_checks':a['technical_checks'],'source_records':[sources[p] for p in e['sources']],'subjective_checks':{'timbre_matches_existing':'pending','natural_decay_no_audible_click':'pending','not_piercing':'pending','perceived_loudness_consistent':'pending','one_minute_not_fatiguing':'pending' if e['frequent'] else 'not_applicable'},'game_test':'not_performed','runtime_file':None})
 feedback={'date':'2026-10-19','user_response':'方向合适，继续这一套风格','scope':'Direction approval for the three demonstrated v02 samples, not approval of all44 files or minute-long fatigue tests.','samples':[{'stem':id,'sha256':measures[id]['measurements']['sha256']} for id in ['god_choose','static_zap_01','awaken']]};dump(R/'records/user_direction_feedback.json',feedback)
 manifest={'task':'G6','date':'2026-10-19','version':'v02','status':'44_candidates_technical_pass_listening_pending','sound_types':30,'candidate_wav_count':len(files),'runtime_files_published':[],'user_direction_feedback':feedback,'browser_production':'44 sounds actually rendered through jsfxr Chrome UI. First24 WAVs downloaded via link; remaining20 saved from the visible generated WAV data-link after download did not complete.','ai_generation_used':False,'tools':{'web':'jsfxr free, Chrome native CUA and connected Chrome extension','processing':'Python3, NumPy, FFmpeg8.1.1; no new offline oscillator synthesis'},'audio_audit':'records/audio_audit.json','sources':list(sources.values()),'files':files,'extra_sources_not_used':{'crow':'CC0 author page checked; Chrome blocked download, no file acquired or used. Raven uses wingbeats instead.','cat':'CC0 author page checked; Chrome blocked download, no file acquired or used. Cat uses air/claw impact instead.'},'game_test':'not_performed'}
 manifest['ai_generation_note']='No AI audio generation model/service was called; sound parameters and processing code were created with Codex assistance.'
 acceptance_path=R/'records/listening_acceptance.json';acceptance=json.loads(acceptance_path.read_text()) if acceptance_path.exists() else None
 published=bool(acceptance and acceptance.get('all44_listened_and_accepted') and len(acceptance.get('minute_groups_accepted',[]))==7 and all((R.parents[1]/'audio/sfx'/Path(e['candidate']).name).exists() and sha(R.parents[1]/'audio/sfx'/Path(e['candidate']).name)==e['sha256'] and acceptance['accepted_candidate_sha256'].get(e['stem'])==e['sha256'] for e in files))
 if published:
  manifest.update(status='published_after_user_listening_acceptance',runtime_files_published=['audio/sfx/'+Path(e['candidate']).name for e in files],listening_acceptance=acceptance)
  for e in files:
   e.update(status='user_listening_accepted_technical_pass',runtime_file='audio/sfx/'+Path(e['candidate']).name,listening_evidence='records/listening_acceptance.json');e['subjective_checks']={k:('not_applicable' if v=='not_applicable' else 'accepted_by_user') for k,v in e['subjective_checks'].items()}
 dump(R/'manifest.json',manifest)
 # Small actual-signal plots, not game artwork.
 for e in files:
  p=R/e['candidate']
  with wave.open(str(p)) as w:x=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
  bins=np.array_split(x,260);top=[float(np.max(abs(b))) for b in bins if len(b)];lines=''.join(f'<line x1="{k*2}" x2="{k*2}" y1="{27-v*24:.2f}" y2="{27+v*24:.2f}"/>' for k,v in enumerate(top));svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="520" height="54" viewBox="0 0 520 54"><rect width="520" height="54" fill="#121721"/><g stroke="#78b6cd" stroke-width="1">{lines}</g></svg>';(R/'previews'/f"{e['stem']}_waveform.svg").write_text(svg)
 groups={}
 for e in files:groups.setdefault(e['id'],[]).append(e)
 cards=[]
 for id,items in groups.items():
  first=items[0];rows=[]
  for e in items:
   m=e['measurement'];lufs=m['lufs_padded_window'];rows.append(f'<div class="variant"><strong>{e["stem"]}.wav</strong><audio preload="metadata" controls src="{e["candidate"]}"></audio><img class="wave" alt="{e["stem"]}波形" src="previews/{e["stem"]}_waveform.svg"><p>{m["duration_seconds"]:.3f}s · 峰值{m["sample_peak_dbfs"]:.2f}dBFS · RMS {m["rms_dbfs"]:.1f}dBFS · 补零比较窗 {lufs:.1f}LUFS</p><a href="{e["candidate"]}" download>下载候选</a> · <a href="{e["browser_record"]}">Chrome参数记录</a></div>')
  minute='<button class="minute">1分钟变体连播</button>' if first['frequent'] else ''
  cards.append(f'<article data-id="{id}" data-frequent="{str(first["frequent"]).lower()}"><h2>{id}</h2><p>{escape(first["purpose"])}</p><p class="tag">技术通过 · 听感待验收</p>{"".join(rows)}<div class="actions"><button class="compare">本组依次试听</button>{minute}<button class="stop">停止</button></div><p class="progress" aria-live="polite"></p><label>听感记录 <select class="review"><option value="pending">未试听 /待判断</option><option value="pass">已试听，听感通过</option><option value="rework">需要重做</option></select></label><input class="note" placeholder="具体问题，例如刺耳、像激光、力度不足"><details><summary>来源与处理</summary><p>{escape("；".join(first["processing"]["recipe"]))}</p><p>来源、包络、滤波、许可及哈希见manifest；生成和技术检查不表示已听感通过。</p></details></article>')
 refhtml=''.join(f'<div class="reference"><strong>{e["id"]}</strong><audio controls preload="metadata" src="{e["file"]}"></audio><p>原游戏对照 · RMS {e["measurements"]["rms_dbfs"]:.1f}dBFS</p></div>' for e in audit['references'])
 page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>G6 神术音效 · 44条候选试听</title><style>body{margin:0;background:#121721;color:#e2e8ef;font:15px/1.6 system-ui}header{padding:28px 32px;border-bottom:1px solid #38495d}h1{margin:0;font-size:28px}h2{font-size:20px;margin:0}a{color:#9ed5f3}button,select,input{padding:8px 12px;background:#233349;border:1px solid #506982;color:white;border-radius:4px}button{cursor:pointer}input.note{display:block;box-sizing:border-box;width:100%;margin-top:10px}.toolbar{display:flex;gap:12px;align-items:center;flex-wrap:wrap}.toolbar input{min-width:240px}main{padding:24px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,500px),1fr));gap:20px}article{padding:20px;border:1px solid #34485e;background:#192332;overflow:hidden}.tag{color:#bfd4a3}.variant{border-top:1px solid #34485e;padding:12px 0}audio{display:block;width:100%;margin:10px 0}.variant p{font-size:13px;color:#b4c2d0;margin:6px 0}.wave{display:block;width:100%;height:54px}.actions{display:flex;gap:8px;flex-wrap:wrap;margin:15px 0}.progress{color:#a4d6ef;min-height:24px}.references{padding:20px 32px;display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:20px}.reference p{font-size:12px;color:#a6b8c8}summary{cursor:pointer;margin-top:12px}.muted{color:#a8b6c7}article[hidden]{display:none}</style><header><h1>G6 · 30种神术音效 /44条候选</h1><p>44条通过技术检查。用户已确认3个样音的方向；其余听感、同套音色、1分钟疲劳度仍待验收。尚未发布到游戏目录，也未Godot实测。</p><p>WAV · 单声道 · 16位 · 44100Hz · 峰值−1dBFS。频繁触发组每条≤0.3秒；觉醒1.5秒。短音效LUFS采用至少1秒补零比较窗，不能与音乐综合响度直接比较。</p><p><a href="manifest.json">完整清单与来源</a> · <a href="records/audio_audit.json">技术核验</a> · <a href="README.md">交付说明</a> · <a href="records/rejected_v01.json">首轮退回原因</a></p><div class="toolbar"><input id="filter" placeholder="按文件名或中文用途筛选"><label>试听音量 <input id="volume" type="range" min="0" max="100" value="25"></label><button id="stopAll">全部停止</button><button id="export">下载听感记录</button></div><p id="status">载入候选清单…</p></header><section class="references">'''+refhtml+'''</section><main>'''+''.join(cards)+'''</main><script>
const audioEls=[...document.querySelectorAll('audio')];const groups=[...document.querySelectorAll('article')];let volume=.25,active=null,timers=[],sessionToken=0;let started=null;
function stopAll(){sessionToken++;for(const t of timers)clearTimeout(t);timers=[];active=null;for(const a of audioEls){a.pause();a.currentTime=0}for(const p of document.querySelectorAll('.progress'))p.textContent=''}
for(const a of audioEls){a.volume=volume;a.addEventListener('play',()=>{for(const b of audioEls)if(b!==a)b.pause();if(active&&a.closest('article')!==active){sessionToken++;for(const t of timers)clearTimeout(t);timers=[];active=null}});a.addEventListener('error',()=>updateStatus())}
function updateStatus(){const candidates=[...document.querySelectorAll('article audio')],errors=candidates.filter(a=>a.error).length;document.querySelector('#status').textContent=`44/44 文件技术通过 · 7组变体 · 浏览器音频错误 ${errors} · 听感待验收`}
updateStatus();document.querySelector('#volume').oninput=e=>{volume=+e.target.value/100;for(const a of audioEls)a.volume=volume};document.querySelector('#stopAll').onclick=stopAll;document.querySelector('#filter').oninput=e=>{const q=e.target.value.trim().toLowerCase();for(const c of groups)c.hidden=!c.textContent.toLowerCase().includes(q)};
async function runGroup(card,seconds){stopAll();const token=sessionToken,items=[...card.querySelectorAll('audio')],progress=card.querySelector('.progress');active=card;started=performance.now();let i=0,plays=0;async function next(){if(token!==sessionToken)return;const elapsed=(performance.now()-started)/1000;if((seconds&&elapsed>=seconds)||(!seconds&&i>=items.length)){progress.textContent=seconds?'已完成1分钟播放；请自行记录听感判断':'本组已播放完；请自行记录听感判断';return}const a=items[i%items.length];i++;plays++;a.currentTime=0;a.volume=volume;progress.textContent=seconds?`1分钟连播 ${elapsed.toFixed(1)} /60秒 · ${plays}次`:`变体 ${i} /${items.length}`;try{await a.play();a.onended=()=>{if(token===sessionToken)timers.push(setTimeout(next,seconds?110+(i%3)*35:250))}}catch(e){progress.textContent='播放失败：'+e.message}}next();if(seconds)timers.push(setTimeout(()=>{if(token!==sessionToken)return;for(const a of items)a.pause();progress.textContent='已完成1分钟播放；请自行记录听感判断';sessionToken++},seconds*1000))}
for(const c of groups){c.querySelector('.compare').onclick=()=>runGroup(c,0);const b=c.querySelector('.minute');if(b)b.onclick=()=>runGroup(c,60);c.querySelector('.stop').onclick=stopAll;const key='G6-v02-'+c.dataset.id;try{const old=JSON.parse(localStorage.getItem(key)||'null');if(old){c.querySelector('.review').value=old.status;c.querySelector('.note').value=old.note||''}}catch{}const save=()=>localStorage.setItem(key,JSON.stringify({status:c.querySelector('.review').value,note:c.querySelector('.note').value}));c.querySelector('.review').onchange=save;c.querySelector('.note').oninput=save}
document.querySelector('#export').onclick=()=>{const result={task:'G6',version:'v02',created:new Date().toISOString(),note:'User-entered listening decisions; playback timer alone is not approval',groups:groups.map(c=>({id:c.dataset.id,status:c.querySelector('.review').value,note:c.querySelector('.note').value}))};const url=URL.createObjectURL(new Blob([JSON.stringify(result,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='G6_listening_review.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)};
</script></html>'''
 timeline=json.loads((R/'records/reel_timeline.json').read_text())
 reel=f'<details><summary>全套44条顺序试听（{timeline["duration"]:.1f}秒）</summary><audio id="reel" controls preload="metadata" src="previews/audition_reel.wav"></audio><p id="reelNow">按清单顺序播放；每条之间留0.3秒，原候选音量不变。</p></details>'
 page=page.replace('<p id="status">载入候选清单…</p>',reel+'<p id="status">载入候选清单…</p>')
 page=page.replace('const audioEls=', 'const reelTimeline='+json.dumps(timeline['segments'])+';const audioEls=')
 page=page.replace('updateStatus();document.querySelector',"document.querySelector('#reel').addEventListener('timeupdate',e=>{const s=reelTimeline.find(x=>e.target.currentTime>=x.start&&e.target.currentTime<x.end);document.querySelector('#reelNow').textContent=s?s.stem:'间隔 /播放结束'});updateStatus();document.querySelector",1)
 if published:
  page=page.replace('44条通过技术检查。用户已确认3个样音的方向；其余听感、同套音色、1分钟疲劳度仍待验收。尚未发布到游戏目录，也未Godot实测。','44条通过技术检查；用户已确认整套内容、音量、尾音和七组一分钟连播均可接受。已发布到游戏音效目录；尚未Godot实测。')
  page=page.replace('技术通过 · 听感待验收','技术通过 · 用户听感通过').replace('听感待验收`','用户听感已验收`').replace('44条候选试听','44条音效试听').replace('/44条候选','/44条成品').replace('下载候选','下载成品').replace('src="candidates/','src="approved/').replace('href="candidates/','href="approved/').replace('<option value="pass">已试听，听感通过','<option value="pass" selected>已试听，听感通过')
 (R/'gallery.html').write_text(page);(R/'records/gallery_script.js').write_text(page.split('<script>')[1].split('</script>')[0])
 table='\n'.join(f"| `{e['stem']}` | {e['measurement']['duration_seconds']:.3f} | {e['measurement']['sample_peak_dbfs']:.2f} | {e['measurement']['rms_dbfs']:.1f} | {e['measurement']['lufs_padded_window']:.1f} |" for e in files)
 readme=f'''# G6 神术音效候选（2026-10-19）

当前状态：30种、44条v02 WAV候选齐全，技术检查44/44通过。用户已听过选神、静电、觉醒三个样音并确认「方向合适，继续这一套风格」；这不是全部44条听感或一分钟疲劳测试的批准。**尚未发布到assets/audio/sfx，不声称G6完整验收。**

## 实际制作

- 已实际操作Chrome免费jsfxr，导入44套参数并生成原始WAV。前24条由网页下载链接落盘；其余20条因下载未完成，直接保存当前页面可见WAV导出链接中的数据。每条真实参数、网页状态或生成统计、来源与保存方法在 `records/browser_*.json`；原音在 `originals/`，未把离线合成冒充浏览器产出。
- 使用任务B已核验且本地保留的CC0金属、布料、玻璃、魔法等原件作分层，逐条复制到本批并保留来源及SHA256。野猪声音来自fvcalderan自制人声加EQ的CC0音效，实际通过Chrome下载，不称为野生动物实录。鸦鸣和猫叫虽核验CC0，但Chrome阻止下载，未绕过警告、未使用未取得的文件；渡鸦用短振翅，战猫用干净扑击/爪击，符合任务用途。
- Python/NumPy/FFmpeg仅作已生成/授权音频的裁切、变速、混音、滤波、包络、格式和测量，没有另外生成离线振荡器音源。没有账号注册、付款、付费API或AI音频模型调用。
- 首轮部分光系/提示音在相同峰值下RMS高于现有基准约5–9dB，退回调整能量衰减，44条首轮稿保留在 `candidates/v01/`。实际配方和v02包络目标/结果在 `records/processing_recipes.json`；不把RMS调整当作已经听辨音量。

## 实际技术检查

全部WAV为PCM16位、44100Hz、单声道；在−60dBFS阈值下起音≤10ms；样本峰值−1dBFS（容差0.01dB）；首尾样本为0，无数字满幅样本；最后10ms RMS低于−45dBFS。7组每组有3个不同哈希的变体、每条≤0.3秒；同组RMS差≤1.5dB。觉醒为1.5秒。实际值见 `records/audio_audit.json`，没有用这些指标冒充自然衰减、不刺耳或一分钟不烦的听感结论。

已复制现有lightning_01、rune_bolt、fire_burn、feather_hit、arrow_shot到 `references/` 并测量，图集提供并排播放器。图集提供44个候选播放器、波形、分组变体对照、7组一分钟连播、问题备注及用户听感记录导出。默认25%试听音量，同时仅一条播放；一分钟播放完毕只记播放完成，不自动标通过。没有保存大体积一分钟缓存。

## 清单

LUFS：短音效补零至至少1秒后用FFmpeg EBU R128测量，是明确标注的比较窗，不能当作事件内综合响度或直接与音乐LUFS比较。

| 候选 | 秒 | 样本峰值dBFS | RMS dBFS | 比较窗LUFS |
|---|---:|---:|---:|---:|
{table}

## 授权与交付边界

主生成工具 [jsfxr](https://sfxr.me/) 官方明确免费版导出WAV及无限制商用；软件Unlicense不冒充外部录音授权。复用样本为 [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds)、[Kenney RPG Audio](https://kenney.nl/assets/rpg-audio)、[rubberduck80CC0RPGSFX](https://opengameart.org/content/80-cc0-rpg-sfx) 及 [fvcalderan Boar](https://opengameart.org/content/boar-0)，CC0允许商用和改编，不表示本项目独占。每条输入来源/作者/许可/哈希在manifest，软件授权沿用项目LICENSES已核验的Python、NumPy BSD三条款、FFmpeg GPLv3。只离线使用处理软件，不把其程序嵌入游戏。

音频任务不适用RGBA、帧条、GIF及4×4地块平铺，以试听列表、测量值、原音和配方替代。只写本批assets，未改代码、场景、docs或项目配置，没有git提交/推送。

## 尚未通过

全部44条的完整主观听感、与旧音效的同套音色/感知音量、7组一分钟疲劳度，以及Godot实测仍待验收。请在图集标出需重做的组和问题；有完整听感结论前不复制到游戏自动接入目录。正式发布后再交由Claude接入并实测。

## 复现

`python3 {str(R.relative_to(R.parents[2]))}/build_audio.py`\n
`python3 {str(R.relative_to(R.parents[2]))}/audit_audio.py`\n
`python3 {str(R.relative_to(R.parents[2]))}/make_delivery.py`\n

以上只重建本批候选/测量/图集，不重新登录、下载、注册、付费或自动发布。
'''
 if published:
  readme=readme.replace('# G6 神术音效候选（2026-10-19）','# G6 神术音效交付（2026-10-19）')
  start=readme.index('当前状态：');end=readme.index('## 实际制作')
  readme=readme[:start]+'当前状态：30种、44条v02 WAV通过技术检查。用户明确确认全套内容、音量、尾音合适，并确认七组一分钟连播均可接受。44条已发布到 `assets/audio/sfx/`，正式文件、approved与候选SHA256相同。听感依据为用户答复，未声称本代理亲自听辨；尚未Godot实测。记录见 `records/listening_acceptance.json` 和 `records/publication_audit.json`。\n\n'+readme[end:]
  start=readme.index('## 尚未通过');end=readme.index('## 复现')
  readme=readme[:start]+'## 听感验收与剩余工作\n\n2026-10-19用户分别答复「已听完整套，内容和音量合适」及「已完整听过七组，均可接受」。听感接受记录绑定44个候选SHA256与全套试听文件SHA256，不由波形数据或播放计时推定。已保留27.8秒全套顺序试听和逐条来源。\n\nChrome实际加载44个成品播放器、5个原游戏对照和全套顺序试听；分组筛选、顺序播放及静电组一分钟播放结束状态已验证。该浏览器功能检查不代表本代理听过全部音频。完整用户听感确认后已发布，现在可交给Claude接入并Godot实测，验证技能触发、混音、密集同屏与音量设置。本代理未修改游戏代码或做Godot实测。\n\n'+readme[end:]
 (R/'README.md').write_text(readme)
 print('Manifest',len(files),'candidates;',len(sources),'actual inputs; gallery30groups/44players+5references')

if __name__=='__main__':main()
