from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageChops, ImageColor, ImageDraw, ImageFilter


SOURCE = Path(__file__).resolve().parent
DEST = SOURCE.parents[2] / "models/midgard/courtyard/v5_painted"
GUIDES = SOURCE / "引导"
SIZE = (1536, 1024)
EDGE_SIZE = (2304, 1536)
INNER_ORIGIN = (384, 256)
GATE_CROP = (914, 71, 1394, 431)

# Rotoscope the two painted headers. The feet and aperture use the same projection in both states.
DORMANT_OUTLINE = [
    (1005, 329), (1020, 301), (1036, 278), (1042, 211), (1033, 200), (1026, 170),
    (1026, 155), (1032, 146), (1042, 141), (1070, 145), (1111, 164), (1157, 181),
    (1170, 191), (1174, 171), (1190, 163), (1211, 165), (1256, 186), (1278, 191),
    (1286, 202), (1283, 221), (1274, 230), (1270, 253), (1257, 258), (1247, 364),
    (1248, 375), (1256, 381), (1243, 403), (1224, 412), (1204, 407), (1190, 398),
    (1195, 380), (1166, 380), (1130, 369), (1087, 353), (1071, 357), (1040, 346),
    (1032, 337), (1020, 342), (1005, 340),
]
RESTORED_OUTLINE = [
    (1031, 332), (1037, 310), (1044, 266), (1049, 194), (1040, 184),
    (1034, 171), (1023, 157), (1019, 139), (1026, 130), (1037, 127), (1061, 132),
    (1100, 147), (1146, 162), (1194, 184), (1258, 212), (1273, 225), (1274, 242),
    (1265, 249), (1264, 263), (1253, 269), (1246, 365), (1247, 374), (1254, 380),
    (1240, 402), (1225, 413), (1201, 406), (1189, 395), (1195, 362), (1204, 255),
    (1105, 211), (1103, 332), (1087, 343), (1077, 355), (1051, 350), (1035, 342),
    (1031, 332),
]
GATE_PAINT_CHANGE = (992, 114, 1295, 418)
ENTRANCE_CORNERS = [(185, 552), (301, 602), (282, 752), (170, 701)]
EXIT_BOARD_CORNERS = [(1095, 233), (1196, 270), (1184, 374), (1091, 339)]

# Elder Futhark, original paths redrawn from the Unicode character forms.
GLYPHS = {
    "ᚠ": [[(.25, .94), (.25, .11)], [(.25, .42), (.78, .15)], [(.25, .68), (.78, .42)]],
    "ᚢ": [[(.22, .94), (.22, .10), (.75, .52), (.75, .94)]],
    "ᚦ": [[(.25, .94), (.25, .10)], [(.25, .27), (.80, .53), (.25, .76)]],
    "ᚨ": [[(.25, .94), (.25, .11)], [(.25, .23), (.76, .51)], [(.25, .46), (.76, .74)]],
    "ᚱ": [[(.23, .93), (.23, .10), (.77, .35), (.25, .58), (.78, .92)]],
    "ᚲ": [[(.79, .17), (.22, .53), (.79, .89)]],
}


def rgb(name):
    image = Image.open(SOURCE / name).convert("RGB")
    if image.size != SIZE:
        raise ValueError(f"{name} must use the registered {SIZE} canvas")
    return image


def guide(name):
    return Image.open(GUIDES / (name + ".png")).convert("RGB").resize(SIZE, Image.Resampling.NEAREST)


def ids(state):
    return np.asarray(guide("mask-groups-" + state), dtype=np.int16)


def group_mask(index, groups, palette):
    select = np.zeros(index.shape[:2], dtype=bool)
    for group in groups:
        select |= np.max(np.abs(index - ImageColor.getrgb(palette[group])), axis=2) <= 2
    return Image.fromarray(select.astype(np.uint8) * 255)


def polygon(points):
    supersampled = Image.new("L", (SIZE[0] * 3, SIZE[1] * 3))
    ImageDraw.Draw(supersampled).polygon([(round(x * 3), round(y * 3)) for x, y in points], fill=255)
    return supersampled.resize(SIZE, Image.Resampling.LANCZOS)


def isolate(paint, mask, filename):
    # Drop RGB only beyond the antialiased edge, preserving straight-alpha filtering.
    keep_edge = mask.filter(ImageFilter.MaxFilter(5)).point(lambda value: 255 if value else 0)
    layer = Image.composite(paint, Image.new("RGB", paint.size), keep_edge)
    layer.putalpha(mask)
    write_atlas(layer, filename)


