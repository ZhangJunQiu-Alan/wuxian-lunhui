from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/windows_2026-10-22/work"
tests = ["test_combat_regressions", "test_vigrid", "test_chapter_intro", "test_title_menu", "test_run_supplies", "test_supply_guard", "test_actor_scale", "test_environment_scale", "test_god_fx_cadence", "test_spatial_queries", "test_density_buffers", "test_odin_density", "test_skadi_balance"]
result_file = HERE / "records/test_results.json"
results = json.loads(result_file.read_text()) if result_file.exists() else []
results = [item for item in results if item.get("exit_code") == 0 and not item.get("errors")]
for name in tests:
    if any(item["name"] == name for item in results): continue
    command = ["godot", "--headless", "--path", str(ROOT), "--script", f"tools/{name}.gd", "--", f"--save-file={WORK}/qa_user/{name}.json", f"--settings-file={WORK}/qa_user/{name}.cfg"]
    if name in ["test_chapter_intro", "test_run_supplies", "test_supply_guard", "test_actor_scale", "test_environment_scale"]:
        command.append(f"--output={WORK}/qa_results/{name}.json")
    elif name not in ["test_combat_regressions", "test_title_menu"]:
        command.append(f"--output={WORK}/qa_results/{name}")
    with (HERE/f"logs/{name}.log").open("w") as output:
        run = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=180)
    log = (HERE/f"logs/{name}.log").read_text()
    errors = [line for line in log.splitlines() if "SCRIPT ERROR" in line or line.startswith("ERROR:")]
    item = {"name":name,"command":command,"exit_code":run.returncode,"errors":errors,"tail":log.splitlines()[-5:]}
    results.append(item)
    result_file.write_text(json.dumps(results,ensure_ascii=False,indent=2)+"\n")
    print(name, run.returncode, item["tail"][-1:], flush=True)
    if run.returncode or errors: raise SystemExit(1)
