from pathlib import Path
from PIL import Image
import json,hashlib,shutil

ROOT=Path(__file__).resolve().parent.parent
ASSETS=ROOT.parents[1]
plan=json.loads((ROOT/'records/production_plan.json').read_text())['assets']
reviews=json.loads((ROOT/'records/reviews.json').read_text()) if (ROOT/'records/reviews.json').exists() else{}
items=[]
for a in plan:
 review=reviews.get(a['id'],{});v=review.get('version','v01');stem=f"{a['id']}_{v}";p=ROOT/'candidates'/f'{stem}.png';gp=ROOT/'records'/f'generation_{stem}.json'
 item={**a,'version':v,'frames':1,'animation_checks':'not_applicable_static_asset','status':review.get('status','pending'),'candidate':f'candidates/{stem}.png','generation_record':f'records/generation_{stem}.json','output':f"sprites/{a['type']}/helheim/{a['id']}.png",'preview':f'previews/{stem}_review.png','tiling':f'previews/{stem}_tile4x4.png' if a.get('tile') else None,'repeat':f'previews/{stem}_repeat4.png' if a.get('axis') else None,'checks':review}
 if p.exists():
  item['technical']=json.loads((ROOT/'records'/f'check_{stem}.json').read_text());item['sha256']=hashlib.sha256(p.read_bytes()).hexdigest();item['status']=review.get('status','candidate')
 if gp.exists():
  item['provenance']=json.loads(gp.read_text());rec=item['provenance'];raw=ROOT/'originals'/f'{stem}_raw.png'
  if not raw.exists():
   choices=[q for q in (ROOT/'originals').glob(f"{a['id']}_v??_raw.png") if q.name.split('_v')[-1][:2]<=v[1:]]
   raw=sorted(choices)[-1] if choices else None
  item['raw_original']=str(raw.relative_to(ROOT)) if raw else None
  item['source']=item['raw_original'] or rec.get('source_export') or rec.get('derived_from') or rec.get('source')
  if not item['source'] or not (ROOT/item['source']).exists():raise ValueError(f"Missing source link: {a['id']}")
 if item['status']=='accepted':
  dest=ASSETS/item['output'];dest.parent.mkdir(parents=True,exist_ok=True)
  if dest.exists() and dest.read_bytes()!=p.read_bytes():
   backup=ROOT/'backups'/f"{a['id']}_before_taskE.png"
   if not backup.exists():shutil.copy2(dest,backup)
  shutil.copy2(p,dest);shutil.copy2(p,ROOT/'approved'/f"{a['id']}.png");item['approved']=f"approved/{a['id']}.png"
 items.append(item)
manifest={'task':'E','date':'2026-10-17','total':len(items),'accepted':sum(a['status']=='accepted' for a in items),'status':'art_self_check_complete' if all(a['status']=='accepted' for a in items) else'in_progress','game_tested':False,'assets':items}
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
data=json.dumps(items,ensure_ascii=False).replace('</','<\\/')
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>任务E 第2关地图素材验收</title><style>body{margin:24px;background:#121721;color:#e5eaf0;font:15px system-ui}header{position:sticky;top:0;padding:12px 0;background:#121721ef;z-index:2}h1{font-size:25px}h2{font-size:18px}a{color:#bbd8f0}select{background:#263344;color:white;padding:6px}section{padding:20px 0;border-top:1px solid #3e4958}figure{display:inline-block;vertical-align:top;margin:12px 24px 12px 0}canvas,img{image-rendering:pixelated}canvas{outline:1px solid #344454}figcaption{font-size:12px;margin-top:8px}.preview{overflow:auto}.status{color:#e1be79}.accepted{color:#9ee4b6}pre{white-space:pre-wrap;font-size:12px}p{line-height:1.7}</style><header><h1>任务 E · 亡者之船地图素材</h1><select id="filter"><option value="all">全部</option><option value="borders">边界</option><option value="ground">地块与过渡</option><option value="props">物件</option><option value="decals">贴花</option></select> <a href="manifest.json">manifest.json</a> · <a href="README.md">README.md</a></header><p>1×是实际像素大小；4×是最近邻放大。#121721背景。地块有4×4平铺，边界有4段拼接，过渡另有组装检查。此处为美术自检，未在Godot内实测。</p><p><a href="previews/perimeter.png">完整边界拼接</a> · <a href="previews/transitions_assembly.png">三类过渡组装</a> · <a href="previews/map_context.png">场景与角色合成检查</a> · <a href="previews/map_scroll.gif">静态地图滚动检查GIF</a></p><main></main><script>
const items=ITEMS,only=new URLSearchParams(location.search).get('only'),main=document.querySelector('main');
for(const a of items){if(only&&!only.split(',').includes(a.id))continue;const s=document.createElement('section');s.id=a.id;s.dataset.type=a.type;main.append(s);s.innerHTML=`<h2>${a.id}</h2><div class="status ${a.status==='accepted'?'accepted':''}">${a.status} · ${a.w}×${a.h} · ${a.technical?.colors??'?'}色</div>`;if(!a.technical)continue;const row=document.createElement('div');row.className='preview';s.append(row);const im=new Image();im.onload=()=>{for(const k of[1,4]){const f=document.createElement('figure'),c=document.createElement('canvas'),cap=document.createElement('figcaption');c.width=a.w*k;c.height=a.h*k;const ctx=c.getContext('2d');ctx.imageSmoothingEnabled=false;ctx.fillStyle='#121721';ctx.fillRect(0,0,c.width,c.height);ctx.drawImage(im,0,0,c.width,c.height);cap.textContent=k+'×';f.append(c,cap);row.append(f)}};im.src=a.candidate;const links=document.createElement('p');links.innerHTML=`<a href="${a.candidate}">PNG</a> · <a href="${a.source}">来源/原图</a> · <a href="${a.generation_record}">Prompt/加工记录</a>`+(a.tiling?` · <a href="${a.tiling}">4×4平铺</a>`:'')+(a.repeat?` · <a href="${a.repeat}">4段拼接</a>`:'');s.append(links);if(a.tiling){const tile=new Image();tile.src=a.tiling;s.append(tile)}const detail=document.createElement('details'),pre=document.createElement('pre');detail.innerHTML='<summary>自检记录</summary>';pre.textContent=JSON.stringify({checks:a.checks,technical:a.technical},null,2);detail.append(pre);s.append(detail)}document.querySelector('#filter').onchange=e=>{for(const s of main.children)s.hidden=e.target.value!=='all'&&s.dataset.type!==e.target.value};
</script></html>'''.replace('ITEMS',data)
(ROOT/'gallery.html').write_text(html)
print(json.dumps({'total':manifest['total'],'accepted':manifest['accepted'],'candidates':sum('technical'in a for a in items)}))
