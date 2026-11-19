"""Re-encode every embedded image of a GLB as baseline JPEG (Pillow) so Godot can decode it."""
import io, json, struct, sys
from PIL import Image

def pad(b, ch=b"\0"):
    return b + ch * ((4 - len(b) % 4) % 4)

for path in sys.argv[1:]:
    raw = open(path, "rb").read()
    jl = struct.unpack("<I", raw[12:16])[0]
    j = json.loads(raw[20:20 + jl])
    bo = 20 + jl
    bl = struct.unpack("<I", raw[bo:bo + 4])[0]
    binc = raw[bo + 8:bo + 8 + bl]
    img_views = {im["bufferView"]: im for im in j.get("images", []) if "bufferView" in im}
    out = bytearray()
    for i, bv in enumerate(j["bufferViews"]):
        data = binc[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        if i in img_views:
            im = Image.open(io.BytesIO(data)).convert("RGB")
            buf = io.BytesIO(); im.save(buf, "JPEG", quality=90); data = buf.getvalue()
            img_views[i]["mimeType"] = "image/jpeg"
        while len(out) % 4: out.append(0)
        bv["byteOffset"] = len(out); bv["byteLength"] = len(data)
        out += data
    out = pad(bytes(out))
    j["buffers"][0]["byteLength"] = len(out)
    js = pad(json.dumps(j, separators=(",", ":")).encode(), b" ")
    total = 12 + 8 + len(js) + 8 + len(out)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON")); f.write(js)
        f.write(struct.pack("<I4s", len(out), b"BIN\0")); f.write(out)
    print("REENCODED", path, len(raw), "->", total)
