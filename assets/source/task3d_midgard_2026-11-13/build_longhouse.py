"""Build the Midgard longhouse as a self-contained glTF binary."""
import json
import math
import random
import struct
import zlib
from collections import defaultdict
from pathlib import Path

rng = random.Random(1958)
surfaces = defaultdict(list)
palette = {
    "Stone": ("505a60", "657074", "586265", "778285"),
    "Timber": ("534039", "644b3d", "735747", "493830", "795e49"),
    "Dark oak": ("312a29", "45322d"),
    "Roof": ("354954", "405661", "4b6068", "586971"),
    "Snow": ("a1bbc6", "becfd4", "b1c6d0"),
    "Iron": ("373d42", "576267"),
    "Red shield": ("844439", "ab6353"),
    "Amber glass": ("f6b55d",),
}

def face(material, points):
    for i in range(1, len(points) - 1):
        a, b, c = points[0], points[i], points[i + 1]
        u, v = [b[j] - a[j] for j in range(3)], [c[j] - a[j] for j in range(3)]
        n = (u[1]*v[2] - u[2]*v[1], u[2]*v[0] - u[0]*v[2], u[0]*v[1] - u[1]*v[0])
        length = math.sqrt(sum(x*x for x in n))
        if length > 1e-8:
            surfaces[material].extend((*p, *(x / length for x in n)) for p in (a, b, c))

def box(material, center, dimensions, tilt=0.0, yaw=0.0, roll=0.0, bevel=0.0):
    cx, cy, cz = center
    x, y, z = [n / 2 for n in dimensions]

    def transform(point):
        px, py, pz = point
        px, py = px*math.cos(roll) - py*math.sin(roll), px*math.sin(roll) + py*math.cos(roll)
        py, pz = py*math.cos(tilt) - pz*math.sin(tilt), py*math.sin(tilt) + pz*math.cos(tilt)
        px, pz = px*math.cos(yaw) + pz*math.sin(yaw), -px*math.sin(yaw) + pz*math.cos(yaw)
        return cx+px, cy+py, cz+pz

    corners = [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    sides = ((3,2,1,0),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2))
    if bevel <= 0:
        for indices in sides:
            face(material, [transform(corners[i]) for i in indices])
        return

    bevel = min(bevel, x*.8, y*.8, z*.8)
    edges = defaultdict(list)
    tips = defaultdict(list)
    for indices in sides:
        plane = next(axis for axis in range(3) if all(corners[i][axis] == corners[indices[0]][axis] for i in indices))
        inset = {}
        for i in indices:
            inset[i] = tuple(value if axis == plane else value - math.copysign(bevel, value)
                             for axis, value in enumerate(corners[i]))
            tips[i].append(inset[i])
        face(material, [transform(inset[i]) for i in indices])
        for i, j in zip(indices, indices[1:] + indices[:1]):
            edges[tuple(sorted((i, j)))].append(inset)
    for (i, j), (a, b) in edges.items():
        outside_face(material, [a[i], a[j], b[j], b[i]], transform)
    for points in tips.values():
        outside_face(material, points, transform)

def outside_face(material, points, transform):
    a, b, c = points[:3]
    u = tuple(b[i] - a[i] for i in range(3))
    v = tuple(c[i] - a[i] for i in range(3))
    normal = tuple(u[(i+1)%3]*v[(i+2)%3] - u[(i+2)%3]*v[(i+1)%3] for i in range(3))
    if sum(a[i]*normal[i] for i in range(3)) < 0:
        points = list(reversed(points))
    face(material, [transform(p) for p in points])

def pick(group):
    return group, rng.randrange(len(palette[group]))

