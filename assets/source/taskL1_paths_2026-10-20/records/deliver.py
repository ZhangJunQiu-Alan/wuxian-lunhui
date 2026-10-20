from pathlib import Path
from PIL import Image, ImageDraw
import json, hashlib, html, os

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'assets/source/taskL1_paths_2026-10-20'
JOBS = json.loads((BASE / 'records/plan_all_L.json').read_text())

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

def relative(path, parent):
    return os.path.relpath(path, parent)

def build(task):
    jobs = [j for j in JOBS if j['task'] == task]
    root = ROOT / jobs[0]['root']
    items, pending, versions, errors = [], [], [], []
    for j in jobs:
        id = j['id']
        save(root / 'records' / f'plan_{id}.json', j)
        gens = sorted((root / 'records').glob(f'generation_{id}_v*.json'))
        for path in gens:
            g = json.loads(path.read_text())
            versions.append({'id': id, 'version': g['version'], 'status': g['status'], 'record': relative(path, root)})
            assert sha(root / g['original']) == g['original_sha256']
            for ref in g['references']:
                assert sha(root / ref['archive']) == ref['sha256']
        a = root / 'records' / f'approved_{id}.json'
        if not a.exists():
            pending.append(id)
            continue
        selected = json.loads(a.read_text())
        v = selected['selected_version']
        record = root / 'records' / f'generation_{id}_{v}.json'
        g = json.loads(record.read_text())
        formal = ROOT / j['target']
        with Image.open(formal) as im:
            assert im.format == 'PNG' and im.mode == 'RGB' and im.size == (720, 1200), formal
            colors = len(im.getcolors(720 * 1200) or [])
        assert sha(formal) == selected['sha256'] == sha(root / 'approved' / f'{id}.png') == sha(root / 'candidates' / f'{id}_{v}.png')
        previews = {kind: f'previews/{id}_{v}_{suffix}.png' for kind, suffix in [('thumbnail', '260'), ('text_mask', 'masked'), ('safe_area', 'safe')]}
        for rel in previews.values():
            with Image.open(root / rel) as im:
                assert im.size == (260, 433)
        levels = []
        size = (720, 1200)
        for f in sorted((root / 'mipmaps' / id).glob('*.png')):
            size = tuple(max(1, n // 2) for n in size)
            with Image.open(f) as im:
                assert im.size == size and im.mode == 'RGB'
            levels.append({'path': relative(f, root), 'size': size, 'sha256': sha(f)})
        assert len(levels) == 10 and size == (1, 1)
        norm = json.loads((root / 'records' / f'normalization_{id}_{v}.json').read_text())
        norm['status'] = 'normalization verified; candidate selected after separate visual review'
        save(root / 'records' / f'normalization_{id}_{v}.json', norm)
        items.append({
            'task_id': task, 'id': id, 'formal': j['target'], 'sha256': sha(formal),
            'frame_size': [720, 1200], 'frames': 1, 'fps': 0,
            'anchor': {'xy': [360, 600], 'convention': 'static UI texture center; no world-space pivot'},
            'loop': 'not applicable: static illustration', 'transparency': 'opaque RGB; Part L overrides pixel-art RGBA contract',
            'rgb_color_count': colors, 'palette_exception': 'non-pixel painterly Part L; 48-color cap does not apply',
            'selected_version': v, 'generation_record': relative(record, root), 'source': g['original'],
            'source_sha256': g['original_sha256'], 'tool': g['tool'], 'commercial_basis': g['commercial_basis'],
            'references': g['references'], 'prompt': g['prompt'], 'gameplay_source_snapshot': j['current_gameplay_source_line'],
            'previews': previews, 'offline_mipmaps': levels, 'normalization': norm,
            'visual_self_review': selected['review'],
            'file_verification': 'passed: PNG/RGB/size/hash/source/reference/preview/mip dimensions',
            'code_integration': 'not performed in this task; existing ID-first loader requires integration-agent verification',
            'godot_import_mipmap': 'not verified; offline files do not enable engine import mipmaps',
            'game_acceptance': 'untested: no actual game session or UI screenshot',
            'animation_rotation_tiling': 'not applicable to static card illustrations'
        })
    hashes = [x['sha256'] for x in items]
    assert len(hashes) == len(set(hashes)), 'duplicate final image'
    manifest = {'task': task, 'expected': len(jobs), 'delivered': len(items), 'pending': pending,
                'status': 'art files and static QA complete' if not pending else 'in production',
                'game_acceptance': 'untested', 'assets': items, 'all_versions': versions}
    save(root / 'manifest.json', manifest)
    save(root / 'records/file_audit.json', {'checked_files': len(items), 'expected': len(jobs), 'pending': pending, 'errors': errors,
         'checks': ['exact PNG RGB 720x1200', 'unique final hashes', 'formal/approved/candidate equal', 'original and input archive hashes', 'three 260x433 previews', 'ten offline mip levels to1x1'], 'game_acceptance': 'untested'})
    title = 'L1：道路及道路觉醒卡面' if task == 'L1' else 'L2：融合卡面'
    readme = f'# {title}\n\n实际交付 {len(items)} / {len(jobs)} 张。' + ('静态文件与自检完成。' if not pending else '仍在制作，未完成项见 manifest。')
    readme += '\n\n正式目录：`assets/sprites/cards/`。PNG RGB，720×1200，单张厚涂插画。原始输出、退稿、实际提示词、输入参考与 SHA256 均保留；没有覆盖原有八神普通或觉醒画像。\n\n使用已批准的 OpenAI 内置 image_gen。授权依据：<https://openai.com/policies/terms-of-use/>；既有参考为本项目自有生成素材，逐次复制留档。Pillow 仅做比例裁切、Lanczos 缩放、检查和预览，未重绘角色。提示词不包含人物名、作品名或画师名。\n\n## 实际检查\n\n逐图检查生成图的人体、手部、武器或动物结构；查看 260×433 缩略图、下45%深色文字遮罩及安全线预览。具体结果和退稿原因在各 generation/approved 记录。重要面容、手势、武器端部和动物脸避开侧边；非关键背景羽翼、光轨、衣摆可出血。下40%亮度仅作辅助记录，不以亮度数字替代目检。并排画风、道路与觉醒对照见 gallery。\n\n离线 mipmap 逐图10级，另提供260×433预览。它们不会自动开启 Godot 导入的 mipmap；接入者必须验证导入和实际 UI。静态卡面不制作动画、GIF、像素4倍或无缝平铺测试，这些不适用。\n\n## 状态边界\n\n本任务未修改代码、场景、设置或导入参数；未执行 Git 提交推送。未运行游戏，不能标记游戏验收通过。缩略和遮罩预览属于离线模拟，实际窗口缩放、卡牌文字和导入过滤仍由接入者验证。\n\n- `manifest.json`：逐图规格、哈希、提示词、参考、选稿与状态。\n- `gallery.html`：正式图、缩略、遮罩、安全线与版本记录入口。\n- `integration.md`：逐文件接入清单。\n- `originals/`：原始生成图及退稿；`approved/`：选中成品；`mipmaps/`：离线缩小版本。\n'
    (root / 'README.md').write_text(readme)
    intro = f'# {title}：接入交接\n\n文件交付 {len(items)}/{len(jobs)}。代码接入、Godot 导入 mipmap、实际游戏验收：本任务未执行。\n\n目标：`scripts/ui/level_up_panel.gd` 的 `_card_art()` 与 `ART_DIR` 卡牌ID优先解析。精确ID应优先于既有普通/觉醒画像或融合双神拼图回退。无需改变升级数据库、神术效果、数值或卡牌文字。\n\n逐张保持 UI 正立、不旋转；720×1200 的中心为(360,600)，展示约260×433，保持3:5比例。按当前UI使用线性+mipmap过滤，并在新PNG导入中启用 `mipmaps/generate=true`，由接入者修改和验证导入设置。下45%渐变文字遮罩保持现有逻辑，不把离线遮罩图当正式纹理；左右40px安全区用于保护关键结构。\n\n离线 mipmap 不会被当前单PNG解析器自动使用，也不替代 Godot 导入mipmap。请在实际卡牌选择界面逐项触发、检查缩放锯齿/清晰度/文字覆盖/ID回退/不同窗口宽度后，单独记录接入和游戏验收。\n\n| 卡牌ID | 正式路径 | 替换的回退外观 | 纹理坐标/旋转/遮罩 | 接入状态 |\n| --- | --- | --- | --- | --- |\n'
    for x in items:
        fallback = '双神画像拼接' if task == 'L2' else ('通用神明觉醒画像' if x['id'].endswith('_awaken') else '通用神明普通画像')
        intro += f"| `{x['id']}` | `{x['formal']}` | {fallback} | 中心360,600；0°；260×433；下45%遮罩 | 未测 |\n"
    intro += '\n剩余问题：实际Godot导入mipmap和游戏UI未测。' + ('\n待制作：' + '、'.join(pending) if pending else '') + '\n'
    intro = intro.replace('目标：`scripts/ui/level_up_panel.gd` 的 `_card_art()` 与 `ART_DIR` 卡牌ID优先解析。', '目标：`scripts/ui/level_up_panel.gd` 的 `_make_card()`（卡牌ID优先解析，当前140行）与 `_card_art()`（当前265行纹理展示）；`ART_DIR` 是正式目录。')
    (root / 'integration.md').write_text(intro)
    cards = []
    for x in items:
        source = html.escape(relative(ROOT / x['formal'], root))
        imgs = ''.join(f'<figure><img src="{html.escape(rel)}" width="260" height="433" loading="lazy"><figcaption>{label}</figcaption></figure>' for label, rel in x['previews'].items())
        cards.append(f'<article><h2>{x["id"]} · {x["selected_version"]}</h2><p><a href="{source}">正式720×1200</a> · <a href="{x["source"]}">原图</a> · <a href="{x["generation_record"]}">实际提示词/参考/审核</a></p><div class="row">{imgs}</div><p>{html.escape(str(x["visual_self_review"]))}</p></article>')
    comparisons = ''.join(f'<figure><a href="{relative(f,root)}"><img src="{relative(f,root)}" style="width:100%;height:auto" loading="lazy"></a><figcaption>{f.stem}</figcaption></figure>' for f in sorted((root/'previews').glob('comparison_*.png')))
    (root / 'gallery.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>'+title+'</title><style>body{background:#121721;color:#e4dfd1;font:16px system-ui;margin:24px}a{color:#b4d7ee}.row{display:flex;gap:16px;flex-wrap:wrap}figure{margin:0}article{margin:40px 0;border-top:1px solid #46505d;padding-top:10px}img{object-fit:contain}p{max-width:950px;line-height:1.6}</style><h1>'+title+f'</h1><p>交付{len(items)}/{len(jobs)}。离线自检，未运行游戏；遮罩仅用于评估。前景关键结构遵守安全边，背景光轨与衣摆可出血。</p><p><a href="manifest.json">Manifest</a> · <a href="README.md">README</a> · <a href="integration.md">接入说明</a></p>'+comparisons+''.join(cards)+'</html>')
    return manifest

if __name__ == '__main__':
    for task in ['L1', 'L2']:
        m = build(task)
        print(task, m['delivered'], '/', m['expected'], 'pending', m['pending'])
    if (BASE/'integration_2026-10-20/acceptance.json').exists():
        import runpy
        runpy.run_path(str(BASE/'integration_2026-10-20/finalize.py'),run_name='__main__')
