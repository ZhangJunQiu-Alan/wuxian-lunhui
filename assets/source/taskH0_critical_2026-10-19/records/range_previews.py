from pathlib import Path
from PIL import Image,ImageDraw
import runpy,math,json,sys
P=runpy.run_path(str(Path(__file__).with_name('pipeline.py')));ROOT=P['ROOT'];PLAN=P['PLAN'];BG=P['BG']

def background(task):
 folder='midgard'if task in ['H1','H2','H3']else'helheim';paths=sorted((ROOT/f'assets/sprites/ground/{folder}').glob('*.png'));t=Image.open(paths[0]).convert('RGBA');o=Image.new('RGBA',(1280,720),BG)
 for y in range(0,o.height,t.height):
  for x in range(0,o.width,t.width):o.alpha_composite(t,(x,y))
 return o

def actors(o):
 for path,xy in [('assets/sprites/characters/swordsman.png',(600,320)),('assets/sprites/enemies/dead.png',(830,330)),('assets/sprites/enemies/frost_giant.png',(430,290))]:
  if(ROOT/path).exists():o.alpha_composite(Image.open(ROOT/path).convert('RGBA'),xy)

def ring(scene,source,radius,band=26,gaps=None):
 # Preview-only polar placement and code-geometry mask; never writes final sprites.
 center=(640,360);w,h=source.size;layer=Image.new('RGBA',scene.size);pix=layer.load();s=source.load();gaps=gaps or[]
 for yy in range(max(0,int(center[1]-radius-band)),min(scene.height,int(center[1]+radius+band+1))):
  for xx in range(max(0,int(center[0]-radius-band)),min(scene.width,int(center[0]+radius+band+1))):
   dx=xx-center[0];dy=yy-center[1];rr=math.hypot(dx,dy)
   if abs(rr-radius)>=band/2:continue
   angle=math.atan2(dy,dx)
   if any(abs((angle-g+math.pi)%(2*math.pi)-math.pi)<.42 for g in gaps):continue
   u=int((angle*radius)%w);v=int((rr-radius)/band*h+h/2)
   if 0<=v<h:pix[xx,yy]=s[u,v]
 scene.alpha_composite(layer)


def build(task):
 assets=[a for a in PLAN if a['task']==task];r=ROOT/assets[0]['source_root'];m=json.loads((r/'manifest.json').read_text());generated=[]
 for row in m['files']:
  a=row;id=a['id'];im=Image.open(ROOT/a['target']).convert('RGBA');frame=im.crop((a['w'],0,a['w']*2,a['h']))if a['frames']>1 else im
  o=background(task);d=ImageDraw.Draw(o);extra=''
  if id in ['hati_howl_wave','garm_howl_wave']:
   radius=280 if task=='H2' else 260;f=frame.resize((radius*2,radius*2),Image.Resampling.NEAREST);o.alpha_composite(f,(640-radius,360-radius));d=ImageDraw.Draw(o);d.ellipse((640-radius,360-radius,640+radius,360+radius),outline='#e8bd72',width=1);extra=f'code radius={radius}; amber outline=geometry only'
  elif id=='skoll_howl':
   radius=162;f=frame.resize((radius*2,radius*2),Image.Resampling.NEAREST);o.alpha_composite(f,(640-radius,360-radius));extra='example visual radius=34+0.8*160=162; no damage ring added'
  elif id=='hrym_wave_band':
   ring(o,frame,240,26,[.35,.35+math.pi]);d=ImageDraw.Draw(o)
   for g in[.35,.35+math.pi]:
    d.line([(640+180*math.cos(g),360+180*math.sin(g)),(640+290*math.cos(g),360+290*math.sin(g))],fill='#62d59a',width=3)
   extra='preview polar layout r240 BAND26; two gaps +/-0.42rad; green=safe opening'
  elif id=='hrym_shield_arc':
   size=116;f=frame.resize((size,size),Image.Resampling.NEAREST);o.alpha_composite(f,(640-size//2,360-size//2));d=ImageDraw.Draw(o);d.arc((582,302,698,418),-math.degrees(1.3),math.degrees(1.3),fill='#e8bd72',width=1);extra='facing RIGHT; code front +/-1.3rad; rear must remain clear'
  elif id=='nidhogg_poison_breath':
   f=frame.resize((300,200),Image.Resampling.NEAREST);o.alpha_composite(f,(628,260));d=ImageDraw.Draw(o);pts=[(640,360)]+[(640+300*math.cos(-.6+i*.1),360+300*math.sin(-.6+i*.1))for i in range(13)]+[(640,360)];d.line(pts,fill='#e8bd72',width=1);extra='breath radius300 half-angle0.6; amber outline; final code must clip fan'
  elif id=='nidhogg_emerge_burst':
   f=frame.resize((200,150),Image.Resampling.NEAREST);o.alpha_composite(f,(540,285));d=ImageDraw.Draw(o);d.ellipse((540,260,740,460),outline='#e8bd72');extra='emerge radius100; impact center(640,360); not an ice ring'
  elif id=='hel_domain_edge':
   ring(o,frame,300,24);d=ImageDraw.Draw(o);d.ellipse((340,60,940,660),outline='#e8bd72');extra='circle r300 shown for fit preview only; game radius1000->380; mask original boundary'
  elif id in['hel_life_ground','hel_death_ground']:
   other='hel_death_ground'if id=='hel_life_ground'else'hel_life_ground';p=ROOT/'assets/sprites/effects/bosses'/f'{other}.png'
   if not p.exists():continue
   left=frame if id=='hel_life_ground'else Image.open(p).convert('RGBA');right=Image.open(p).convert('RGBA')if id=='hel_life_ground'else frame
   for yy in range(0,720,128):
    for xx in range(0,1280,128):o.alpha_composite(left if xx<640 else right,(xx,yy))
   d=ImageDraw.Draw(o);d.line((640,0,640,720),fill='#d9d9e7',width=3);extra='left life / right death; this composite is not the game field'
  elif id=='garm_chain_link':
   for k in range(32):
    x=400+k*16;y=360+14*math.sin(k/31*math.pi);rot=math.degrees(math.atan2(14*math.pi/496*math.cos(k/31*math.pi),1));f=frame.rotate(-rot,expand=True,resample=Image.Resampling.NEAREST);o.alpha_composite(f,(int(x-f.width/2),int(y-f.height/2)))
   extra='16x8 links along original sag14 path; no whole-chain stretch'
  else:continue
  actors(o);d=ImageDraw.Draw(o);d.rectangle((0,0,1280,48),fill=BG);d.text((12,8),id+' | '+extra,fill='white');d.text((12,27),'OFFLINE COMPOSITE - NOT GODOT ACCEPTANCE',fill='#edc991');path=r/'previews'/f'{id}_{a["version"]}_range.png';o.convert('RGB').save(path);generated.append(str(path.relative_to(r)))
 if generated:
  page=r/'gallery.html';s=page.read_text();s=s.replace('</html>','<h2>范围与遮罩离线合成（不是游戏验收）</h2>'+''.join('<p>'+Path(x).name+'</p><img src="'+x+'">'for x in generated)+'</html>');page.write_text(s)
 P['save'](r/'records/range_preview_record.json',{'task':task,'method':'source PNG composited on project terrain with code constants as mask guides; offline preview only','files':generated,'game_test':'not_performed'})
 print(task,'range composites',len(generated))
if __name__=='__main__':
 for task in sys.argv[1:]:build(task)
