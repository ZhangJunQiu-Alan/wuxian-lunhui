# 第三关独立验收与修复接入

本批直接修复工作区代码，不需要另行复制素材。未修改 project.godot、场景或个人存档；没有提交或推送 Git。所有测试保存路径在本目录。

## 已接入修复

| 文件 | 行为 |
|---|---|
| scripts/game.gd | 出生先限界并避开障碍；角落寻找合法出生距离；Boss 重复死亡回调只结算一次 |
| scripts/world/map_layer.gd | 连续障碍最多16轮推离，避免被另一障碍推回原处 |
| scripts/bosses/surtr.gd | 安全格按预警及燃烧期间火墙的预计收缩半径筛选；火墙边缘容差 |
| scripts/bosses/fenrir.gd | 碎片释放后可补充；过滤失效引用时不先进行对象类型转换 |
| scripts/ui/level_up_panel.gd | 说明较长时自动上移卡牌文字区，保证底栏在卡牌内 |
| scripts/entities/xp_gem.gd | 未吸附经验在64像素单元内合并，保留总经验及大宝石标记，不远程发放经验 |
| scripts/entities/sprite_visual.gd | 共享动作 SpriteFrames，保留每个角色独立播放状态 |
| scripts/entities/enemy.gd | 空间索引修订号用于缓存失效；符文状态最多画3个点，实际层数独立 |
| scripts/gods/thor.gd | 死亡电网的可见连线也受80条上限约束，伤害及40目标上限保留 |
| scripts/gods/odin.gd | 阵伤与印记跨重叠阵每敌人每秒一次；觉醒传播同样每秒一次；共享查询并跳过已处理传播对象 |
| scripts/gods/baldr.gd | 白昼改为3秒发射/4秒冷却（最短1.5秒），隐藏时角度继续转动，停火同时停止光柱和所属余辉伤害 |
| scripts/effects/fx_layer.gd | 可见冲击环上限24；奥丁调用使用半径48和0.45透明度，Boss原有判伤范围保留 |
| scripts/gods/skadi.gd | 永冬单跳倍率0.30→0.15，周期0.50→0.75秒，最短周期0.45秒；每跳1霜冻；近距离重复冰面刷新而不叠加 |
| scripts/data/upgrade_db.gd、locale/text.csv | 永冬与九夜符文的中英文说明同步 |

## 接入与验收边界

- baseline.json 记录进入任务时已有的 Claude 代码和其他代理修改；本批不宣称拥有整份 Git diff。
- M 美术代理同时更新地图/援助/剑弧，最新截图可包含其资源，不把这些素材列为本批制作。
- 实际无敌通关、强制状态检查、伤害点测、加速逻辑、压力测试分别保留；无敌测试不代表自然通关。
- 静音通过 Master 总线实施，保留真实音频流和声道池；没有进行听觉验收。
- 完整旧进程运行期间发生的后续代码变更不能追认为旧进程已加载。最终专项和回归按各自日志日期记录。
