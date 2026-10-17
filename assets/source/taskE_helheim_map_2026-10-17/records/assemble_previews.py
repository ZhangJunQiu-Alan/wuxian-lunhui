from pathlib import Path
from PIL import Image,ImageDraw
import json,sys
import pipeline as p
R=p.ROOT
VERS={'sunken_tree':'v02','bone_path':'v03','river_ice':'v07','river_02':'v02','gjoll_bridge':'v03','world_root_arch':'v03','soul_lamp_lit':'v04','hoof_tracks_01':'v02','hel_wall_01':'v02','fog_abyss_01':'v02','gnipa_cave':'v03',**{f'border_corner_{d}':'v02' for d in ['ne','nw','se','sw']}}
def im(id,v=None):return Image.open(R/'candidates'/f'{id}_{v or VERS.get(id,"v01")}.png').convert('RGBA')
def attach(a,b,side,n=72):
 if side=='left':a=a.transpose(Image.Transpose.FLIP_LEFT_RIGHT);b=b.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 if side=='bottom':a=a.transpose(Image.Transpose.TRANSPOSE);b=b.transpose(Image.Transpose.TRANSPOSE)
 if side=='top':a=a.rotate(270,expand=True);b=b.rotate(270,expand=True)
 a,cut=p.overlap_cut(a,b,n)
 if side=='left':a=a.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 if side=='bottom':a=a.transpose(Image.Transpose.TRANSPOSE)
 if side=='top':a=a.rotate(90,expand=True)
 return a,cut
a=Image.open(R/'originals/river_ice_v07_raw.png').convert('RGBA').resize((64,64),Image.Resampling.NEAREST);a.putalpha(255);a=p.quantize(a,p.PLAN['river_ice']);b=im('river_ice','v05');cuts={}
for side,box in [('left',(0,0,12,64)),('right',(52,0,64,64)),('top',(0,0,64,12)),('bottom',(0,52,64,64))]:a,cuts[side]=attach(a,b.crop(box),side,12)
for box in [(0,0,4,64),(60,0,64,64),(0,0,64,4),(0,60,64,64)]:a.paste(b.crop(box),box[:2])
a.save(R/'candidates/river_ice_v07.png');p.views(p.PLAN['river_ice'],'v07');rec=json.loads((R/'records/generation_river_ice_v07.json').read_text());rec.update(formatting={'operation':'Whole64nearest sizing, darkpalettequantization;12pxsource-pixel mincutedgeports fromseamlessv05, exact4pxedgepreserved','cut_paths':cuts});(R/'records/generation_river_ice_v07.json').write_text(json.dumps(rec,indent=2))
ports={
 'nw':[('right','dark_sea_01',(184,0,256,192)),('bottom','fog_abyss_01',(0,184,192,256))],
 'ne':[('left','dark_sea_01',(0,0,72,192)),('bottom','hel_wall_01',(0,184,192,256))],
 'sw':[('right','ice_cliff_01',(184,0,256,192)),('top','fog_abyss_01',(0,0,192,72))],
 'se':[('left','ice_cliff_01',(0,0,72,192)),('top','hel_wall_01',(0,0,192,72))]}
cropboxes={'nw':(0,0,128,112),'ne':(96,0,192,112),'sw':(0,96,96,192),'se':(96,96,192,192)}
for d,ps in ports.items():
 id='border_corner_'+d;a=im(id,'v01').crop(cropboxes[d]).resize((192,192),Image.Resampling.NEAREST);cuts={};pieces={}
 for side,src,box in ps:
  b=im(src).crop(box);pieces[side]=b;a,cuts[side]=attach(a,b,side)
 for side,b in pieces.items():
  if side=='left':a.paste(b.crop((0,0,8,192)),(0,0))
  if side=='right':a.paste(b.crop((64,0,72,192)),(184,0))
  if side=='top':a.paste(b.crop((0,0,192,8)),(0,0))
  if side=='bottom':a.paste(b.crop((0,64,192,72)),(0,184))
 a.save(R/'candidates'/f'{id}_v02.png');p.views(p.PLAN[id],'v02');rec=json.loads((R/'records'/f'generation_{id}_v01.json').read_text());rec.update(version='v02',source_crop=cropboxes[d],resize=[192,192],connector_ports=ps,cut_paths=cuts,operation='Whole corner crop/nearest fit to match strip thickness; existing source pixels only, minimum-error overlap cuts for72px connectorports; endpoint8px strips copied exactly from neighboring repeating boundary. No new pixels painted.');(R/'records'/f'generation_{id}_v02.json').write_text(json.dumps(rec,indent=2))
