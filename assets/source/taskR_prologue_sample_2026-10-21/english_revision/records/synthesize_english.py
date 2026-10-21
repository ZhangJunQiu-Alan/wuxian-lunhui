from pathlib import Path
import hashlib
import json
import sys
import time

import mlx.core as mx
import numpy as np
import soundfile as sf
from mlx_audio.tts.utils import load_model

ROOT = Path(__file__).resolve().parents[1]
TASK = ROOT.parent
snapshots = TASK / "work/hf_english/hub/models--mlx-community--Qwen3-TTS-12Hz-1.7B-VoiceDesign-4bit/snapshots"
model_path = next(p for p in snapshots.iterdir() if (p / "model.safetensors").exists())
mx.set_cache_limit(128 * 1024 * 1024)
print("LOADING", model_path, flush=True)
model = load_model(model_path)
print("MODEL_READY", flush=True)
plan = json.loads((ROOT / "records/narration_plan.json").read_text())
record_path = ROOT / "records/generation.json"
records = json.loads(record_path.read_text()) if record_path.exists() else []
jobs = []
if "--samples" in sys.argv:
    for sample in json.loads((ROOT / "records/sample_plan.json").read_text()):
        jobs.append((sample["name"], sample["text"], sample["instruct"], ROOT / sample["file"]))
else:
    for level, sequence in plan.items():
        for i, shot in enumerate(sequence["shots"]):
            jobs.append((f"{level}_{i+1:02d}", shot["spoken"], shot["instruct"], ROOT / f"originals/{level}_{i+1:02d}.wav"))
for name, text, instruct, path in jobs:
    if path.exists():
        print("PRESERVED", name, flush=True)
        continue
    mx.random.seed(271021)
    started = time.monotonic()
    print("GENERATING", name, flush=True)
    pieces = []
    for result in model.generate_voice_design(text=text, instruct=instruct, language="English", temperature=0.72, top_p=0.90, top_k=40, repetition_penalty=1.08, max_tokens=420, verbose=False):
        pieces.append(np.asarray(result.audio, dtype=np.float32))
    audio = np.concatenate(pieces)
    assert np.isfinite(audio).all() and len(audio) > result.sample_rate
    sf.write(path, audio, result.sample_rate, subtype="PCM_16")
    records.append({"name": name, "text": text, "instruct": instruct, "model": str(model_path.name), "seed": 271021, "temperature": 0.72, "top_p": 0.90, "top_k": 40, "repetition_penalty": 1.08, "max_tokens": 420, "file": str(path.relative_to(ROOT)), "seconds": len(audio)/result.sample_rate, "sample_rate": result.sample_rate, "peak": float(abs(audio).max()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "wall_seconds": time.monotonic()-started, "peak_memory_gb": mx.get_peak_memory()/1e9})
    record_path.write_text(json.dumps(records, ensure_ascii=False, indent=2)+"\n")
    print("GENERATED", name, records[-1]["seconds"], "wall", records[-1]["wall_seconds"], "GB", records[-1]["peak_memory_gb"], flush=True)
    mx.clear_cache()
