from pathlib import Path
import json

from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'originals/swordsman_cutin_v01.png').convert('RGBA')
source.putalpha(source.getchannel('A').point(lambda v: 255 if v >= 128 else 0))
base = Image.open(root / 'candidates/swordsman_nearest_v02.png').convert('RGBA')
colors = sorted({p[:3] for p in base.getdata() if p[3] == 255})
portrait = source.crop((300, 250, 1280, 1034)).convert('RGB').quantize(colors=15, dither=Image.Dither.NONE).convert('RGB')
eye_highlight = max((p[:3] for p in source.crop((850, 530, 980, 625)).getdata() if p[3] == 255), key=sum)
colors = list(dict.fromkeys(colors + sorted(set(portrait.getdata())) + [eye_highlight]))
(root / 'records/swordsman_batch_palette.json').write_text(json.dumps({'rgb': colors, 'count': len(colors), 'base': 'candidates/swordsman_nearest_v02.png', 'additional_shades': 'originals/swordsman_cutin_v01.png'}, indent=2))
palette = Image.new('P', (1, 1))
palette.putpalette([v for color in colors for v in color] + list(colors[-1]) * (256 - len(colors)))
crop = source.crop((300, 250, 1280, 1034)).resize((195, 156), Image.Resampling.NEAREST)
alpha = crop.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
crop = crop.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE).convert('RGBA')
crop.putalpha(alpha)
logical = Image.new('RGBA', (200, 160))
logical.paste(crop, (2, 2))
logical.save(root / 'candidates/swordsman_cutin_logical_v02.png')
logical.resize((400, 320), Image.Resampling.NEAREST).save(root / 'candidates/swordsman_cutin_v02.png')
