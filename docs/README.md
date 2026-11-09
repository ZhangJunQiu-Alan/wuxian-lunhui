# 文档入口

游戏名「诸界余烬」，Godot 4 / GDScript，Mac 开发、导出 Windows。三关（北欧篇章）、四个角色、八位神都已做完。

| 想看什么 | 文档 |
| --- | --- |
| 还要做什么 | [待办](待办.md) |
| 世界、剧情、Boss | [世界观设定](世界观设定.md)、小说[《第零号展品》](小说_第零号展品.md) |
| 四个角色和大招 | [角色设定](角色设定.md) |
| 等级、经验、关卡节奏、八神、融合技 | [局内成长与信仰](局内成长与信仰.md) |
| 三关地图 | [地图设计](地图设计.md) |
| 全部内容一张图 | [游戏思维导图](游戏思维导图/诸界余烬_交互思维导图.html) |
| 装备系统 | [设计稿](https://claude.ai/artifact/9RVzroeDyBuYErDCYNThLt)（武器、套装、词头、词缀），[草案](装备系统草案/index.html)（整体框架） |
| 素材格式和交付规则 | [美术素材规范](美术素材规范.md) |
| 给 Codex 的任务 | [剑士武器](Codex_剑士武器美术任务.md)、[装备系统其他素材](Codex_装备系统美术任务.md) |

数值以代码为准；文档和代码不一致时改文档。

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
scripts/world/         三关地图、第三关战场事件
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
