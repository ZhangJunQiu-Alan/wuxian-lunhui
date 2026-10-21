from pathlib import Path
import hashlib
import json
import subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
TASK = ROOT.parent
PROJECT = TASK.parents[2]
book = json.loads((PROJECT / "assets/cinematics/norse/sequences.json").read_text())
def decode(path):
    data = subprocess.check_output(["ffmpeg","-v","error","-i",str(path),"-ar","48000","-ac","2","-f","f32le","-"])
    return np.frombuffer(data,dtype="<f4").reshape(-1,2)
def rms(samples):
    mono = samples.mean(axis=1)
    n = len(mono)//480
    return np.sqrt(np.mean(mono[:n*480].reshape(-1,480)**2,axis=1))
results = {}
for level in book:
    voice = [decode(PROJECT/f"assets/cinematics/norse/audio/{level}_{stem}.ogg") for stem in ["music","effects","narration"]]
    reference = rms(sum(voice)*0.8)
    video = TASK/f"preview/{level}_story.mp4"
    recorded = rms(decode(video))
    scores = {}
    for lag in range(-12,13):
        a,b = (reference[-lag:],recorded) if lag<0 else (reference,recorded[lag:])
        n=min(len(a),len(b));scores[lag]=float(np.corrcoef(a[:n],b[:n])[0,1])
    best=max(scores,key=scores.get)
    assert abs(best)<=1 and scores[best]>.98,(level,scores)
    results[level] = {"best_offset_ms":best*10,"rms_envelope_correlation":scores[best],"video_sha256":hashlib.sha256(video.read_bytes()).hexdigest(),"scope":"exported movie audio vs current production stems; not subjective listening"}
(ROOT/"qa/audio_video_sync.json").write_text(json.dumps(results,indent=2)+"\n")
print(results)
