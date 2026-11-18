from pathlib import Path
import sys, math, contextlib, json, struct, hashlib
import bpy
from mathutils import Vector
BATCH=Path(__file__).resolve().parent
ROOT=BATCH.parents[2]
sys.path.insert(0,str(BATCH.parent/'task3d_architecture_quality_2026-11-15'))
import build_architecture as base
art=base.art
art.BATCH=BATCH
S,W,I,E,F,R,C=art.S,art.W,art.I,art.E,art.F,art.R,art.C
box,beam,cylinder,bolt,slab,line,torus=art.box,art.beam,art.cylinder,art.bolt,art.slab,art.line,art.torus

def material(name,color,metal=0,rough=.8,glow=None):
    m=bpy.data.materials.new(name); m.use_nodes=True; m.node_tree.nodes.clear()
    p=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled'); out=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(p.outputs['BSDF'],out.inputs[0])
    p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    if glow:
        p.inputs['Emission Color'].default_value=(*glow,1); p.inputs['Emission Strength'].default_value=1.4
    art.mats[name]=m
    return name

def reset(id):
    art.reset(id)
    material('Ancient brass',(.19,.115,.035),.7,.63)
    material('Cold inlay',(.023,.10,.14),.2,.5,(.025,.28,.42))
    material('Still dark water',(.015,.04,.055),.18,.22)
    worn=next(n for n in art.mats[E].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    worn.inputs['Base Color'].default_value=(.055,.065,.075,1); worn.inputs['Roughness'].default_value=.66

@contextlib.contextmanager
def runtime_maps():
    originals=[]; copies={}
    for obj in art.root.children_recursive:
        if obj.type!='MESH': continue
        for mat in obj.data.materials:
            for node in mat.node_tree.nodes:
                if node.type!='TEX_IMAGE' or node.image is None or any(n==node for n,_ in originals): continue
                image=node.image
                if max(image.size)<=1024: continue
                if image not in copies:
                    copy=image.copy(); copy.name=image.name+'_runtime1k'; copy.scale(1024,1024)
                    copy.file_format='PNG'; copy.filepath_raw=str(BATCH/'textures'/(copy.name.replace('/','_')+'.png'))
                    copy.save(); copy.pack(); copies[image]=copy
                originals.append((node,image)); node.image=copies[image]
    try: yield
    finally:
        for node,image in originals: node.image=image
        for copy in copies.values(): bpy.data.images.remove(copy)

original_export=art.export
def export(id):
    with runtime_maps(): return original_export(id)
art.export=export

def tube(name,points,radii,mat=W,sides=12):
    verts=[]
    for i,p in enumerate(points):
        p=Vector(p); tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        tangent.normalize(); ref=Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((1,0,0))
        u=tangent.cross(ref).normalized(); v=tangent.cross(u).normalized()
        for j in range(sides):
            a=j*math.tau/sides; verts.append(tuple(p+radii[i]*(math.cos(a)*u+math.sin(a)*v)))
    faces=[tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))]
    for row in range(len(points)-1):
        for j in range(sides): faces.append((row*sides+j,row*sides+(j+1)%sides,(row+1)*sides+(j+1)%sides,(row+1)*sides+j))
    o=art.mesh(name,verts,faces,mat,.002)
    for p in o.data.polygons: p.use_smooth=True
    return o

def chain(name,a,b,count=16,radius=.045):
    for j in range(count):
        p=Vector(a).lerp(Vector(b),j/(count-1))
        torus(name,p,radius,.009,E,(math.pi/2,0,math.pi/2 if j%2 else 0),16)

def rune_mark(center,scale=.15,mat=R):
    x,y,z=center
    for a,b in [((-1,0,-1),(1,0,1)),((0,0,-1.2),(0,0,1.3)),((-1,0,1),(1,0,-.2))]:
        beam('Incised metal rune',(x+a[0]*scale,y,z+a[2]*scale),(x+b[0]*scale,y,z+b[2]*scale),.012,.014,mat)

def finish_entry(entry,builder):
    art.reset=reset_wrapper
    art.BUILDERS={entry[0]:builder}
    result=art.build_one(entry)
    result['runtime_texture_limit']=1024; result['production_stage']='首版待审核'
    (BATCH/'records'/(entry[0]+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    return result

original_reset=art.reset
def reset_wrapper(id):
    art.reset=original_reset
    reset(id)
    art.reset=reset_wrapper