def shield_disk(material, x, y, z, radius, inner=0.0, segments=16):
    for i in range(segments):
        a, b = i * math.tau / segments, (i+1) * math.tau / segments
        edge_a = (x + radius*math.cos(a), y + radius*math.sin(a), z)
        edge_b = (x + radius*math.cos(b), y + radius*math.sin(b), z)
        if inner > 0:
            face(material, [(x + inner*math.cos(a), y + inner*math.sin(a), z),
                            edge_a, edge_b, (x + inner*math.cos(b), y + inner*math.sin(b), z)])
        else:
            face(material, [(x, y, z), edge_a, edge_b])

def snow_patch(x, z, width, depth, slope):
    edge, shoulder = [], []
    for i in range(14):
        angle = i * math.tau / 14
        radius = rng.uniform(0.78, 1.05)
        dx, dz = math.cos(angle)*width*radius, math.sin(angle)*depth*radius
        edge.append((x + dx, 1.73 - abs(z + dz)*slope + .043, z + dz))
        pz = z + dz*.74
        shoulder.append((x + dx*.74, 1.73 - abs(pz)*slope + rng.uniform(.061, .082), pz))
    crown = (x, 1.73 - abs(z)*slope + .096, z)
    for i in range(len(edge)):
        j = (i+1) % len(edge)
        face(("Snow", 0), [edge[j], edge[i], shoulder[i], shoulder[j]])
        face(("Snow", 2), [shoulder[j], shoulder[i], crown])

# Stone footing and vertically planked walls.
box(("Stone", 0), (0, .103, 0), (2.27, .206, 1.31), bevel=.024)
box(("Dark oak", 0), (0, .61, 0), (2.22, .89, 1.26))
for side in (-1, 1):
    for i in range(12):
        x = -1.055 + .192*i
        box(pick("Stone"), (x, .061, side*.652), (.186, rng.uniform(.102, .12), .107),
            yaw=rng.uniform(-.09,.09), bevel=.020)
        box(pick("Stone"), (x + .035, .162, side*.653), (.174, rng.uniform(.089, .107), .111),
            yaw=rng.uniform(-.08,.08), bevel=.015)
        box(pick("Timber"), (x, .63, side*.645), (rng.uniform(.172,.187), .80, .07), bevel=.008)
    for i in range(7):
        z = -.57 + .19*i
        box(pick("Timber"), (side*1.118, .63, z), (.075, .81, .178), bevel=.008)
        box(pick("Stone"), (side*1.133, .113, z), (.084, .20, .176), bevel=.018)
    gable = [(side*1.127, 1.0, -.70), (side*1.127, 1.73, 0), (side*1.127, 1.0, .70)]
    face(("Timber", 2), gable if side > 0 else list(reversed(gable)))
    for z in (-.60,.60):
        box(("Dark oak", 1), (side*1.106,.65,z), (.13, .99, .13), bevel=.013)
    box(("Dark oak", 1), (side*1.145, 1.306, 0), (.075, .62, .077), bevel=.009)
    box(("Dark oak", 1), (side*1.146, 1.012, 0), (.08, .11, 1.38), bevel=.011)
    for lean in (-1, 1):
        box(("Timber", 3), (side*1.149, 1.237, lean*.24), (.074, .49, .058), tilt=lean*.94, bevel=.008)

slope = .77
for side in (-1, 1):
    box(("Roof", 0), (0, 1.335, side*.45), (2.62, .045, 1.13), tilt=side*math.atan(slope))
    for row in range(7):
        for i in range(15):
            x = -1.235 + .174*i + (.032 if row % 2 else 0)
            z = side*(.065 + .119*row)
            box(pick("Roof"), (x, 1.73 - abs(z)*slope + row*.0028, z), (.169, .032, .19),
                tilt=side*math.atan(slope) + rng.uniform(-.023,.023), yaw=rng.uniform(-.016,.016),
                bevel=.004 if row == 6 or (i + row) % 4 == 0 else 0.0)
    for x in (-1.32, 1.32):
        box(("Dark oak", 1), (x, 1.398, side*.448), (.086,.11,1.165), tilt=side*math.atan(slope), bevel=.014)
    for x, z, width, depth in ((-.82,.25,.39,.12),(-.41,.31,.34,.08),(.53,.48,.54,.12),(.91,.58,.28,.10),(-.89,.70,.29,.065)):
        snow_patch(x + side*.055, z*side, width, depth, slope)
    box(("Timber", 1), (0, 1.044, side*.848), (2.68,.11,.075), bevel=.01)
    for i in range(9):
        x = -1.18 + .295*i
        box(("Dark oak", 1), (x, 1.006, side*.738), (.067,.073,.22), bevel=.009)
