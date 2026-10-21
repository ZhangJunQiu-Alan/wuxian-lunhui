from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
TASK = ROOT.parent
metadata = json.loads((ROOT / "records/model_files.json").read_text())
revision = metadata["sha"]
base = TASK / "work/hf_english/hub/models--mlx-community--Qwen3-TTS-12Hz-1.7B-VoiceDesign-4bit/snapshots" / revision
parts = TASK / "work/english_download_parts"
parts.mkdir(exist_ok=True)
block = 8 * 1024 * 1024
for item in metadata["siblings"]:
    if "lfs" not in item:
        continue
    name, size = item["rfilename"], item["size"]
    target = base / name
    expected = item["lfs"]["sha256"]
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == expected:
        print("VERIFIED existing", name, flush=True)
        continue
    jobs = [(start, min(size-1,start+block-1)) for start in range(0,size,block)]
    def fetch(pair):
        start,end = pair
        path = parts / f"{expected}_{start}"
        if path.exists() and path.stat().st_size == end-start+1: return path
        url = f"https://huggingface.co/{metadata['id']}/resolve/{revision}/{name}?download=true&range_start={start}"
        for attempt in range(3):
            try:
                request = urllib.request.Request(url,headers={"Range":f"bytes={start}-{end}"})
                with urllib.request.urlopen(request,timeout=60) as response:
                    assert response.status == 206
                    assert response.headers['Content-Range'] == f"bytes {start}-{end}/{size}"
                    data = response.read()
                assert len(data) == end-start+1
                path.write_bytes(data)
                return path
            except Exception:
                if attempt == 2: raise
    with ThreadPoolExecutor(max_workers=4) as pool:
        for n,future in enumerate(as_completed([pool.submit(fetch,pair) for pair in jobs]),1):
            future.result()
            if n%12 == 0: print(name,n,"/",len(jobs),flush=True)
    if target.is_symlink(): target.unlink()
    with target.open("wb") as output:
        for start,_ in jobs: output.write((parts/f"{expected}_{start}").read_bytes())
    assert hashlib.sha256(target.read_bytes()).hexdigest() == expected
    print("VERIFIED complete",name,size,flush=True)
