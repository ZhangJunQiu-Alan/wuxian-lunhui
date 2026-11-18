# 精细废墟拱门样板

本批只制作一个出口门，供审核新的模型精度。原版和深暗废墟八件模型保留。

- `rune_gate.blend` 可编辑门体、材质、升门动画和近景摄影灯光。
- `room_assembly.blend` 门体与庭院摆放评审场景。
- `../../models/midgard/quality/rune_gate.glb` 游戏模型，包含 open 动画。
- `previews/rune_gate.png` 近景渲染。
- `previews/room_assembly.png` Blender 场景视角。
- `previews/godot_gate.png` Godot 兼容渲染器中的独立导入检查场景，非最终游戏灯光。
- `manifest.json` 文件、尺寸、面数和用途清单。
- `records/material-sources.json` 贴图原始下载地址与 SHA256。

几何为本项目程序建模，包含独立拱券、带破损的砌块、厚木板、锻铁箍、铆钉、门环、锁链和碎石。开门时木闸整体上升。模型为美术样板，尚未接入战斗房清场逻辑、碰撞、遮挡淡出或 LOD；没有据此声称已完成关卡或性能验收。

## 材质来源

三组 Poly Haven 扫描 PBR 材质，保留原始 2K JPG 下载文件，制作时进行色调处理并在 Blender 中打包。纹理许可 CC0。

- Rock Face 03 — Dario Barresi / Rico Cilliers。https://polyhaven.com/a/rock_face_03
- Weathered Brown Planks — Dimitrios Savva / Rico Cilliers。https://polyhaven.com/a/weathered_brown_planks
- Rust Coarse 01 — Dimitrios Savva / Rico Cilliers。https://polyhaven.com/a/rust_coarse_01
- 许可 https://polyhaven.com/license

这些是材质来源，未下载第三方门体模型。石拱、木闸和五金几何保存在可编辑母版中。

## 重建

```sh
python3 assets/source/task3d_gate_quality_2026-11-15/download_materials.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_gate_quality_2026-11-15/build_gate.py
```
