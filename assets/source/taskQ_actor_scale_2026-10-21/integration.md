# 接入

已完成代码接入，无需人工复制素材。

| 文件 | 改动 |
| --- | --- |
| scripts/entities/sprite_visual.gd | ACTOR_SCALE = 1.1，放在加载器常量中，由角色显式使用 |
| scripts/entities/player.gd | 创建精灵后乘以 1.1；同步 base_scale；设置 nearest |
| scripts/entities/enemy.gd | 现有精英额外比例之后乘以 1.1；同步 base_scale；排除 Boss 与 still |

不改 Node2D 根缩放、碰撞圆、半径、速度、血量、武器或攻击距离。保留原脚底锚点和 base_pos，动画仍从更新后的 base_scale 取值。第三关自定义 foot 的重新锚定在其已有子类完成，专项以实际脚底坐标验证，而非强制比较精灵节点原点。

独立测试副本使用隔离的 custom_user_dir，并传入独立 save-file/settings-file；生产存档未被这些测试改写。runtime 为整个当前工作区副本；publish_runtime 为此次 Git 暂存内容的可运行副本。assets 链接到项目已有素材，脚本输入哈希在 records/。

运行命令（把 ROOT 换成独立副本绝对路径，把 OUT 换成结果绝对路径）：

```sh
godot --headless --path ROOT --script tools/test_actor_scale.gd -- --save-file=user://scale.json --settings-file=user://scale.cfg --output=OUT
godot --headless --path ROOT --script tools/test_combat_regressions.gd -- --save-file=user://combat.json --settings-file=user://combat.cfg
godot --headless --path ROOT --script tools/test_vigrid.gd -- --save-file=user://vigrid.json --settings-file=user://vigrid.cfg
```

第三关专项仅用于 runtime；publish_runtime 的 HEAD 基线尚未包含第三关代码，因此专项按实际建成的关卡枚举角色。工具 review_actor_scale.gd 可在有显示窗口的独立副本运行，传入 output 目录，输出同场景对照。

剩余：本次没有重跑完整正常难度通关、手柄、窗口失焦或长时性能测试。nearest 下 1.1 倍缩放是有意的非整数缩放，存在像素宽度不完全均匀的特征；实机对照已检查可读性，没有重新采样改写原图。
