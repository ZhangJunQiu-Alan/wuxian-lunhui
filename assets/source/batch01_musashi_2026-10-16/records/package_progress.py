import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageSequence

root = Path(__file__).resolve().parents[1]
assets = root.parents[1]
final = root / 'approved'
final.mkdir(exist_ok=True)
destination = assets / 'sprites/characters'
destination.mkdir(parents=True, exist_ok=True)
specs = [
    ('musashi', 'musashi_nearest_v02.png', 1, 64, 'https://chatgpt.com/c/6ad124f1-7878-83ea-8bfa-0dba7d08a575', 'musashi_base_v01.png', 'musashi_base_prompt.txt'),
    ('musashi_hurt', 'musashi_hurt_v02.png', 2, 64, 'https://chatgpt.com/c/6ad126f7-f0c0-83ea-937a-df5b31c06206', 'musashi_hurt_v01.png', 'musashi_hurt_prompt_v01.txt'),
    ('musashi_death', 'musashi_death_v02.png', 6, 64, 'https://chatgpt.com/c/6ad126fd-c038-83e9-b13d-75730a5e36e5', 'musashi_death_v01.png', 'musashi_death_prompt_v01.txt'),
    ('musashi_cutin', 'musashi_cutin_v02.png', 1, None, 'https://chatgpt.com/c/6ad127a5-eac0-83ea-a876-c3136be322e3', 'musashi_cutin_v01.png', 'musashi_cutin_prompt_v01.txt'),
]
records = []
palette = json.loads((root / 'records/musashi_batch_palette.json').read_text())
allowed_colors = {tuple(c) for c in palette['rgb']}
for name, candidate, count, size, url, original, prompt in specs:
    source = root / 'candidates' / candidate
    im = Image.open(source)
    expected = (size * count, size) if size else (400, 320)
    assert im.size == expected and im.mode == 'RGBA' and im.format == 'PNG'
    assert set(im.getchannel('A').getdata()) == {0, 255}
    colors = {p[:3] for p in im.getdata() if p[3] == 255}
    assert colors <= allowed_colors
    frames = []
    for index in range(count):
        f = im.crop((index * size, 0, (index + 1) * size, size)) if size else im
        bbox = f.getbbox()
        assert min(bbox[0], bbox[1], f.width - bbox[2], f.height - bbox[3]) >= 2
        if size:
            assert bbox[3] - 1 == 59
            assert abs((bbox[0] + bbox[2] - 1) / 2 - 31.5) <= 0.5
        frames.append({'index': index, 'size': f.size, 'bbox_exclusive': bbox, 'colors': len({p[:3] for p in f.getdata() if p[3] == 255}), 'baseline_y': 59 if size else None})
    if not size:
        logical = Image.open(root / 'candidates/musashi_cutin_logical_v02.png')
        assert im.tobytes() == logical.resize((400, 320), Image.Resampling.NEAREST).tobytes()
    approved = final / f'{name}.png'
    shutil.copy2(source, approved)
    target = destination / approved.name
    if target.exists() and target.read_bytes() != approved.read_bytes():
        backup = root / 'backup_before_replace'
        backup.mkdir(exist_ok=True)
        shutil.copy2(target, backup / f'{datetime.now():%Y%m%d_%H%M%S}_{target.name}')
    shutil.copy2(approved, target)
    record = {
        'id': name, 'status': 'self_check_passed_pending_game_review',
        'file': str(target.relative_to(assets)), 'source': f'originals/{original}',
        'approved_copy': f'approved/{approved.name}', 'candidate': f'candidates/{candidate}',
        'tools': ['ChatGPT web in Chrome', 'Pillow 11.1.0 local normalization'],
        'generation_url': url, 'prompt': f'records/{prompt}',
        'references': ['assets/source/norse_pixel_2026-10-16_overview.png'] if name == 'musashi' else ['candidates/musashi_nearest_v02.png', 'originals/musashi_base_v01.png'],
        'size': im.size, 'frame_size': [size, size] if size else None, 'frame_count': count,
        'colors': len(colors), 'batch_palette': 'records/musashi_batch_palette.json',
        'sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'frames': frames,
        'checks': {'exact_size_png_rgba': True, 'binary_transparency': True, 'palette_subset': True,
                   'two_pixel_margin': True, 'centered': True, 'fixed_foot_baseline': True if size else 'not_applicable_portrait',
                   'facing_right_visual_review': True, 'style_light_outline_visual_review': True,
                   'one_x_dark_background_review': True, 'no_text_watermark_scene_visual_review': True,
                   'anatomy_and_proportions_frame_review': True,
                   'loop_seam': 'not_applicable_single_play_action' if count > 1 else 'not_applicable_static'},
        'game_test': 'not_performed',
    }
    if count > 1:
        gif = root / f'previews/{name}_v02.gif'
        animation = Image.open(gif)
        durations = [frame.info['duration'] for frame in ImageSequence.Iterator(animation)]
        assert animation.size == (256, 256) and len(durations) == count
        assert sum(durations) == count * 125
        record['preview'] = {'gif': str(gif.relative_to(root)), 'size': [256, 256], 'frame_count': count, 'durations_ms': durations, 'average_fps': 8, 'note': 'GIF centisecond timing uses alternating 120/130 ms. Hurt/death are single-play actions; the preview repeats for inspection.'}
    records.append(record)

