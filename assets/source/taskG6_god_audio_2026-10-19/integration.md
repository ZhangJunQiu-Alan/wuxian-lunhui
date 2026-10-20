# G6 音效接入交接（2026-10-19）

## 文件交付

30种、44条已通过用户听感确认的v02 WAV已在 `assets/audio/sfx/`。本轮复核已有交付，不重新制作、复制或覆盖音频；H/I及J/K/L不在本轮范围。当前任务书中G6正式文件尚未出现的描述与本次磁盘核查不一致，本交接记录实际文件状态，不修改任务书。

原始浏览器导出、CC0输入、候选、首轮退回稿、approved、参数与来源继续保留在本目录。每条输入的作者、页面、许可、SHA256见 `manifest.json` 的 `sources` / `files[].source_records`；商用记录见 `assets/LICENSES.md` 的G6条目。本轮未新增来源或外部工具使用。

## 自检结果

- 本轮重新测量44条正式WAV：PCM16位、单声道、44100Hz；峰值−1dBFS容差0.01；−60dBFS阈值起音≤10ms；首尾样本0；无满幅样本；最后10ms RMS≤−45dBFS。
- 正式文件、approved、候选和用户接受记录的44个SHA256全部一致；83个输入来源哈希一致。7组各3条变体的文件名集合准确、哈希互异、时长≤0.3秒。既有组内响度测量仍绑定相同文件，详见 `records/audio_audit.json`。
- 44份已有Godot导入描述及44个所指向的缓存文件均存在；描述中关闭循环及归一化。本轮只读取这些文件，未创建或修改导入设置；缓存存在不等于已用引擎验证加载。
- 听感依据仍是用户此前对全套44条及七组一分钟连播的明确答复，见 `records/listening_acceptance.json`。本轮未再次试听，未把数据检查视为亲自听辨。
- 复跑入口：`python3 assets/source/taskG6_god_audio_2026-10-19/records/audit_integration.py`。本轮结果为 `records/integration_audit_2026-10-19.json`。

## 所需代码接入

当前源代码已具备全部30种调用入口：26个神术/拾取事件直接传入音效名，4个奖励提示在 `scripts/game.gd::_open_reward()` 根据 `entry.kind` 构造名称。按当前代码和目录合同，没有需要追加的音效调用或更名；本轮未修改代码。下表逐文件绑定现有函数、行号和播放参数，行号为本次源码快照，源码SHA256见审计记录。

### 通用加载与替换合同

- 入口为 `Audio.sfx_or(sound, fallback, volume_db, pitch)`，加载器 `scripts/core/audio.gd::_find()` 在 `res://assets/audio/sfx/` 先查WAV，再查OGG；同一音效收集无后缀及 `_01`、`_02`、`_03` 文件，`_play_sfx()` 随机选择其中一个。不要把带编号的单条变体名传作基础音效名，也不要再添加重复的同名基础WAV。
- 新文件存在时替代对应fallback声音；fallback为空时，文件缺失不会发出该声音。表中fallback只是现有缺文件回退，不表示仍需同时播放旧声音。
- 所有文件为一次性音效，当前导入描述 `edit/loop_mode=0`。使用现有全局 `SFX` 总线及声音池，不建立新的空间声源。坐标原点、锚点、旋转、缩放、帧率、alpha和遮罩对本批音频不适用。
- 现有池24个声音、同名最多4个、同名触发最短间隔0.05秒；代码已有这些限制，本批不改变战斗冷却、伤害、AI或声音池。
- `_find()` 缓存命名查询结果，包括缺文件结果。若游戏在放入音效前已启动，需结束该次运行并重新启动，使新音频进入首次查找；不要把旧实例的静音误判为文件缺失。现有导入缓存仅作静态证据，实际导入成功与播放仍交游戏接入代理核验。
- 下表dB和pitch为代码现值，不代表已在游戏混音中验收。pitch为默认±范围，`heal_pickup`沿用±0.30，其余±0.06。

### 44条正式文件映射

正式目录前缀统一为 `res://assets/audio/sfx/`。完整文件哈希、来源和本轮测量见manifest与审计JSON。

