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
TASK = ROOT.parent
PROJECT = TASK.parents[2]
FORMAL = PROJECT / "assets/cinematics/norse"
WORK = TASK / "work/english_audio"
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
        raw = ROOT / f"originals/{level}_{i+1:02d}.wav"
        normalized = WORK / raw.name
        encode(["-i", str(raw), "-af", "highpass=f=65,lowpass=f=10000,loudnorm=I=-19:TP=-3:LRA=11", "-ar", str(RATE), "-ac", "2", str(normalized)])
        audio, rate = sf.read(normalized, dtype="float32", always_2d=True)
        assert rate == RATE
        voice_seconds = len(audio) / RATE
        start = 0.0 if i == 0 else end - 1.2
        span = math.ceil(max(8.8, voice_seconds + 3.8) * 24) / 24
        end = start + span
        shot.update(start=round(start, 6), end=round(end, 6), voice_start=round(start + 1.55, 6), voice_seconds=voice_seconds, caption_start=round(start + 1.20, 6), caption_end=round(min(end - 0.6, start + 1.55 + voice_seconds + 0.85), 6))
        pieces.append((int(round((start + 1.55) * RATE)), audio))
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
    encode(["-stream_loop", "-1", "-i", str(source), "-af", f"atrim=start={offset}:duration={length},asetpts=PTS-STARTPTS,loudnorm=I=-23:TP=-5:LRA=11,afade=t=in:d=1.5,afade=t=out:st={length-2.1}:d=2.1", "-ar", str(RATE), "-ac", "2", str(path)])
    music, _ = sf.read(path, dtype="float32", always_2d=True)
    music = music[:len(voice_tracks[level])]
    if len(music) < len(voice_tracks[level]): music = np.pad(music, ((0,len(voice_tracks[level])-len(music)),(0,0)))
    times = np.arange(len(music)) / RATE
    envelope = np.ones(len(music), dtype=np.float32)
    for shot in sequence["shots"]:
        onset, release = shot["voice_start"], shot["voice_start"] + shot["voice_seconds"]
        attack = np.clip((times - (onset-0.35))/0.35,0,1)
        recovery = np.clip((release+0.85-times)/0.85,0,1)
        envelope = np.minimum(envelope, 1.0 - 0.62*np.minimum(attack,recovery))
    sf.write(path, music * envelope[:,None], RATE, subtype="PCM_16")
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
rows = list(csv.reader(io.StringIO(locale.read_text())))
translations = {shot["caption"]:shot["english"] for sequence in book.values() for shot in sequence["shots"]}
for row in rows:
    if row and row[0] in translations: row[1] = translations.pop(row[0])
for zh,en in translations.items(): rows.append([zh,en])
buffer = io.StringIO(newline="")
writer = csv.writer(buffer, lineterminator="\n")
writer.writerows(rows)
locale.write_text(buffer.getvalue())
