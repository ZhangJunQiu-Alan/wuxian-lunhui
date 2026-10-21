from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parents[1]
publication = json.loads((HERE/"records/source_publication.json").read_text())
assert publication["source_commit"] == publication["verified_remote"]
subprocess.run(["git","merge-base","--is-ancestor",publication["source_commit"],"HEAD"],cwd=ROOT,check=True)
tracked = {p for p in subprocess.check_output(["git","ls-files","-z"],cwd=ROOT).decode().split("\0") if p}
def protected_digest():
    digest = hashlib.sha256()
    count = 0
    for name in sorted(tracked):
        path = ROOT/name
        if not path.is_file(): continue
        with path.open("rb") as stream: file_hash = hashlib.file_digest(stream,"sha256").hexdigest()
        digest.update((name+"\0"+file_hash+"\n").encode())
        count += 1
    return count,digest.hexdigest()
def logical_size(path):
    if path.is_symlink(): return path.lstat().st_size
    if path.is_file(): return path.stat().st_size
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file() and not p.is_symlink())
candidates = []
work = ROOT/"assets/source/taskR_prologue_sample_2026-10-21/work"
if work.exists(): candidates.extend((p,"rebuildable narration model/dependency/test workspace") for p in work.iterdir() if p.name!=".gitignore")
for base,dirs,files in os.walk(ROOT/"assets/source"):
    for name in list(dirs):
        if name in [".godot","__pycache__"]:
            candidates.append((Path(base)/name,"rebuildable source-only Godot/Python cache"))
            dirs.remove(name)
        elif name=="work": dirs.remove(name)
refs = {x["file"] for x in json.loads((HERE/"records/source_metadata_references.json").read_text())}
initial = json.loads((HERE/"records/initial_scope.json").read_text())
for name in initial["excluded_untracked_source_sidecars"]:
    if name not in refs and name not in tracked: candidates.append((ROOT/name,"untracked unreferenced generated source metadata"))
archive = ROOT/"build/windows_2026-10-22/work/Godot_v4.7.2-stable_export_templates.tpz"
if archive.exists(): candidates.append((archive,"verified official template archive; installed Windows templates retained"))
selected = []
for path,reason in sorted(candidates,key=lambda x:len(x[0].parts)):
    if not path.exists() and not path.is_symlink(): continue
    if any(path.is_relative_to(parent) for parent,_ in selected): continue
    relative = str(path.relative_to(ROOT))
    assert not any(name==relative or name.startswith(relative+"/") for name in tracked),relative
    assert subprocess.run(["git","check-ignore","-q",relative],cwd=ROOT).returncode==0,relative
    selected.append((path,reason))
commands = subprocess.check_output(["ps","-axo","command="],text=True).splitlines()
assert not any("godot " in cmd.lower() and any(str(path) in cmd for path,_ in selected) for cmd in commands),"A selected cache is in use by Godot"
before = protected_digest()
free_before = shutil.disk_usage(ROOT).free
removed = []
for path,reason in selected:
    size = logical_size(path)
    if path.is_symlink() or path.is_file(): path.unlink()
    else: shutil.rmtree(path)
    removed.append({"path":str(path.relative_to(ROOT)),"logical_bytes":size,"reason":reason})
after = protected_digest()
assert before==after,"A committed file changed during cleanup"
report = {"published_source_commit":publication["source_commit"],"protected_tracked_files":before[0],"before_protected_aggregate_sha256":before[1],"after_protected_aggregate_sha256":after[1],"committed_files_unchanged":True,"removed":removed,"logical_bytes_removed":sum(x["logical_bytes"] for x in removed),"disk_free_before":free_before,"disk_free_after":shutil.disk_usage(ROOT).free,"preserved":"all tracked runtime/source files, originals, prompts, licenses, QA evidence, player saves, shared root .godot, .git/LFS; 221 manifest-referenced metadata files retained","rebuild_note":"Narration work/model environments were never game dependencies. Recreate isolated environments from retained records/environment.json, download the pinned public model revision and verify retained hashes before synthesis."}
(HERE/"records/cleanup_result.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
print("CLEANUP",len(removed),"paths",report["logical_bytes_removed"],"logical bytes;",before[0],"committed files unchanged")
