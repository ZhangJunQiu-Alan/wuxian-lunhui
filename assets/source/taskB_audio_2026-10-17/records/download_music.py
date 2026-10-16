from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
from urllib.request import urlopen
import json,hashlib
R=Path(__file__).resolve().parents[1];rows=json.loads((R/'records/researched_music_sources.json').read_text());authors={'boss_music':'Emma_MA','mysterious':'nene','new_sunrise':'nene','dream_ambience':'TokyoGeisha','opening':'nene','war_horns':'Eldritch Grim','rising_moon':'RandomMind','lament':'RandomMind'}
def get(a):
 files=a['files'];url=next((x for x in files if x.lower().endswith('.wav')),files[-1]);url=files[-1] if a['id'] in ['lament','new_sunrise'] else url;p=R/'originals'/'music'/f"{a['id']}.{url.split('.')[-1]}";p.parent.mkdir(exist_ok=True)
 if not p.exists():p.write_bytes(urlopen(url,timeout=60).read())
 return dict(a,selected_url=url,author=authors[a['id']],raw_file=str(p.relative_to(R)),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
results=[]
with ThreadPoolExecutor(max_workers=4) as pool:
 for f in as_completed([pool.submit(get,a) for a in rows]):
  try:a=f.result();results.append(a);print(a['id'],a['bytes'],flush=True)
  except Exception as e:print(type(e).__name__,str(e),flush=True)
(R/'records/music_downloads.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
