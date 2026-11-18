"""Fetch the selected CC0 material maps and preserve their source metadata."""
import concurrent.futures
import hashlib
import json
import urllib.request
from pathlib import Path

BATCH=Path(__file__).resolve().parent
HEADERS={"User-Agent":"Midgard-Asset-Review/1.0"}
ASSETS=["weathered_brown_planks","rock_face_03","rust_coarse_01"]

def get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url,headers=HEADERS),timeout=30) as response:
        return json.load(response)

def fetch(item):
    asset,kind,url=item
    path=BATCH/"textures"/f"{asset}_{kind}.jpg"
    if not path.exists():
        with urllib.request.urlopen(urllib.request.Request(url,headers=HEADERS),timeout=45) as response:
            path.write_bytes(response.read())
    return {"asset":asset,"map":kind,"url":url,"path":str(path.relative_to(BATCH)),
            "sha256":hashlib.sha256(path.read_bytes()).hexdigest()}

def main():
    jobs=[]
    for asset in ASSETS:
        data=get_json("https://api.polyhaven.com/files/"+asset)
        (BATCH/"records"/f"{asset}-files.json").write_text(json.dumps(data,indent=2))
        info=get_json("https://api.polyhaven.com/info/"+asset)
        (BATCH/"records"/f"{asset}-info.json").write_text(json.dumps(info,indent=2))
        print(asset,list(data),flush=True)
        for name,kind in [("Diffuse","albedo"),("nor_gl","normal"),("Rough","roughness")]:
            key=next((key for key in data if key.lower()==name.lower()),None)
            if not key:
                raise ValueError((asset,name,list(data)))
            choice=data[key]["2k"]
            format="jpg" if "jpg" in choice else "png"
            url=choice[format]["url"]
            jobs.append((asset,kind,url))
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        records=list(pool.map(fetch,jobs))
    (BATCH/"records"/"material-sources.json").write_text(json.dumps(records,indent=2))
    print("Downloaded",len(records),"maps")

if __name__=="__main__":
    main()
