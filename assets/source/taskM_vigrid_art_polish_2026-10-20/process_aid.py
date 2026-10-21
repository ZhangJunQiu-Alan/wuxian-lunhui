from pathlib import Path
import colorsys
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

B = Path(__file__).parent
JOBS = [("freyja", 140, .14), ("baldr", 110, .145), ("ran", 130, .575), ("skadi", 130, .535)]
LEVELS = np.array([0, 24, 48, 72, 112, 152, 192, 216])
report = []
yy, xx = np.mgrid[:320, :320]
rr = np.hypot(xx - 160, yy - 160)

for god, radius, hue in JOBS:
    raw_path = B / f"originals/aid_{god}_v01_raw.png"
    raw = Image.open(raw_path).convert("RGBA")
    w, h = raw.size
    assert abs(w / h - 2) < .01
    cell = w / 4
    frames, details = [], []
    for i in range(8):
        if i == 7:
            frames.append(Image.new("RGBA", (320, 320)))
            details.append({"frame": 8, "empty": True, "operation": "required transparent terminal frame"})
            continue
        crop = raw.crop(tuple(round(v) for v in ((i % 4) * cell, (i // 4) * cell, (i % 4 + 1) * cell, (i // 4 + 1) * cell)))
        a = np.asarray(crop)
        ys, xs = np.where(a[:, :, 3] >= 96)
        cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
        if i < 2:
            target_extent = [105, 120][i]
            source_extent = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2
            scale = target_extent / source_extent
            target_y = [142, 156][i]
            if god == "baldr":
                # The beam tip lands on the common ground anchor, rather than below it.
                cy = float(ys.max())
                target_extent = [56, 72][i]
                scale = target_extent / source_extent
                target_y = [128, 160][i]
        else:
            source_extent = float(np.quantile(np.hypot(xs - cx, ys - cy), .995))
            target_extent = radius * [.50, .80, 1.0, 1.0, .94][i - 2]
            scale = target_extent / source_extent
            scale *= {"freyja": 1.08, "baldr": 1.37, "ran": 1.12, "skadi": 1.0}[god]
            target_y = 160
        image = crop.transform((320, 320), Image.Transform.AFFINE,
            (1 / scale, 0, cx - 160 / scale, 0, 1 / scale, cy - target_y / scale),
            resample=Image.Resampling.NEAREST)
        arr = np.array(image)
        # One global palette adjustment per identity; source coordinates are unchanged.
        rgb = arr[:, :, :3]
        unique, inv = np.unique(rgb.reshape(-1, 3), axis=0, return_inverse=True)
        mapped = []
        for color in unique:
            sh, sat, val = colorsys.rgb_to_hsv(*(color / 255))
            if god in ("freyja", "baldr"):
                sh = hue
                sat = min(sat, .75 if god == "freyja" else .32)
            else:
                sh = hue + max(-.025, min(.025, sh - hue))
                sat = min(sat, .82 if god == "ran" else .55)
            mapped.append(tuple(round(c * 255) for c in colorsys.hsv_to_rgb(sh, sat, val)))
        rgb = np.asarray(mapped, dtype=np.uint8)[inv].reshape(320, 320, 3)
        gains = [.62, .76, .74, .86, .86, .63, .26]
        alpha = arr[:, :, 3].astype(float) * gains[i]
        if i >= 2:
            alpha[rr > radius + 6] = 0
            alpha *= np.clip((radius + 6 - rr) / 4, 0, 1)
            alpha[rr < 45] = np.minimum(alpha[rr < 45], 112)
        # Remove low-alpha generated haze, keeping crisp authored feather/net/ice marks.
        alpha[alpha < 24] = 0
        alpha = LEVELS[np.abs(alpha[:, :, None] - LEVELS).argmin(axis=2)].astype(np.uint8)
        rgb[alpha == 0] = 0
        arr = np.dstack((rgb, alpha))
        frames.append(Image.fromarray(arr))
        visible = alpha > 0
        details.append({"frame": i + 1, "source_cell": i, "source_center": [cx, cy],
            "source_extent": source_extent, "uniform_scale": scale, "target_extent": target_extent,
            "target_center": [160, target_y], "alpha_gain": gains[i],
            "max_alpha": int(alpha.max()), "center_alpha_max": int(alpha[rr < 45].max()),
            "nonzero_pixels": int(visible.sum()), "max_visible_radius": float(rr[visible].max())})
    # Shared 48-color palette across all nonempty frames of this god.
    strip = Image.new("RGBA", (2560, 320))
    for i, frame in enumerate(frames): strip.paste(frame, (i * 320, 0))
    palette = strip.convert("RGB").quantize(colors=48, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    palette.putalpha(strip.getchannel("A"))
    out = np.array(palette); out[out[:, :, 3] == 0] = 0
    strip = Image.fromarray(out)
    strip.save(B / f"candidates/aid_{god}_v03.png")
    frames = [strip.crop((i * 320, 0, (i + 1) * 320, 320)) for i in range(8)]
    bg = Image.open(B / "candidates/ash_road_v01.png").convert("RGBA")
    def backdrop(size):
        im = Image.new("RGBA", size)
        for y in range(0, size[1], 64):
            for x in range(0, size[0], 64): im.paste(bg, (x, y))
        return im
    board = backdrop((1280, 640))
    anim = []
    for i, frame in enumerate(frames):
        board.alpha_composite(frame, ((i % 4) * 320, (i // 4) * 320))
        af = backdrop((320, 320)); af.alpha_composite(frame); anim.append(af.convert("RGB"))
    board.convert("RGB").save(B / f"previews/aid_{god}_1x.png")
    board.resize((5120, 2560), Image.Resampling.NEAREST).save(B / f"previews/aid_{god}_4x.png")
    anim[0].save(B / f"previews/aid_{god}_12fps.gif", save_all=True, append_images=anim[1:], duration=[80, 90, 80, 80, 90, 80, 80, 90], loop=0)
    anim[0].save(B / f"previews/aid_{god}_slow.gif", save_all=True, append_images=anim[1:], duration=250, loop=0)
    report.append({"id": "aid_" + god, "source_size": [w, h], "source_sha256": hashlib.sha256(raw_path.read_bytes()).hexdigest(),
        "palette_limit": 48, "alpha_levels": LEVELS.tolist(), "radius": radius, "frames": details,
        "operations": "4x2 source cells; whole-frame uniform NN registration; identity palette normalization; low-alpha haze removal; terminal blank; no new painted spatial detail"})
(B / "records/aid_processing.json").write_text(json.dumps(report, indent=2))