def write_atlas(image, filename, outer=None):
    if image.size == SIZE:
        atlas = outer or Image.new(image.mode, EDGE_SIZE)
        atlas.paste(image, INNER_ORIGIN)
        image = atlas
    image.save(DEST / filename)


def depth_value(depth):
    depth = np.asarray(depth, dtype=np.float32)
    return 7.0 + 23.0 * (depth[..., 0] * 256 + depth[..., 1]) / 65535.0


def extend_depth(depth, ground, whitebox_mask, silhouette, name):
    # A small expanded fringe may sit beyond the whitebox raster. Carry its nearest
    # silhouette depth outward so it does not inherit the floor depth through gaps.
    whitebox = np.asarray(whitebox_mask) > 128
    target = np.asarray(silhouette) > 28
    known = whitebox.copy()
    codes = np.asarray(depth).copy()
    for _ in range(78):
        if np.all(known[target]):
            break
        extended = known.copy()
        for axis, step in ((0, 1), (0, -1), (1, 1), (1, -1)):
            adjacent = np.roll(known, step, axis=axis)
            valid = adjacent & ~extended
            codes[valid] = np.roll(codes, step, axis=axis)[valid]
            extended |= adjacent
        known = extended
    # The paintover shifts a few parts farther than the guide contains geometry.
    # Keep those newly exposed cap and footing pixels in front of the backing plate.
    scene = np.asarray(depth, dtype=np.int32)
    floor = np.asarray(ground, dtype=np.int32)
    value = codes[..., 0].astype(np.int32) * 256 + codes[..., 1]
    backing = np.minimum(scene[..., 0] * 256 + scene[..., 1], floor[..., 0] * 256 + floor[..., 1])
    value[target] = np.minimum(value[target], np.maximum(backing[target] - 128, 0))
    codes[..., 0] = value // 256
    codes[..., 1] = value % 256
    write_atlas(Image.fromarray(codes), name)


def export_group_masks(palette):
    mask_dir = GUIDES / "遮罩"
    mask_dir.mkdir(exist_ok=True)
    for state in ("dormant", "restored", "sealed"):
        full_size = Image.open(GUIDES / f"mask-groups-{state}.png")
        index = np.asarray(full_size.convert("RGB"), dtype=np.int16)
        groups = palette.keys() - {"ground", "water"} if state == "dormant" else [
            "gate_jambs", "gate_lintel", "entrance_shutter"
        ]
        for group in sorted(groups):
            mask = group_mask(index, [group], palette)
            if mask.getbbox():
                mask.save(mask_dir / f"{state}-{group}.png")


def world_x(proj, depth):
    height, width = depth.shape
    col, row = np.meshgrid(np.arange(width) + .5, np.arange(height) + .5)
    across = (col - width * .5) / 64.0
    up = (height * .5 - row) / 64.0
    eye_distance = np.linalg.norm(np.array(proj["eye_world"]) - proj["center_world"])
    return (proj["center_world"][0] + across * proj["basis_x"][0]
            + up * proj["basis_y"][0] + (eye_distance - depth) * proj["basis_z"][0])


