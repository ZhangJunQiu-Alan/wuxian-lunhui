"""Composite the registered west and east paintings and export the room depth cutouts."""
import json

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

from prepare_layers import (
    DEST, EDGE_SIZE, GUIDES, SOURCE, extended_paint,
    group_mask, ids, restored_without_left_brace, rgb, smooth,
)
from prepare_stelae import layout as stelae_layout, old_stela_mask, painted_stelae

# Projection bounds relative to the original middle-court guide, in world units.
PPU = 64
ROOM_SIZE = (64 * PPU, 2192)
WEST_SIZE = (48 * PPU, 32 * PPU)
EAST_ORIGIN = (24 * PPU, 144)
WEST_ORIGIN = (0, 144)
MARGIN_ORIGIN = (33 * PPU, 0)
RESAMPLE = Image.Resampling.LANCZOS
WEST_PAINT_SIZE = (1536, 1024)
# Matches the approach layer's depth offset in fimbulwinter_courtyard_painted.gd.
WEST_DEPTH_SHIFT = 4


def paint(name, size):
    return Image.open(SOURCE / name).convert("RGB").resize(size, RESAMPLE)


def mask_image(values):
    return Image.fromarray(np.round(values * 255).astype(np.uint8))


def east_plate(palette):
    mask = group_mask(ids("dormant"), ["longhouse", "entrance", "walls", "standing_stones",
        "scree", "landmarks"], palette).filter(ImageFilter.MinFilter(7))
    gate_groups = ["gate_jambs", "gate_lintel", "gate_shutter"]
    gates = ImageChops.lighter(group_mask(ids("dormant"), gate_groups, palette),
                              group_mask(ids("restored"), gate_groups, palette))
    mask = ImageChops.lighter(mask, gates.filter(ImageFilter.MaxFilter(39)))
    surface = restored_without_left_brace(rgb("court-paint.png"))
    return extended_paint(Image.composite(rgb("court-underpaint.png"), surface, mask))


def depth(name):
    return Image.open(GUIDES / (name + ".png")).convert("RGB").resize(WEST_SIZE, Image.Resampling.NEAREST)


def dusk(image):
    channels = np.asarray(image, dtype=np.float32)
    warm = np.maximum(channels[:, :, 0] - channels[:, :, 1] - 5, 0)
    tint = channels * [.94, .95, .96] + warm[:, :, None] * [-.32, -.10, .20]
    return Image.fromarray(np.clip(tint, 0, 255).round().astype(np.uint8))


def shade_snow(image, shading):
    channels = np.asarray(image, dtype=np.float32)
    luma = channels @ [.2126, .7152, .0722]
    amount = shading * smooth(54, 97, luma)
    shadow = amount * (1 - smooth(90, 155, luma))
    tint = channels * (1 - amount[:, :, None] * [.143, .133, .084])
    tint += shadow[:, :, None] * [1, -1.5, 2]
    return Image.fromarray(np.clip(tint, 0, 255).round().astype(np.uint8))


