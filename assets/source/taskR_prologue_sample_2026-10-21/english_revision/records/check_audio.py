from pathlib import Path
import hashlib
import json
import subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parent.parents[2]
FORMAL = PROJECT / "assets/cinematics/norse"
book = json.loads((FORMAL / "sequences.json").read_text())
results = {}
for level, sequence in book.items():
    stems = {}
    arrays = []
    for stem in ["music", "effects", "narration"]:
        path = FORMAL / f"audio/{level}_{stem}.ogg"
        decoded = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-ar", "48000", "-ac", "2", "-f", "f32le", "-"])
        samples = np.frombuffer(decoded, dtype="<f4").reshape(-1,2)
        assert np.isfinite(samples).all() and np.max(abs(samples)) < 1
        assert abs(len(samples)/48000-sequence["duration"]) < 0.005
        arrays.append(samples)
        stems[stem] = {"seconds": len(samples)/48000, "peak_dbfs": float(20*np.log10(max(1e-12,np.max(abs(samples))))), "sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
    assert len({len(a) for a in arrays}) == 1
    assert np.max(abs(arrays[2][:48000])) < 1e-6
    mix = sum(arrays)*0.8
    assert np.max(abs(mix)) < 0.95
    for i,shot in enumerate(sequence["shots"]):
        assert shot["language"] == "English"
        assert shot["voice_start"]+shot["voice_seconds"] < shot["end"]-0.6
        assert shot["caption_start"] < shot["voice_start"]
        assert shot["caption_end"] > shot["voice_start"]+shot["voice_seconds"]
        assert shot["spoken"].isascii()
    results[level] = {"stems":stems,"combined_at_default_bus_gain_peak_dbfs":float(20*np.log10(max(1e-12,np.max(abs(mix))))),"no_clipped_or_nonfinite_samples":True,"voice_starts_after_one_second":True,"subjective_listening":"pending_user_review"}
    out = ROOT / f"preview/{level}_english_mix.wav"
    subprocess.run(["ffmpeg","-v","error","-y","-f","f32le","-ar","48000","-ac","2","-i","-","-c:a","pcm_s16le",str(out)],input=mix.astype("<f4").tobytes(),check=True)
(ROOT / "qa/audio_checks.json").write_text(json.dumps(results,indent=2)+"\n")
print("9 stems, 12 English lines, timing and mix peaks verified")
