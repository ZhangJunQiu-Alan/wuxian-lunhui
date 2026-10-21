from pathlib import Path
import shutil

B = Path(__file__).parent
runtime = B / "preview_project/runtime"
for god in ["freyja", "baldr", "ran", "skadi"]:
    shutil.copyfile(B / f"candidates/aid_{god}_v03.png", runtime / f"assets/sprites/effects/gods/aid_{god}.png")
shutil.copyfile(B / "candidates/surtr_sword_arc_large_v01.png", runtime / "assets/sprites/effects/bosses/surtr_sword_arc_large.png")
fx = runtime / "scripts/effects/boss_fx.gd"
s = fx.read_text()
if '"surtr_sword_arc_large"' not in s:
    s = s.replace('"surtr_sword_arc",', '"surtr_sword_arc", "surtr_sword_arc_large",')
fx.write_text(s)
for name in ["m_art_overlay.gd", "review_m_fx.gd"]:
    shutil.copyfile(B / "preview_project" / name, runtime / "tools" / name)
(runtime / "tools/review_m_fx.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tools/review_m_fx.gd" id="1"]\n[node name="ReviewMFX" type="Node"]\nscript = ExtResource("1")\n')
