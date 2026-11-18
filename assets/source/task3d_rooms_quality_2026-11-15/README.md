# 精细房间模块

延续已确认的精细废墟拱门，制作 7 件房间模块。原版和深暗废墟版保留。

| 文件名 | 模型 | 结构与用途 |
| --- | --- | --- |
| snow_floor | 冻裂石板地面 | 3.2 m 拼接节距，独立石板、裂口、碎石和薄霜 |
| void_causeway | 残破木石断桥 | 真实空洞、悬崖断面、木板、底梁、锻铁连接 |
| spike_trap | 锻铁升降地刺 | 九根独立尖刺、导向套、升降架、活塞杆；spike 动画 |
| rune_trap | 破损符文祭盘 | 分段石环、下沉中心、铁辐条与嵌入符文 |
| pressure_plate | 配重压力踏板 | 独立下压踏面、导向结构、弹簧、铁框；press 动画 |
| lever | 棘轮锁链拉杆 | 棘轮、横轴、支架、包箍木柄、链条；activate 动画 |
| brazier | 铆接锻铁火盆 | 有厚度的凹盆、卷边、侧环、锻铁支腿、余烬 |

每件提供 `.blend`、游戏 `.glb`、渲染预览和清单记录。已确认的 `quality_rune_gate` 在总清单中引用原文件，未重写原门体。

- 游戏文件位于 `../../models/midgard/quality/`。
- `room_assembly.blend` 是静态组合评审场景，摆放含中央断桥、侧路陷阱、踏板、拉杆、祭盘、火盆和出口门。
- `previews/room_assembly.png` 为 Blender 渲染。
- `previews/godot_assets.png` 为 Godot 独立检查场景，实际游戏灯光仍需后续调校。
- `manifest.json` 为包含出口门的完整清单。
- `records/` 保存制作记录、导入与动画检查、源文件检查和 SHA256。

## 来源

几何由本批 Blender 脚本制作。材质复用 `../task3d_gate_quality_2026-11-15/rune_gate.blend` 中已处理并打包的 Poly Haven CC0 扫描材质，不增加第三方模型。石材 Rock Face 03（Dario Barresi / Rico Cilliers）、木材 Weathered Brown Planks 与锈铁 Rust Coarse 01（Dimitrios Savva / Rico Cilliers）。原始下载 URL、官方元数据和贴图哈希见前一批 `records/material-sources.json`。本批母版均打包实际使用的贴图。

## 制作与检查

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_rooms_quality_2026-11-15/build_assets.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_rooms_quality_2026-11-15/assemble_room.py
/opt/homebrew/bin/godot --headless --path . --editor --import --quit
/opt/homebrew/bin/godot --headless --path . --script assets/source/task3d_rooms_quality_2026-11-15/records/verify_assets.gd
/opt/homebrew/bin/godot --path . --rendering-method gl_compatibility --script assets/source/task3d_rooms_quality_2026-11-15/records/render_room.gd
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_rooms_quality_2026-11-15/verify_sources.py
```

模型原点与功能锚点随 GLB 导出。Blender 使用 Z 向上，Godot 使用 Y 向上。地刺与踏板尺寸清单同时记录收起姿态和评审姿态。

这是模型与动画制作批次。碰撞、伤害、预警、坠落判定、机关联动、房间生成和完整关卡性能尚未接入或验收。火盆余烬为静态几何，场景点光只用于评审。
