from pathlib import Path
import hashlib
import json
import numpy as np
import soundfile as sf
import jieba
from misaki import zh
from kokoro_onnx import Kokoro

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "work/models"
OUTPUT = ROOT / "originals/narration"
OUTPUT.mkdir(exist_ok=True)
jieba.dt.tmp_dir = str(ROOT / "work")
plan = json.loads((ROOT / "records/narration_plan.json").read_text())
g2p = zh.ZHG2P(version="1.1")
engine = Kokoro(str(MODELS / "kokoro-v1.1-zh.onnx"), str(MODELS / "voices-v1.1-zh.bin"), vocab_config=str(MODELS / "config.json"))
records = []
for level, sequence in plan.items():
    for index, shot in enumerate(sequence["shots"]):
        phonemes, _ = g2p(shot["spoken"])
        assert "❓" not in phonemes, (shot["spoken"], phonemes)
        samples, rate = engine.create(phonemes, voice="zm_010", speed=0.90, is_phonemes=True)
        assert np.isfinite(samples).all() and len(samples) > rate
        path = OUTPUT / f"{level}_{index + 1:02d}.wav"
        sf.write(path, samples, rate, subtype="PCM_16")
        record = {"level": level, "shot": index, "text": shot["spoken"], "phonemes": phonemes, "voice": "zm_010", "speed": 0.90, "sample_rate": rate, "seconds": len(samples) / rate, "peak": float(np.max(np.abs(samples))), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "file": str(path.relative_to(ROOT))}
        records.append(record)
        print(level, index + 1, round(record["seconds"], 3), shot["spoken"], flush=True)
(ROOT / "records/tts/narration_generation.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
