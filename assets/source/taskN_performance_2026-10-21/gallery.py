from pathlib import Path
from html import escape
import json
p=Path(__file__).resolve().parent
sets=[('normal_realtime','实时正常伤害流程','真实窗口、正式刷怪，最终胜败见JSON。'),('final_extreme','最终高血量压力','350活动敌人，强制百万HP；性能未通过，不代表自然刷怪。'),('reachable','正常HP合成补怪原型','每秒补满350，额外制造大量击杀/掉落；不等同自然刷怪。')]
html=['<!doctype html><meta charset="utf-8"><title>2026-10-21 运行续验</title><style>body{font:16px system-ui;background:#111a28;color:#dce6f4;margin:32px auto;max-width:1400px;padding:0 24px}a{color:#87cce8}h1{font-size:30px}h2{margin-top:36px}p{line-height:1.65;color:#b3c2d5}img{max-width:100%;display:block;background:#080b10}figure{margin:0}figcaption{padding:8px 0;font-size:14px}section .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:20px}input{padding:12px;width:min(500px,90%);background:#1b293c;color:white;border:1px solid #60748c;margin:20px 0}#trend{max-width:1000px}</style><h1>性能与正常伤害流程续验 · 2026-10-21</h1><p>功能回归通过与密集性能通过分开判断。静音运行不提供听感验收；机器人通关不代表真人、低成长或全角色通过。截图可供复核，不宣称全部逐张目视通过。</p><p><a href="README.md">README</a> · <a href="RESULTS.md">详细结果</a> · <a href="summary.json">结构化汇总</a> · <a href="integration.md">接入契约</a> · <a href="results/regression_summary.json">11组回归</a></p><a href="results/performance_trend.png"><img id="trend" src="results/performance_trend.png"></a><input id="search" placeholder="筛选截图文件名">']
count=0
for folder,title,caption in sets:
 images=sorted((p/'results'/folder).glob('*.png'))
 html.append('<section><h2>'+escape(title)+'</h2><p>'+escape(caption)+'</p><div class="grid">')
 for file in images:
  rel=file.relative_to(p).as_posix();label=folder+'/'+file.name;count+=1
  html.append(f'<figure data-label="{escape(label)}"><a href="{escape(rel)}"><img loading="lazy" src="{escape(rel)}"></a><figcaption>{escape(label)}</figcaption></figure>')
 html.append('</div></section>')
html.append('<script>document.querySelector("#search").addEventListener("input",e=>{let q=e.target.value.toLowerCase();document.querySelectorAll("figure").forEach(f=>f.hidden=!f.dataset.label.toLowerCase().includes(q));});</script>')
(p/'gallery.html').write_text('\n'.join(html))
print('gallery images',count)
