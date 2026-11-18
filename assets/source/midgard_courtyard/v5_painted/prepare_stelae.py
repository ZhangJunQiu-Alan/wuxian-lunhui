"""Project the replacement stelae at the existing approach anchors."""
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from prepare_layers import GUIDES, SOURCE, smooth

RESAMPLE = Image.Resampling.LANCZOS
STRUCTURE = SOURCE / "blender/stele_v2/stele-v2-structure.png"


def layout():
    return json.loads((GUIDES / "approach-stelae-v2.json").read_text())


def project(source, data, stele, density=1):
    left, top, right, bottom = data["structure_bounds"]
    scale = density * stele["height"] / (bottom - top)
    sprite = source.crop((left, top, right, bottom)).resize(
        (round((right - left) * scale), density * stele["height"]), RESAMPLE)
    source_x, source_y = data["structure_foot"]
    x, y = stele["foot"]
    return sprite, (round(x * density - (source_x - left) * scale),
                    round(y * density - (source_y - top) * scale))


def old_stela_mask(data, size):
    mask = Image.new("L", size)
    draw = ImageDraw.Draw(mask)
    for stele in data["stelae"]:
        draw.polygon([(x * 2, y * 2) for x, y in stele["old_outline"]], fill=255)
        x, y = stele["foot"]
        half_width = stele["height"] * .30
        left, right = x - half_width, x + half_width
        fall = half_width * .48
        draw.polygon([(round(u * 2), round(v * 2)) for u, v in [
            (left, y - 33 + fall), (right, y - 33 - fall),
            (right, y + 11 - fall), (left, y + 11 + fall),
        ]], fill=255)
    return mask.filter(ImageFilter.MaxFilter(27)).filter(ImageFilter.GaussianBlur(4))


def painted_stelae(data):
    paint = Image.open(SOURCE / "approach-stele-v2-painted.png").convert("RGBA")
    for stele in data["stelae"]:
        sprite, origin = project(paint, data, stele, density=2)
        alpha = sprite.getchannel("A")
        cols = np.linspace(0, 1, sprite.width)[None, :]
        rows = np.linspace(0, 1, sprite.height)[:, None]
        snow_line = .93 - .27 * cols
        zone = smooth(snow_line, snow_line + .09, rows)

        # Feather the windblown snow below the depth-writing rubble.
        firm = alpha.filter(ImageFilter.MinFilter(round(sprite.height * .075) | 1))
        firm = firm.filter(ImageFilter.GaussianBlur(2.2))
        edge = np.asarray(firm, dtype=np.float32)
        opacity = np.asarray(alpha, dtype=np.float32)
        floor_alpha = np.minimum(opacity, edge * 2.15) * zone
        cut_alpha = opacity * (1 - zone) + edge * zone
        skirt = sprite.copy()
        skirt.putalpha(Image.fromarray(floor_alpha.round().astype(np.uint8)))
        sprite.putalpha(Image.fromarray(cut_alpha.round().astype(np.uint8)))
        yield stele, sprite, skirt, origin