def refine_approach(west, clear, join, cols, rows):
    guide = json.loads((GUIDES / "approach-refine-r07.json").read_text())
    bank_edge = np.interp(cols, *zip(*guide["bank_edge"]))
    crest = np.interp(cols, *zip(*guide["cliff_crest"]))
    outside_wall = 1 - smooth(bank_edge - 16, bank_edge - 4, rows)
    edit = paint("approach-forest-sea-r07.png", WEST_PAINT_SIZE)

    forest = outside_wall * smooth(315, 450, cols) * (1 - smooth(905, 995, cols))
    forest *= smooth(190, 360, rows)
    west.paste(edit, mask=mask_image(forest))
    left, top, right, bottom = guide["bank_crop"]
    near_bank = paint("approach-forest-bank-r07.png", (right - left, bottom - top))
    patch = np.s_[top:bottom, left:right]
    bank_blend = outside_wall[patch] * smooth(left, left + 35, cols[patch])
    bank_blend *= (1 - smooth(right - 37, right, cols[patch])) * smooth(top, top + 32, rows[patch])
    west.paste(near_bank, (left, top), mask_image(bank_blend))

    # Reframe the painted cliff face below the fixed snow lip and blend into
    # the existing sea. Samples stay monotonic through the bottom overscan.
    reveal = np.interp(cols, *zip(*guide["sea_reveal"]))
    edge = WEST_PAINT_SIZE[1] - 1
    pivot = 945
    source_rows = np.where(
        rows <= pivot, rows + reveal * smooth(crest + 5, crest + 36, rows),
        rows + reveal * (edge - rows) / (edge - pivot))
    pixels = np.asarray(edit)
    below = np.floor(source_rows).astype(int)
    fraction = (source_rows - below)[:, :, None]
    sea = pixels[below, cols] * (1 - fraction) + pixels[np.minimum(below + 1, edge), cols] * fraction
    sea_blend = smooth(crest + 4, crest + 26, rows) * smooth(750, 850, cols) * (1 - smooth(1010, 1100, cols))
    west.paste(Image.fromarray(sea.round().astype(np.uint8)), mask=mask_image(sea_blend))

    road = Image.new("L", WEST_PAINT_SIZE)
    ImageDraw.Draw(road).polygon([tuple(point) for point in guide["road"]], fill=255)
    road = road.filter(ImageFilter.MaxFilter(13)).filter(ImageFilter.GaussianBlur(4))
    shading = np.asarray(join, dtype=np.float32) / 255 * (1 - np.asarray(road, dtype=np.float32) / 255)
    shading *= 1 - smooth(crest - 4, crest + 10, rows)
    return shade_snow(west, shading), shade_snow(clear, shading)


def contour_mask(contours):
    mask = Image.new("L", WEST_PAINT_SIZE)
    samples = []
    for item in contours:
        shape = item.get("matte")
        if shape is None:
            shape = Image.new("L", WEST_PAINT_SIZE)
            ImageDraw.Draw(shape).polygon(item["outline"], fill=255)
        mask = ImageChops.lighter(mask, shape)
        samples.append((shape, item["foot"]))
    return mask, samples


def foot_depth(ground, x, y, depth_per_pixel):
    px, py = x * 2, y * 2
    row = py
    r, g, _ = ground.getpixel((px, row))
    # The guide clamps to depth 7. Continue the projected ground slope
    # from the nearest in-range sample for roots on the foreground ledge.
    while not (r or g) and row > 0:
        row -= 1
        r, g, _ = ground.getpixel((px, row))
    shift = WEST_DEPTH_SHIFT - (py - row) * depth_per_pixel
    code = round(256 * r + g + shift * 65535 / 23)
    return (*divmod(code, 256), 0)


