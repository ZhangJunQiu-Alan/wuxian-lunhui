from pathlib import Path
from PIL import Image
import json,html
r=Path(__file__).resolve().parents[1]
items=json.loads((r/'records/candidates.json').read_text());m=json.loads((r/'manifest.json').read_text());passed=[];other=[];latest={}
for j in items:
    im=Image.open(r/j['candidate']).convert('RGBA');w,h=j['frame_size'];n=j['frames'];frames=[im.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
    contact=Image.new('RGB',im.size,'#121721');enlarged=[]
    for i,f in enumerate(frames):
        bg=Image.new('RGBA',(w,h),'#121721');bg.alpha_composite(f);contact.paste(bg.convert('RGB'),(i*w,0));enlarged.append(bg.resize((w*4,h*4),Image.Resampling.NEAREST).convert('RGB'))
    stem=Path(j['candidate']).stem;contact.save(r/'previews'/f'{stem}_contact_1x.png');contact.resize((contact.width*4,contact.height*4),Image.Resampling.NEAREST).save(r/'previews'/f'{stem}_contact_4x.png')
    durations=[120 if i%2==0 else 130 for i in range(n)];enlarged[0].save(r/'previews'/f'{stem}_8fps.gif',save_all=True,append_images=enlarged[1:],duration=durations,loop=0,disposal=2)
    card=f'<article><h2>{html.escape(j["id"])} / {stem}</h2><p>{html.escape(j["status"])}</p><p>原站姿</p><img loading="lazy" src="references/{j["character"]}.png"><p>1×全帧</p><img loading="lazy" src="previews/{stem}_contact_1x.png"><p>4×全帧</p><div class="wide"><img loading="lazy" src="previews/{stem}_contact_4x.png"></div><p>8fps /4倍循环预览</p><img loading="lazy" src="previews/{stem}_8fps.gif"></article>'
    (passed if j['status']=='art_self_check_passed_pending_game_review' else other).append(card)
    if j['status'] not in ['rejected','superseded_not_selected']:latest[j['id']]=j
state='美术自检完成' if m['approved_assets']==7 else '进行中'
(r/'gallery.html').write_text('<!doctype html><meta charset="utf-8"><title>第5批第1关敌人行走</title><style>body{background:#121721;color:#e0e7ef;font:16px system-ui;margin:24px}a{color:#9bd5ee}article{border-top:1px solid #49515e;padding:18px 0}img{image-rendering:pixelated}.wide{overflow:auto}</style><h1>第5批第1关敌人行走 · '+state+'</h1><p>'+str(m['approved_assets'])+'/7项美术自检通过。地块4×4平铺不适用。未在游戏实测。</p><p><a href="manifest.json">manifest</a> · <a href="README.md">README</a> · <a href="records/motion_review.html">逐帧播放审核</a> · <a href="records/final_audit.json">最终文件核对</a></p><img src="previews/handoff_overview.png" alt="第1关7条行走总览">'+''.join(passed)+'<details><summary>其他候选与中间稿</summary>'+''.join(other)+'</details>')
data=[{'id':j['id'],'path':'../'+j['candidate'],'reference':'../references/'+j['character']+'.png','n':j['frames'],'w':j['frame_size'][0],'h':j['frame_size'][1]} for j in latest.values()]
page='''<!doctype html><meta charset="utf-8"><title>第5批行走逐帧审核</title><style>body{background:#121721;color:#e0e7ef;font:14px sans-serif}section{display:inline-block;vertical-align:top;width:460px;margin:8px}canvas,img{image-rendering:pixelated}canvas{margin:3px}button{margin:4px}</style><h1>第5批 第1关敌人行走 · 1× /4× /8fps</h1><p>站姿对照、循环和暂停逐帧。仅素材检查，未游戏实测。</p><main></main><script>const jobs=DATA;
for(const j of jobs){const s=document.createElement('section');s.innerHTML='<h2>'+j.id+'</h2>';const ref=new Image();ref.src=j.reference;s.append(ref);const image=new Image();image.src=j.path;let k=0,run=true;const small=document.createElement('canvas');small.width=j.w;small.height=j.h;const big=document.createElement('canvas');big.width=j.w*4;big.height=j.h*4;const label=document.createElement('span');const paint=()=>{for(const c of[small,big]){const x=c.getContext('2d');x.imageSmoothingEnabled=false;x.clearRect(0,0,c.width,c.height);x.drawImage(image,k*j.w,0,j.w,j.h,0,0,c.width,c.height)}label.textContent='帧 '+(k+1)+' / '+j.n};image.onload=paint;s.append(small,big,label);for(const[t,fn]of[['暂停/继续',()=>run=!run],['下一帧',()=>{run=false;k=(k+1)%j.n;paint()}]]){const b=document.createElement('button');b.textContent=t;b.onclick=fn;s.append(b)}setInterval(()=>{if(run&&image.complete){k=(k+1)%j.n;paint()}},125);document.querySelector('main').append(s)}
</script>'''
(r/'records/motion_review.html').write_text(page.replace('DATA',json.dumps(data)))
print('approved',len(passed),'other',len(other))
