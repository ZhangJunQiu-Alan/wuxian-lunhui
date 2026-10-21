from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
RUNTIME = ROOT / "work/qa_runtime"
book = json.loads((PROJECT / "assets/cinematics/norse/sequences.json").read_text())
result_path = ROOT / "qa/video_checks.json"
results = json.loads(result_path.read_text()) if result_path.exists() else {}
for level, sequence in book.items():
    if len(sys.argv)>1 and level!=sys.argv[1]: continue
    avi = ROOT / f"work/{level}.avi"
    command = ["godot", "--path", str(RUNTIME), "res://scenes/chapter_intro.tscn", "--write-movie", str(avi), "--fixed-fps", "24", "--disable-vsync", "--", "--save-file=user://cinematic_export.json", "--settings-file=user://cinematic_export.cfg", f"--cinematic-export={level}"]
    with (ROOT / f"qa/movie_{level}_final.log").open("w") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    metadata = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(avi)]))
    expected = round(sequence["duration"] * 24)
    stream = next(stream for stream in metadata["streams"] if stream["codec_type"] == "video")
    assert expected <= int(stream["nb_frames"]) <= expected + 2, (level, stream)
    assert "CINEMATIC_EXPORT_DONE" in (ROOT / f"qa/movie_{level}_final.log").read_text()
    video = ROOT / f"preview/{level}_story.mp4"
    command = ["ffmpeg", "-hide_banner", "-y", "-i", str(avi), "-t", str(sequence["duration"]), "-frames:v", str(expected), "-c:v", "libx264", "-crf", "18", "-preset", "medium", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(video)]
    with (ROOT / f"qa/encode_{level}_final.log").open("w") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    final = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(video)]))
    decoded = subprocess.run(["ffmpeg", "-v", "error", "-i", str(video), "-f", "null", "-"], capture_output=True, text=True, check=True)
    assert not decoded.stderr.strip(), decoded.stderr
    final_stream = next(stream for stream in final["streams"] if stream["codec_type"] == "video")
    assert int(final_stream["nb_frames"]) == expected
    results[level] = {"expected_frames": expected, "avi": metadata, "final": final, "full_decode_errors": decoded.stderr}
    print("VERIFIED_MOVIE", level, expected, sequence["duration"], flush=True)
    (ROOT / "qa/video_checks.json").write_text(json.dumps(results, indent=2) + "\n")
