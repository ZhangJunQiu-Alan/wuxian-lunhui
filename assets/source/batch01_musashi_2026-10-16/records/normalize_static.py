from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'originals/musashi_base_v01.png').convert('RGBA')
mask = source.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
bbox = mask.getbbox()
source.putalpha(mask)
subject = source.crop(bbox)
width = round(subject.width * 48 / subject.height)
for name, method in [('nearest', Image.Resampling.NEAREST), ('box', Image.Resampling.BOX), ('lanczos', Image.Resampling.LANCZOS)]:
    small = subject.resize((width, 48), method)
    alpha = small.getchannel('A').point(lambda value: 255 if value >= 128 else 0)
    rgb = small.convert('RGB').quantize(colors=32, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
    rgb.putalpha(alpha)
    result = Image.new('RGBA', (64, 64))
    result.paste(rgb, ((64 - width) // 2, 12))
    result.save(root / f'candidates/musashi_{name}_v02.png')

background = Image.new('RGB', (3 * 340, 370), '#121721')
from PIL import ImageDraw
draw = ImageDraw.Draw(background)
for index, name in enumerate(['nearest', 'box', 'lanczos']):
    candidate = Image.open(root / f'candidates/musashi_{name}_v02.png')
    background.paste(candidate, (index * 340 + 26, 32), candidate)
    enlarged = candidate.resize((256, 256), Image.Resampling.NEAREST)
    background.paste(enlarged, (index * 340 + 16, 100), enlarged)
    draw.text((index * 340 + 100, 30), name + ' / 64x64 / 32 colors', fill='white')
background.save(root / 'previews/musashi_sampling_comparison.png')