for action, count, url in [('idle', 4, 'https://chatgpt.com/c/6ad126f3-2310-83ea-9f8a-87eb0067729f'), ('move', 6, 'https://chatgpt.com/c/6ad126f6-3358-83e9-b928-4d3bee281d32')]:
    im = Image.open(root / f'candidates/musashi_{action}_v03.png')
    reason = 'Face, shoes and garment pixels drift between frames; not a stable breathing cycle.' if action == 'idle' else 'Last two frames change torso orientation; cycle does not connect cleanly to the first frame. Arm/leg alternation remains inconsistent.'
    records.append({'id': f'musashi_{action}', 'status': 'rejected_needs_revision', 'expected_final': f'sprites/characters/musashi_{action}.png', 'source': [f'originals/musashi_{action}_v01.png', f'originals/musashi_{action}_v02.png'], 'candidate': f'candidates/musashi_{action}_v03.png', 'tools': ['ChatGPT web in Chrome', 'Pillow 11.1.0 local normalization'], 'generation_url': url, 'prompts': [f'records/musashi_{action}_prompt_v01.txt', f'records/musashi_{action}_prompt_v02.txt'], 'references': ['candidates/musashi_nearest_v02.png', 'originals/musashi_base_v01.png'], 'size': im.size, 'frame_size': [64, 64], 'frame_count': count, 'colors': len({p[:3] for p in im.getdata() if p[3] == 255}), 'checks': {'exact_size_png_rgba': True, 'binary_transparency': set(im.getchannel('A').getdata()) == {0, 255}, 'anatomy_and_frame_consistency': False, 'loop_seam': False}, 'rejection_reason': reason, 'preview_gif': f'previews/musashi_{action}_v03.gif', 'game_test': 'not_performed'})

manifest = {'batch': 'batch01_musashi_2026-10-16', 'date': '2026-10-16', 'status': 'incomplete_4_of_6_self_checked', 'approved_count': 4, 'rejected_count': 2, 'terrain_4x4_preview': 'not_applicable_no_terrain_in_batch_1', 'batch_order': {'1': 'incomplete', '2': 'not_started', '3': 'not_started', '4': 'not_started', '5': 'not_started', '6': 'not_started'}, 'assets': records, 'game_test': 'not_performed_by_art_agent'}
(root / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
print(json.dumps({'approved': [r['file'] for r in records if 'file' in r], 'rejected': ['musashi_idle', 'musashi_move']}, ensure_ascii=False))