a=im('gnipa_cave','v02');cuts={};s=im('ice_cliff_01')
for side,box in [('left',(0,0,72,192)),('right',(184,0,256,192))]:a,cuts[side]=attach(a,s.crop(box),side)
a.paste(s.crop((0,0,8,192)),(0,0));a.paste(s.crop((248,0,256,192)),(248,0));a.save(R/'candidates/gnipa_cave_v03.png');p.views(p.PLAN['gnipa_cave'],'v03');rec=json.loads((R/'records/generation_gnipa_cave_v02.json').read_text());rec.update(version='v03',cut_paths=cuts,operation='Match both cave endpoints with existing southcliff source pixels using72px mincutports; outerpadding crop retained. No new pixels painted.');(R/'records/generation_gnipa_cave_v03.json').write_text(json.dumps(rec,indent=2))
a=im('river_02','v01');b=im('river_01');cuts={}
for side,box in [('left',(0,0,16,64)),('right',(48,0,64,64)),('top',(0,0,64,16)),('bottom',(0,48,64,64))]:a,cuts[side]=attach(a,b.crop(box),side,16)
for box in [(0,0,4,64),(60,0,64,64),(0,0,64,4),(0,60,64,64)]:a.paste(b.crop(box),box[:2])
a.save(R/'candidates/river_02_v02.png');p.views(p.PLAN['river_02'],'v02');rec=json.loads((R/'records/generation_river_02_v01.json').read_text());rec.update(version='v02',cut_paths=cuts,operation='Source-pixel 16px minimum-error texture overlap with river01 on4sides, exact4px edgeports; preserves icechips in centralvariant, compatible river01/02mix.');(R/'records/generation_river_02_v02.json').write_text(json.dumps(rec,indent=2))
p.transitions()
def tiled(id,w,h):
 t=im(id);o=Image.new('RGBA',(w,h))
 for y in range(0,h,t.height):
  for x in range(0,w,t.width):o.alpha_composite(t,(x,y))
 return o
stone=Image.open(R/'refs/stone_01.png').convert('RGBA')
def base(w,h):
 o=Image.new('RGBA',(w,h))
 for y in range(0,h,64):
  for x in range(0,w,64):o.alpha_composite(stone,(x,y))
 return o
o=base(1152,1152)
for d,xy in [('nw',(0,0)),('ne',(960,0)),('sw',(0,960)),('se',(960,960))]:o.alpha_composite(im('border_corner_'+d),xy)
for z in range(3):
 o.alpha_composite(im('dark_sea_01'),(192+z*256,0));o.alpha_composite(im('fog_abyss_01'),(0,192+z*256));o.alpha_composite(im('hel_wall_01'),(960,192+z*256));o.alpha_composite(im('gnipa_cave' if z==1 else'ice_cliff_01'),(192+z*256,960))
