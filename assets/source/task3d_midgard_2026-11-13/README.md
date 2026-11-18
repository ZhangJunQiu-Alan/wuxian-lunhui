# 米德加尔特 3D 素材第一批

首件评审样品为雪村长屋。造型来自本项目的芬布尔之冬地图设定。参考《I Am Machine》的斜俯视构图、场地轮廓和信息层级。

| 制作顺序 | 资产 | 制作方法 |
| --- | --- | --- |
| 1 | 长屋、断栅栏、火盆、松树、岩石 | 模块化低模，按试玩镜头配色和校验体积。长屋先完成样品 |
| 2 | 奥丁祭坛和立石、冰湖边缘、雪地及冻土 | 地标分别建模；雪、冻土与冰用可平铺材质，裂纹、脚印和积雪变化用贴花或独立小网格 |
| 3 | 剑士和太刀、尸鬼、冬狼、冰霜精魂、斯库尔 | 项目设定做三视图，制作低模并绑定骨架。人形可共用基础骨架，狼类单独绑定。武器单独建模并挂到手部 |
| 4 | 刀光、冰弹、落雷、Boss 冲锋预警 | 在 Godot 做，范围提示沿用战斗判定参数，使用实际镜头检查可读性 |

场景模型以接地中心作为原点，Y 轴朝上。角色模型保留脚底原点，骨骼动画原地播放，由现有战斗逻辑驱动位移。第一轮角色动作包括待机、移动、攻击、闪避、受击和倒地。敌人还需要能看清的蓄力动作。角色精确比例以原型镜头的走位测试为准。

静态资产交付 GLB 和可复现源文件。有骨骼的模型计划使用 Blender 保存可编辑母版，再导出 GLB。运行时场景和碰撞由 Godot 管理。

长屋由本地 Python 脚本生成，模型包含木板、瓦片、积雪、石基和窗光。无外部素材。运行 `python3 assets/source/task3d_midgard_2026-11-13/build_longhouse.py` 可重建模型。现阶段为样品评审。

细化版增加错缝双层石基、山墙斜撑、倒角木梁、七排搭接瓦片、厚薄不均的积雪、窗扇和门窗铁件。近景与试玩镜头均在 Godot Compatibility 渲染器下检查。

## Blender 材质评审版

`midgard_longhouse_material.blend` 保留可编辑网格、八个材质、打包的颜色与法线贴图，以及近景渲染灯光。贴图由本地脚本绘制。沿木板方向铺木纹，屋瓦和石基使用各自的纹理，积雪用冷色明暗和细小法线表现表面起伏。游戏模型为 `assets/models/midgard/midgard_longhouse_material.glb`，包含同一网格和两张内嵌贴图。

使用 Blender 5.3 从仓库根目录运行：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python assets/source/task3d_midgard_2026-11-13/refine_longhouse_blender.py
```

`previews/midgard-longhouse-material-detail.png` 是 Blender 近景。`previews/midgard-longhouse-material-in-game.png` 是 Godot Compatibility 下三个模型实例的试玩镜头。实机图为试摆预览。