def west_layers(projection, placements):
    old_contours = json.loads((GUIDES / "approach-contours.json").read_text())
    stones = [item for item in old_contours if item["name"] != "海侧冷杉"]
    firs = json.loads((GUIDES / "approach-fir-contours-r07.json").read_text())
    stone_mask, _ = contour_mask(stones)

    old = paint("approach-paint.png", WEST_PAINT_SIZE)
    repaint = dusk(paint("approach-paint-r07.png", WEST_PAINT_SIZE))
    clear = dusk(paint("approach-underpaint-r07.png", WEST_PAINT_SIZE))
    for fir in firs:
        if "offset" not in fir:
            continue
        dx, dy = fir["offset"]
        x, y = fir["foot"]
        scale = fir.get("scale", 1)
        affine = (1 / scale, 0, x - (x + dx) / scale,
                  0, 1 / scale, y - (y + dy) / scale)
        original, _ = contour_mask([fir])
        neighbors, _ = contour_mask(item for item in firs if item is not fir)
        removal = original.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(2))
        removal = ImageChops.subtract(removal, neighbors)
        difference = np.asarray(ImageChops.difference(repaint, clear)).max(axis=2)
        needles = mask_image(smooth(19, 45, difference))
        matte = ImageChops.lighter(original.filter(ImageFilter.MinFilter(9)),
                                   ImageChops.multiply(original, needles))
        matte = matte.filter(ImageFilter.GaussianBlur(.65))
        shifted = repaint.transform(WEST_PAINT_SIZE, Image.Transform.AFFINE, affine, Image.Resampling.BICUBIC)
        fir["matte"] = matte.transform(WEST_PAINT_SIZE, Image.Transform.AFFINE, affine, Image.Resampling.BICUBIC)
        repaint = Image.composite(clear, repaint, removal)
        repaint = Image.composite(shifted, repaint, fir["matte"])
        fir["foot"] = (x + dx, y + dy)
    fir_mask, firs_at = contour_mask(firs)

    cols, rows = np.meshgrid(np.arange(old.width), np.arange(old.height))
    # Follow the bend toward the gate, fading back to the approved court palette.
    join = np.interp(rows, [0, 480, 620, 720, 800, 1023], [950, 970, 1045, 1095, 1150, 1240])
    repaint_weight = mask_image(1 - smooth(join - 48, join + 45, cols))
    west = Image.composite(repaint, old, repaint_weight)
    old_clear = paint("approach-underpaint.png", WEST_PAINT_SIZE)
    clear = Image.composite(clear, old_clear, repaint_weight)
    west, clear = refine_approach(west, clear, repaint_weight, cols, rows)

    # Preserve the original pigment around the registered replacement patches.
    protected = stone_mask.copy()
    for box in [(653, 621, 697, 700), (747, 555, 787, 616), (944, 443, 987, 519)]:
        ImageDraw.Draw(protected).rounded_rectangle(box, radius=8, fill=255)
    protected = protected.filter(ImageFilter.MaxFilter(25)).filter(ImageFilter.GaussianBlur(3))
    west = Image.composite(old, west, protected).resize(WEST_SIZE, RESAMPLE)

    # Exact same outer pigment on both layers. Underpaint only inside the traced
    # silhouette, so the antialiased fringe reads continuously against the plate.
    fir_mask = fir_mask.resize(WEST_SIZE, RESAMPLE)
    fir_clear = clear.resize(WEST_SIZE, RESAMPLE)
    underpaint = Image.composite(fir_clear, west, fir_mask.filter(ImageFilter.MinFilter(5)))
    padding = fir_mask.filter(ImageFilter.MaxFilter(5)).point(lambda value: 255 if value else 0)
    foreground = Image.composite(west, Image.new("RGB", WEST_SIZE), padding)
    foreground.putalpha(fir_mask)

    codes = Image.new("RGB", WEST_SIZE)
    ground_depth = depth("depth-approach-ground")
    depth_per_pixel = projection["basis_y"][1] / (PPU * projection["basis_z"][1])
    samples = [(foot_depth(ground_depth, x, y, depth_per_pixel),
                shape.resize(WEST_SIZE, Image.Resampling.NEAREST))
               for shape, (x, y) in firs_at]
    for stele, sprite, _, origin in placements:
        foreground.alpha_composite(sprite, origin)
        mask = Image.new("L", WEST_SIZE)
        mask.paste(sprite.getchannel("A"), origin)
        x, y = stele["foot"]
        samples.append((foot_depth(ground_depth, x, y, depth_per_pixel), mask))
    foreground.save(DEST / "approach-foreground.png")
    for code, shape in sorted(samples, key=lambda sample: sample[0], reverse=True):
        depth_mask = shape.point([0] * 128 + [255] * 128)
        codes.paste(code, (0, 0, *WEST_SIZE), depth_mask)
    codes.save(DEST / "depth-approach-foreground.png")
    return underpaint


