from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
TASK = ROOT.parent
PROJECT = TASK.parents[2]
FORMAL = PROJECT / "assets/cinematics/norse"
def describe(path):
    return {"bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
def source_files(base):
    result = {}
    for path in sorted(base.rglob("*")):
        if not path.is_file(): continue
        name = path.relative_to(base)
        if str(name)=="manifest.json" or "work" in name.parts or ".godot" in name.parts or "__pycache__" in name.parts: continue
        if str(name).startswith("preview/frames/"): continue
        if str(name).startswith("demo/") and path.suffix in [".uid",".import"]: continue
        result[str(name)] = describe(path)
    return result
book = json.loads((FORMAL/"sequences.json").read_text())
routes = json.loads((ROOT/"qa/routes.json").read_text())
window = json.loads((ROOT/"qa/window_routes.json").read_text())
assert not routes["failures"] and not window["failures"]
audio = json.loads((ROOT/"qa/audio_checks.json").read_text())
video = json.loads((ROOT/"qa/video_checks.json").read_text())
sync = json.loads((ROOT/"qa/audio_video_sync.json").read_text())
assert len(video)==3 and all(not item["full_decode_errors"] for item in video.values())
formal = {str(path.relative_to(PROJECT)):describe(path) for path in sorted(FORMAL.rglob("*")) if path.is_file()}
revision = {"task":"R English B narration and dynamic music mix","direction":"B: 阴沉预言; user selected sample direction only","language":"English","subtitles":"Chinese default; English localization retained","model":"mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-4bit","model_license":"Apache-2.0","inference":"MLX-Audio 0.6.1 / MIT","reference_audio":"none; original text-designed narrator","seed":271021,"selected_raw_wav_count":12,"comparison_samples":2,"superseded_A_lines":len(json.loads((ROOT/"records/generation_A_interrupted.json").read_text())),"formal_audio_stems":9,"runtime_code_changed_by_audio_revision":False,"full_set_subjective_listening":"pending","validation":{"headless_routes":routes,"window_routes":window,"audio":audio,"video_audio_sync":sync,"full_video_decode_errors":0,"current_translation_missing":0,"current_translation_unused":0,"game_release_acceptance":False},"formal_files":formal,"source_files":source_files(ROOT)}
(ROOT/"manifest.json").write_text(json.dumps(revision,ensure_ascii=False,indent=2)+"\n")
main = json.loads((ROOT/"before/manifest.json").read_text())
main["task"]="R complete Norse per-level cinematics, English B audio revision"
main["narrator"]={key:revision[key] for key in ["language","model","model_license","inference","reference_audio","seed","direction","full_set_subjective_listening"]}
main["narration_raw_wav_count"]=12
main["archived_chinese_raw_wav_count"]=12
main["english_revision_manifest"]="english_revision/manifest.json"
main["sequences"]={key:{"seconds":seq["duration"],"frames_24fps":round(seq["duration"]*24),"video":f"preview/{key}_story.mp4"} for key,seq in book.items()}
main["validation"]={"headless_routes":routes,"window_routes":window,"current_translation_entries":853,"translation_missing":0,"full_video_decode_errors":0,"audio_video_sync":sync,"prior_chinese_revision_combat_regression":{"checks":997,"failures":0,"rerun_for_this_audio_revision":False},"game_release_acceptance":False}
main["formal_files"]=formal
main["production_code_hashes"]={name:hashlib.sha256((PROJECT/name).read_bytes()).hexdigest() for name in main["production_code_hashes"]}
main["source_files"]=source_files(TASK)
(TASK/"manifest.json").write_text(json.dumps(main,ensure_ascii=False,indent=2)+"\n")
for base, manifest in [(ROOT,revision),(TASK,main)]:
    for name,entry in manifest["source_files"].items(): assert describe(base/name)==entry,name
    for name,entry in manifest["formal_files"].items(): assert describe(PROJECT/name)==entry,name
for gallery in [ROOT/"gallery.html",TASK/"gallery.html"]:
    for ref in re.findall(r'(?:src|href|poster)="([^"]+)"',gallery.read_text()):
        if not re.match(r"https?://",ref): assert (gallery.parent/ref).exists(),ref
print("VERIFIED manifests",len(main["source_files"]),"source files,",len(formal),"formal files; gallery links valid")
