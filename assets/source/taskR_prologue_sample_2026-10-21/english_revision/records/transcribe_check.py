from pathlib import Path
import hashlib
import json
import sys
import soundfile as sf
import mlx.core as mx
from mlx_audio.stt import load

ROOT = Path(__file__).resolve().parents[1]
TASK = ROOT.parent
model_path = next((TASK / "work/hf_english/hub/models--mlx-community--whisper-base.en-asr-6bit/snapshots").iterdir())
model = load(str(model_path))
files = sorted((ROOT / ("candidates" if "--samples" in sys.argv else "originals")).glob("*.wav"))
output = ROOT / ("qa/candidate_transcripts.json" if "--samples" in sys.argv else "qa/transcripts.json")
records = []
for path in files:
    result = model.generate(str(path), language="en", temperature=(0.0,0.2,0.4,0.6,0.8), condition_on_previous_text=False)
    duration = sf.info(path).duration
    bounded = [s for s in result.segments if s["start"] < duration and s["end"] <= duration+0.15]
    transcript = "".join(s["text"] for s in bounded)
    records.append({"file":str(path.relative_to(ROOT)),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"seconds":duration,"transcript_within_audio":transcript,"unfiltered_transcript":result.text,"segments":result.segments,"subjective_review":"ASR only; padded silence can hallucinate beyond file duration; not human listening acceptance"})
    print(path.name, transcript, flush=True)
    output.write_text(json.dumps(records,ensure_ascii=False,indent=2)+"\n")
    mx.clear_cache()
