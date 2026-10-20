# H0 代码接入交接（未执行）

素材放入目录不等于接入；此文件是逐项交接，未改任何游戏代码。坐标从单帧左上角起算，+X向右、+Y向下；默认旋转0指向右，正角为顺时针。中心锚点与脚底点请用源像素坐标减去后再旋转/缩放。

## thokk.png

- 正式路径：`assets/sprites/enemies/thokk.png`；SHA256 `09eacf76a01cbb38177da6174e85247b02a290b1d6f2e6f01e4692337738e64b`。
- 单帧：96×96；横向1帧，无间隔；0fps；单次（播完释放临时节点；单张除外）。
- 锚点：[48, 92]，源像素；方向和透明要求按 manifest，避免使用整张帧条尺寸计算锚点。
- 目标脚本／函数：scripts/data/enemy_db.gd thokk；scripts/entities/enemy.gd _ready() / SpriteVisual.create_actions()。
- 替换与保持：保留既有半径20、血量、精英倍率、追击及逃走逻辑。
- 层级／缩放／遮罩：区域效果放人物下方，接触闪光短播放人物附近；按实际判定范围裁切，不能扩大伤害暗示。曲线与圆弧条段用独立网格/节段排布，禁止整个帧条直接当单图。保留原预警几何和伤害逻辑；替换对应旧重复视觉，资源缺失保留回退。
- 后续验收：真实视角逐帧核对朝向/锚点/遮挡/范围、状态结束释放、多人同屏节点数。代码接入未执行；游戏验收未执行。

## thokk_move.png

- 正式路径：`assets/sprites/enemies/thokk_move.png`；SHA256 `2c4b9a998f653da414009ffff2eb7cb1f6a0efef81fbc303eedc16a3e3242a79`。
- 单帧：96×96；横向6帧，无间隔；8fps；循环（状态结束立即停止）。
- 锚点：[48, 92]，源像素；方向和透明要求按 manifest，避免使用整张帧条尺寸计算锚点。
- 目标脚本／函数：scripts/entities/enemy.gd _ready() / _physics_process()；SpriteVisual.create_actions()。
- 替换与保持：保留同一角色比例、脚底92与移动速度。
- 层级／缩放／遮罩：区域效果放人物下方，接触闪光短播放人物附近；按实际判定范围裁切，不能扩大伤害暗示。曲线与圆弧条段用独立网格/节段排布，禁止整个帧条直接当单图。保留原预警几何和伤害逻辑；替换对应旧重复视觉，资源缺失保留回退。
- 后续验收：真实视角逐帧核对朝向/锚点/遮挡/范围、状态结束释放、多人同屏节点数。代码接入未执行；游戏验收未执行。

## thokk_attack.png

- 正式路径：`assets/sprites/enemies/thokk_attack.png`；SHA256 `cc7b7364e7dcc4f542d3bb902635ff07b53bb06bf829aee920aab2960ca3dbef`。
- 单帧：96×96；横向4帧，无间隔；16fps；单次（播完释放临时节点；单张除外）。
- 锚点：[48, 92]，源像素；方向和透明要求按 manifest，避免使用整张帧条尺寸计算锚点。
- 目标脚本／函数：scripts/entities/enemy.gd _update_attack() / SpriteVisual.create_actions()。
- 替换与保持：保留ATTACK_TIME、ATTACK_STRIKE、接触判伤和现有挥击光效。
- 层级／缩放／遮罩：区域效果放人物下方，接触闪光短播放人物附近；按实际判定范围裁切，不能扩大伤害暗示。曲线与圆弧条段用独立网格/节段排布，禁止整个帧条直接当单图。保留原预警几何和伤害逻辑；替换对应旧重复视觉，资源缺失保留回退。
- 后续验收：真实视角逐帧核对朝向/锚点/遮挡/范围、状态结束释放、多人同屏节点数。代码接入未执行；游戏验收未执行。

## hel_death_bolt.png

- 正式路径：`assets/sprites/effects/hel_death_bolt.png`；SHA256 `e4abc7d80a6feedabb4499611b9c900fa79e240967311fa7f623ddcdc54f58c6`。
- 单帧：32×16；横向1帧，无间隔；0fps；单次（播完释放临时节点；单张除外）。
- 锚点：[16, 8]，源像素；方向和透明要求按 manifest，避免使用整张帧条尺寸计算锚点。
- 目标脚本／函数：scripts/bosses/hel.gd _update_state() cast_windup 中 _fan() 的 texture=null。
- 替换与保持：替换第一阶段空纹理；保持5发、spread0.5、伤害10、速度200、命中半径；第二阶段_nail不变。
- 层级／缩放／遮罩：区域效果放人物下方，接触闪光短播放人物附近；按实际判定范围裁切，不能扩大伤害暗示。曲线与圆弧条段用独立网格/节段排布，禁止整个帧条直接当单图。保留原预警几何和伤害逻辑；替换对应旧重复视觉，资源缺失保留回退。
- 后续验收：真实视角逐帧核对朝向/锚点/遮挡/范围、状态结束释放、多人同屏节点数。代码接入未执行；游戏验收未执行。

## 显示尺度待确认

`Enemy._ready()` 传入的height=52只是期望值；`SpriteVisual` 的maxf(1, round(height/tex_height))使96px画布至少1倍显示。隔离副本实测普通scale1、精英scale1.2；此前“实际显示52px、需要专用高度”的建议有误，撤回。碰撞radius20、血量、速度、精英逻辑、逃跑与攻击判伤不改。`SpriteVisual` 现有move/attack自动加载可用；攻击逻辑实际函数名为 `_update_attack()`。
