from pathlib import Path
import copy
import csv
import hashlib
import io
import json
import math
import subprocess
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
FORMAL = PROJECT / "assets/cinematics/norse"
WORK = ROOT / "work/audio"
WORK.mkdir(parents=True, exist_ok=True)
RATE = 48000
plan = json.loads((ROOT / "records/narration_plan.json").read_text())
commands = []

def encode(args):
    commands.append(args)
    result = subprocess.run(["ffmpeg", "-hide_banner", "-y", *args], capture_output=True, text=True)
    with (ROOT / "qa/full_audio_encode.log").open("a") as log:
        log.write(result.stderr)
    result.check_returncode()

book = copy.deepcopy(plan)
voice_tracks = {}
for level, sequence in book.items():
    pieces = []
    end = 0.0
    for i, shot in enumerate(sequence["shots"]):
        raw = ROOT / f"originals/narration/{level}_{i+1:02d}.wav"
        normalized = WORK / raw.name
        encode(["-i", str(raw), "-af", "highpass=f=65,lowpass=f=10000,loudnorm=I=-18:TP=-3:LRA=8", "-ar", str(RATE), "-ac", "2", str(normalized)])
        audio, rate = sf.read(normalized, dtype="float32", always_2d=True)
        assert rate == RATE
        voice_seconds = len(audio) / RATE
        start = 0.0 if i == 0 else end - 1.2
        span = math.ceil(max(7.8, voice_seconds + 2.8) * 24) / 24
        end = start + span
        shot.update(start=round(start, 6), end=round(end, 6), voice_start=round(start + 1.35, 6), voice_seconds=voice_seconds, caption_start=round(start + 1.05, 6), caption_end=round(min(end - 0.6, start + 1.35 + voice_seconds + 0.65), 6))
        pieces.append((int(round((start + 1.35) * RATE)), audio))
    sequence["duration"] = math.ceil(end * 24) / 24
    voice = np.zeros((round(sequence["duration"] * RATE), 2), dtype=np.float32)
    for start, audio in pieces:
        assert start + len(audio) < len(voice)
        voice[start:start+len(audio)] += audio
    voice_tracks[level] = voice

beds = {"midgard": ("hub", 12), "helheim": ("helheim", 8), "vigrid": ("vigrid", 0)}
cues = {
    "midgard": [(2, "boss_howl", 2.0, 0.07)],
    "helheim": [(1, "gleipnir_tension", 1.9, 0.12)],
    "vigrid": [(1, "jormungandr_hiss", 1.8, 0.11), (2, "gleipnir_tension", 1.9, 0.14), (3, "surtr_gate", 1.8, 0.10)],
}
sources = {}
for level, sequence in book.items():
    length = sequence["duration"]
    bed, offset = beds[level]
    source = PROJECT / f"assets/audio/music/{bed}.ogg"
    sources[str(source.relative_to(PROJECT))] = hashlib.sha256(source.read_bytes()).hexdigest()
    path = WORK / f"{level}_music.wav"
    encode(["-i", str(source), "-af", f"atrim=start={offset}:duration={length},asetpts=PTS-STARTPTS,loudnorm=I=-29:TP=-9:LRA=8,afade=t=in:d=1,afade=t=out:st={length-1.9}:d=1.9", "-ar", str(RATE), "-ac", "2", str(path)])
    fx = np.zeros_like(voice_tracks[level])
    for i, sound, delay, gain in cues[level]:
        source = PROJECT / f"assets/audio/sfx/{sound}.wav"
        sources[str(source.relative_to(PROJECT))] = hashlib.sha256(source.read_bytes()).hexdigest()
        target = WORK / f"fx_{sound}.wav"
        encode(["-i", str(source), "-af", f"atrim=duration=3.5,afade=t=in:d=0.06,afade=t=out:st=3.1:d=0.4,volume={gain}", "-ar", str(RATE), "-ac", "2", str(target)])
        samples, _ = sf.read(target, dtype="float32", always_2d=True)
        start = round((sequence["shots"][i]["start"] + delay) * RATE)
        count = min(len(samples), len(fx)-start)
        fx[start:start+count] += samples[:count]
    sf.write(WORK / f"{level}_effects.wav", fx, RATE, subtype="PCM_16")
    sf.write(WORK / f"{level}_narration.wav", voice_tracks[level], RATE, subtype="PCM_16")
    for stem in ["music", "effects", "narration"]:
        encode(["-i", str(WORK / f"{level}_{stem}.wav"), "-c:a", "vorbis", "-strict", "-2", "-q:a", "6", str(FORMAL / f"audio/{level}_{stem}.ogg")])
    print(level, round(length, 3), "seconds", flush=True)

(FORMAL / "sequences.json").write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n")
(ROOT / "records/full_audio_commands.json").write_text(json.dumps(commands, ensure_ascii=False, indent=2) + "\n")
(ROOT / "records/full_audio_source_hashes.json").write_text(json.dumps(sources, indent=2) + "\n")

locale = PROJECT / "locale/text.csv"
existing = {row[0] for row in csv.reader(io.StringIO(locale.read_text())) if row}
translations = [(shot["caption"], shot["english"]) for sequence in book.values() for shot in sequence["shots"]]
translations += [("回看本关剧情", "Replay chapter story"), ("暂停 [Space]", "Pause [Space]"), ("继续 [Space]", "Resume [Space]"), ("跳过 [Esc]", "Skip [Esc]")]
buffer = io.StringIO(newline="")
writer = csv.writer(buffer, lineterminator="\n")
for zh, en in translations:
    if zh not in existing:
        writer.writerow([zh, en])
        existing.add(zh)
with locale.open("a") as output:
    output.write(buffer.getvalue())
