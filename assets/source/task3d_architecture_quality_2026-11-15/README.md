# 精细建筑与掩体模型

延续精细拱门和房间模块的材质与尺度。本批新增 6 件，审核总清单累计 14 件。原 8 件精细模型保留，原版与深暗废墟版保留。

| 文件名 | 模型 | 特征 |
| --- | --- | --- |
| ruined_wall | 破损砌石残墙 | 3.2 米节距、错缝砌筑、破损墙冠、扶壁、背面木修补 |
| timber_pillar | 铁箍承重木柱 | 石础、包箍、横梁托座、斜撑与连接销 |
| stone_stairs | 冻裂石阶 | 五级独立踏步、分块阶身、侧墙和破损边角 |
| barricade | 铁木战斗路障 | 交叉支脚、横板、斜撑和铆接铁带 |
| supply_chest | 铁箍补给箱 | 开放内腔、拱形分板箱盖、铁带、铰链、锁孔、侧环与 open 动画 |
| runestone | 刻槽符文立碑 | 不规则石体、布尔雕刻槽、嵌入符文与落石 |

逐件 `.blend` 保留独立零件、打包材质和评审摄影。游戏 `.glb` 位于 `../../models/midgard/quality/`，按父节点和材质合并网格。功能锚点随 GLB 导出。

- `room_assembly.blend` 是本批建筑、掩体、补给箱与前一批地面、门和火盆的静态组合评审场景。
- `previews/room_assembly.png` 是 Blender 渲染。
- `previews/godot_assets.png` 是 Godot 独立导入检查场景。
- `previews/supply_chest_open.png` 单独展示打开的箱盖与内部。
- `manifest.json` 是完整 14 件清单；`new-models.json` 只包含本批 6 件。
- `records/` 保存制作、源文件验证、导入、动画、网页检查及文件哈希。

材质复用同日精细拱门中已登记的 Poly Haven CC0 扫描材质。几何由本项目 Blender 脚本制作，无新增第三方模型或贴图。原始来源、作者、下载 URL 与哈希见 `../task3d_gate_quality_2026-11-15/records/material-sources.json` 和项目 assets/LICENSES.md。

模型与动画已制作；审核状态仍由用户决定。组合场景是美术展示布局，尚未接入碰撞、掩体遮挡、宝箱掉落、祝福交互、导航和程序房间生成。

## 重建

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_architecture_quality_2026-11-15/build_architecture.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_architecture_quality_2026-11-15/render_open_chest.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_architecture_quality_2026-11-15/assemble_room.py
python3 assets/source/task3d_architecture_quality_2026-11-15/finalize_catalog.py
/opt/homebrew/bin/godot --headless --path . --editor --import --quit
/opt/homebrew/bin/godot --headless --path . --script assets/source/task3d_architecture_quality_2026-11-15/records/verify_assets.gd
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_architecture_quality_2026-11-15/verify_sources.py
```