def clear_old_stelae(room, stelae, placements):
    mask = old_stela_mask(stelae, WEST_SIZE)
    left, top, right, bottom = (n * 2 for n in stelae["underpaint_crop"])
    underpaint = paint("approach-stele-v2-underpaint.png", (right - left, bottom - top))
    target = (left, top + WEST_ORIGIN[1])
    room.paste(underpaint, target, mask.crop((left, top, right, bottom)))

    contact = Image.new("L", underpaint.size)
    draw = ImageDraw.Draw(contact)
    for stele in stelae["stelae"]:
        x, y = stele["foot"]
        h = stele["height"]
        x, y = x * 2 - left + h * .08, y * 2 - top + h * .13
        rx, ry = h * .62, h * .21
        draw.ellipse((round(x - rx), round(y - ry), round(x + rx), round(y + ry)), fill=115)
    room.paste("#16283e", (*target, target[0] + contact.width, target[1] + contact.height),
               contact.filter(ImageFilter.GaussianBlur(5)))
    for _, _, skirt, (x, y) in placements:
        room.paste(skirt, (x, y + WEST_ORIGIN[1]), skirt.getchannel("A"))

    # The last approach marker straddles the inner court parapet atlas.
    path = DEST / "parapets.png"
    with Image.open(path) as image:
        parapets = image.convert("RGBA")
    offset = EAST_ORIGIN[0] - WEST_ORIGIN[0]
    atlas_mask = mask.crop((offset, 0, offset + parapets.width, parapets.height))
    original_alpha = parapets.getchannel("A")
    alpha = ImageChops.darker(original_alpha, ImageChops.invert(atlas_mask))
    if ImageChops.difference(alpha, original_alpha).getbbox():
        parapets.putalpha(alpha)
        parapets.save(path)


def run():
    projection = json.loads((GUIDES / "projection.json").read_text())
    stelae = stelae_layout()
    placements = list(painted_stelae(stelae))
    west = west_layers(projection, placements)
    east = east_plate(dict(projection["groups_rgb"]))
    rim = paint("court-east-edge.png", EDGE_SIZE)
    room = Image.new("RGB", ROOM_SIZE, "#17263a")
    # Fill the unused overscan with painted pigment too. Keep the full eastern
    # extension in its original projection where the exit camera can see it.
    room.paste(rim.crop((1650, 1024, 2230, 1536)).resize((1984, 684), RESAMPLE), (2112, 1508))
    room.paste(rim, MARGIN_ORIGIN)
    room.paste(west.crop((0, 0, WEST_SIZE[0], 144)).transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0, 0))
    room.paste(west, WEST_ORIGIN)
    # Restore the east margin beyond the west overlap (the borrowed part is
    # blended continuously with the registered middle-court ground below).
    rcols = np.arange(EDGE_SIZE[0])[None, :] + MARGIN_ORIGIN[0]
    rrows = np.arange(EDGE_SIZE[1])[:, None]
    east_weight = np.maximum(smooth(2900, 3100, rcols),
        (1 - smooth(105, 160, rrows)) * smooth(2070, 2240, rcols))
    room.paste(rim, MARGIN_ORIGIN, mask_image(east_weight))

    # The join follows the crest of the cliff and the continuous approach lane.
    # Leave the original east art exact in the playable middle and at both gates.
    cols, rows = np.meshgrid(np.arange(EDGE_SIZE[0]), np.arange(EDGE_SIZE[1]))
    merge = np.interp(rows, [0, 680, 1050, 1300, 1536], [385, 350, 420, 640, 910])
    weight = smooth(merge - 110, merge + 140, cols)
    weight *= smooth(0, 60, rows) * smooth(0, 75, EDGE_SIZE[1] - 1 - rows)
    weight *= smooth(0, 74, EDGE_SIZE[0] - 1 - cols)
    room.paste(east, EAST_ORIGIN, mask_image(weight))
    clear_old_stelae(room, stelae, placements)
    room.save(DEST / "room-ground.png")


if __name__ == "__main__":
    run()
