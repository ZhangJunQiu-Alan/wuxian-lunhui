# 剑士太刀：刀（刀身 + 刀镡 + 刀柄）和空刀鞘，按 02_三视图/武器.png 上排的长刀做。
# 坐标：挂点本地空间，+Y 是刀身方向，+Z 是刃口一侧（刀背在 -Z），握把中心在原点。
# 用法：blender -b --python katana_build.py -- <输出 .blend>
import bpy, bmesh, math, sys
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, color, metallic=0.0, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1.0)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    return m

def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

M = {
    "steel": mat("katana_steel", srgb("#c9d1d8"), 0.9, 0.28),
    "edge": mat("katana_edge", srgb("#eef2f5"), 0.9, 0.18),
    "brass": mat("katana_brass", srgb("#b48f4e"), 0.9, 0.38),
    "bronze": mat("katana_bronze", srgb("#6f5b3c"), 0.85, 0.45),
    "wrap": mat("katana_wrap", srgb("#1f1d22"), 0.0, 0.8),
    "same": mat("katana_same", srgb("#9a3a2a"), 0.0, 0.7),
    "lacquer": mat("saya_lacquer", srgb("#3b201d"), 0.1, 0.32),
}

SORI = 0.022          # 刀身弯曲（刀背方向）
BLADE_START, BLADE_LEN = 0.072, 0.70

def curve_z(y):
    """刀身的弯曲：从刀镡往刀尖越来越偏向刀背（-Z），刀身中段最弯。"""
    t = max(0.0, (y - BLADE_START) / BLADE_LEN)
    return -SORI * (t ** 1.6)

def new_obj(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    return ob

def ring_mesh(bm, sections, mat_of=lambda i, j: 0, cap=(True, True)):
    """sections：每节一圈点（同样数量），依次连成管子"""
    rings = [[bm.verts.new(p) for p in sec] for sec in sections]
    n = len(sections[0])
    for i in range(len(rings) - 1):
        for j in range(n):
            f = bm.faces.new((rings[i][j], rings[i][(j + 1) % n], rings[i + 1][(j + 1) % n], rings[i + 1][j]))
            f.material_index = mat_of(i, j)
    if cap[0]:
        bm.faces.new(list(reversed(rings[0])))
    if cap[1]:
        bm.faces.new(rings[-1])
    return rings

def ellipse(y, rx, rz, n=16, z0=0.0, phase=0.0):
    return [Vector((rx * math.cos(2 * math.pi * (k + phase) / n), y, z0 + rz * math.sin(2 * math.pi * (k + phase) / n))) for k in range(n)]

# —— 刀身：棱形截面（刀背、两侧镐线、刃口），从根部到切先渐窄，切先斜削 ——
bm = bmesh.new()
sections, steps = [], 40
for i in range(steps + 1):
    t = i / steps
    y = BLADE_START + BLADE_LEN * t
    width = 0.030 - 0.007 * t            # 身幅
    thick = 0.0072 - 0.0022 * t          # 重
    if t > 0.9:                          # 切先：刃口一侧向刀背收拢
        k = (t - 0.9) / 0.1
        width *= 1.0 - 0.92 * k ** 1.3
        thick *= 1.0 - 0.7 * k
    zc = curve_z(y)
    back, edge = zc - width * 0.5, zc + width * 0.5
    shinogi = back + width * 0.32
    sections.append([
        Vector((0.0, y, back)),
        Vector((thick * 0.5, y, shinogi)),
        Vector((0.0004, y, edge)),
        Vector((-0.0004, y, edge)),
        Vector((-thick * 0.5, y, shinogi)),
    ])
# 刃口两侧那两条面用亮一点的材质，做出刃文的感觉
ring_mesh(bm, sections, mat_of=lambda i, j: 1 if j in (1, 3) else 0)
blade = new_obj("katana_blade", bm, [M["steel"], M["edge"]])

# —— 刀铐、刀镡、柄、柄头 ——
def tube(name, y0, y1, rx, rz, material, n=16, segs=1, rx1=None, rz1=None):
    bm = bmesh.new()
    secs = []
    for s in range(segs + 1):
        t = s / segs
        secs.append(ellipse(y0 + (y1 - y0) * t, rx + ((rx1 or rx) - rx) * t, rz + ((rz1 or rz) - rz) * t, n))
    ring_mesh(bm, secs)
    return new_obj(name, bm, [material])

habaki = tube("katana_habaki", 0.056, 0.080, 0.0062, 0.0175, M["brass"])
tsuba = tube("katana_tsuba", 0.047, 0.056, 0.036, 0.040, M["bronze"], n=32)
fuchi = tube("katana_fuchi", 0.030, 0.047, 0.0135, 0.0175, M["brass"])

# 柄：卷绳和鲛皮交错成菱形（按格子交替两种材质，远看就是黑底红菱）
bm = bmesh.new()
n, segs = 16, 26
secs = []
for s in range(segs + 1):
    t = s / segs
    y = 0.030 - 0.245 * t
    swell = 1.0 + 0.06 * math.sin(math.pi * t)      # 柄中段略鼓
    secs.append(ellipse(y, 0.0125 * swell, 0.0160 * swell, n, phase=0.5 * (s % 2)))  # 每圈错开半格，格子变成斜的菱形
# 每两圈一组：上半组的一半格子露出红色鲛皮，其余是黑色卷绳，像参考图里黑绳中间露出的红菱
ring_mesh(bm, secs, mat_of=lambda i, j: 1 if (i % 2 == 0 and j % 2 == (i // 2) % 2) else 0, cap=(False, False))
tsuka = new_obj("katana_tsuka", bm, [M["wrap"], M["same"]])
kashira = tube("katana_kashira", -0.215, -0.235, 0.0135, 0.0170, M["brass"], rx1=0.010, rz1=0.013)

katana_parts = [blade, habaki, tsuba, fuchi, tsuka, kashira]

# —— 空刀鞘：沿刀身同样的弧度，鞘口在原点一侧，鞘尾包铜 ——
SAYA_START, SAYA_LEN = -0.15, 0.78
def saya_z(y):
    t = max(0.0, (y - SAYA_START) / SAYA_LEN)
    return -SORI * (t ** 1.6)
bm = bmesh.new()
secs = []
for s in range(25):
    t = s / 24
    y = SAYA_START + SAYA_LEN * t
    secs.append(ellipse(y, 0.0125 - 0.002 * t, 0.0215 - 0.004 * t, 16, saya_z(y)))
ring_mesh(bm, secs)
saya = new_obj("saya_body", bm, [M["lacquer"]])
koiguchi = tube("saya_koiguchi", SAYA_START - 0.004, SAYA_START + 0.022, 0.0135, 0.0228, M["bronze"])
y_end = SAYA_START + SAYA_LEN
bm = bmesh.new()
ring_mesh(bm, [ellipse(y_end - 0.045, 0.0108, 0.0177, 16, saya_z(y_end - 0.045)),
               ellipse(y_end + 0.004, 0.0112, 0.0180, 16, saya_z(y_end))])
kojiri = new_obj("saya_kojiri", bm, [M["bronze"]])
saya_parts = [saya, koiguchi, kojiri]

def join(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    ob.data.name = name
    return ob

katana = join(katana_parts, "katana")
saya = join(saya_parts, "katana_saya")
for ob in (katana, saya):
    me = ob.data
    print(ob.name, "faces", len(me.polygons), "dims", tuple(round(d, 3) for d in ob.dimensions))
bpy.ops.wm.save_as_mainfile(filepath=out)
