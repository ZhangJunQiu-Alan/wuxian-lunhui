"""Build editable Nordic room modules, export glTF, and render review images."""
import importlib.util
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
BATCH = Path(__file__).resolve().parent
ROOT = BATCH.parents[2]
MODELS = ROOT / "assets/models/midgard/rooms"
PREVIEWS = BATCH / "previews"
RNG = random.Random(1411)
MODULES = [
    ("snow_floor", "积雪石板地面", "场地", "可拼接的冻土与积雪地块，边缘石材用于区分通路。", "雪村、墓丘、石阵", "静态模型", "static"),
    ("void_causeway", "虚空断台与石桥", "虚空", "两侧断台围出真实空洞，中间保留一条窄桥。用于限制横向走位。", "墓丘、精英房", "需要接入边界碰撞与坠落判定", "static"),
    ("spike_trap", "伸缩地刺", "陷阱", "金属基座与九根可伸缩尖刺。预警后升起，再回落。", "雪村侧巷、码头", "已导出伸缩动画，Godot 动画名 spike；伤害与预警待接", "spike_cycle"),
    ("rune_trap", "符文喷发陷阱", "陷阱", "凹陷的法阵槽和环绕的立石，中央发光用于提示即将喷发。", "墓丘、奥丁石阵", "发光材质已导出，技能与范围预警待接", "static"),
    ("pressure_plate", "石质压力踏板", "机关", "可下压的独立踏板与外圈框架，作为门或陷阱的触发器。", "普通房、机关房", "已导出 press 动画，触发与联动待接", "press"),
    ("rune_gate", "升降符文门", "出口", "雕纹石柱支撑带铆钉的木闸，顶部徽记可对应出口奖励。", "战斗房出口", "已导出 open 动画，清场解锁与奖励门标待接", "open"),
    ("lever", "铁木拉杆", "机关", "石基上的可转动手柄，保留独立枢轴用于控制门或陷阱。", "安全侧道、支路", "已导出 activate 动画，交互逻辑待接", "activate"),
    ("brazier", "北欧铁制火盆", "道具", "带支脚、铆钉与燃炭的火盆，标记出口和安全区域。", "雪村、营火房", "火光为静态发光几何，粒子与实时灯光待接", "static"),
]
MATS = {}
MAT_INDEX = {}
ATLAS_ROWS = 1


def load_materials():
    path = ROOT / "assets/source/task3d_midgard_2026-11-13/refine_longhouse_blender.py"
    spec = importlib.util.spec_from_file_location("midgard_materials", path)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    palette = [("Stone", "535f69"), ("Timber", "654c3e"), ("Snow", "b8ced5"),
               ("Iron", "48525c"), ("Amber glass", "e6b263"), ("Dark oak", "282f38")]
    images, rows = helper.make_atlas(palette)
    for index, (group, _) in enumerate(palette):
        MATS[group] = helper.material_for(group, images)
        MAT_INDEX[group] = index
    return helper


def finish(obj, name, material, bevel=0):
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Worn edge bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    obj.data.materials.append(MATS[material])
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new()
    bounds = [max(abs(v.co[i]) for v in obj.data.vertices) or 1 for i in range(3)]
    for face in obj.data.polygons:
        axis = max(range(3), key=lambda i: abs(face.normal[i]))
        horizontal, vertical = [i for i in range(3) if i != axis]
        for loop in face.loop_indices:
            point = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            u = point[horizontal] / (2*bounds[horizontal]) + .5
            v = point[vertical] / (2*bounds[vertical]) + .5
            uv.data[loop].uv = ((MAT_INDEX[material] + .05 + .9*u)/6, .05 + .9*v)
    return obj


def box(name, at, size, material="Stone", bevel=.025, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.dimensions = size
    obj.rotation_euler = rotation
    return finish(obj, name, material, bevel)


def cylinder(name, at, radius, depth, material="Iron", vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=at)
    return finish(bpy.context.object, name, material, .012)

def socket(at):
    bpy.ops.mesh.primitive_torus_add(major_segments=12, minor_segments=6,
        location=at, major_radius=.104, minor_radius=.020)
    return finish(bpy.context.object, "Spike socket rim", "Iron")


def cone(name, at, radius, depth, material="Iron"):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=radius, radius2=.008, depth=depth, location=at)
    return finish(bpy.context.object, name, material)


