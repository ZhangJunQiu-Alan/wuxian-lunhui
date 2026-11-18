from math import cos, pi, sin, tau
from pathlib import Path
from random import Random

import bmesh
import bpy
from mathutils import Vector, noise

SOURCE = Path(__file__).resolve().parent
PROPS = SOURCE / "props"
PREVIEWS = SOURCE / "previews"
ROOT = SOURCE.parents[3]
RUNTIME = ROOT / "assets/models/midgard/courtyard/v4"


def point(p):
    x, y, z = p
    return (x, -z, y)


def material(name, color, roughness=.88, metal=0, image_name=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = mat.diffuse_color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metal
    image_path = RUNTIME / f"{image_name}.png"
    if image_name and image_path.is_file():
        albedo = mat.node_tree.nodes.new("ShaderNodeTexImage")
        albedo.image = bpy.data.images.load(str(image_path), check_existing=True)
        albedo.image.pack()
        mat.node_tree.links.new(albedo.outputs["Color"], shader.inputs["Base Color"])
        for suffix, socket in (("normal", "Normal"), ("roughness", "Roughness")):
            path = RUNTIME / f"{image_name}_{suffix}.png"
            if not path.is_file():
                continue
            texture = mat.node_tree.nodes.new("ShaderNodeTexImage")
            texture.image = bpy.data.images.load(str(path), check_existing=True)
            texture.image.colorspace_settings.name = "Non-Color"
            texture.image.pack()
            if suffix == "normal":
                normal = mat.node_tree.nodes.new("ShaderNodeNormalMap")
                normal.inputs["Strength"].default_value = .44
                mat.node_tree.links.new(texture.outputs["Color"], normal.inputs["Color"])
                mat.node_tree.links.new(normal.outputs["Normal"], shader.inputs[socket])
            else:
                mat.node_tree.links.new(texture.outputs["Color"], shader.inputs[socket])
    return mat


def palette():
    return {
        "basalt": material("Winter basalt", (.18, .21, .25), image_name="basalt"),
        "stone": material("Carved slate", (.25, .30, .37), image_name="basalt"),
        "wood": material("Weathered oak", (.19, .12, .077), .8, image_name="oak"),
        "end": material("Split endgrain", (.16, .092, .052), .86),
        "snow": material("Wind packed snow", (.70, .76, .85), .92, image_name="snowfield"),
        "cut": material("Cut stone recess", (.10, .122, .16)),
        "lip": material("Weathered carving relief", (.26, .30, .34)),
        "metal": material("Frosted wrought iron", (.14, .17, .21), .62, .48),
        "rune": material("Gate rune channels", (.28, .36, .42), .81),
    }


def empty(name, parent=None, loc=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = point(loc)
    return obj


def mesh(parent, name, vertices, faces, mat, uv_scale=.6, uv_axis=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata([point(v) for v in vertices], [], faces)
    data.update()
    edit = bmesh.new()
    edit.from_mesh(data)
    bmesh.ops.recalc_face_normals(edit, faces=list(edit.faces))
    bmesh.ops.triangulate(edit, faces=list(edit.faces))
    edit.to_mesh(data)
    edit.free()
    data.materials.append(mat)
    uv = data.uv_layers.new().data
    for poly in data.polygons:
        axis = max(range(3), key=lambda i: abs(poly.normal[i])) if uv_axis is None else uv_axis
        for loop in poly.loop_indices:
            x, z, y = data.vertices[data.loops[loop].vertex_index].co
            u, v = ((z, y), (x, y), (z, x))[axis]
            uv[loop].uv = (u * uv_scale, v * uv_scale)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    return obj


def skin(parent, name, rings, mat, uv_axis=None, smooth=False):
    count = len(rings[0])
    faces = [tuple(reversed(range(count)))]
    for j in range(len(rings)-1):
        for i in range(count):
            a = j*count + i
            b = j*count + (i+1) % count
            faces.append((a, b, b+count, a+count))
    faces.append(tuple(range((len(rings)-1)*count, len(rings)*count)))
    obj = mesh(parent, name, [p for ring in rings for p in ring], faces, mat, uv_axis=uv_axis)
    if smooth:
        for face in obj.data.polygons:
            face.use_smooth = True
    return obj


def ridge(parent, name, points, radii, mat, sides=7):
    rings = []
    for index, (p, r) in enumerate(zip(points, radii)):
        tangent = Vector(points[min(index+1,len(points)-1)]) - Vector(points[max(0,index-1)])
        tangent.normalize()
        axis = tangent.cross(Vector((0, 0, 1)))
        if axis.length < .01:
            axis = tangent.cross(Vector((0, 1, 0)))
        axis.normalize()
        across = tangent.cross(axis)
        ring = [tuple(Vector(p) + r*(cos(i*tau/sides)*axis + sin(i*tau/sides)*across)) for i in range(sides)]
        rings.append(ring)
    return skin(parent, name, rings, mat, smooth=True)


def stone(parent, name, size, mat, *, levels=14, seed=1, drift=.15, snow=None, at=(0, 0, 0)):
    rnd = Random(seed)
    w, h, d = size
    ax, ay, az = at
    sides = 18 if levels > 7 else 12
    outline = [rnd.uniform(.90, 1.09) for _ in range(sides)]
    rings = []
    for j in range(levels+1):
        t = j / levels
        turn = -.03*t + .013*sin(t*24)
        taper = (1 - .17*t) * (1 - .23*max(0, t-.82)/.18)
        taper *= .91 if j == 0 else 1.0
        shape = []
        for i in range(sides):
            rot = (i+.5)*tau/sides + turn
            x = cos(rot)
            z = sin(rot)
            surface = outline[i]*taper*(1+.021*sin(j*2.5+i*1.7))
            x = (abs(x)**.42) * (1 if x >= 0 else -1) * w*.5
            z = (abs(z)**.51) * (1 if z >= 0 else -1) * d*.5
            fracture = noise.noise_vector(Vector((i*.67,t*5.1,seed*.29)))[0]
            split = .055*sin(i*2.3 + t*8) if j in (levels//4, levels*3//4) else 0
            shape.append((ax+x*(surface+split) + h*drift*t + fracture*w*.037,
                          ay+h*(t + .027*sin(i*.73+t*3.9) + .019*fracture),
                          az+z*(surface+split)+fracture*d*.06))
        rings.append(shape)
    obj = skin(parent, name, rings, mat)
    if snow:
        snowcap(parent, name + " wind crust", rings[-1], snow, .095 if h > 1.0 else .048)
    return obj


def snowcap(parent, name, edge, mat, height=.13):
    center = sum((Vector(v) for v in edge), Vector()) / len(edge)
    rings = [[tuple(Vector(v) - Vector((0, height*.20, 0))) for v in edge]]
    for t, raise_by in ((1.01,.30), (.84,.80), (.44,1), (.10,1.15)):
        rings.append([(center.x+(x-center.x)*t, y+height*(raise_by+.20*sin(i*.91)),
                       center.z+(z-center.z)*t) for i,(x,y,z) in enumerate(edge)])
    return skin(parent, name, rings, mat, smooth=True)


def beam(parent, name, a, b, thickness, depth, mats, split=False, cap=False):
    start, end = Vector(a), Vector(b)
    direction = (end-start).normalized()
    side = Vector((0, 0, 1)).cross(direction).normalized()
    across = direction.cross(side)
    rings = []
    stations = (0,.08,.27,.52,.77,.95,1) if thickness < .14 else (0,.037,.15,.32,.46,.61,.77,.92,.982,1)
    sides = 8 if thickness < .14 else 12
    for j, t in enumerate(stations):
        center = start.lerp(end, t) + Vector((0, .023*sin(t*pi), .013*sin(t*5)))
        perimeter = []
        for i in range(sides):
            angle = (i+.5)*tau/sides
            u, v = cos(angle), sin(angle)
            perturb = 1 + .038*sin(i*4.2+t*12) + .037*sin(i*.81+t*25)
            p = center + perturb * (thickness*side*(abs(u)**.34)*(-1 if u < 0 else 1) +
                                    depth*across*(abs(v)**.32)*(-1 if v < 0 else 1))
            if j == len(stations)-1 and split:
                p += direction * thickness * (.38*u + .37*sin(i*2.8))
            perimeter.append(tuple(p))
        rings.append(perimeter)
    wood = skin(parent, name, rings, mats["wood"], uv_axis=1)
    if split:
        tips = rings[-1]
        for i in range(0,sides,3):
            p = Vector(tips[i])
            q = p - direction * thickness * (1.1+ .1*i)
            q.z += depth*.025
            ridge(parent,name+" split fiber",[tuple(q),tuple(q.lerp(p,.73)),tuple(p)], [.006,.013,.006],mats["end"],5)
    if cap:
        edge = []
        for j in range(0,len(rings),2):
            ring = sorted(rings[j], key=lambda p: p[1])
            edge.append(ring[-3])
        edge.extend(sorted(rings[-1],key=lambda p:p[1])[-3:])
        for j in range(len(rings)-2,-1,-2):
            edge.append(sorted(rings[j],key=lambda p:p[1])[-2])
        snowcap(parent, name+" upper frost", edge, mats["snow"], .10)
    return wood


RUNES = (
    (((0,0),(0,1)),((0,.94),(.39,.73),(0,.54),(.40,.31))),
    (((0,0),(0,1)),((-.40,.78),(0,.55),(.40,.36))),
    (((0,.03),(0,.97)),((-.38,.33),(0,.60),(.36,.84))),
    (((-.35,.08),(0,.97),(.35,.08)),((-.21,.42),(.22,.42))),
    (((-.38,.25),(.35,.82)),((-.38,.82),(.35,.25)),((0,.07),(0,.98))),
)


def inscriptions(parent, x, z, mats, *, bottom=.62, height=1.75, scale=.16, active=False, variant=0):
    material_name = "rune" if active else "cut"
    relief = empty("RunesLit" if active else "Carved grooves", parent)
    for row in range(6):
        shape = RUNES[(row*3+variant) % len(RUNES)]
        for stroke in shape:
            path = [(x+u*scale, bottom+height*(row+v*.71)/6,z) for u,v in stroke]
            ridge(relief, "Rune relief", path, [.013]*len(path), mats[material_name], 6)
    for sign in (-1,1):
        trail=[]
        for i in range(69):
            t=i/68
            trail.append((x+sign*(.15+.064*sin(t*tau*3.5)),bottom+height*t,z-.011))
        ridge(parent,"Twined relief",trail,[.019]*len(trail),mats["cut"],6)
    return relief


def beast(parent, name, loc, side, mats):
    x,y,z=loc
    spine=((0,0,.00),(.13,.13,.01),(.24,.35,.025),(.26,.58,.030),(.36,.77,.056),
           (.60,.78,.081),(.80,.70,.085),(.89,.62,.105),(.70,.56,.116))
    track=[(x+side*u,y+v,z+w) for u,v,w in spine]
    ridge(parent,name,track,[.17,.16,.136,.13,.172,.168,.102,.071,.038],mats["wood"],12)
    ridge(parent,name+" brow",[(x+side*u,y+v,z+w) for u,v,w in ((.37,.82,.16),(.49,.86,.20),(.65,.82,.17),(.77,.76,.14))],
          [.035,.045,.039,.012],mats["end"])
    ridge(parent,name+" eye and cheek",[(x+side*u,y+v,z+w) for u,v,w in ((.45,.71,.218),(.57,.745,.235),(.67,.70,.195))],
          [.014,.026,.013],mats["metal"])
    ridge(parent,name+" lower jaw",[(x+side*u,y+v,z+w) for u,v,w in ((.46,.60,.091),(.61,.52,.14),(.81,.55,.154))],
          [.093,.042,.026],mats["wood"])
    for i in range(3):
        ridge(parent,name+" neck cut", [(x+side*u,y+v+i*.103,z+w) for u,v,w in ((.13,.19,.13),(.24,.23,.175),(.30,.30,.13))],
              [.010,.014,.006],mats["end"],5)


def rune_stone(root, mats, variant):
    h = 2.56 if variant == 0 else 3.05
    w = .92 if variant == 0 else 1.08
    stone(root,"Buried foot",(w*1.12,.39,.78),mats["basalt"],levels=7,seed=32+variant,snow=mats["snow"])
    stone(root,"Sculpted split monolith",(w,h,.50),mats["stone"],levels=22,seed=10+variant,
          drift=.016 if variant else -.024, snow=mats["snow"])
    inscriptions(root,-.05 if not variant else .04,.243,mats,bottom=.62,height=h-.89,scale=.37,variant=variant)
    scar = [(-w*.42,h*.79,.21),(-w*.21,h*.72,.253),(-w*.105,h*.76,.256),(.03,h*.71,.26),(.24,h*.75,.24)]
    ridge(root,"Diagonal weathered split",scar,[.009,.016,.013,.014,.009],mats["cut"])


def longhouse(root, mats, variant):
    for i in range(11):
        x = -2.55+i*.51
        for z in (-.69,.64):
            stone(root,"Hand-laid foundation",(.59,.34,.45),mats["basalt"],levels=5,seed=i*5+int(z>0),
                  at=(x,-.032,z),drift=.07,snow=mats["snow"])
    for i,x in enumerate((-2.39,-.85,1.22,2.35)):
        h = (2.45,1.63,2.15,1.46)[i] if not variant else (1.73,2.13,.91,1.57)[i]
        bank = (-.22,.18,-.18,-.39)[i]
        for z in (-.62,.59):
            foot=(x,.25,z)
            tip=(x+bank,h+(.42 if z < 0 else 0),z+.12)
            beam(root,"Weathered post",foot,tip,.165,.17,mats,split=True)
            if h > 1.25:
                beam(root,"Diagonal oak knee",(x,.89,z),(x+.53,1.45,z),.094,.095,mats,split=True)
        if i in (0,2):
            beam(root,"Broken transverse tie",(x,h+.32,-.81),(x+.10,h+.26,.77),.132,.14,mats,split=True,cap=True)
    beam(root,"Collapsed ridge",(-2.53,2.76,-.69),(1.36,2.15,-.70),.20,.18,mats,split=True,cap=True)
    beam(root,"Fractured sill",(-2.54,2.45,.60),(-.36,1.86,.76),.155,.12,mats,split=True,cap=True)
    for i in range(21):
        x=-2.53+i*.24
        extent=1.20+.098*sin(i*1.7) if i<7 else .34 + .15*cos(i*.8)
        h=2.71 - (x+2.53)*.15
        beam(root,"Split roof shake",(x,h,-.59),(x+.03,h-extent*.40,-.61+extent),
             .052,.114,mats,split=True,cap=i%3 != 0)
    for i in range(8):
        x=-2.53+i*.24
        h=1.10+.27*sin(.61*i)+.15*cos(i*2.0)
        beam(root,"Weathered plank",(x,.28,-.59),(x+.10,h,-.55),.106,.039,mats,split=True)
    beast(root,"Longhouse ridge beast",(-2.45,2.57,-.65),-1,mats)


def rock_shelf(root, mats, variant):
    rnd=Random(31+variant)
    for i,(x,z,w,h,d) in enumerate(((-.30,.04,1.39,1.05,.77),(.53,-.12,1.04,.69,.69),
                                   (-.98,.32,.49,.39,.59),(.94,.29,.63,.32,.44),(-.04,.40,.6,.39,.69))):
        stone(root,"Stratified spall",(w*(1+.15*variant),h*(1+.21*variant),d),mats["basalt"],
              levels=12,seed=11+variant*61+i,drift=rnd.uniform(-.31,.03),snow=mats["snow"],at=(x,-.025,z))


def setup_preview(root, size, aim, name, active=None):
    scene=bpy.context.scene
    scene.render.engine="BLENDER_EEVEE"
    scene.render.resolution_x=800
    scene.render.resolution_y=450
    scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new("Winter sky")
    scene.world.use_nodes=True
    scene.world.node_tree.nodes.get("Background").inputs[0].default_value=(.26,.35,.52,1)
    scene.world.node_tree.nodes.get("Background").inputs[1].default_value=.34
    floor=material("Blue gray display ground",(.100,.126,.175))
    mesh(root,"Preview ground",[(-13,-.07,-13),(-13,-.07,13),(13,-.07,13),(13,-.07,-13)],[(0,1,2,3)],floor)
    bpy.ops.object.camera_add(location=point((-6.2,10,6.1)))
    cam=bpy.context.object
    cam.rotation_euler=(Vector(point(aim))-cam.location).to_track_quat("-Z","Y").to_euler()
    cam.data.type="ORTHO"
    cam.data.ortho_scale=size
    scene.camera=cam
    for loc,color,power,width in [((-5,5,6),(.79,.87,1),1100,6),((4,3,-5),(.52,.7,1),550,6),
                                   ((-3,2,-1),(1,.68,.39),84,2)]:
        bpy.ops.object.light_add(type="AREA", location=point(loc))
        light=bpy.context.object
        light.rotation_euler=(Vector(point(aim))-light.location).to_track_quat("-Z","Y").to_euler()
        light.data.color=color
        light.data.energy=power
        light.data.shape="DISK"
        light.data.size=width
    scene.render.filepath=str(PREVIEWS/f"{name}.png")
    if active:
        active[1].hide_render=True
        bpy.ops.render.render(write_still=True)
        active[0].hide_render=True
        active[1].hide_render=False
        scene.render.filepath=str(PREVIEWS/f"{name}_awakened.png")
    bpy.ops.render.render(write_still=True)


def simplify_longhouse():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or len(obj.data.polygons) < 84:
            continue
        bpy.context.view_layer.objects.active = obj
        reduced = obj.modifiers.new("Game mesh", "DECIMATE")
        reduced.ratio = .69
        bpy.ops.object.modifier_apply(modifier=reduced.name)


def merge_surfaces():
    all_roots = [obj for obj in bpy.context.scene.objects if obj.type == "EMPTY"]
    for parent in all_roots:
        surfaces = {}
        for obj in list(parent.children):
            if obj.type != "MESH" or obj.name.startswith(("lintel_L", "lintel_R")):
                continue
            key = obj.data.materials[0]
            surfaces.setdefault(key, []).append(obj)
        for mat, objects in surfaces.items():
            if len(objects) < 2:
                continue
            bpy.ops.object.select_all(action="DESELECT")
            for obj in objects:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = objects[0]
            bpy.ops.object.join()
            objects[0].name = mat.name
    bpy.ops.object.select_all(action="DESELECT")



def build(name, factory, size, aim, preview):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    mats=palette()
    root=empty(name)
    active=factory(root,mats)
    if name.startswith("longhouse"):
        simplify_longhouse()
    merge_surfaces()
    bpy.ops.wm.save_as_mainfile(filepath=str(PROPS/f"{name}.blend"),compress=True)
    faces=sum(len(obj.data.polygons) for obj in bpy.data.objects if obj.type=="MESH")
    print(f"V4_PROP {name} {faces}",flush=True)
    if preview:
        setup_preview(root,size,aim,name,active)


def exit_gate(root,mats):
    groups=[]
    from refine_architecture import refined_door

    for mode,name in (("dormant","DormantGate"),("awakened","AwakenedGate")):
        col=bpy.data.collections.new("Gate_Dormant" if mode=="dormant" else "Gate_Awakened")
        bpy.context.scene.collection.children.link(col)
        col_instance=bpy.context.view_layer.layer_collection.children[col.name]
        bpy.context.view_layer.active_layer_collection=col_instance
        state=empty(name,root)
        refined_door(state,mats,mode)
        groups.append(col)
    return groups


if __name__ == "__main__":
    import sys

    sys.path.insert(0, str(SOURCE))
    from refine_architecture import approach_seal, dry_wall, refined_door

    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    preview="preview" in args
    assets=[
        ("rune_stone_a",lambda r,m:rune_stone(r,m,0),4.0,(0,1.15,0)),
        ("rune_stone_b",lambda r,m:rune_stone(r,m,1),4.7,(0,1.34,0)),
        ("longhouse_ruin",lambda r,m:longhouse(r,m,0),7.9,(0,1.04,0)),
        ("longhouse_ruin_b",lambda r,m:longhouse(r,m,1),7.9,(0,1.04,0)),
        ("exit_gate",exit_gate,6.7,(0,1.55,0)),
        ("entry_shutter",lambda r,m:refined_door(r,m,"entry"),6.55,(0,1.51,0)),
        ("basalt_rocks",lambda r,m:rock_shelf(r,m,0),4.1,(0,.4,0)),
        ("basalt_rocks_b",lambda r,m:rock_shelf(r,m,1),4.65,(0,.4,0)),
        ("low_wall",lambda r,m:dry_wall(r,m,0),3.5,(0,.28,0)),
        ("low_wall_b",lambda r,m:dry_wall(r,m,1),3.5,(0,.28,0)),
        ("low_wall_c",lambda r,m:dry_wall(r,m,2),3.5,(0,.28,0)),
        ("low_wall_d",lambda r,m:dry_wall(r,m,3),3.5,(0,.28,0)),
        ("approach_seal",approach_seal,8.1,(0,.09,0)),
    ]
    for name,factory,size,aim in assets:
        if len(args) == int(preview) or name in args:
            build(name,factory,size,aim,preview)
