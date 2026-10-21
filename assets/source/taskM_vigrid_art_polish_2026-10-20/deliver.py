from pathlib import Path
import colorsys
import hashlib
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw

B = Path(__file__).parent
ROOT = B.parents[2]
checks = []
def check(name, condition, data=None):
    checks.append({"check":name, "passed":bool(condition), "data":data})
    if not condition: raise AssertionError(name)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
plan = json.loads((B / "records/plan.json").read_text())
baseline = json.loads((B / "records/existing_sprite_hashes.json").read_text())
changes = [p for p,h in baseline.items() if not (ROOT/p).exists() or sha(ROOT/p) != h]
check("all pre-existing sprite files unchanged", not changes, {"count":len(baseline), "changed":changes})
manifest = []
for item in plan["files"]:
    ident = item["id"]
    version = "v03" if ident.startswith("aid_") else "v02" if ident.startswith("ash_road_edge_") or ident=="cracked_lava_02" else "v01"
    candidate = B / f"candidates/{ident}_{version}.png"
    image = Image.open(candidate)
    arr = np.array(image)
    fw,fh = item["frame_size"]
    n = item["frames"]
    check(ident+": RGBA exact size",image.mode=="RGBA" and image.size==(fw*n,fh), {"mode":image.mode,"size":list(image.size)})
    check(ident+": transparent RGB clean",not np.any(arr[arr[:,:,3]==0,:3]))
    colors = len(np.unique(arr[arr[:,:,3]>0,:3],axis=0))
    check(ident+": palette <=48",colors<=48,colors)
    alpha = np.unique(arr[:,:,3]).tolist()
    check(ident+": alpha <=8 steps", len(alpha)<=8,alpha)
    frames = [arr[:,i*fw:(i+1)*fw] for i in range(n)]
    if ident.startswith("aid_"):
        check(ident+": frame8 empty",not np.any(frames[7]))
        check(ident+": all 7 authored visible frames distinct",len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames[:7]})==7)
        check(ident+": maximum opacity <=0.85",max(int(f[:,:,3].max()) for f in frames)<=216)
        yy,xx=np.mgrid[:320,:320];r=np.hypot(xx-160,yy-160)
        radii={"aid_freyja":140,"aid_baldr":110,"aid_ran":130,"aid_skadi":130};radius=radii[ident]
        check(ident+": peak frame outside radius+8 empty",not np.any(frames[4][r>radius+8,3]))
        profile=[(k,float((frames[4][:,:,3][(r>=k)&(r<k+1)]>72).mean())) for k in range(int(radius*.6),radius+7)]
        outer=int(max(k for k,v in profile if v>=.35))
        check(ident+": primary perimeter ±8",abs(outer-radius)<=8,{"target":radius,"perimeter_35pct_angular_coverage":outer,"delta":outer-radius})
        warm=sum(.0<=h<.11 and s>.3 and v>.25 for h,s,v in [colorsys.rgb_to_hsv(*(c/255)) for c in np.unique(arr[arr[:,:,3]>0,:3],axis=0)])
        check(ident+": no saturated red/orange",warm==0,warm)
        item["radius"]=radius
        item["source"]=[f"originals/{ident}_v01_raw.png"]
        item["prompt_records"]=[f"records/prompt_{ident}_v01.json"]
    elif ident=="surtr_sword_arc_large":
        yy,xx=np.mgrid[:640,:640];r=np.hypot(xx-320,yy-320);angle=np.arctan2(yy-320,xx-320)
        outside=(r>290)|(np.abs(angle)>1.05)
        check(ident+": all four frames within exact sector",not any(np.any(f[outside,3]) for f in frames))
        check(ident+": final opacity <0.3",int(frames[3][:,:,3].max())/255<.3,int(frames[3][:,:,3].max())/255)
        check(ident+": hollow center",not any(np.any(f[r<160,3]) for f in frames))
        item["radius"]=290;item["half_angle"]=1.05;item["scale"]=[1,1]
        item["source"]=[f"originals/surtr_sword_arc_large_f0{i}_v01_raw.png" for i in range(4)]
        item["prompt_records"]=[f"records/prompt_surtr_sword_arc_large_f0{i}_v01.json" for i in range(4)]
    elif ident.startswith("ash_road_edge_"):
        check(ident+": binary mask",set(alpha)<=set([0,255]))
        part=ident.removeprefix("ash_road_edge_")
        old=ROOT/f"assets/sprites/ground/helheim/bone_path_edge_{part}.png"
        check(ident+": old topology only subtracted",not np.any((arr[:,:,3]>0)&(np.array(Image.open(old).convert('RGBA'))[:,:,3]<128)))
        item["source"]=["originals/ash_road_v01_raw.png",str(old.relative_to(ROOT))]
        item["prompt_records"]=["records/prompt_ash_road_v01.json"]
    else:
        check(ident+": opaque terrain",alpha==[255])
        l=arr[:,:,:3]@np.array([.299,.587,.114]);mean=float(l.mean());std=float(l.std())
        if ident=="ash_road":check(ident+": brightness AND contrast targets",mean>=48 and std>=14,{"luminance":mean,"stddev":std})
        if ident=="burnt_grass_02":
            check(ident+": brightness difference >=6",abs(mean-33.4)>=6,mean-33.4)
            ember=((arr[:,:,0]>arr[:,:,1]*1.4)&(arr[:,:,0]>45)).mean()
            check(ident+": embers <=1pct",ember<=.01,float(ember))
        if ident=="cracked_lava_02":
            hsv=[colorsys.rgb_to_hsv(*(c[:3]/255)) for c in arr.reshape(-1,4)]
            orange=sum(.02<=h<=.15 and s>=.45 and v>=.20 for h,s,v in hsv)/4096
            check(ident+": orange cracks 3 to6pct",.03<=orange<=.06,orange)
            check(ident+": warm max value <=160",max(max(c[:3]) for c,(h,s,v) in zip(arr.reshape(-1,4),hsv) if .02<=h<=.15 and s>=.45 and v>=.20)<=160)
        item["source"]=[f"originals/{ident}_v01_raw.png"]
        item["prompt_records"]=[f"records/prompt_{ident}_v01.json"]
    # Every original and prompt must exist before publication.
    source_records=[]
    for source in item["source"]:
        path=ROOT/source if source.startswith("assets/") else B/source
        check(ident+": source exists "+source,path.exists())
        source_records.append({"path":source,"sha256":sha(path)})
    for prompt in item["prompt_records"]:check(ident+": prompt exists",(B/prompt).exists())
    item["source_records"]=source_records
    item["candidate"]=str(candidate.relative_to(B));item["sha256"]=sha(candidate)
    item["palette_colors"]=colors;item["alpha_values"]=alpha
    item["status"]="art self-reviewed; isolated controlled visual preview; production integration pending"
    manifest.append(item)