box(("Dark oak", 1), (0,1.752,0), (2.72,.11,.16), bevel=.02)
for i in range(7):
    box(pick("Snow"), (-.97+i*.305, 1.811, rng.uniform(-.025,.025)), (.26,.034,.11),
        yaw=rng.uniform(-.11,.11), bevel=.012)

# Recessed door, warm shuttered window, iron hinges and shield.
for i in range(4):
    box(pick("Dark oak"), (-.48 + .09*i,.50,.687), (.084,.62,.075))
for x in (-.55,-.14):
    box(("Timber",4), (x,.53,.726), (.07,.70,.085), bevel=.011)
box(("Timber",3), (-.345,.889,.73), (.53,.12,.104), bevel=.016)
for i in range(3):
    x = -.46 + .105*i
    for side in (-1, 1):
        box(("Timber", 4), (x + side*.013,.889,.787), (.015,.053,.009), roll=side*.56, bevel=.002)
for y in (.31,.66):
    box(("Iron",0), (-.36,y,.736), (.30,.035,.035), bevel=.006)
    for x in (-.472, -.363, -.25):
        shield_disk(("Iron",1), x, y, .755, .009, segments=6)
shield_disk(("Iron",1), -.228,.484,.753,.022,.014,segments=10)
box(("Stone",2), (-.34,.085,.78), (.48,.17,.28), bevel=.025)
box(("Dark oak",0), (.55,.65,.692), (.45,.38,.07), bevel=.011)
box(("Amber glass",0), (.55,.65,.731), (.33,.26,.025))
for x in (.37,.55,.73):
    box(("Timber",1), (x,.65,.754), (.037,.30,.033))
for y in (.51,.65,.79):
    box(("Timber",3), (.55,y,.754), (.40,.030,.035), bevel=.004)
for x in (.317,.783):
    box(("Timber",2), (x,.65,.75), (.082,.34,.050), yaw=math.copysign(.13, x-.55), bevel=.007)
    for y in (.546,.754):
        box(("Iron",0), (x,y,.778), (.081,.026,.010), bevel=.003)
box(("Timber",4), (.55,.478,.777), (.49,.043,.15), bevel=.008)
shield_disk(("Red shield",0), .96,.53,.747,.157)
for i in range(3):
    box(("Red shield",1), (.96,.48 + i*.05,.749), (.235,.006,.005))
shield_disk(("Iron",0), .96,.53,.754,.159,.142)
shield_disk(("Iron",1), .96,.53,.786,.042,segments=12)
box(("Iron",0), (.96,.53,.767), (.068,.068,.028), roll=.65, bevel=.012)

for side in (-1, 1):
    for i in range(12):
        x = -1.055 + .192*i
        if side > 0 and (-.63 < x < -.10 or .26 < x < 1.13):
            continue
        for j in range(3):
            grain_x = x + rng.uniform(-.064,.064)
            grain_y = rng.uniform(.35,.85)
            length = rng.uniform(.055,.175)
            z = side*.682
            points = [(grain_x, grain_y, z), (grain_x + .007, grain_y + length*.31, z),
                      (grain_x + .005, grain_y + length, z), (grain_x - .004, grain_y + length*.46, z)]
            face(("Timber",3 if j % 2 else 4), points if side > 0 else list(reversed(points)))

