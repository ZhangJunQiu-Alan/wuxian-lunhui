# I1 接入记录

## bridge_guard.png

- 已接入 `scripts/quests/bridge_guard_quest.gd` 的 `_draw_quest()`。
- 世界坐标：`guard = (_zone.end.x+34, _zone.end.y+30)`，锚点 `[32, 62]`；旋转0、缩放1倍，坐标取整，最近邻继承项目设置。
- offered 静态；active 使用待机帧条；桥区与计时条原样保留。
- 非地块，不需要平铺/遮罩/碰撞。视觉大小不作为互动半径。
- 证据：本目录 previews；运行记录在 ../taskI1_bridge_guard_2026-10-19/runtime/。

## bridge_guard_idle.png

- 已接入 `scripts/quests/bridge_guard_quest.gd` 的 `_draw_quest()`。
- 世界坐标：`同 bridge_guard`，锚点 `[32, 62]`；旋转0、缩放1倍，坐标取整，最近邻继承项目设置。
- 4帧8fps循环；脚底锚点固定，无程序缩放或抖动。
- 非地块，不需要平铺/遮罩/碰撞。视觉大小不作为互动半径。
- 证据：本目录 previews；运行记录在 ../taskI1_bridge_guard_2026-10-19/runtime/。

完整手动游戏验收未执行。

受控运行完成；六份脚本的非绘制函数与开工备份完全相同。专项77项/回归997项0失败，完整手动通关未执行。无需额外代码接入；后续接入代理可审核本次差异与试玩。
