from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
R=Path(__file__).resolve().parents[1];inventory=json.loads((R/'records/priority03_04_inventory.json').read_text());meta={a['id']:a for a in inventory}
pal=json.loads((R/'references/existing_midgard_palette48.json').read_text());p=Image.new('P',(1,1));flat=sum(pal,[]);p.putpalette(flat+flat[:3]*(256-len(pal)))
# Full source-object crop boxes, selected from the saved coordinate-grid previews.
crops={}
def add(src,items):
 for ident,box in items:crops[ident]=(src,box)
add('crossroads_v01',list(zip(['cart_overturned','barrel_01','barrel_02','sack_01','sack_02','signpost_01','signpost_02'],[(0,0,470,530),(470,0,745,530),(745,0,1100,530),(1100,0,1448,530),(0,530,385,1086),(430,530,740,1086),(780,530,1170,1086)])))
add('village_large_v02',list(zip(['longhouse_snow','longhouse_frame','longhouse_ridge','sheep_pen'],[(0,0,640,660),(640,0,1254,660),(0,700,650,1254),(650,700,1254,1254)])))
add('village_v01',list(zip(['fence_broken_01','fence_broken_02','fence_gate','frozen_well','fish_rack','chopping_block','campfire_unlit'],[(1180,0,1448,420),(0,430,390,740),(395,430,800,740),(800,430,1130,740),(1130,430,1448,740),(0,745,350,1086),(880,745,1160,1086)])))
add('harbor_v01',list(zip(['pier_straight_01','pier_straight_02','pier_broken','mooring_post_01','mooring_post_02','fishing_net_01','fishing_net_02','boat_overturned','crate_stack_01','crate_stack_02'],[(0,0,350,430),(350,0,730,430),(730,0,1080,430),(1080,0,1448,430),(0,430,380,740),(380,430,735,740),(735,430,1080,740),(1080,430,1448,740),(0,745,375,1086),(375,745,740,1086)])))
add('stone_circle_v01',list(zip(['runestone_03','altar_01','altar_02','drinking_horn_01','drinking_horn_02','mistletoe_01','mistletoe_02','raven_feathers'],[(0,0,445,485),(445,0,900,485),(900,0,1340,485),(1340,0,1774,485),(0,485,445,887),(445,485,900,887),(900,485,1340,887),(1340,485,1774,887)])))
add('burial_v01',list(zip(['burial_mound_open','burial_mound_collapsed','grave_stone_small_01','grave_stone_small_02','headstone_fallen_01','headstone_fallen_02','burial_sword_01','burial_sword_02','bone_pile_01','bone_pile_02'],[(0,0,410,390),(410,0,815,390),(850,0,1080,390),(1150,0,1400,390),(0,390,410,740),(420,390,805,740),(815,420,1060,730),(1170,420,1400,730),(0,740,370,1086),(370,740,735,1086)])))
add('lake_v01',list(zip(['fishing_boat_frozen','underice_fish_01','underice_fish_02','underice_weeds_01','underice_weeds_02'],[(0,0,540,480),(540,0,1080,480),(1080,0,1536,480),(0,480,540,1024),(540,480,1080,1024)])))
add('outskirts_v01',list(zip(['dead_pine_03','bush_01','bush_02','rock_04','snowdrift_03','fallen_log','weapons_in_snow','broken_shield_01','broken_shield_02','frozen_horse','raven_branch'],[(0,0,385,500),(385,0,750,500),(750,0,1085,500),(1085,0,1448,500),(0,510,395,745),(395,510,825,745),(825,510,1085,745),(1085,510,1448,745),(0,750,385,1086),(385,750,830,1086),(830,750,1100,1086)])))
add('cart_overturned_v02',[('cart_overturned',(0,0,1448,1086))])
add('headstones_v02',[('headstone_fallen_01',(0,0,1086,724)),('headstone_fallen_02',(1086,0,2172,724))])
records=[]
for ident,(src,box) in crops.items():
 a=meta[ident];size=[32,48] if ident.startswith('burial_sword') else a['size'];raw=Image.open(R/f'originals/{src}_raw.png').convert('RGBA');box=(0,0,raw.width,raw.height) if src=='cart_overturned_v02' else box;im=raw.crop(box)
 alpha=im.getchannel('A');threshold=40 if ident.startswith('underice') else 128;alpha=alpha.point(lambda v:255 if v>=threshold else 0);bbox=alpha.getbbox()
 if not bbox:print('EMPTY',ident);continue
 contact=bool((bbox[0]==0 and box[0]==0) or (bbox[2]==im.width and box[2]==raw.width) or (bbox[1]==0 and box[1]==0) or (bbox[3]==im.height and box[3]==raw.height))
 im.putalpha(alpha);im=im.crop(bbox);ratio=min((size[0]-4)/im.width,(size[1]-4)/im.height);fit=(max(1,round(im.width*ratio)),max(1,round(im.height*ratio)));im=im.resize(fit,Image.Resampling.NEAREST);alpha=im.getchannel('A');im=im.convert('RGB').quantize(palette=p,dither=Image.Dither.NONE).convert('RGBA');im.putalpha(alpha)
 canvas=Image.new('RGBA',size);canvas.paste(im,((size[0]-fit[0])//2,size[1]-2-fit[1]));canvas.save(R/f'candidates/{ident}_v01.png');records.append(dict(id=ident,type='props',group=a['group'],source=f'originals/{src}_raw.png',crop=box,source_alpha_bbox=list(bbox),alpha_threshold=threshold,size=size,source_edge_contact=contact,status='candidate_pending_visual_review',processing='Full object crop; binary alpha; aspect-preserving nearest fit with >=2px margin and bottom contact; existing Midgard RGB palette'))
# Decals are independent cell crops; alpha only normalized; darkest current palette shades.
raw=Image.open(R/'originals/decals_v01_raw.png').convert('RGBA');dec=[a for a in inventory if a['type']=='decals']
for i,a in enumerate(dec):
 x=round(i%4*raw.width/4);y=round(i//4*raw.height/4);xx=round((i%4+1)*raw.width/4);yy=round((i//4+1)*raw.height/4);im=raw.crop((x,y,xx,yy));alpha=im.getchannel('A').point(lambda v:255 if v>=100 else 0);bbox=alpha.getbbox()
 if not bbox:print('EMPTY',a['id']);continue
 im.putalpha(alpha);im=im.crop(bbox);im.thumbnail((60,60),Image.Resampling.NEAREST);alpha=im.getchannel('A');
 palette=Image.new('P',(1,1));coldpal=[[43,59,73],[44,50,58],[30,34,38]];palette.putpalette(sum(coldpal,[])+coldpal[0]*(256-len(coldpal)))
 if a['id'].startswith('blood'):
  palette=Image.new('P',(1,1));bloodpal=[[48,23,29]];palette.putpalette(sum(bloodpal,[])+bloodpal[0]*(256-len(bloodpal)))
 im=im.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA');im.putalpha(alpha)
 out=Image.new('RGBA',(64,64));out.paste(im,((64-im.width)//2,(64-im.height)//2));out.save(R/f"candidates/{a['id']}_v01.png");records.append(dict(id=a['id'],type='decals',source='originals/decals_v01_raw.png',crop=[x,y,xx,yy],size=[64,64],source_edge_contact=False,status='candidate_pending_visual_review',processing='Cell crop; binary alpha; original palette nearest fit; original Midgard fixed RGB palette; cold decal shades restricted below snow value; blood uses one muted dark red hue across three shape variations'))
for group in sorted(set(a.get('group',a['type']) for a in records)):
 subset=[a for a in records if a.get('group',a['type'])==group];cols=4;cw,ch=196,180;board=Image.new('RGBA',(cols*cw,((len(subset)+cols-1)//cols)*ch),'#121721');d=ImageDraw.Draw(board)
 for i,a in enumerate(subset):
  im=Image.open(R/f"candidates/{a['id']}_v01.png");x=i%cols*cw;y=i//cols*ch;board.alpha_composite(im,(x+4,y+20));factor=max(1,min(4,184//im.width,125//im.height));big=im.resize((im.width*factor,im.height*factor),Image.Resampling.NEAREST);board.alpha_composite(big,(x+(cw-big.width)//2,y+40));d.text((x+4,y+4),a['id'],fill='white')
 board.save(R/f'previews/props_{group}_v01.png')
(R/'records/props_decals_normalization_v01.json').write_text(json.dumps(records,ensure_ascii=False,indent=2));print(len(records),'candidates');print('Source edge contacts:',[a['id'] for a in records if a['source_edge_contact']])
