from pathlib import Path
import hashlib
import html
import json
import shutil
from PIL import Image

BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def dump(name,data):(BASE/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')


checks=[]


def check(name,ok,detail=None):checks.append(dict(check=name,passed=bool(ok),detail=detail))


rows=json.loads((BASE/'records/normalization_candidates_v01.json').read_text())
assets=[]
for r in rows:
    path=BASE/r['candidate'];im=Image.open(path).convert('RGBA');n=r['frames']
    check(r['action']+':sheet',im.size==(128*n,128))
    frames=[]
    for i in range(n):
        f=im.crop((i*128,0,(i+1)*128,128));frames.append(f);colors=set(f.get_flattened_data());box=f.getchannel('A').getbbox()
        check(f'{r["action"]}:{i}:binary_alpha',{c[3] for c in colors}<={0,255})
        check(f'{r["action"]}:{i}:48rgb',len({c[:3] for c in colors if c[3]})<=48)
        check(f'{r["action"]}:{i}:margin_except_neck',box[1]>=2 and box[2]<=126 and box[3]<=126)
        check(f'{r["action"]}:{i}:neck_socket',f.getpixel((0,62))[3]==255)
        connected=sum(f.getpixel((0,y))[3]>0 for y in range(46,78))
        check(f'{r["action"]}:{i}:joint_opaque_rows',connected>=30,connected)
    check(r['action']+':unique_frames',len({sha_ for sha_ in [hashlib.sha256(f.tobytes()).hexdigest() for f in frames]})==n)
    gifs=[]
    for kind in ['native','slow8']:
        p=BASE/f'previews/head_{r["action"]}_v01_{kind}.gif';gif=Image.open(p);check(r['action']+':'+kind+':gif_frames',gif.n_frames==n)
        timings=[]
        for i in range(gif.n_frames):
            gif.seek(i);timings.append(gif.info['duration'])
            bg=Image.new('RGB',(128,128),'#121721');bg.paste(frames[i],(0,0),frames[i]);bg=bg.resize((512,512),Image.Resampling.NEAREST)
            check(f'{r["action"]}:{kind}:{i}:gif_pixels',gif.convert('RGB').tobytes()==bg.tobytes())
        gifs.append(dict(file=str(p.relative_to(BASE)),durations_ms=timings,
                         timing_note='GIF 10ms quantization; non-loop action last frame has extra600ms review hold, not gameplay duration'))
    assets.append(dict(id='jormungandr_head_'+r['action'],formal_path='assets/sprites/bosses/jormungandr_head_'+r['action']+'.png',
                       raw=f'originals/head_{r["action"]}_v01_raw.png',prompt=f'records/prompt_head_{r["action"]}_v01.json',
                       candidate=r['candidate'],approved='approved/jormungandr_head_'+r['action']+'.png',
                       frame_size=[128,128],frames=n,fps=r['fps'],loop=r['loop'],anchor=[64,64],neck_socket=[0,62],
                       palette='approved original head 48RGB',alpha=[0,255],source_sha256=sha(BASE/f'originals/head_{r["action"]}_v01_raw.png'),
                       sha256=sha(path),preview_gifs=gifs,visual_review='1x/4x frame comparison, straight joints and isolated Godot curved/poison cases inspected',
                       margin_exception='left neck port intentionally touches x0',game_acceptance='not_tested'))

snapshot=json.loads((ROOT/'assets/source/taskK_contract_2026-10-20/records/baseline.json').read_text())
changed=[p for p,h in snapshot.items() if not (ROOT/p).exists() or sha(ROOT/p)!=h]
check('preexisting_inputs_unchanged_before_publication',not changed,changed)
captures=json.loads((BASE/'preview_project/captures/result.json').read_text())
check('isolated_fixture22_saved',len(captures)==22 and all(r['save_error']==0 for r in captures))
log=(BASE/'records/godot_fixture_final.log').read_text()
check('fixture_no_gdscript_failure','SCRIPT ERROR' not in log and 'Parse Error' not in log and 'ERROR:' not in log)
audit=dict(task='K1',checks=len(checks),failures=sum(not c['passed'] for c in checks),items=checks,
           source_checks='existing source/registered files unchanged before these three new publications',
           fixture_scope='isolated Godot asset rendering only, not Game or third-level gameplay',
           platform_diagnostic='macOS IMKCFRunLoopWakeUpReliable mach-port diagnostic retained in log; not hidden as a GDScript error',
           runtime_acceptance='not_tested')
dump('records/final_audit.json',audit)
if audit['failures']:raise SystemExit(json.dumps([c for c in checks if not c['passed']],ensure_ascii=False))
for row in assets:
    source=BASE/row['candidate'];approved=BASE/row['approved'];target=ROOT/row['formal_path']
    if target.exists() and sha(target)!=row['sha256']:raise SystemExit('refuse to overwrite existing different formal file: '+str(target))
    shutil.copyfile(source,approved)
    if not target.exists():shutil.copyfile(source,target)

reuse=['assets/sprites/bosses/jormungandr_head.png','assets/sprites/bosses/jormungandr_body.png','assets/sprites/bosses/jormungandr_tail.png',
       'assets/sprites/effects/bosses/nidhogg_poison_breath.png','assets/sprites/effects/poison_pool.png',
       'assets/sprites/effects/hit_bite.png','assets/sprites/effects/gods/thor_hammer.png','assets/sprites/effects/gods/thor_cloud.png']
reuse=[dict(path=p,sha256=sha(ROOT/p),decision='reuse_unchanged_no_new_production') for p in reuse]
dump('manifest.json',dict(task='K1',status='art_delivered_self_checked_not_game_integrated',formal_png=3,frames=11,
                         contract=json.loads((BASE/'records/contract_ref.json').read_text()),assets=assets,reused=reuse,
                         generated_originals=3,rejected_generations=0,
                         original_source_manifest='assets/source/batch02_repairs_2026-10-16/manifest.json',
                         tools=['OpenAI built-in image_gen','Pillow12.1.1 MIT-CMU normalization/QA only','Godot4.7.2 MIT isolated fixture'],
                         license='../../LICENSES.md',self_check='pass',game_acceptance='not_tested'))
dump('records/jobs.json',[dict(asset=r['id'],status='published_art_self_checked_not_game_integrated',prompt=r['prompt'],raw=r['raw'],formal=r['formal_path']) for r in assets])
dump('records/visual_review.json',dict(actual_method='local image views of 1x/4x comparisons, straight joint strips, three R240 full screenshots and R128_attack01; all22 fixture contact sheet',
     observations=['same dark-teal/ivory creature and horns; articulated throat/jaw readable across windup/attack',
                   'all frames use one neck socket; source body meets it without an open gap; no claim that generated port RGB equals old source port',
                   'continuous UV ribbon curves avoid rigid-card wedges at both R240 and R128; tail connection visible',
                   'poison reused texture remains thin; clear authoritative warning outline must remain in production, do not rely on cloud alpha for damage boundary',
                   'idle four frames are distinct; movement is small and neck does not translate'],
     untested=['actual enemy targeting head-only registration','real hazard damage','Thor fate condition or aid gameplay','350 enemy density','full third-level playthrough'],
     GIF_review='frames and timings decoded/pixel-checked; not a claim of external manual game acceptance'))
(BASE/'README.md').write_text('''# K1：耶梦加得动作与复用交付

3张正式PNG、11帧：head_idle 4帧8fps循环；head_windup 3帧8fps单次末帧保持；head_attack 4帧16fps单次。新文件只发布此前不存在的三个动作，既有头/身/尾不覆盖。

实际使用已批准内置image_gen生成3张原图，实际Prompt、输入图、工具结果及SHA保留records/originals/references；无失败生成，全部v01。Pillow只固定格裁排、最近邻128、原图48色表/二值alpha规范化和预览检查，没有程序绘制新动作。三条动画共6份原速/8fps慢放GIF；GIF末帧600ms只是检查停顿，不是游戏动作延时。

自检见records/final_audit.json。所有帧尺寸、alpha、颜色、非颈部边距、独立帧、颈口连通与GIF像素核对通过。已实际查看逐帧/静态参考对照、直线接缝、独立Godot R240/R128曲线和毒息叠加。身体/尾巴原图不变，采用连续UV带；body_repeat_4x4仅为已有身体重复纹理检查，不是新地面图。

独立Godot素材场景实际保存22张截图，不是实际Game场景、不代表第三关已接入。原代码、场景、docs、根项目设置未改；没有Git提交推送。平台输入法mach-port诊断保留，未混称GDScript错误。

毒雾喷吐/持续区域、撞击、托尔援助复用既有资源和程序表现，未重复做图；动作本体不含毒雾。毒息纹理是薄雾，实际危险边界必须保留清楚的程序预警，不能由alpha猜范围。实际判伤、仅蛇头可被瞄准、90秒命运条件、350怪场景及第三关通关均未测。

逐文件接入见integration.md；规范源为../taskK_contract_2026-10-20/contract.json，冻结的是资产接口，不是已实现玩法。图库gallery.html，原图originals/，批准副本approved/，帧条正式位于assets/sprites/bosses/。
''')
(BASE/'integration.md').write_text('''# K1 接入交接

本轮未改生产代码。契约：K-assets-v1.0，SHA见records/contract_ref.json。新增Boss脚本仍需由集成实施，不能因PNG已存在就认定能播放。

|正式文件|单帧/帧/播放|目标与事件|
|---|---|---|
|assets/sprites/bosses/jormungandr_head_idle.png|128×128 / 4 / 8fps循环|新Jormungandr视图的idle；运动跟随环绕路径，不重做move|
|assets/sprites/bosses/jormungandr_head_windup.png|128×128 / 3 / 8fps单次|poison_windup；播完末帧保持至控制器release|
|assets/sprites/bosses/jormungandr_head_attack.png|128×128 / 4 / 16fps单次|poison_attack；release在zero-based1帧对应事件，但实际判伤由控制器，非animation_finished|

共同锚点(64,64)，左颈socket(0,62)，面向右。身体/尾使用旧64px图，body socket(0,30)/(64,30)，tail右口(64,30)。生成颈口中心稳定，边缘RGBA并非与原身体逐像素相同；直线预览和曲线最近邻已检查无开放缝隙。允许实际视图用2px几何重叠消除采样边界，不修改原PNG。

参考实现是preview_project/render_review.gd：弧长UV带按完整纹理周期映射，避免每段硬卡片独立旋转留缝；这个演示不是完整Boss脚本。只有头在enemies组/空间索引/第2受击层，身体和尾是无受伤注册的视图与几何接触，不能建立一串Enemy节点。

需要在BossDB加入jormungandr并实现新脚本；sprite_name必须为jormungandr_head。新Boss单独设置attack16fps，现Boss._ready默认8fps不能直接沿用，不改动前六Boss。保留明显头部可受击提示；身体接触击退与伤害冷却由几何控制器负责。

复用nidhogg_poison_breath（96×64/4/16fps，喷口4,32），poison_pool（48×48/8帧）、hit_bite、thor_hammer/cloud以及现有LightningFx；均沿原路径加载，不复制新正式文件。新毒区不可直接照搬PoisonPool固定半径/椭圆判定；用权威region裁切，薄雾之上保留清楚预警。毒息口示例坐标head local(108,66)，实际动画帧释放点再由控制器确认，其他方向旋转必须同步变换socket。

托尔条件读本局信仰并从本场实际登场计未暂停时长，<=90秒击败时记录thor_saved，最终战援助只触发对应事件；本轮未运行此条件。游戏验收仍需实际瞄准/判伤/缩圈、所有动作衔接、托尔援助、密集场景及整关流程，不借用独立22张截图作通过。
''')
page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>K1蛇头动作</title><style>body{background:#121721;color:#dce5e9;font:16px/1.6 system-ui;margin:32px}a{color:#9ad5cd}img{image-rendering:pixelated;max-width:100%;height:auto}section{margin:32px 0}.gifs{display:flex;gap:24px;flex-wrap:wrap}.gifs img{width:256px}</style><h1>K1 耶梦加得</h1><p>3PNG / 11帧已交付和素材自检；独立Godot素材场景验证，未接入实际第三关。</p><p><a href="manifest.json">清单</a> · <a href="integration.md">接入</a> · <a href="records/final_audit.json">自检</a> · <a href="records/visual_review.json">实际查看记录</a></p>'
for row in assets:
    action=row['id'].removeprefix('jormungandr_head_')
    page+=f'<section><h2>{html.escape(action)} / {row["frames"]}帧 {row["fps"]}fps</h2><div class="gifs"><div>原速<br><img src="previews/head_{action}_v01_native.gif"></div><div>8fps检查<br><img src="previews/head_{action}_v01_slow8.gif"></div></div><img src="previews/head_{action}_v01_review_1x.png"><p><a href="previews/head_{action}_v01_review_4x.png">4倍逐帧</a> · <a href="previews/head_{action}_v01_joints.png">逐帧接缝</a> · <a href="{row["raw"]}">原图</a> · <a href="{row["prompt"]}">实际Prompt</a></p></section>'
page+='<h2>独立Godot检查，不是正式关卡</h2><img src="previews/godot_all_cases.png"><h2>现有身体重复纹理</h2><img src="previews/body_repeat_4x4.png"></html>'
(BASE/'gallery.html').write_text(page)
dump('completion.json',dict(task='K1',production='complete',formal_png=3,frames=11,self_check='passed',
     isolated_godot_asset_view='22 captures; curve and poison composition inspected',production_game_integration='not_implemented',
     game_acceptance='not_tested',remaining=['head-only targeting','actual hazards','Thor fate/aid','dense scene','third-level gameplay'],
     git_commit=False,git_push=False))
dump('source_inventory.json',[dict(path=str(p.relative_to(BASE)),sha256=sha(p)) for p in sorted(BASE.rglob('*'))
                             if p.is_file() and p.name!='source_inventory.json' and '.godot' not in p.parts])
print(json.dumps(dict(assets=3,frames=11,checks=len(checks),failures=audit['failures'],published=[r['formal_path'] for r in assets]),ensure_ascii=False))
