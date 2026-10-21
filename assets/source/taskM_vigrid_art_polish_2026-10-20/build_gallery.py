from pathlib import Path
import hashlib
import html
import json
from PIL import Image,ImageDraw

B=Path(__file__).parent
ROOT=B.parents[2]
manifest=json.loads((B/'manifest.json').read_text())
audit=json.loads((B/'records/final_audit.json').read_text())
sections=[]
for item in manifest['files']:
    name=item['id']; n=item['frames']
    gif=('surtr_arc_game.gif' if name=='surtr_sword_arc_large' else name+'_game.gif') if n>1 else None
    source='approved/'+Path(item['path']).name
    media=f'<a href="{source}"><img class="sheet" src="{source}" alt="{html.escape(name)} 原生帧序"></a>'
    if gif:media=f'<a href="previews/{gif}"><img class="game" src="previews/{gif}" alt="实际Game独立预览动画"></a>'+media
    sections.append(f'<section><h2>{name}</h2><p>{item["frame_size"][0]}×{item["frame_size"][1]} · {n} 帧 · {item["fps"]} fps · 锚点 {item["anchor"]}</p>{media}<p><a href="previews/{name}_4x4.png">4×4 平铺／逐帧接触表</a> · <a href="{source}">正式同字节PNG</a></p><code>{html.escape(item["path"])}</code></section>')
evidence=[]
for f in ['terrain_comparison.png','aid_identity_comparison.png','sword_density_comparison.png']:
    evidence.append(f'<a href="previews/{f}"><img class="evidence" src="previews/{f}" alt="{f}"></a>')
