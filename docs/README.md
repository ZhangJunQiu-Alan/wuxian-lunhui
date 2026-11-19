# 文档入口

游戏名「诸界余烬」，Godot 4 / GDScript，Mac 开发、导出 Windows，目标上 Steam。斜俯视动作肉鸽，房间制（2026-11-19 起，替代原来的割草玩法）：一局连续打完北欧篇三关，每关 15 个房间。代码里还保留着旧的割草玩法，逐步替换。

| 想看什么 | 文档 |
| --- | --- |
| 游戏是什么、核心规则 | [游戏设定](游戏设定.md) |
| 还要做什么 | [待办](待办.md) |
| 世界、剧情、Boss | [世界观设定](世界观设定.md)、小说[《第零号展品》](小说_第零号展品.md) |
| 四个角色和大招 | [角色设定](角色设定.md) |
| 等级、经验、八神、融合技 | [局内成长与信仰](局内成长与信仰.md) |
| 房间、路线和 M 地图 | [地图设计](地图设计.md)、[房间图鉴](芬布尔之冬房间图鉴/index.html)（旧草案，题材可参考） |
| 美术风格 | [游戏整体美术风格](游戏整体美术风格.md) |
| 场景和角色的技术路线 | [技术细节](技术细节.md) |
| 素材格式和交付规则 | [美术与音频素材规范](美术素材规范.md) |
| 装备系统 | [设计稿](https://claude.ai/artifact/9RVzroeDyBuYErDCYNThLt)（武器、套装、词头、词缀）、[已确认](装备系统_已确认.md)、[草案](装备系统草案/index.html)（整体框架） |
| 给 Codex 的任务 | [冻石庭院](Codex_冻石庭院第四版/README.md)（已完成）、[剑士 3D 试点](Codex_剑士3D试点/README.md)、[装备音效](Codex_装备音效任务.md) |

已实现的数值以代码为准，文档和代码不一致时改文档。还没实现的房间制规则以文档为准。距离用「身位」：1 身位 = 角色身高。

## 项目结构

```text
project.godot          项目配置
scenes/                标题、主神空间（hub）、战斗（main）
scripts/core/          存档 save_data.gd、设置 settings.gd、音频 audio.gd
scripts/game.gd        战斗总控：刷怪、计时、结算
scripts/data/          数据表：角色、神明、升级卡、敌人、关卡、第三关数值
scripts/entities/      玩家、敌人、拾取物
scripts/weapons/       四个角色的基础武器
scripts/gods/          八神神术、质变、觉醒
scripts/ultimates/     四个大招
scripts/bosses/        Boss（boss.gd 是基类）
scripts/world/         三关地图（旧玩法）、第三关战场事件
scripts/roguelite/     房间制：冻石庭院
scripts/effects/       特效
scripts/ui/            界面
locale/text.csv        翻译表：第一列是中文原文
tools/                 测试脚本和小工具
assets/                素材（Git LFS），授权台账 LICENSES.md；source/ 是每批素材的制作记录
```

## 测试

用独立存档和设置，不碰正式存档；日志丢掉，避免写出巨大文件：

```sh
godot --headless --path . --log-file /dev/null --script tools/test_combat_regressions.gd -- --save-file=user://test_save.json --settings-file=user://test_settings.cfg
python3 tools/check_translations.py
```

其他专项测试在 `tools/test_*.gd`，用法相同。
