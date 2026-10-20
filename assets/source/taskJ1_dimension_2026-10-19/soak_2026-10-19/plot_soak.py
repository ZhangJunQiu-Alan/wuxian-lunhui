from pathlib import Path
import json,csv,math,sys
from reportlab.graphics.shapes import Drawing,String,Line
from reportlab.graphics.charts.lineplots import LinePlot
from reportlab.graphics import renderSVG,renderPM
from reportlab.lib import colors
B=Path(__file__).resolve().parent
OUT=B/('smoke' if '--smoke' in sys.argv else 'results')
r=json.loads((OUT/'soak_result.json').read_text());rows=r['samples'];rss=list(csv.DictReader((OUT/'rss.csv').open()))
last=r['wall_seconds']/60
panels=[('Memory trend (MiB)',[(x['seconds']/60,x['static_bytes']/1048576) for x in rows],[(float(x['seconds'])/60,float(x['rss_kib'])/1024) for x in rss],['Godot static','Process RSS']),('Nodes and objects',[(x['seconds']/60,x['nodes']) for x in rows],[(x['seconds']/60,x['objects']) for x in rows],['Nodes','Objects']),('Resource count',[(x['seconds']/60,x['resources']) for x in rows],None,['Resource count'])]
d=Drawing(960,840)
d.add(String(24,812,'J combat-art unattended soak | committed 71ebcc9 | actual Godot render',fontSize=16,fillColor=colors.HexColor('#152039')))
for i,(title,a,b,names) in enumerate(panels):
 y=565-i*250; p=LinePlot();p.x=75;p.y=y;p.width=840;p.height=170;p.data=[a]+([b] if b else []);p.joinedLines=1;p.xValueAxis.valueMin=0;p.xValueAxis.valueMax=math.ceil(last);p.xValueAxis.valueStep=2
 values=[v for data in p.data for _,v in data];p.yValueAxis.valueMin=0;p.yValueAxis.valueMax=max(values)*1.1;p.yValueAxis.labelTextFormat='%.0f';p.lines[0].strokeColor=colors.HexColor('#1976a1');p.lines[0].strokeWidth=1.5
 if b:p.lines[1].strokeColor=colors.HexColor('#cf7d25');p.lines[1].strokeWidth=1
 p.xValueAxis.labels.fontSize=9;p.yValueAxis.labels.fontSize=9;d.add(p);
 for mark in [5,10,15]:
  if mark<last:d.add(Line(75+840*mark/math.ceil(last),y,75+840*mark/math.ceil(last),y+170,strokeColor=colors.lightgrey,strokeDashArray=[2,3]))
 d.add(String(75,y+195,title,fontSize=12))
 for j,name in enumerate(names):d.add(String(75+j*180,y+178,name,fontSize=9,fillColor=colors.HexColor('#1976a1') if j==0 else colors.HexColor('#cf7d25')))
 d.add(String(450,y-30,'Wall time (minutes)',fontSize=10))
d.add(String(24,8,'First 15 minutes: stationary / live AI / stationary repeat. Then drain, 60 scene cycles, final idle.',fontSize=10))
renderSVG.drawToFile(d,str(OUT/'memory_trend.svg'))
try:
 renderPM.drawToFile(d,str(OUT/'memory_trend.png'),fmt='PNG')
 print('SVG and PNG written')
except Exception as e:
 print('SVG written; optional PNG unavailable:',type(e).__name__,str(e)[:150])