for side in (-1,1):
    for x in (-.99,-.64,.62,1.03):
        box(pick("Snow"), (x,.027,side*.71), (rng.uniform(.19,.39),.054,.16),
            yaw=rng.uniform(-.2,.2), bevel=.019)

def export(path):
    data = bytearray()
    views, accessors, primitives, materials = [], [], [], []
    batches = defaultdict(list)
    swatches = [bytes.fromhex(palette[group][variant]) for group, variant in surfaces]
    for index, ((group, variant), vertices) in enumerate(surfaces.items()):
        material_group = group if group in ("Iron", "Amber glass") else "Painted surfaces"
        uv = ((index + 0.5) / len(swatches), 0.5)
        batches[material_group].extend((*vertex, *uv) for vertex in vertices)
    for group, vertices in batches.items():
        material = {"name": group, "pbrMetallicRoughness": {
            "baseColorTexture": {"index": 0}, "metallicFactor": .35 if group == "Iron" else 0.0,
            "roughnessFactor": .63 if group == "Iron" else .89}}
        if group == "Amber glass":
            material["emissiveFactor"] = [.57,.23,.036]
        materials.append(material)
        attributes = {}
        for name, start, size in (("POSITION", 0, 3), ("NORMAL", 3, 3), ("TEXCOORD_0", 6, 2)):
            values = [row[start:start + size] for row in vertices]
            start_at = len(data)
            data.extend(b"".join(struct.pack(f"<{size}f", *row) for row in values))
            views.append({"buffer": 0, "byteOffset": start_at, "byteLength": len(data) - start_at, "target": 34962})
            accessor = {"bufferView": len(views) - 1, "componentType": 5126, "count": len(values), "type": f"VEC{size}"}
            if name == "POSITION":
                accessor["min"] = [min(v[i] for v in values) for i in range(3)]
                accessor["max"] = [max(v[i] for v in values) for i in range(3)]
            accessors.append(accessor)
            attributes[name] = len(accessors) - 1
        primitives.append({"attributes": attributes, "material": len(materials) - 1})
    def png_chunk(kind, content):
        return struct.pack(">I", len(content)) + kind + content + struct.pack(">I", zlib.crc32(kind + content))

    png = bytes.fromhex("89504e470d0a1a0a")
    png += png_chunk(b"IHDR", struct.pack(">IIBBBBB", len(swatches), 1, 8, 2, 0, 0, 0))
    png += png_chunk(b"IDAT", zlib.compress(bytes(1) + b"".join(swatches)))
    png += png_chunk(b"IEND", b"")
    views.append({"buffer": 0, "byteOffset": len(data), "byteLength": len(png)})
    data.extend(png)
    data.extend(bytes(-len(data) % 4))
    doc = {"asset": {"version": "2.0", "generator": "Zhu Jie Yu Jin Midgard asset source"},
           "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"name": "MidgardLonghouse", "mesh": 0}],
           "meshes": [{"name": "MidgardLonghouse", "primitives": primitives}], "materials": materials,
           "images": [{"bufferView": len(views) - 1, "mimeType": "image/png"}],
           "textures": [{"source": 0, "sampler": 0}], "samplers": [{"magFilter": 9728, "minFilter": 9728}],
           "buffers": [{"byteLength": len(data)}], "bufferViews": views, "accessors": accessors}
    metadata = json.dumps(doc, separators=(",", ":")).encode()
    metadata += b" " * (-len(metadata) % 4)
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, 28 + len(metadata) + len(data))
                     + struct.pack("<I4s", len(metadata), b"JSON") + metadata
                     + struct.pack("<I4s", len(data), b"BIN\0") + data)
    print(f"{path.name}: {sum(len(v) // 3 for v in surfaces.values())} triangles, {len(primitives)} material surfaces")

if __name__ == "__main__":
    export(Path(__file__).resolve().parents[2] / "models/midgard/midgard_longhouse.glb")
