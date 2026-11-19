from pathlib import Path
from PIL import Image, ImageChops
import math

source = Path(__file__).parent
root = source.parents[2] / 'models/midgard/courtyard/v5_painted'
original = Image.open(source / '过程/brazier-r09.png').convert('RGBA')
paint = Image.open(source / '过程/brazier-r10-snow-redraw.png').convert('RGBA')
paint = paint.resize((round(paint.width * .30), round(paint.height * .30)), Image.Resampling.LANCZOS)
snow = Image.new('RGBA', (400, 310))
snow.alpha_composite(paint, (-55, 18))
mask = Image.new('L', snow.size)
values = []
for y in range(snow.height):
    for x in range(snow.width):
        crest = 228 + 3 * math.sin(x / 18) + 2 * math.sin(x / 8)
        top = max(0, min(1, (y - crest) / 5))
        edge = max(0, min(1, x / 20, (399 - x) / 20, (309 - y) / 15))
        values.append(round(255 * top * edge))
mask.putdata(values)
snow.putalpha(ImageChops.multiply(snow.getchannel('A'), mask))
result = Image.new('RGBA', snow.size)
result.alpha_composite(original, (64, 0))
result.alpha_composite(snow)

# Taper both drift ends into the ground and cool the snow toward the surrounding ground tone.
import numpy as np
pixels = np.asarray(result).astype(np.float32)
h, w, _ = pixels.shape
def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)
lower = smooth((np.arange(h) - 205) / 25.0)[:, None]
across = 1 - smooth((np.abs(np.arange(w) - w / 2) / (w / 2 - 8) - .62) / .38)
pixels[..., 3] *= 1 - (1 - across[None, :]) * lower
bright = (pixels[..., :3].mean(axis=2) > 150)[..., None]
cool = .28 * lower[..., None] * bright
pixels[..., :3] = pixels[..., :3] * (1 - cool) + np.array([186, 190, 214], np.float32) * cool
Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).save(root / 'brazier-grounded.png')
