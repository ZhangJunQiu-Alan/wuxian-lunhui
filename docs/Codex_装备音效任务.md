# Codex 任务：装备音效（S-SFX-01）

2026-11-19 从原「装备系统美术任务」里拆出来。像素素材任务已全部作废，音效不受影响，可以开工。装备系统设计见 [装备系统 · 已确认](装备系统_已确认.md)。

## 音效清单

放在 `assets/audio/sfx/`，单声道、44.1 kHz、16 位 WAV，和现有音效一致。响度对齐现有的 `pickup_xp`、`heal_pickup`。

| 文件 | 什么时候播 | 要求 |
| --- | --- | --- |
| `gear_drop_common.wav` | 普通装备落地 | 轻「叮」，很短 |
| `gear_drop_rare.wav` | 稀有装备落地 | 清脆 |
| `gear_drop_epic.wav` | 史诗装备落地 | 低沉的钟声 |
| `gear_drop_legendary.wav` | 传说装备落地 | 号角 |
| `gear_drop_artifact.wav` | 神器落地 | 专属，最隆重，约 1.5 秒以内 |
| `gold_pickup.wav` | 捡金币 | 短，连续捡很多次也不吵 |
| `enhance_success.wav` | 强化成功 | 锻打加上扬的收尾 |
| `enhance_fail.wav` | 强化失败 | 闷响，不要刺耳 |
| `salvage.wav` | 分解装备 | 碎裂加一点余烬的嘶声 |
| `equip.wav` | 换装 | 金属或皮革的轻响 |

- 5 档掉落音逐级更隆重，闭着眼也能听出是哪一档。
- 和现有的 `pickup_xp`、`heal_pickup`、`chest_open` 要能分开。

## 交付

- 每个音效在游戏里实际触发听一遍，不只在播放器里听。
- 交付记录放 `assets/source/taskS_sfx_<日期>/`，规则见[美术与音频素材规范](美术素材规范.md)「交付规则」。
- 新来源先确认可商用，记进 `assets/LICENSES.md`。
