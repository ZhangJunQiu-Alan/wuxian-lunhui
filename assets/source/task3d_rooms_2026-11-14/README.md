# 芬布尔之冬房间模型批次

2026-11-14 制作八件原创模块，以项目的北欧雪地、旧木、黑石与暖色符文为基础。材质图由项目既有本地材质生成脚本绘制，模型通过 Blender Python API 建造。每件包含可编辑 Blender 母版、GLB 和预览图。尺寸以米记录，Blender Z 向上，GLB 与 Godot Y 向上。

| ID | 内容 | 活动部件 |
| --- | --- | --- |
| snow_floor | 3 米积雪石板地块 | 静态 |
| void_causeway | 断台、中央空洞与窄石桥 | VoidVolume 标记 |
| spike_trap | 九根地刺与金属框架 | SpikeCarrier，GLB spike_cycle，Godot spike 循环 |
| rune_trap | 符文喷发陷阱 | BlastOrigin 标记 |
| pressure_plate | 外框与可下压踏板 | MovingPlate，press 动画 |
| rune_gate | 石柱、木闸、奖励徽记 | GateMoving，open 动画，ExitAnchor 标记 |
| lever | 石座、转轴与木柄 | HandlePivot，activate 动画 |
| brazier | 支脚、火盆与燃炭 | FireOrigin 标记 |

网页清单位于 docs/芬布尔之冬模型清单/index.html，收录此前长屋与本批模型，共九件。审核选项和备注保存在当前浏览器，可导出 JSON。制作清单和 SHA-256 见本目录 manifest.json、records/。

组合样例 room_assembly.blend 是静态布局评审场景。中央虚空与桥提供直线路线，两侧留出绕行，地刺和拉杆分居两侧。通过调整这些模块的位置可形成房间变体。房间地形和机关关联由关卡设计配置。

运行方式

    /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python assets/source/task3d_rooms_2026-11-14/build_room_assets.py
    /Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python assets/source/task3d_rooms_2026-11-14/assemble_review_room.py

第一个脚本在 -- 后可跟单件 ID，仅重建指定模型。GLB 导出独立活动部件和动画。Godot 会把带 _cycle 后缀的地刺动画导入为 spike 循环。

本批交付建模与动画。陷阱伤害、触发器碰撞、坠落处理、奖励标识替换和联动逻辑需要在游戏中接入。
