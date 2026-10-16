from pathlib import Path
from PIL import Image,ImageDraw
import json
r=Path(__file__).resolve().parents[1];near='#25cde8';far='#ec5fa8';wood='#bc8551'
def build(kind,count):
 cols=3 if count==6 else 2;out=Image.new('RGB',(cols*64,128),'#121721');d=ImageDraw.Draw(out)
 walks=[((38,47,44,59),(25,47,20,59)),((31,48,30,59),(27,46,24,52)),((25,47,20,59),(38,47,43,59)),((24,48,19,59),(38,47,44,59)),((27,46,24,52),(33,48,34,59)),((38,47,43,59),(25,48,20,59))]
 for i in range(count):
  ox=i%cols*64;oy=i//cols*64
  def line(ps,color,width=1):d.line([(x+ox,y+oy) for x,y in ps],fill=color,width=width)
  d.rectangle((ox,oy,ox+63,oy+63),outline='#3c4654');d.text((ox+2,oy+2),str(i+1),fill='white');line([(3,60),(61,60)],'#576171')
  d.ellipse((ox+28,oy+14,ox+36,oy+22),outline='#c0c8d4');line([(32,22),(32,39)],'#c0c8d4',2);line([(28,27),(36,27)],'#c0c8d4')
  if kind=='walk':
   a,b=walks[i];line([(30,39),a[:2],a[2:]],near,2);line([(34,39),b[:2],b[2:]],far,2);line([(28,27),(25,35),(23,40)],near);line([(36,27),(39,33),(42,35)],far)
  elif kind=='blades':
   line([(30,39),(26,48),(22,59)],near,2);line([(34,39),(38,48),(41,59)],far,2)
   na=[[(28,27),(25,35),(26,39)],[(28,27),(34,36),(45,37)],[(28,27),(26,35),(28,39)],[(28,27),(24,35),(26,39)],[(28,27),(25,35),(27,39)],[(28,27),(25,35),(26,39)]][i]
   fa=[[(36,27),(39,31),(40,35)],[(36,27),(38,28),(38,29)],[(36,27),(39,31),(40,35)],[(36,27),(40,28),(45,28)],[(36,27),(38,32),(40,35)],[(36,27),(39,31),(40,35)]][i]
   line(fa,far,2);line(na,near,2)
   tip1=(55,37) if i==1 else (36,40);tip2=(40,20) if i==1 else (55,28) if i==3 else (50,34)
   line([na[-1],tip1],'#eeeeee');line([fa[-1],tip2],'#eeeeee')
  else:
   line([(30,39),(26,49),(24,59)],near,2);line([(34,39),(38,49),(41,59)],far,2)
   staff=[((44,3),(44,50)),((44,7),(44,54)),((47,12),(47,59)),((27,12),(27,59))][i];line(staff,wood,2)
   hands=[((44,26),(44,34)),((44,30),(44,38)),((47,34),(47,42)),((27,34),(41,40))][i]
   line([(28,27),(31,32),hands[0]],near,2);line([(36,27),(40,33),hands[1]],far,2)
 out.resize((out.width*6,out.height*6),Image.Resampling.NEAREST).save(r/'references'/f'{kind}_pose_guide.png')
for kind,n in [('walk',6),('blades',6),('staff',4)]:build(kind,n)
rej=[{'candidate':'candidates/gunslinger_move_v01.png','status':'rejected','reason':'Same leg repeats forward; near/far boots not visibly alternating.'},{'candidate':'candidates/assassin_attack_v01.png','status':'rejected','reason':'Both thrusts use same arm; fourth blade violates margin/clips.'},{'candidate':'candidates/mage_attack_v01.png','status':'rejected','reason':'Raised staff becomes a short wand; rigid weapon length not preserved.'}]
(r/'records/C_wave1_rejections.json').write_text(json.dumps(rej,ensure_ascii=False,indent=2)+'\n')
cs=json.loads((r/'records/candidates.json').read_text())
for c in cs:
 for j in rej:
  if c['candidate']==j['candidate']:c['status']='rejected';c['rejection_reason']=j['reason']
(r/'records/candidates.json').write_text(json.dumps(cs,ensure_ascii=False,indent=2)+'\n')