def smooth(lo, hi, value):
    t = np.clip((value - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def map_quad(image, src, dest):
    rows = []
    values = []
    for (x, y), (u, v) in zip(dest, src):
        rows.extend([[x, y, 1, 0, 0, 0, -x * u, -y * u],
                     [0, 0, 0, x, y, 1, -x * v, -y * v]])
        values.extend([u, v])
    matrix = np.linalg.solve(np.array(rows, dtype=float), values)
    return image.transform(SIZE, Image.Transform.PERSPECTIVE, matrix, Image.Resampling.BICUBIC)


def render_runes():
    scale = 3
    runes = Image.new("L", tuple(n * scale for n in SIZE))
    draw = ImageDraw.Draw(runes)
    for top, bottom in [((1068, 207), (1064, 323)), ((1222, 265), (1213, 379))]:
        for index, rune in enumerate(GLYPHS):
            t = (index + .5) / len(GLYPHS)
            x = top[0] * (1 - t) + bottom[0] * t
            y = top[1] * (1 - t) + bottom[1] * t
            for stroke in GLYPHS[rune]:
                draw.line([
                    (round((x + (u - .5) * 13 - (v - .5) * 1.0) * scale),
                     round((y + (u - .5) * 5 + (v - .5) * 14) * scale))
                    for u, v in stroke
                ], fill=255, width=5, joint="curve")
    crisp = runes.resize(SIZE, Image.Resampling.LANCZOS)
    glow = crisp.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(3.1))
    glow = glow.point(lambda value: round(value * .51))
    alpha = ImageChops.lighter(crisp, glow)
    ink = Image.composite(Image.new("RGB", SIZE, "#d3f9ff"), Image.new("RGB", SIZE, "#42aeed"), crisp)
    isolate(ink, alpha, "gate-runes.png")


def render_effects():
    full = Image.open(SOURCE / "brazier-paint.png").convert("RGBA")
    bbox = full.getchannel("A").point(lambda value: 255 if value >= 30 else 0).getbbox()
    if bbox == (0, 0, *full.size):
        raise ValueError("Brazier paint has no usable transparent border")
    full = full.crop(bbox)
    full.thumbnail((248, 248), Image.Resampling.LANCZOS)
    framed = Image.new("RGBA", (272, 256))
    framed.paste(full, ((272 - full.width) // 2, 250 - full.height))
    framed.save(DEST / "brazier.png")

    t = np.linspace(-1.0, 1.0, 256)
    x, y = np.meshgrid(t, t)
    for name, color, spread in (("ice-halo", "#50baf7", .67), ("warm-halo", "#f9a769", .55)):
        radius = np.sqrt((x * .98) ** 2 + (y * 1.21) ** 2)
        light = np.exp(-(radius / spread) ** 2 * 2.3) * (1.0 - smooth(.50, .98, radius))
        sprite = Image.new("RGB", (256, 256), color)
        sprite.putalpha(Image.fromarray(np.round(light * 255).astype(np.uint8)))
        sprite.save(DEST / (name + ".png"))

    radius = np.sqrt((x * 1.3) ** 2 + (y * 1.78) ** 2)
    alpha = np.exp(-radius ** 2 * 3.4) * (1.0 - smooth(.62, 1.0, radius))
    contact = Image.new("RGB", (256, 256), "#242139")
    contact.putalpha(Image.fromarray(np.round(alpha * 255).astype(np.uint8)))
    contact.save(DEST / "brazier-contact.png")


def gate_without_right_brace(image):
    x0, y0, x1, y1 = GATE_CROP
    edited = Image.open(SOURCE / "gate-without-right-brace.png").convert("RGB")
    edited = edited.resize((x1 - x0, y1 - y0), Image.Resampling.LANCZOS)
    region = Image.new("RGB", SIZE)
    region.paste(edited, (x0, y0))
    mask = polygon([(1246, 258), (1269, 263), (1276, 312), (1294, 376),
                    (1282, 390), (1262, 387), (1242, 377), (1242, 322)])
    return Image.composite(region, image, mask.filter(ImageFilter.GaussianBlur(2.4)))


def restored_without_left_brace(image):
    x0, y0, x1, y1 = GATE_CROP
    edited = Image.open(SOURCE / "gate-restored-without-left-brace.png").convert("RGB")
    edited = edited.resize((x1 - x0, y1 - y0), Image.Resampling.LANCZOS)
    region = Image.new("RGB", SIZE)
    region.paste(edited, (x0, y0))
    mask = polygon([(972, 245), (1016, 229), (1045, 229), (1057, 242),
                    (1057, 335), (1044, 358), (996, 359), (975, 340), (969, 293)])
    return Image.composite(region, image, mask.filter(ImageFilter.GaussianBlur(3.8)))


def extended_paint(inner):
    extension = Image.open(SOURCE / "court-edge-paint.png").convert("RGB")
    extension = extension.resize(EDGE_SIZE, Image.Resampling.LANCZOS)
    left, top = INNER_ORIGIN
    box = (left, top, left + SIZE[0], top + SIZE[1])
    original = np.asarray(inner, dtype=np.int16)
    generated = np.asarray(extension.crop(box), dtype=np.int16)
    cols, rows = np.meshgrid(np.arange(SIZE[0]), np.arange(SIZE[1]))
    distance = np.minimum.reduce([cols, SIZE[0] - 1 - cols, rows, SIZE[1] - 1 - rows])
    match = np.median((original - generated)[(distance >= 16) & (distance <= 50)], axis=0)
    edge_pixels = np.asarray(extension, dtype=np.float32)
    edge_pixels = np.clip(edge_pixels + np.clip(match, -16, 16), 0, 255).astype(np.uint8)
    extension = Image.fromarray(edge_pixels)
    inner_coverage = Image.fromarray(np.round(255 * smooth(6, 72, distance)).astype(np.uint8))
    extension.paste(inner, INNER_ORIGIN, inner_coverage)
    return extension


def run():
    DEST.mkdir(parents=True, exist_ok=True)
    proj = json.loads((GUIDES / "projection.json").read_text())
    palette = dict(proj["groups_rgb"])
    index = ids("dormant")
    restored_ids = ids("restored")
    sealed_ids = ids("sealed")
    main = rgb("court-paint.png")
    underpaint = rgb("court-underpaint.png")
    broken = gate_without_right_brace(rgb("court-broken.png"))
    restored = restored_without_left_brace(gate_without_right_brace(rgb("court-restored.png")))
    ground_depth = guide("depth-ground")
    full_depth = guide("depth-dormant")
    restored_depth = guide("depth-restored")
    sealed_depth = guide("depth-sealed")

    hall = group_mask(index, ["longhouse"], palette)
    whitebox_gate = group_mask(index, ["gate_jambs", "gate_lintel", "gate_shutter"], palette)
    whitebox_restored = group_mask(restored_ids, ["gate_jambs", "gate_lintel"], palette)
    props = group_mask(index, ["entrance", "walls", "standing_stones", "scree", "landmarks"], palette)
    props = ImageChops.subtract(props, hall.filter(ImageFilter.MaxFilter(3)))
    entrance_shutter = group_mask(sealed_ids, ["entrance_shutter"], palette)
    dormant_mask = polygon(DORMANT_OUTLINE)
    restored_mask = polygon(RESTORED_OUTLINE)
    gate_reference = ImageChops.lighter(whitebox_gate, whitebox_restored)
    isolate(main, hall, "longhouse.png")
    isolate(broken, dormant_mask, "gate-dormant.png")
    isolate(restored, restored_mask, "gate-restored.png")
    shutter = map_quad(broken, EXIT_BOARD_CORNERS, ENTRANCE_CORNERS)
    isolate(shutter, entrance_shutter, "entrance-shutter.png")
    write_atlas(full_depth, "depth-architecture.png")
    edge_depth = Image.open(GUIDES / "depth-edge-ground.png").convert("RGB")
    edge_depth = edge_depth.resize(EDGE_SIZE, Image.Resampling.NEAREST)
    write_atlas(ground_depth, "depth-ground.png", edge_depth)
    extend_depth(full_depth, ground_depth, whitebox_gate, dormant_mask, "depth-dormant.png")
    extend_depth(restored_depth, ground_depth, whitebox_restored, restored_mask, "depth-restored.png")
    write_atlas(sealed_depth, "depth-sealed.png")

    # Inpaint beneath opaque interiors. Keep an overlap of the exact same source
    # pigment at antialiased edges so the split does not introduce a fringe.
    clean = ImageChops.lighter(hall, props).filter(ImageFilter.MinFilter(7))
    clean = ImageChops.lighter(clean, gate_reference.filter(ImageFilter.MaxFilter(39)))
    under_architecture = Image.composite(underpaint, main, clean)
    # Both gate states supply a local threshold plate from their own brushwork.
    # The aperture, cast shadow and snow stay matched to the layer above them.
    window = Image.new("L", SIZE)
    ImageDraw.Draw(window).rectangle(GATE_PAINT_CHANGE, fill=255)
    window = window.filter(ImageFilter.GaussianBlur(9))
    for state, paint, mask in (("dormant", broken, dormant_mask), ("restored", restored, restored_mask)):
        floor_plate = ImageChops.multiply(window, ImageChops.invert(mask.filter(ImageFilter.MinFilter(9))))
        isolate(paint, floor_plate, f"threshold-{state}.png")

    x = world_x(proj, depth_value(edge_depth))
    cols, rows = np.meshgrid(np.arange(EDGE_SIZE[0]), np.arange(EDGE_SIZE[1]))
    border = np.minimum.reduce([cols, EDGE_SIZE[0] - 1 - cols, rows, EDGE_SIZE[1] - 1 - rows])
    opacity = smooth(-17.0, -14.9, x) * smooth(0, 48, border)
    cover = Image.fromarray(np.round(opacity * 255).astype(np.uint8))
    isolate(extended_paint(under_architecture), cover, "ground.png")

    cols, rows = np.meshgrid(np.arange(SIZE[0]), np.arange(SIZE[1]))
    inner_border = np.minimum.reduce([cols, SIZE[0] - 1 - cols, rows, SIZE[1] - 1 - rows])
    edge = Image.fromarray(np.round(255 * smooth(2, 62, inner_border)).astype(np.uint8))
    isolate(restored_without_left_brace(main), ImageChops.multiply(props, edge), "parapets.png")

    render_runes()
    render_effects()
    export_group_masks(palette)


if __name__ == "__main__":
    run()
