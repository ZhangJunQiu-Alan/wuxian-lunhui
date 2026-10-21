from pathlib import Path
import json
import shutil
import subprocess
import sys

B=Path(__file__).parent
ROOT=B.parents[2]
runtime=B/'preview_project/runtime'
runtime.mkdir(parents=True,exist_ok=True)
for directory in ['scripts','scenes','tools','locale']:
    shutil.copytree(ROOT/directory,runtime/directory,dirs_exist_ok=True)
shutil.copytree(ROOT/'assets',runtime/'assets',dirs_exist_ok=True,ignore=shutil.ignore_patterns('source'))
shutil.copyfile(ROOT/'project.godot',runtime/'project.godot')
p=runtime/'scripts/world/vigrid_map.gd';s=p.read_text()
s=s.replace('const ROUTE := "scorched_02"','const ROUTE := "ash_road"')
s=s.replace('"burnt_grass"','"burnt_grass_02"').replace('"cracked_lava"','"cracked_lava_02"')
if 'edges["ash_road"]' not in s:
    s=s.replace('edge_masks = {"burnt_grass_02": "path_edge"}','edge_masks = {"burnt_grass_02": "path_edge"}\n\tedges["ash_road"] = "ash_road_edge"')
p.write_text(s)
shutil.copyfile(B/'records/review_m_terrain.gd.txt',runtime/'tools/review_m_terrain.gd')
(runtime/'tools/review_m_terrain.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tools/review_m_terrain.gd" id="1"]\n[node name="ReviewM" type="Node"]\nscript = ExtResource("1")\n')
subprocess.run([sys.executable,str(B/'prepare_fx_review.py')],check=True)
print(json.dumps({'runtime':str(runtime),'next':'Godot --headless --editor --path <runtime> --import, then launch review_m_terrain.tscn or review_m_fx.tscn with separate save/settings/output user args'}))
