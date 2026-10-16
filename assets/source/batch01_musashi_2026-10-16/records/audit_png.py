import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('path', type=Path)
parser.add_argument('--frame', type=int, required=True)
parser.add_argument('--frames', type=int, default=1)
args = parser.parse_args()
im = Image.open(args.path)
rgba = im.convert('RGBA')
results = []
for index in range(args.frames):
    frame = rgba.crop((index * args.frame, 0, (index + 1) * args.frame, args.frame))
    alpha = frame.getchannel('A')
    bbox = alpha.getbbox()
    results.append({
        'index': index,
        'bbox_exclusive': bbox,
        'baseline_y': bbox[3] - 1 if bbox else None,
        'opaque_colors': len({p[:3] for p in frame.getdata() if p[3] == 255}),
        'alpha_values': sorted(set(alpha.getdata())),
        'two_pixel_margin': bool(bbox and min(bbox[0], bbox[1], args.frame - bbox[2], args.frame - bbox[3]) >= 2),
        'horizontal_bbox_center': (bbox[0] + bbox[2] - 1) / 2 if bbox else None,
        'sha256_rgba': hashlib.sha256(frame.tobytes()).hexdigest(),
    })
print(json.dumps({
    'file': str(args.path),
    'format': im.format,
    'mode': im.mode,
    'size': im.size,
    'expected_size': [args.frame * args.frames, args.frame],
    'exact_size': im.size == (args.frame * args.frames, args.frame),
    'sha256_file': hashlib.sha256(args.path.read_bytes()).hexdigest(),
    'frame_results': results,
    'manual_checks': {
        'facing_right': 'pending',
        'style_palette_outline_light': 'pending',
        'one_x_dark_background_readability': 'pending',
        'no_text_watermark_background': 'pending',
        'anatomy_and_frame_consistency': 'pending',
        'loop_review': 'pending' if args.frames > 1 else 'not_applicable',
    },
    'game_test': 'not_performed',
}, ensure_ascii=False, indent=2))
