from pathlib import Path
from PIL import Image, ImageDraw
import importlib.util, json, hashlib, shutil, html

HERE=Path(__file__).parent
s=importlib.util.spec_from_file_location('pipeline',HERE/'pipeline.py'); p=importlib.util.module_from_spec(s); s.loader.exec_module(p)
ROOT=p.ROOT
DETAILS={
 'bridge_guard':('bridge_guard_quest.gd','_draw_quest','offered 静态；active 使用待机帧条；桥区与计时条原样保留。','guard = (_zone.end.x+34, _zone.end.y+30)'),
 'bridge_guard_idle':('bridge_guard_quest.gd','_draw_quest','4帧8fps循环；脚底锚点固定，无程序缩放或抖动。','同 bridge_guard'),
 'bonfire_survivors':('bonfire_quest.gd','_draw_quest','替换四个人头圆点；现有campfire及150范围圈/进度环保持。中央54px透明，实际火焰最大51px。','marker_pos + (0,12)'),
 'valkyrie_wings':('valkyrie_quest.gd','_draw_overlay','替换金色三角，改在已有z20前景overlay画；不生成完整身体；150击杀/3倍刷怪不变。','player.global_position + (0,-34)'),
 'iron_horseshoe':('hoof_tracks_quest.gd','_draw_quest','替换金属弧线；沿途暗色蹄印、18px提示光圈、拾取30+14范围及5件条件保留。','shoe + (0,6)'),
 'river_sword':('river_sword_quest.gd','_draw_quest','替换发光斜线；90px圈、进度弧、15秒累计及怪物生成不变。碎冰线位置/长度公式保留，alpha由0.7降至0.35、线宽2降至1，避免抢过实体长剑。','marker_pos + (0,12)'),
 'sun_altar':('ember_quest.gd','_draw_quest','添加低矮祭坛；70px圈、现有余烬头顶/掉落、携带减速、受伤掉落和冷却不变。','_altar + (0,16)'),
}
VISUAL={
 'bridge_guard':'年轻女性、暗金布衣、深灰斗篷、发辫与朝右轮廓已看；正式静态取自待机第0帧，避免静/动尺寸切换。',
 'bridge_guard_idle':'四帧逐格查看，面部/服装/发辫一致；双靴落地基线固定y61，细小呼吸与披风变化，循环回接无大幅跳转。脚边像素存在1px以内轮廓变化，未宣称逐像素完全相同。',
 'bonfire_survivors':'四名蹲坐者可分辨；左右两组35px宽，中心54px透明；已叠加现有64px画布篝火，实体最大51px，不重画火焰。',
 'valkyrie_wings':'四种张合角度可分辨，只有两翼，中心13px以上透明；整体中心(32,16)，无人体或大光晕。',
 'iron_horseshoe':'16px原尺寸U型铁物件有厚度与高亮，和暗色3px蹄印可区分。',
 'river_sword':'实体刀身、横护手、柄和圆形柄头可分辨，四帧微弱冷色闪光/涟漪；刀尖整帧定位在顶边y2，刀身中心x16附近，非整身旋转。',
 'sun_altar':'低矮台阶和空白台面可辨认；源图外围低alpha背景经实体alpha阈值去除，正式图无底色/光晕；现有余烬叠图可置于台面。',
}
report=[]
for name,(task,folder,w,h,n,kind) in p.SPECS.items():
 d=p.directory(name); formal=ROOT/'assets/sprites/quests'/f'{name}.png'; im=Image.open(formal).convert('RGBA')
 frames=[im.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
 rgb=len({px[:3] for px in im.getdata() if px[3]}); alphas=sorted(set(im.getchannel('A').getdata()))
 boxes=[f.getbbox() for f in frames]
 assert im.size==(w*n,h) and rgb<=48 and alphas==[0,255]
 assert all(b and b[0]>=2 and b[1]>=2 and b[2]<=w-2 and b[3]<=h-2 for b in boxes),(name,boxes)
 assert len({f.tobytes() for f in frames})==n
 assert p.sha(formal)==p.sha(d/'approved'/f'{name}.png')
 anchor=[w//2,h-2] if kind=='feet' else [w//2,h//2]
 rows=[]
 for f in frames:
  bg=Image.new('RGBA',f.size,p.BG);bg.alpha_composite(f);rows.append(bg.convert('RGB'))
 contact=Image.new('RGB',im.size,p.BG[:3])
 for i,f in enumerate(rows):contact.paste(f,(i*w,0))
 contact.save(d/'previews'/f'{name}_1x.png')
 contact.resize((contact.width*4,h*4),Image.Resampling.NEAREST).save(d/'previews'/f'{name}_4x.png')
 baseline=contact.resize((contact.width*4,h*4),Image.Resampling.NEAREST)
 draw=ImageDraw.Draw(baseline)
 for i in range(n):
  x=(i*w+anchor[0])*4;y=anchor[1]*4
  draw.line((i*w*4,y,(i+1)*w*4-1,y),fill=(70,160,190));draw.line((x,0,x,h*4-1),fill=(70,160,190))
 baseline.save(d/'previews'/f'{name}_anchor.png')
 gifs=[]
 if n>1:
  for mul in [1,4]:
   fs=[f.resize((w*mul,h*mul),Image.Resampling.NEAREST) for f in rows]
   for label in ['native','slow8fps']:
    path=d/'previews'/f'{name}_{label}_{mul}x.gif'
    fs[0].save(path,save_all=True,append_images=fs[1:],duration=[120,130,120,130],loop=0,disposal=2)
    decoded=Image.open(path); durations=[]
    for i in range(n):
     decoded.seek(i); assert decoded.convert('RGB').tobytes()==fs[i].tobytes(),(name,i)
     durations.append(decoded.info['duration'])
    assert sum(durations)==500
    gifs.append(str(path.relative_to(d)))
 script,func,notes,coord=DETAILS[name]
 normalized=json.loads((d/'records'/f'normalization_{name}_v01.json').read_text())
 extra=[]
 if name=='bridge_guard':extra=['最终静态从同源待机原图规范化第0格裁得；首次独立静态保留为角色设计输入和候选，未冒称独立静态原图直接成为成品。']
 if name=='bonfire_survivors':extra=['初版间隙24px退回；36px间隙叠实际51px火焰仍触碰披风退回；最终左右两组整体裁排/统一最近邻缩小，间隙54px。']
 if name=='valkyrie_wings':extra=['左右整翼分别向外平移1px，保持2px四周留白，扩大透明中心。']
 if name=='river_sword':extra=['原bbox居中使刀尖漂移1px；按上方刀身定位整帧，刀尖顶行y2；旧候选保留。']
 manifest={'task_id':task,'file':str(formal.relative_to(ROOT)),'source_tool':'OpenAI built-in image_gen','license':'https://openai.com/policies/terms-of-use/',
  'frame_size':[w,h],'frames':n,'fps':8 if n>1 else 0,'loop':n>1,'anchor':anchor,'alpha_strategy':'binary 0/255; solid object and feather silhouette','rgb_count':rgb,'alpha_values':alphas,'sha256':p.sha(formal),
  'frame_bboxes':boxes,'unique_frames':n,'actual_self_checks':{'rgba_dimensions_padding_colors_alpha_hash':'passed','native_and_4x_dark_background':'visually reviewed','all_frames_and_loop_transition':'reviewed' if n>1 else 'not applicable','gif_decode_pixels_and_average_fps':'passed' if n>1 else 'not applicable','visual_notes':VISUAL[name]},
  'normalization':normalized,'selected_candidate':str(next(x for x in (d/'candidates').glob('*.png') if p.sha(x)==p.sha(formal)).relative_to(d)), 'selected_approved':str((d/'approved'/f'{name}.png').relative_to(d)), 'additional_source_operations':extra,'previews':gifs,'failed_candidates':sorted(x.name for x in (d/'candidates').glob('*rejected*')),
  'code_integration':'integrated','runtime_acceptance':'pending controlled review','manual_game_acceptance':'not performed','remaining_problems':['完整手动通关与密集实战遮挡未测。'],'tiling_preview':'not applicable: isolated non-tile quest asset'}
 report.append(manifest)
 file=d/'manifest.json'
 current=json.loads(file.read_text()) if file.exists() else {'task_id':task,'assets':[]}
 current['assets']=[a for a in current['assets'] if a['file']!=manifest['file']]+[manifest]
 file.write_text(json.dumps(current,ensure_ascii=False,indent=2)+'\n')
 entries=[]
 for a in current['assets']:
  nm=Path(a['file']).stem; sc,fn,nt,co=DETAILS[nm]
  entries.append(f"## {nm}.png\n\n- 已接入 `scripts/quests/{sc}` 的 `{fn}()`。\n- 世界坐标：`{co}`，锚点 `{a['anchor']}`；旋转0、缩放1倍，坐标取整，最近邻继承项目设置。\n- {nt}\n- 非地块，不需要平铺/遮罩/碰撞。视觉大小不作为互动半径。\n- 证据：本目录 previews；运行记录在 ../taskI1_bridge_guard_2026-10-19/runtime/。\n")
 (d/'integration.md').write_text('# '+task+' 接入记录\n\n'+'\n'.join(entries)+'\n完整手动游戏验收未执行。\n')
 (d/'README.md').write_text('# '+task+' 支线素材\n\n'+ '\n'.join('- '+Path(a['file']).name+f"：{a['frame_size']}，{a['frames']}帧，RGB {a['rgb_count']}色。" for a in current['assets'])+'\n\n原图、输入参考、实际Prompt和SHA256见 originals / references / records。正式图与 approved 哈希一致。previews 包含深色底1倍/4倍、脚底或中心定位线；动画原速和8fps慢放均为8fps，GIF10ms时基用120/130ms交替，平均周期500ms。\n\n'+ '\n'.join(VISUAL[Path(a['file']).stem] for a in current['assets'])+'\n\n没有地块，4×4平铺不适用。仅沿用已批准内置图像工具，没有新账号或付款。代码已接入；受控运行与完整手动验收状态分别记录，不把生成或文件检查当作通关验收。\n')
 links=[]
 for a in current['assets']:
  nm=Path(a['file']).stem
  links.append(f'<h2>{html.escape(nm)}</h2><p>{html.escape(VISUAL[nm])}</p>')
  for suffix in ['1x.png','4x.png','anchor.png']:
   rel=f'previews/{nm}_{suffix}';links.append(f'<p>{suffix}</p><a href="{rel}"><img src="{rel}"></a>')
  for rel in a['previews']:links.append(f'<p>{html.escape(rel)}</p><img src="{rel}">')
  links.append('<p><a href="manifest.json">manifest</a> · <a href="integration.md">integration</a> · <a href="README.md">README</a></p>')
 for img in (d/'previews').glob('*overlay.png'):links.append(f'<p>叠图：{img.name}</p><img src="previews/{img.name}">')
 (d/'gallery.html').write_text('<!doctype html><meta charset="utf-8"><title>'+task+' Quest Art</title><style>body{background:#121721;color:#ddd;font:16px sans-serif;padding:24px}img{image-rendering:pixelated;max-width:100%}a{color:#8dcfff}</style><h1>'+task+' 支线素材</h1>'+''.join(links))
(HERE/'asset_audit.json').write_text(json.dumps({'files':len(report),'frames':sum(a['frames'] for a in report),'failures':[],'assets':report},ensure_ascii=False,indent=2))
print('ASSET AUDIT',len(report),'files',sum(a['frames'] for a in report),'frames, 0 failures')