def beam(name, a, b, width, material="Timber"):
    a, b = Vector(a), Vector(b)
    obj = box(name, (a+b)/2, (width, width, (b-a).length), material, .012)
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return obj


def empty(name, at=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = at
    return obj


def parent_at(obj, parent):
    bpy.context.view_layer.update()
    matrix = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = matrix


def animate(obj, name, property_name, samples):
    for frame, value in samples:
        setattr(obj, property_name, value)
        obj.keyframe_insert(data_path=property_name, frame=frame)
    obj.animation_data.action.name = name


def rune(center, size=.22):
    x,y,z = center
    beam("Rune spine", (x,y,z), (x,y,z+size), .018, "Amber glass")
    beam("Rune branch", (x,y,z+size*.55), (x+size*.42,y,z+size*.8), .018, "Amber glass")


def snow_floor():
    box("Ground core", (0,0,-.19), (3,3,.38), "Stone", .07)
    for i in range(5):
        for j in range(5):
            box("Worn flagstone", ((i-2)*.59,(j-2)*.59,-.045+RNG.uniform(-.008,.008)),
                (.565,.565,.13), "Stone", .045, (0,0,RNG.uniform(-.018,.018)))
    for i in range(8):
        x,y=RNG.uniform(-1.2,1.2),RNG.uniform(-1.2,1.2)
        obj=cylinder("Windblown snow", (x,y,.035+i*.004), RNG.uniform(.18,.43), .045, "Snow", 9)
        obj.scale.y=RNG.uniform(.5,1.0)


def bank(x):
    box("Cliff core", (x,0,-.55), (1.28,3.08,.96), "Dark oak", .10)
    for j in range(7):
        for i in range(2):
            box("Cliff rock", (x+(i-.5)*.69,(j-3)*.46,-.48), (.77,.48,.87), "Stone", .065,
                (RNG.uniform(-.04,.04),RNG.uniform(-.04,.04),RNG.uniform(-.055,.055)))
    box("Snowy rim", (x,0,-.005), (1.47,3.22,.1), "Snow", .07)


def void_causeway():
    bank(-1.65)
    bank(1.65)
    for i in range(7):
        box("Bridge slab", ((i-3)*.34,0,-.035), (.355,.88,.15), "Stone", .035,
            (0,RNG.uniform(-.018,.018),RNG.uniform(-.02,.02)))
    for y in [-.47,.47]:
        beam("Iron side support", (-1.17,y,-.16),(1.17,y,-.16), .075, "Iron")
    marker=empty("VoidVolume", (0,0,-.6))
    marker["hazard_role"]="fall_zone"
    marker["bounds_xyz"]=[1.7,3.25,1.15]


def spike_trap():
    box("Recessed mechanism", (0,0,-.12), (1.6,1.6,.24), "Dark oak", .035)
    for side in [-1,1]:
        box("Frame", (side*.75,0,.005), (.12,1.62,.13), "Iron")
        box("Frame", (0,side*.75,.005), (1.4,.12,.13), "Iron")
    moving=empty("SpikeCarrier")
    for x in [-.43,0,.43]:
        for y in [-.43,0,.43]:
            socket((x,y,.021))
            obj=cone("Spike", (x,y,.36),.087,.68)
            parent_at(obj,moving)
    for x in [-.72,.72]:
        for y in [-.72,.72]:
            cylinder("Rivet", (x,y,.086),.035,.028)
    animate(moving,"spike_cycle","location",[(1,(0,0,-.65)),(18,(0,0,-.65)),(23,(0,0,0)),(38,(0,0,0)),(52,(0,0,-.65)),(60,(0,0,-.65))])


def rune_trap():
    cylinder("Basalt plinth", (0,0,-.08), .94,.16,"Stone",16)
    cylinder("Inset center", (0,0,.012), .64,.035,"Dark oak",16)
    for i in range(12):
        angle=i*math.tau/12
        x,y=math.cos(angle)*.76,math.sin(angle)*.76
        obj=box("Outer rune segment",(x,y,.018),(.12,.24,.022),"Amber glass",.005,(0,0,angle))
    for a,b in [((-.38,-.25,.04),(.38,.25,.04)),((-.38,.25,.04),(.38,-.25,.04)),((0,-.49,.04),(0,.49,.04))]:
        beam("Runic inlay",a,b,.028,"Amber glass")
    for i in range(4):
        a=math.pi/4+i*math.pi/2
        x,y=math.cos(a)*.84,math.sin(a)*.84
        box("Broken marker", (x,y,.23),(.20,.20,.44),"Stone",.045,(.05,-.04,a))
    empty("BlastOrigin",(0,0,.06))


def pressure_plate():
    box("Pedestal", (0,0,-.10),(1.36,1.36,.2),"Stone",.055)
    box("Recess", (0,0,.015),(1.1,1.1,.045),"Dark oak")
    slab=box("MovingPlate",(0,0,.12),(.94,.94,.16),"Stone",.05)
    for a,b in [((-.27,0,.207),(.27,0,.207)),((0,-.27,.207),(0,.27,.207))]:
        obj=beam("Plate groove",a,b,.024,"Amber glass")
        parent_at(obj,slab)
    animate(slab,"press","location",[(1,(0,0,.12)),(15,(0,0,.03)),(35,(0,0,.03)),(50,(0,0,.12))])
    empty("TriggerCenter",(0,0,.22))


def rune_gate():
    for side in [-1,1]:
        box("Pillar base",(side*1.12,0,.13),(.62,.66,.26),"Stone",.055)
        for i in range(4):
            box("Pillar block",(side*1.12,0,.46+i*.46),(.43,.48,.43),"Stone",.045)
        box("Pillar cap",(side*1.12,0,2.16),(.60,.64,.2),"Stone",.035)
        rune((side*1.12,-.255,1.04),.39)
        for z in [.45,1.94]:
            box("Pillar band",(side*1.12,0,z),(.47,.52,.075),"Iron",.012)
    box("Lintel",(0,0,2.30),(2.87,.67,.23),"Timber",.045)
    door=empty("GateMoving")
    for i in range(9):
        x=(i-4)*.219
        parent_at(box("Gate plank",(x,0,1.10),(.204,.15,1.94),"Timber",.015),door)
        parent_at(cone("Top spear",(x,0,2.08),.070,.16),door)
    for z in [.45,1.43]:
        parent_at(box("Gate brace",(0,-.104,z),(1.95,.075,.11),"Iron",.014),door)
        for x in [-.78,-.39,0,.39,.78]:
            obj=cylinder("Brace rivet",(x,-.153,z),.026,.028)
            obj.rotation_euler.x=math.pi/2
            parent_at(obj,door)
    cylinder("Reward seal",(0,-.369,2.32),.16,.045,"Amber glass").rotation_euler.x=math.pi/2
    empty("ExitAnchor",(0,0,0))
    animate(door,"open","location",[(1,(0,0,0)),(42,(0,0,2.15)),(60,(0,0,2.15))])


def lever():
    box("Foundation",(0,0,.10),(.72,.65,.20),"Stone",.04)
    box("Iron housing",(0,0,.26),(.45,.40,.18),"Iron")
    for x in [-.22,.22]:
        box("Pivot cheek",(x,0,.39),(.10,.30,.33),"Iron",.035)
    axle=cylinder("Axle",(0,0,.48),.068,.59)
    axle.rotation_euler.y=math.pi/2
    handle=empty("HandlePivot",(0,0,.48))
    rod=cylinder("Lever shaft",(0,0,.82),.035,.68)
    parent_at(rod,handle)
    parent_at(box("Timber grip",(0,0,1.15),(.40,.09,.10),"Timber",.025),handle)
    animate(handle,"activate","rotation_euler",[(1,(.60,0,0)),(30,(-.60,0,0)),(60,(-.60,0,0))])


def brazier():
    for i in range(4):
        a=math.pi/4+i*math.pi/2
        beam("Splayed foot",(math.cos(a)*.35,math.sin(a)*.35,0),(math.cos(a)*.20,math.sin(a)*.20,.66),.075,"Iron")
    cylinder("Ash bowl",(0,0,.60),.34,.15,"Iron",16)
    cylinder("Glowing coal",(0,0,.69),.265,.03,"Amber glass",12)
    for i in range(8):
        a=i*math.tau/8
        obj=box("Bowl rim",(math.cos(a)*.32,math.sin(a)*.32,.71),(.10,.25,.15),"Iron",.022,(0,0,a))
    for i in range(6):
        x,y=RNG.uniform(-.16,.16),RNG.uniform(-.16,.16)
        cone("Flame shape",(x,y,.82+RNG.random()*.08),.065,.27,"Amber glass")
    empty("FireOrigin",(0,0,.82))


def bounds(objects):
    points=[obj.matrix_world @ Vector(p) for obj in objects if obj.type=="MESH" for p in obj.bound_box]
    return [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]


def apply_defaults():
    bpy.context.scene.frame_set(1)
    for obj in bpy.context.scene.objects:
        if obj.name.startswith("SpikeCarrier"):
            obj.location.z=0
    bpy.context.view_layer.update()


def review_scene(objects, helper, preview_path):
    low, high=bounds(objects)
    center=Vector([(a+b)*.5 for a,b in zip(low,high)])
    extent=max(high[i]-low[i] for i in range(3))
    scene=helper.studio()
    floor=bpy.data.objects.get("Review floor")
    floor.location.z=low[2]-.045
    scene.render.engine="CYCLES"
    scene.cycles.samples=12
    scene.render.resolution_x=1000
    scene.render.resolution_y=800
    scene.camera.location=center+Vector((extent*1.0,-extent*1.5,extent*1.30))
    helper.aim(scene.camera,center)
    scene.camera.data.ortho_scale=max(extent*1.75,1.7)
    scene.render.filepath=str(preview_path)
    return scene


def build_one(entry, helper):
    ident,name,category,description,rooms,status,clip=entry
    existing=set(bpy.data.objects)
    globals()[ident]()
    objects=[obj for obj in bpy.data.objects if obj not in existing]
    root=empty(ident)
    root["asset_id"]=ident
    root["room_use"]=rooms
    for obj in objects:
        if obj.parent is None:
            parent_at(obj,root)
    objects.append(root)
    scene=bpy.context.scene
    scene.render.fps=30
    scene.frame_end=60
    apply_defaults()
    low,high=bounds(objects)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    glb=MODELS / f"{ident}.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format="GLB",use_selection=True,
        export_extras=True,export_animation_mode="ACTIONS",export_force_sampling=True)
    preview=PREVIEWS / f"{ident}.png"
    apply_defaults()
    review_scene(objects,helper,preview)
    if ident=="spike_trap":
        scene.frame_set(28)
    blend=BATCH / f"{ident}.blend"
    bpy.context.scene.render.filepath="//previews/"+preview.name
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                area.spaces.active.region_3d.view_perspective="CAMERA"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.render.render(write_still=True)
    result={"id":ident,"name":name,"category":category,"description":description,"rooms":rooms,
        "status":status,"expected_clip":clip,"blend":str(blend.relative_to(ROOT)),
        "glb":str(glb.relative_to(ROOT)),"preview":str(preview.relative_to(ROOT)),
        "dimensions_blender_xyz":[round(high[i]-low[i],3) for i in range(3)]}
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj,do_unlink=True)
    return result


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    helper=load_materials()
    records={}
    manifest=BATCH / "manifest.json"
    if manifest.exists():
        records={entry["id"]:entry for entry in json.loads(manifest.read_text())}
    requested=set(sys.argv[sys.argv.index("--")+1:]) if "--" in sys.argv else set()
    for entry in MODULES:
        if requested and entry[0] not in requested:
            continue
        records[entry[0]]=build_one(entry,helper)
        ordered=[records[item[0]] for item in MODULES if item[0] in records]
        manifest.write_text(json.dumps(ordered,ensure_ascii=False,indent=2)+"\n")
    print("ROOM_BATCH_DONE",len(records))


if __name__=="__main__":
    main()