document='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>M 第三关美术优化交付</title><style>
body{margin:0;background:#151719;color:#ece9df;font:16px/1.6 system-ui,sans-serif}main{max-width:1320px;margin:auto;padding:32px}a{color:#c4dacd}h1{font-size:28px}h2{font-size:19px}section{padding:22px 0;border-top:1px solid #41443f}p{max-width:1000px}img{image-rendering:pixelated;max-width:100%;height:auto;background:repeating-conic-gradient(#242629 0 25%,#303337 0 50%) 0/20px 20px}.sheet{max-height:320px;width:auto;object-fit:contain}.game{width:640px;vertical-align:top;margin-right:16px}.evidence{display:block;margin:20px 0;width:1280px}code{font-size:13px;word-break:break-all}.note{color:#c0bda9}
</style><main><h1>第三关 M-ART-01～03</h1><p>20 PNG · 51 帧单位 · 新文件交付。点击图片打开原图；GIF 仅作循环查看，正式特效单次播放。</p><p class="note">已做素材自检与独立实际 Game 受控视觉预览。正式代码尚待 Claude 切换；不代表完整战斗、自然触发、手柄或性能验收。援助 GIF 使用预览专用八帧绘制器。地面 4×4 为平铺；过渡块与特效的 4×4 为接触表，不宣称它们单独无缝平铺。</p><p><a href="README.md">交付说明</a> · <a href="manifest.json">Manifest</a> · <a href="integration.md">Claude 接入契约</a> · <a href="records/final_audit.json">文件自检</a> · <a href="records/visual_review.md">视觉检查记录</a></p>'''+''.join(evidence)+''.join(sections)+'</main></html>'
(B/'gallery.html').write_text(document)

# Comparisons are presentation-only crops/resizes of actual runtime screenshots.
before=ROOT/'assets/source/taskK_code_integration_2026-10-20/screenshots/map_spawn.png'
after=B/'previews/terrain_game_final/map_spawn_M01_1280.png'
board=Image.new('RGB',(1280,760),(20,22,25));d=ImageDraw.Draw(board)
for i,(p,label) in enumerate([(before,'BEFORE / K approved terrain / actual Game'),(after,'AFTER / M terrain / actual Game isolated preview')]):
    im=Image.open(p).convert('RGB').resize((640,360),Image.Resampling.NEAREST)
    board.paste(im,(i*640,30));d.text((i*640+12,8),label,fill='white')
    im=Image.open(p).convert('RGB').crop((320,180,960,540))
    board.paste(im,(i*640,400))
board.save(B/'previews/terrain_comparison.png')
(B/'records/comparison_sources.json').write_text(json.dumps([{'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [before,after]],indent=2))
board=Image.new('RGB',(1280,688),(20,22,25));d=ImageDraw.Draw(board)
for x,g in enumerate(['freyja','baldr','ran','skadi']):
    d.text((x*320+12,5),g+' / f2 then f5 / actual Game crop 1x',fill='white')
    for row,f in enumerate([2,5]):
        im=Image.open(B/f'previews/fx_game_final/aid_{g}_f{f}.png').convert('RGB')
        # Actual viewport anchor is close to(640,360), or +35px for target-point aids.
        cx=640 if g=='freyja' else 675
        board.paste(im.crop((cx-160,200,cx+160,520)),(x*320,28+row*330))
board.save(B/'previews/aid_identity_comparison.png')
shot=Image.open(B/'previews/fx_game_final/surtr_arc_f2.png').convert('RGB')
board=Image.new('RGB',(768,350),(20,22,25));d=ImageDraw.Draw(board)
for i,(box,label) in enumerate([((566,320,646,400),'NEW ARC / 80px crop at4x'),((822,274,902,354),'SURTR BODY / 80px crop at4x')]):
    board.paste(shot.crop(box).resize((320,320),Image.Resampling.NEAREST),(i*384,30));d.text((i*384+8,8),label,fill='white')
board.save(B/'previews/sword_density_comparison.png')

terrain=json.loads((B/'records/terrain_processing.json').read_text())
readme=f'''# 第三关 M-ART-01～03 美术优化交付

日期：2026-10-20。**20 张新增正式 PNG，共 51 帧单位；已完成素材自检和独立实际 Game 受控视觉检查，正式项目尚待 Claude 切换代码。**

| 任务 | 文件 | 规格 | 结果 |
|---|---:|---|---|
| M01 地面与道路 | 15 | 64×64；灰烬路面 + 12 碎边过渡 + 焦草 + 裂地 | 道路亮度62.06、对比16.81；焦草亮度42.22，与底色差8.82；暖色裂缝3.247%，最高通道160 |
| M02 大剑弧 | 1 | 横排4×640²，2560×640，16fps，单次 | R290、半角1.05、中心320²，原生1×；四帧扇形外像素0；末帧alpha72/255 |
| M03 四神援助 | 4 | 各横排8×320²，2560×320，12fps，单次 | 羽毛/日轮/渔网/冰箭四种身份；半径140/110/130/130，末帧空，中心保持可见 |

## 查看

- `gallery.html`：正式同字节图、实际 Game GIF、4×4 接触表与对比图。
- `integration.md`：明确文件名、帧、锚点、朝向、缩放、触发位置及 Claude 接入注意点。
- `manifest.json`：20 文件、原图与提示词链接、SHA256、规格、检查边界。
- `records/final_audit.json`：{audit['passed']} 项技术/来源/文件一致性检查，{audit['failed']} 失败。文件检查不是游戏验收。
- `records/visual_review.md`：逐项实际视觉检查、退回修改、预览限制。
- `previews/terrain_game_final/`：18 张实际 Game 地面截图；两种窗口各9张。
- `previews/fx_game_final/`：41 张实际 Game 特效截图；十只敌人、苏尔特预警、四种援助逐帧及范围线。

## 来源与加工

内置图像工具实际生成11份原图：地面3份，剑弧4份，援助4份。都保留在 originals/；真实提示词与参考路径在 records/prompt_*.json。生成源地面/剑弧1254×1254，援助1774×887，**不是模型原生输出64/320/640像素**。最终规范通过裁帧、整体近邻缩放/定位、有限色板和透明度归一取得，未把旧128px剑弧放大充当新大弧。

道路边缘复用已许可helheim过渡的二值轮廓拓扑，RGB取本批新路面，沿轮廓用已有碎石明暗减去1～3px缺口。无代码绘制新图替代模型生成；Python用于来源裁帧、最近邻统一、调色/透明/遮罩、几何校验和预览排版。

共同色板每文件最多48种可见RGB；地面/边缘alpha为255或0，FX量化为最多8档。援助全部像素alpha≤216/255，落地阶段中心额外≤112/255；第8帧完全透明。GIF按10ms单位近似显示12/16fps，正式播放速度以manifest和引擎为准，预览GIF循环不等于正式特效循环。

商用来源和工具许可见 assets/LICENSES.md 的 M-ART-01～03 条目（OpenAI输出条款、Pillow MIT-CMU、Godot MIT）。没有引入第三方作品人物、注册账户或付费API。

## 退回、修正与运行边界

首版裂缝暖色面积不足3%；旧遮罩轮廓过于规整；援助首版主环偏小、巴德尔次版光柱落点偏下，均已修改并保留退稿，详见 records/rejections.json。预览脚本也曾因缩进、提前解析autoload、临时纹理释放和窗口失焦暂停失败，失败日志/截图均保留，不计为通过。

最终有效素材由 approved/ 同字节复制到 manifest列明的正式新路径；{len(json.loads((B/'records/existing_sprite_hashes.json').read_text()))} 个开工时已有sprite文件SHA256未变。正式scripts/、scenes/、docs/及project.godot未由本任务修改，无commit/push。

实际窗口检查使用独立存档和设置、无敌玩家、关闭自然刷怪、冻结指定Boss/敌人，只证明图像在当前Game背景中的显示。**援助使用预览专用八帧绘制器，正式自动触发与战斗代码没有接入。** 完整战斗、自然触发、效果时序、手柄、性能与K-QA均不在本次通过范围。source根 .gdignore 避免归档原图和预览被正式项目导入；临时可重建 runtime/ 被 .gitignore 排除。
'''
(B/'README.md').write_text(readme)
