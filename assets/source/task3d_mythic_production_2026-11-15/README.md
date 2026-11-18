# 北欧神话角色与建筑首版

本批新增 23 件，精细模型总清单累计 37 件。全部待人工审批，保留前 14 件与原版、深暗版。

## 角色与武器

- 剑士·暗红披肩，独立护具、链甲、披肩、手指、佩挂刀鞘与持剑；20 骨骼，7 个动作。
- 尸鬼、冬狼、冰霜精魂，分别提供骨骼、蒙皮与 5 个动作。
- 斯库尔·蚀日巨狼，独立体型、颈部护具与鬃毛细节，7 个动作。
- 独立长剑和佩挂刀鞘各一件。

角色为造型、比例与动作首版。没有把技术检查当成人工美术验收。布料和毛发没有物理模拟，战斗判定、动画状态机、脚底接触和实际游戏镜头仍需接入与审核。

## 神话建筑

奥丁渡鸦神殿门廊、世界树盘根祭坛、诺伦命运之井、彩虹桥符光桥段、彩虹桥守望门柱、英灵殿列盾墙段、托尔雷锤祭坛、斯卡蒂猎誓祭坛、赫尔冥界界门、誓约供奉台。

建筑围绕神话意象原创设计，并对应入口、通路、神恩、事件和边界等关卡用途。不是历史建筑复原。设计背景参考世界树与命运之井等北欧神话意象；参考文献链接见 records/design-sources.json。

## 自然环境与设施

积雪岩群、风折枯树、石垒墓丘、3.2 米木桩码头段、盘绳系船桩、石圈营火。供边界、掩体、主题房间与安全补给房使用。营火为静态余烬；没有火焰或烟雾模拟。

## 文件与审批

- 每件 `.blend` 保留分件、打包材质；角色保留骨骼、蒙皮、命名动作与 NLA 记录。
- 游戏 GLB 位于 `../../models/midgard/quality/`。本批运行时贴图上限为 1024 像素，母版保留原始材质图。部分纯色材质无贴图。
- `manifest.json` 包含全部 37 件；`current_batch` 标记本批 23 件。
- `room_assembly.blend` 与 `previews/room_assembly.png` 为神话建筑展示场景。
- `environment_assembly.blend` 与 `previews/environment_assembly.png` 为自然环境和设施组合场景。
- `actors_assembly.blend` 与 `previews/actors_assembly.png` 为角色并排评审场景。
- `../../../docs/芬布尔之冬模型清单/启动模型审核.command` 可启动本地审批文档。也可使用工具目录的 serve_review.py。

文档支持旋转、缩放、正侧背视角、网格、动作切换与进度定位，支持上一件/下一件和本批筛选。审批结果与意见存于当前浏览器，导出 JSON 包含所有画风；可导入恢复，较新的本地意见保留。模型版本变化后，旧审核意见继续保留并提示复核。直接打开 HTML 时可看图片和填写意见，三维预览需要启动本地查看服务。

## 来源

石材、旧木、锈铁复用已登记的 Poly Haven CC0 材质。角色织物、皮革、钢材与毛皮的纹理由本批脚本本地生成。所有模型几何为程序建模；未下载第三方角色、建筑或动作。Three.js（MIT）用于本地预览，esbuild（MIT）用于打包；版本锁定于 tools/asset_review/package-lock.json，预览无需 CDN。

## 重建

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_mythic_production_2026-11-15/build_mythic.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_mythic_production_2026-11-15/build_actors.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_mythic_production_2026-11-15/build_environment.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_mythic_production_2026-11-15/assemble_gallery.py -- mythic
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_mythic_production_2026-11-15/assemble_gallery.py -- actors
/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/source/task3d_mythic_production_2026-11-15/assemble_gallery.py -- environment
python3 assets/source/task3d_mythic_production_2026-11-15/finalize_catalog.py
npm ci --prefix tools/asset_review
npm run build --prefix tools/asset_review
python3 tools/asset_review/serve_review.py
```