o.save(R/'previews/perimeter.png')
o=base(1152,448);d=ImageDraw.Draw(o)
# Eight-neighbor masks demonstrate both convex and concave corners.
cells={(x,y) for y in range(1,6) for x in range(1,5)}-{(3,1),(4,1),(4,2)}
for n,fam in enumerate(['river','bone_path','marsh']):
 tex='river_01' if fam=='river' else fam
 for x,y in cells:
  o.alpha_composite(im(tex),(n*384+x*64,y*64))
 for x in range(0,6):
  for y in range(0,7):
   if(x,y)in cells:continue
   e=(x+1,y)in cells;w=(x-1,y)in cells;s=(x,y+1)in cells;nn=(x,y-1)in cells
   if s and e:key='inner_se'
   elif s and w:key='inner_sw'
   elif nn and e:key='inner_ne'
   elif nn and w:key='inner_nw'
   elif s:key='n'
   elif nn:key='s'
   elif e:key='w'
   elif w:key='e'
   else:
    opts=[('outer_nw',(x+1,y+1)),('outer_ne',(x-1,y+1)),('outer_sw',(x+1,y-1)),('outer_se',(x-1,y-1))];key=next((k for k,pos in opts if pos in cells),None)
   if key:o.alpha_composite(im(fam+'_edge_'+key),(n*384+x*64,y*64))
 d.text((n*384+8,8),fam,fill='white')
o.save(R/'previews/transitions_assembly.png')
o=base(1280,720)
mix=Image.new('RGBA',(256,256))
for y in range(4):
 for x in range(4):mix.paste(im('river_01' if(x+y)%2==0 else'river_02'),(x*64,y*64))
mix.save(R/'previews/river_mix_4x4.png')
for y in range(3):
 for x in range(20):o.alpha_composite(im('river_01' if(x+y)%2==0 else'river_02'),(x*64,80+y*64))
o.alpha_composite(tiled('plaza',576,320),(384,336));o.alpha_composite(tiled('marsh',320,384),(0,336));o.alpha_composite(tiled('bone_path',1280,64),(0,272))
placements={'gjoll_bridge':(480,8),'bridge_booth':(720,265),'soul_lamp':(400,390),'soul_lamp_lit':(850,390),'cane':(580,520),'straw_hat':(620,515),'wine_jug':(660,520),'wooden_horse':(700,520),'nail_pier':(1040,30),'nail_basket':(1170,275),'cargo_crate':(1110,285),'shield_spear':(1200,280),'hall_pillar':(990,360),'hall_arch_broken':(1080,510),'empty_throne':(1170,400),'long_table':(980,580),'hall_carpet':(1090,342),'world_root_arch':(380,530),'glow_mushroom':(360,650),'small_cave':(790,600),'nail_heap_01':(80,265),'nail_heap_02':(185,260),'workbench':(220,310),'nail_plank':(20,310),'half_golem':(320,285),'sunken_tree':(80,400),'floating_bones':(200,520),'luggage':(920,300)}
decals={'queue_tracks_01':(500,400),'queue_tracks_02':(720,400),'hoof_tracks_01':(370,285),'hoof_tracks_02':(800,280),'paw_tracks_01':(870,580),'dried_blood_01':(900,490),'dried_blood_02':(1040,450),'drag_mark_01':(140,280),'root_crack_01':(370,600),'root_crack_02':(680,600),'moss_01':(80,560),'moss_02':(190,400)}
for id,xy in decals.items():o.alpha_composite(im(id),xy)
for id,xy in sorted(placements.items(),key=lambda item:item[1][1]+im(item[0]).height):o.alpha_composite(im(id),xy)
for id,xy in [('swordsman',(560,210)),('dead',(640,425)),('nail_golem',(255,390))]:o.alpha_composite(Image.open(R/'refs'/f'{id}.png').convert('RGBA'),xy)
o.save(R/'previews/map_context.png')
frames=[]
for x,y in [(0,0),(320,0),(640,0),(640,180),(320,180),(0,180),(320,180),(640,180),(640,0),(320,0)]:frames.append(o.crop((x,y,x+640,y+540)).convert('RGB').resize((640,540),Image.Resampling.NEAREST))
frames[0].save(R/'previews/map_scroll.gif',save_all=True,append_images=frames[1:],duration=600,loop=0)
(R/'records/static_versions.json').write_text(json.dumps(VERS,indent=2))
(R/'records/context_placements.json').write_text(json.dumps({'props':placements,'decals':decals,'game_tested':False,'purpose':'Material readability and relative scale preview, not final level layout'},indent=2))
print('Borders,36transitions,perimeter,scene and scrollGIF built')