| 文件 | 用途 / 基础音效名 | 现有脚本::函数（行） | fallback | dB | pitch± |
|---|---|---|---|---:|---:|
| `god_choose.wav` | 弹出「选择一位神」 / `god_choose`，kind=god | `scripts/game.gd::_open_reward()` (474) | `level_up` | 0 | 0.06 |
| `path_choose.wav` | 弹出「选择一条道路」（质变） / `path_choose`，kind=path | `scripts/game.gd::_open_reward()` (474) | `level_up` | 0 | 0.06 |
| `awaken.wav` | 弹出「神之觉醒」：1.5 秒左右，庄严、有力 / `awaken`，kind=awaken | `scripts/game.gd::_open_reward()` (476) | `level_up` | 0 | 0.06 |
| `fusion.wav` | 弹出「融合技」：两种力量合在一起的感觉 / `fusion`，kind=fusion | `scripts/game.gd::_open_reward()` (476) | `level_up` | 0 | 0.06 |
| `hammer_throw.wav` | 托尔掷出战锤（呼啸） / `hammer_throw` | `scripts/gods/thor.gd::_throw_hammers()` (160) | `dash` | -4 | 0.06 |
| `hammer_catch.wav` | 战锤飞回手里 / `hammer_catch` | `scripts/gods/thor.gd::_hammer_returned()` (167) | ``（空） | -6 | 0.06 |
| `static_zap_01.wav` | 静电场的电网互相电击（很轻的噼啪声） / `static_zap` | `scripts/gods/thor.gd::_tick_static()` (207) | ``（空） | -8 | 0.06 |
| `static_zap_02.wav` | 静电场的电网互相电击（很轻的噼啪声） / `static_zap` | `scripts/gods/thor.gd::_tick_static()` (207) | ``（空） | -8 | 0.06 |
| `static_zap_03.wav` | 静电场的电网互相电击（很轻的噼啪声） / `static_zap` | `scripts/gods/thor.gd::_tick_static()` (207) | ``（空） | -8 | 0.06 |
| `spear_throw.wav` | 奥丁掷出长枪 / `spear_throw` | `scripts/gods/odin.gd::_throw_spears()` (78) | `rune_bolt` | 2 | 0.06 |
| `rune_detonate_01.wav` | 符文印记引爆 / `rune_detonate` | `scripts/gods/odin.gd::detonate()` (151) | ``（空） | -6 | 0.06 |
| `rune_detonate_02.wav` | 符文印记引爆 / `rune_detonate` | `scripts/gods/odin.gd::detonate()` (151) | ``（空） | -6 | 0.06 |
| `rune_detonate_03.wav` | 符文印记引爆 / `rune_detonate` | `scripts/gods/odin.gd::detonate()` (151) | ``（空） | -6 | 0.06 |
| `raven_dive.wav` | 渡鸦俯冲（短促的鸦鸣或振翅） / `raven_dive` | `scripts/gods/odin.gd::_tick_ravens()` (222) | ``（空） | -6 | 0.06 |
| `wolf_bite_01.wav` | 火焰幼狼咬人 / `wolf_bite` | `scripts/gods/loki.gd::_tick_wolf()` (130) | `fire_burn` | -4 | 0.06 |
| `wolf_bite_02.wav` | 火焰幼狼咬人 / `wolf_bite` | `scripts/gods/loki.gd::_tick_wolf()` (130) | `fire_burn` | -4 | 0.06 |
| `wolf_bite_03.wav` | 火焰幼狼咬人 / `wolf_bite` | `scripts/gods/loki.gd::_tick_wolf()` (130) | `fire_burn` | -4 | 0.06 |
| `wolf_breath.wav` | 巨狼喷火 / `wolf_breath` | `scripts/gods/loki.gd::_tick_wolf()` (145) | `fire_burn` | 2 | 0.06 |
| `decoy_spawn.wav` | 洛基留下火焰分身 / `decoy_spawn` | `scripts/gods/loki.gd::_spawn_decoy()` (177) | `fire_burn` | 0 | 0.06 |
| `feather_launch.wav` | 弗蕾亚的羽刃一齐射出 / `feather_launch` | `scripts/gods/freyja.gd::_tick_hawk()` (145) | `feather_hit` | 0 | 0.06 |
| `cat_pounce_01.wav` | 战猫扑击 / `cat_pounce` | `scripts/gods/freyja.gd::_tick_cats()` (239) | `feather_hit` | -4 | 0.06 |
| `cat_pounce_02.wav` | 战猫扑击 / `cat_pounce` | `scripts/gods/freyja.gd::_tick_cats()` (239) | `feather_hit` | -4 | 0.06 |
| `cat_pounce_03.wav` | 战猫扑击 / `cat_pounce` | `scripts/gods/freyja.gd::_tick_cats()` (239) | `feather_hit` | -4 | 0.06 |
| `chariot_charge.wav` | 猫车冲过屏幕 / `chariot_charge` | `scripts/gods/freyja.gd::_tick_chariot()` (253) | `dash` | 2 | 0.06 |
| `light_beam.wav` | 巴德尔射出光束（明亮、干净） / `light_beam` | `scripts/gods/baldr.gd::tick()` (76) | `rune_bolt` | -2 | 0.06 |
| `light_spear.wav` | 光矛掷出 / `light_spear` | `scripts/gods/baldr.gd::tick()` (64) | `rune_bolt` | 2 | 0.06 |
| `light_burst_01.wav` | 带光痕的敌人死亡时爆出一圈光（很轻） / `light_burst` | `scripts/gods/baldr.gd::_light_burst()` (156) | ``（空） | -10 | 0.06 |
| `light_burst_02.wav` | 带光痕的敌人死亡时爆出一圈光（很轻） / `light_burst` | `scripts/gods/baldr.gd::_light_burst()` (156) | ``（空） | -10 | 0.06 |
| `light_burst_03.wav` | 带光痕的敌人死亡时爆出一圈光（很轻） / `light_burst` | `scripts/gods/baldr.gd::_light_burst()` (156) | ``（空） | -10 | 0.06 |
| `light_flash.wav` | 每 30 秒的全屏闪光 / `light_flash` | `scripts/gods/baldr.gd::tick()` (87) | `level_up` | 0 | 0.06 |
| `net_throw.wav` | 澜抛出渔网 / `net_throw` | `scripts/gods/ran.gd::_throw_nets()` (74) | `dash` | -6 | 0.06 |
| `net_close.wav` | 收网（绳子收紧、水声） / `net_close` | `scripts/gods/ran.gd::_close()` (103) | ``（空） | -4 | 0.06 |
| `wave_push.wav` | 推出巨浪 / `wave_push` | `scripts/gods/ran.gd::_push_waves()` (173) | `dash` | -2 | 0.06 |
| `wave_crash.wav` | 浪拍下来 / `wave_crash` | `scripts/gods/ran.gd::_crash()` (200) | `boss_slam` | -6 | 0.06 |
| `sword_hit_01.wav` | 弗雷的飞剑砍中敌人 / `sword_hit` | `scripts/gods/freyr.gd::strike()` (102) | `feather_hit` | -8 | 0.06 |
| `sword_hit_02.wav` | 弗雷的飞剑砍中敌人 / `sword_hit` | `scripts/gods/freyr.gd::strike()` (102) | `feather_hit` | -8 | 0.06 |
| `sword_hit_03.wav` | 弗雷的飞剑砍中敌人 / `sword_hit` | `scripts/gods/freyr.gd::strike()` (102) | `feather_hit` | -8 | 0.06 |
| `boar_charge.wav` | 野猪冲锋（蹄声、哼叫） / `boar_charge` | `scripts/gods/freyr.gd::_tick_boars()` (135) | `dash` | -2 | 0.06 |
| `ice_arrow_01.wav` | 斯卡蒂射出冰箭 / `ice_arrow` | `scripts/gods/skadi.gd::_volley()` (69) | `arrow_shot` | -4 | 0.06 |
| `ice_arrow_02.wav` | 斯卡蒂射出冰箭 / `ice_arrow` | `scripts/gods/skadi.gd::_volley()` (69) | `arrow_shot` | -4 | 0.06 |
| `ice_arrow_03.wav` | 斯卡蒂射出冰箭 / `ice_arrow` | `scripts/gods/skadi.gd::_volley()` (69) | `arrow_shot` | -4 | 0.06 |
| `ice_snipe.wav` | 蓄力狙击的一箭 / `ice_snipe` | `scripts/gods/skadi.gd::_tick_hunter()` (133) | `arrow_shot` | 2 | 0.06 |
| `ice_shatter.wav` | 冻结的敌人碎成冰片 / `ice_shatter` | `scripts/gods/skadi.gd::on_enemy_died()` (112) | `ice_pillar` | -6 | 0.06 |
| `heal_pickup.wav` | 捡起金羽、金泪、苹果 / `heal_pickup` | `scripts/gods/heal_pickup.gd::_process()` (32) | `pickup_xp` | -4 | 0.3 |

## 剩余问题与游戏验收

本轮没有实际运行Godot或游戏，不标记代码运行验收、游戏听感、混音或通关通过。现阶段完成的是素材正式目录落盘、静态调用核对和交接。

接入代理需要在新启动的实际游戏实例中确认：

1. 四种奖励面板在暂停状态下分别触发选神、质变、觉醒、融合提示；按钮选择仍沿用原有card_pick，避免把提示音重复加在按钮回调。
2. 八位神的全部26个技能/拾取声音在对应事件实际响起；七组高频变体被随机加载，未意外播放旧fallback。
3. 在现有SFX音量设置下检查密集战斗、同名限流、总声音池及混音尾音。`spear_throw`、`wolf_breath`、`chariot_charge`、`light_spear`、`ice_snipe`现有调用为+2dB，素材峰值−1dBFS；在总线实际增益及多声音叠加下是否削波需实测，本次没有改动这些参数。
4. 确认打包/导出后资源可加载，停止或切换场景时声音行为符合现有游戏设计。

若后续听感或运行检查发现问题，按具体文件与事件退回处理；保留本批已接受原件及记录。本轮未改脚本、场景、docs、project.godot或导入设置，未执行Git提交或推送。
