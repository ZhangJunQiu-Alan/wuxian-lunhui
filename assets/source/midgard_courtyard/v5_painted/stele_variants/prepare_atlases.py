"""Rebuild only the approach stele regions from the pre-integration atlases."""
import json
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np
from PIL import Image

VARIANTS = Path(__file__).resolve().parent
SOURCE = VARIANTS.parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(SOURCE))

from prepare_room import PPU, WEST_ORIGIN, depth, foot_depth
from prepare_stelae import layout, painted_stelae

BACKUP = VARIANTS / "过程/原图集"
DESTINATION = SOURCE.parents[2] / "models/midgard/courtyard/v5_painted"
FOREGROUND = "approach-foreground.png"
DEPTH = "depth-approach-foreground.png"
GROUND = "room-ground.png"


def build():
    manifest = json.loads((VARIANTS / "分配.json").read_text())
    projection = json.loads((SOURCE / "引导/projection.json").read_text())
    depth_per_pixel = projection["basis_y"][1] / (PPU * projection["basis_z"][1])
    ground_depth = depth("depth-approach-ground")
    foreground = Image.open(BACKUP / FOREGROUND).convert("RGBA")
    depths = Image.open(BACKUP / DEPTH).convert("RGB")
    ground = Image.open(BACKUP / GROUND).convert("RGB")
    previous = list(painted_stelae(layout()))

    # Remove exactly the previous stelae, preserving the firs in the same atlas.
    for entry, (old, sprite, _, (x, y)) in zip(manifest["placements"], previous, strict=True):
        if entry["foot_px"] != old["foot"] or entry["original_height_px"] != old["height"]:
            raise ValueError(f"Old placement differs at slot {entry['slot']}")
        box = (x, y, x + sprite.width, y + sprite.height)
        alpha = sprite.getchannel("A")
        old_alpha = np.asarray(alpha)
        actual = np.asarray(foreground.crop(box).getchannel("A"))
        if not np.array_equal(actual[old_alpha > 0], old_alpha[old_alpha > 0]):
            raise ValueError(f"Backup foreground does not match old stele {entry['slot']}")
        foreground.paste((0, 0, 0, 0), box, alpha.point(lambda value: 255 if value else 0))
        depths.paste((0, 0, 0), box, alpha.point(lambda value: 255 if value >= 128 else 0))

    for entry in manifest["placements"]:
        patch = Image.open(VARIANTS / entry["replace_ground_patch"]).convert("RGBA")
        x, y = entry["ground_patch_top_left_2x_px"]
        if list(patch.size) != entry["ground_patch_size_px"]:
            raise ValueError(f"Wrong ground patch size at slot {entry['slot']}")
        ground.paste(patch, (x + WEST_ORIGIN[0], y + WEST_ORIGIN[1]), patch.getchannel("A"))

    for entry in manifest["placements"]:
        x, y = entry["placement_top_left_2x_px"]
        size = tuple(entry["placement_size_2x_px"])
        sprite = Image.open(VARIANTS / entry["depth_writing_layer"]).convert("RGBA")
        mask = Image.open(VARIANTS / entry["occlusion_alpha"]).convert("L")
        contact = Image.open(VARIANTS / entry["ground_contact_layer"]).convert("RGBA")
        if (entry["mirror_x"] or list(sprite.size) != entry["layer_size_px"]
                or contact.size != sprite.size or mask.tobytes() != sprite.getchannel("A").tobytes()):
            raise ValueError(f"Mismatched sprite, ground contact, or depth mask at slot {entry['slot']}")
        sprite = sprite.resize(size, Image.Resampling.LANCZOS)
        contact = contact.resize(size, Image.Resampling.LANCZOS)
        ground.paste(contact, (x + WEST_ORIGIN[0], y + WEST_ORIGIN[1]), contact.getchannel("A"))
        foreground.alpha_composite(sprite, (x, y))
        code = foot_depth(ground_depth, *entry["depth_sample_foot_px"], depth_per_pixel)
        depth_mask = sprite.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
        depths.paste(code, (x, y, x + sprite.width, y + sprite.height), depth_mask)

    with TemporaryDirectory(prefix="stele-atlases-", dir=VARIANTS) as temporary:
        staging = Path(temporary)
        for filename, image in ((FOREGROUND, foreground), (DEPTH, depths), (GROUND, ground)):
            image.save(staging / filename)
        for filename in (FOREGROUND, DEPTH, GROUND):
            (staging / filename).replace(DESTINATION / filename)


if __name__ == "__main__":
    build()
