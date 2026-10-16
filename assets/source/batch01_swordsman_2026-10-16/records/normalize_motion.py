import argparse
import json
from pathlib import Path
from statistics import median

from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument('action', choices=['idle', 'move', 'hurt', 'death'])
parser.add_argument('--columns', type=int, required=True)
parser.add_argument('--rows', type=int, required=True)
parser.add_argument('--height', type=int, default=48)
parser.add_argument('--row-split', type=int)
parser.add_argument('--source-version', default='v01')
parser.add_argument('--output-version', default='v02')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
source = Image.open(root / f'originals/swordsman_{args.action}_{args.source_version}.png').convert('RGBA')
base = Image.open(root / 'candidates/swordsman_nearest_v02.png').convert('RGBA')
colors = sorted({p[:3] for p in base.getdata() if p[3] == 255})
palette = Image.new('P', (1, 1))
palette.putpalette([v for color in colors for v in color] + list(colors[-1]) * (256 - len(colors)))
cells = []
boxes = []
for row in range(args.rows):
    for column in range(args.columns):
        top = (0 if row == 0 else args.row_split) if args.row_split else round(row * source.height / args.rows)
        bottom = (args.row_split if row == 0 else source.height) if args.row_split else round((row + 1) * source.height / args.rows)
        cell = source.crop((round(column * source.width / args.columns), top, round((column + 1) * source.width / args.columns), bottom))
        alpha = cell.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
        cell.putalpha(alpha)
        bbox = alpha.getbbox()
        if not bbox:
            raise ValueError('Empty frame')
        cells.append(cell)
        boxes.append(bbox)
height_reference = boxes[0][3] - boxes[0][1] if args.action == 'death' else median(box[3] - box[1] for box in boxes)
scale = args.height / height_reference
strip = Image.new('RGBA', (64 * len(cells), 64))
preview_frames = []
report = {'action': args.action, 'source_size': source.size, 'grid': [args.columns, args.rows], 'source_bboxes_exclusive': boxes, 'shared_scale_all_frames': scale, 'palette_source': 'candidates/swordsman_nearest_v02.png', 'frames': []}
contact = Image.new('RGB', (len(cells) * 274, 330), '#121721')
draw = ImageDraw.Draw(contact)
for index, (cell, bbox) in enumerate(zip(cells, boxes)):
    subject = cell.crop(bbox)
    target = (round(subject.width * scale), round(subject.height * scale))
    if target[0] > 60 or target[1] > 58:
        raise ValueError(f'Frame {index} does not fit without changing scale: {target}')
    subject = subject.resize(target, Image.Resampling.NEAREST)
    alpha = subject.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
    subject = subject.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE).convert('RGBA')
    subject.putalpha(alpha)
    frame = Image.new('RGBA', (64, 64))
    offset = ((64 - subject.width) // 2, 60 - subject.height)
    frame.paste(subject, offset)
    frame.save(root / f'candidates/swordsman_{args.action}_frame_{index:02d}_{args.output_version}.png')
    strip.paste(frame, (index * 64, 0))
    preview = Image.new('RGB', (256, 256), '#121721')
    enlarged = frame.resize((256, 256), Image.Resampling.NEAREST)
    preview.paste(enlarged, (0, 0), enlarged)
    preview_frames.append(preview)
    contact.paste(frame, (index * 274 + 8, 18), frame)
    contact.paste(preview, (index * 274 + 8, 86))
    draw.text((index * 274 + 90, 24), f'Frame {index + 1}', fill='white')
    report['frames'].append({'index': index, 'scaled_subject': target, 'offset': offset, 'bbox_exclusive': frame.getbbox()})
strip.save(root / f'candidates/swordsman_{args.action}_{args.output_version}.png')
preview_frames[0].save(root / f'previews/swordsman_{args.action}_{args.output_version}.gif', save_all=True, append_images=preview_frames[1:], duration=[120 if index % 2 == 0 else 130 for index in range(len(preview_frames))], loop=0, disposal=2, optimize=False)
contact.save(root / f'previews/swordsman_{args.action}_contact_{args.output_version}.png')
(root / f'records/swordsman_{args.action}_normalization_{args.output_version}.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
