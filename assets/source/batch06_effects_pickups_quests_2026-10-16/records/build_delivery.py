from pathlib import Path
from PIL import Image, ImageDraw
import json, hashlib, html, shutil

ROOT=Path(__file__).resolve().parent.parent
ASSETS=ROOT.parents[1]
PLAN=json.loads((ROOT/'records/production_plan.json').read_text())['assets']
BG=(18,23,33)

def build():
    reviews=json.loads((ROOT/'records/reviews.json').read_text()) if (ROOT/'records/reviews.json').exists() else {}
    items=[]
    for a in PLAN:
        decision=reviews.get(a['id'],{})
        version=decision.get('version','v01')
        stem=f"{a['id']}_{version}"
        candidate=ROOT/'candidates'/f'{stem}.png'
        item={**a,'version':version,'status':'pending','source':f'originals/{stem}_raw.png','generation_record':f'records/generation_{stem}.json','candidate':f'candidates/{stem}.png','output':f"sprites/{a['folder']}/{a['id']}.png",'checks':decision}
        record_path=ROOT/item['generation_record']
        if record_path.exists():
            record=json.loads(record_path.read_text());item['tools']=record.get('tool','builtin image_gen');item['provenance']=record
        item['fps']=8 if a['frames']>1 else None
        item['game_fps']=16 if a['id']=='einherjar_attack' else item['fps']
        item['pivot']=[a['w']//2,a['h']-2] if a['anchor']=='bottom' else [a['w']//2,a['h']//2]
        if a['id']=='rune_missile':item['pivot']=[21,15]
        if a['id']=='raven':item['pivot']=[24,15]
        item['source_kind']='assembled from three separately generated originals; see provenance.sources' if a['id']=='raven' and version=='v04' else 'generated original or documented editor export'
        if candidate.exists():
            report=json.loads((ROOT/'records'/f'normalization_{stem}.json').read_text())
            item.update({'status':decision.get('status','candidate'),'technical':report,'preview':f'previews/{stem}_review.png','gif':f'previews/{stem}.gif' if a['frames']>1 else None})
        if decision.get('status')=='accepted':
            dest=ASSETS/item['output'];dest.parent.mkdir(parents=True,exist_ok=True)
            if dest.exists() and dest.read_bytes()!=candidate.read_bytes():
                backup=ROOT/'backups'/f"{a['id']}_before_batch06.png"
                if not backup.exists():shutil.copy2(dest,backup)
            shutil.copy2(candidate,dest);shutil.copy2(candidate,ROOT/'approved'/f"{a['id']}.png")
            item['approved']=f"approved/{a['id']}.png"
            item['sha256']=hashlib.sha256(candidate.read_bytes()).hexdigest()
        items.append(item)
    manifest={'batch':6,'date':'2026-10-16','scope':'Effects, pickups, quest props and two quest-character animations; 34 outputs','status':'art_self_check_complete' if all(i['status']=='accepted' for i in items) else 'in_progress','accepted':sum(i['status']=='accepted' for i in items),'total':len(items),'tool':'OpenAI built-in image_gen, explicitly approved by user; Pillow formatting and QA only','license':'../../LICENSES.md','game_test':'Not performed by this art agent; code integration and Godot verification belong to Claude','tiling_4x4':{'applicable':False,'reason':'This batch has no ground tiles. Rings, projectiles, items and characters are transparent standalone sprites; do not tile them.'},'assets':items}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
    data=json.dumps(items,ensure_ascii=False).replace('</','<\\/')
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>第6批 · 特效与支线物件验收</title><style>
    *{box-sizing:border-box}body{margin:24px;background:#121721;color:#e5eaf0;font:15px system-ui}h1{font-size:24px}p{max-width:1100px;line-height:1.7}a{color:#c5def8}button{background:#2d3b4d;color:#fff;border:1px solid #60728a;padding:6px 12px;cursor:pointer}section{border-top:1px solid #465163;padding:18px 0;margin-top:16px}h2{font-size:18px}canvas,img{image-rendering:pixelated;vertical-align:top}canvas{background:#121721;outline:1px solid #364050}figure{display:inline-block;margin:12px 24px 8px 0}figcaption{font-size:12px;margin:8px 0}.preview{overflow:auto}.status{font-size:13px;color:#f8d37b}.accepted{color:#9fe3bb}.controls{margin:10px 0;display:flex;gap:8px;align-items:center;flex-wrap:wrap}details{margin-top:12px;max-width:1100px;overflow:auto}pre{white-space:pre-wrap;font-size:12px}.static4{max-width:none}header{position:sticky;top:0;background:#121721ed;padding:10px 0;z-index:2}.bad{color:#faac9b}
    </style><header><h1>第6批 · 特效、拾取物与支线物件</h1><button id="pause">全部暂停</button> <button id="step">全部下一帧</button> <a href="manifest.json">manifest.json</a> · <a href="README.md">README.md</a></header>
    <p>统一深色背景 #121721；左侧1倍为实际游戏像素大小，右侧4倍为最近邻放大。动画按8帧/秒预览，攻击在游戏中建议16帧/秒。非循环特效的自动重播仅供检查；单次播放与锚点见 manifest。无地块，4×4平铺检查不适用。本页只反映美术自检，不代表游戏实测。</p><main id="main"></main><script>
    const assets=ASSET_DATA, running=[], main=document.getElementById('main'); let allPlay=true;
    const only=new URLSearchParams(location.search).get('only');
    for(const a of assets){if(only&&!only.split(',').includes(a.id))continue;const s=document.createElement('section');s.id=a.id;const accepted=a.status==='accepted';s.innerHTML=`<h2>${a.label} <code>${a.id}</code></h2><div class="status ${accepted?'accepted':''}">${a.status} · ${a.w}×${a.h} × ${a.frames} · ${a.technical?.colors??'?'}色 · ${a.loop?'循环':'单次/静态'} · 锚点 ${a.anchor}</div>`;main.append(s);
    if(!a.technical){s.insertAdjacentHTML('beforeend','<p>尚无候选图。</p>');continue}
    const row=document.createElement('div');row.className='preview';s.append(row);const canvases=[];
    for(const k of [1,4]){const f=document.createElement('figure'),c=document.createElement('canvas');c.width=a.w*k;c.height=a.h*k;const caption=document.createElement('figcaption');caption.textContent=k+'× · #121721';f.append(c,caption);row.append(f);canvases.push(c)}
    const ctrl=document.createElement('div');ctrl.className='controls';s.append(ctrl);const toggle=document.createElement('button'),step=document.createElement('button'),label=document.createElement('span');toggle.textContent='暂停';step.textContent='下一帧';ctrl.append(toggle,step,label);
    const links=document.createElement('span');links.innerHTML=` <a href="${a.candidate}">PNG帧条/静态</a> · <a href="${a.source}">生成原图</a> · <a href="${a.generation_record}">Prompt及来源</a>`+(a.gif?` · <a href="${a.gif}">8fps 4× GIF</a>`:'');ctrl.append(links);
    const im=new Image(), state={a,frame:0,play:true,draw:()=>{if(!im.complete||!im.naturalWidth)return;for(const c of canvases){const ctx=c.getContext('2d'),k=c.width/a.w;ctx.imageSmoothingEnabled=false;ctx.fillStyle='#121721';ctx.fillRect(0,0,c.width,c.height);ctx.drawImage(im,state.frame*a.w,0,a.w,a.h,0,0,a.w*k,a.h*k)}label.textContent=`帧 ${state.frame+1}/${a.frames}`}};im.onload=state.draw;im.src=a.candidate;running.push(state);toggle.onclick=()=>{state.play=!state.play;toggle.textContent=state.play?'暂停':'播放'};step.onclick=()=>{state.play=false;toggle.textContent='播放';state.frame=(state.frame+1)%a.frames;state.draw()};if(a.frames===1){toggle.disabled=true;step.disabled=true}
    const d=document.createElement('details'),sum=document.createElement('summary'),pre=document.createElement('pre');sum.textContent='自检细节与技术检查';pre.textContent=JSON.stringify({checks:a.checks,technical:a.technical},null,2);d.append(sum,pre);s.append(d)}
    document.getElementById('pause').onclick=()=>{allPlay=!allPlay;document.getElementById('pause').textContent=allPlay?'全部暂停':'全部播放'};document.getElementById('step').onclick=()=>{allPlay=false;document.getElementById('pause').textContent='全部播放';for(const s of running){s.frame=(s.frame+1)%s.a.frames;s.draw()}};setInterval(()=>{if(allPlay)for(const s of running)if(s.play){s.frame=(s.frame+1)%s.a.frames;s.draw()}},125);
    </script></html>'''.replace('ASSET_DATA',data)
    (ROOT/'gallery.html').write_text(page)
    print(json.dumps({'accepted':manifest['accepted'],'total':len(items),'candidate':sum('technical' in a for a in items)}))

if __name__=='__main__':build()