captures=[]
for kind,count in [("terrain_game_final",18),("fx_game_final",41)]:
    p=B/f"previews/{kind}/captures.json"
    data=json.loads(p.read_text())
    check(kind+": exact screenshot count",len(data["captures"])==count,len(data["captures"]))
    for shot in data["captures"]:
        im=Image.open(p.parent/shot["file"])
        check(kind+":"+shot["file"],shot["ok"] and list(im.size)==shot["window"])
    captures.append({"folder":str(p.parent.relative_to(B)),"count":len(data["captures"]),"scope":data["scope"]})

for item in manifest:
    source=B/item["candidate"];dest=ROOT/item["path"]
    check(item["id"]+": add-only formal publish",not dest.exists() or sha(dest)==sha(source))
    dest.parent.mkdir(parents=True,exist_ok=True)
    if not dest.exists():shutil.copyfile(source,dest)
    shutil.copyfile(source,B/"approved"/dest.name)
    check(item["id"]+": formal approved candidate identical",sha(dest)==sha(source)==sha(B/"approved"/dest.name))
    # 4x4 presentation: terrain seamless fill, edge alpha contact repetition, FX frames repeated row-major.
    sheet=Image.open(source).convert("RGBA");fw,fh=item["frame_size"];n=item["frames"]
    board=Image.new("RGBA",(4*fw,4*fh),(28,29,32,255))
    for i in range(16):board.alpha_composite(sheet.crop(((i%n)*fw,0,(i%n+1)*fw,fh)),((i%4)*fw,(i//4)*fh))
    board.convert("RGB").save(B/f"previews/{item['id']}_4x4.png")
    if n==1:
        sheet.resize((fw*4,fh*4),Image.Resampling.NEAREST).save(B/f"previews/{item['id']}_4x.png")

for ident,n,ms in [("surtr_arc",4,[60,60,70,60])]+[("aid_"+g,8,[80,90,80,80,90,80,80,90]) for g in ["freyja","baldr","ran","skadi"]]:
    frames=[Image.open(B/f"previews/fx_game_final/{ident}_f{i+1}.png").convert("RGB") for i in range(n)]
    frames[0].save(B/f"previews/{ident}_game.gif",save_all=True,append_images=frames[1:],duration=ms,loop=0)

(B/"manifest.json").write_text(json.dumps({"task":"M-ART-01–03","date":"2026-10-20","files":manifest,"file_count":len(manifest),"frame_units":sum(x['frames'] for x in manifest),"generation":"OpenAI built-in imagegen; 11 retained raw generations; sources are larger than logical final delivery","licensing":"assets/LICENSES.md M-ART-01–03 entry; OpenAI output ownership terms; nonexclusive; Pillow/Godot processing","runtime_evidence":captures,"production_code_modified":False,"full_game_acceptance":False},ensure_ascii=False,indent=2))
(B/"records/final_audit.json").write_text(json.dumps({"passed":sum(c['passed'] for c in checks),"failed":sum(not c['passed'] for c in checks),"checks":checks,"pre_existing_sprite_files":len(baseline),"pre_existing_changed":changes},ensure_ascii=False,indent=2,default=lambda x:x.item()))
print(json.dumps({"files":len(manifest),"frame_units":sum(x['frames'] for x in manifest),"checks":len(checks),"failed":0,"existing_unchanged":len(baseline)}))
