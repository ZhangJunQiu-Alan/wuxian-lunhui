# 实测结果

| 测试环境 / 套件 | 结果 | 日志 |
| --- | --- | --- |
| 当前工作区 / 全角色尺寸专项 | 408 项，0 失败 | logs/current_final.log |
| 当前工作区 / 战斗回归 | 997 项，0 失败 | logs/combat.log |
| 当前工作区 / 第三关回归 | 368 项，0 失败 | logs/vigrid.log |
| 独立提交内容 / 尺寸专项 | 342 项，0 失败 | logs/publish_actor.log |
| 独立提交内容 / 战斗回归 | 997 项，0 失败 | logs/publish_combat.log |

以上最终日志均无 ERROR、WARNING、SCRIPT ERROR 或退出泄漏。尺寸专项覆盖四个角色、敌人数据库各条目及其精英形式，检查 1.1 比例、静态物件豁免、Boss 豁免、动画基准比例、实际脚底、碰撞圆与基础属性。当前工作区有第三关三类敌人和九个 Boss；独立提交版本有原先两关敌人和六个 Boss。角色动作帧选择逐一检查；没有将它描述为逐帧肉眼审完所有动作。

Godot 实际窗口捕获：四名角色和六个怪物实例，同位置、同 atlas 帧，切换唯一的 1.1 因子。已检查全图及四组局部对照：脚底位置、长宽比例、像素边缘、角色和怪物可读性。visual.log 的两次 CAPTURE 为 0；macOS 的 IMK mach-port 提示不属于 Godot 资源泄漏。

失败尝试完整保留：

1. current.log/current_attempt1：测试使用严格浮点比较、忽略漂浮的基础 bob、未模拟第三关自定义 foot，且 Garm 缺 spawner，造成 30 项失败；修正测试模型。
2. test_parse_attempt2：局部变量 height 重复，修正命名。
3. current_attempt3：参考精灵助手对 Boss 错用 EnemyDB 下标，改用 get 默认值；当时中止的参考精灵留下泄漏。
4. current_verbose.log.gz：408 项已通过，但 Hel 暗场、Fenrir 碎片等延迟添加尚未执行就销毁场景，留下 12 个实例；测试销毁前等待一帧，最终 current_final 已无泄漏。

这些修正均在测试工具中完成，没有为使断言通过而修改战斗生产逻辑。

不标记：真人正常通关、完整游戏验收、第三关整体发布。其他代理未提交代码仍留在原工作区。
