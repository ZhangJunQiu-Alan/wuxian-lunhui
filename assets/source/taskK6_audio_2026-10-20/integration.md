# K6 音频接入

正式文件：`assets/audio/music/vigrid.ogg` 与 `assets/audio/sfx/{jormungandr_hiss,fenrir_swallow,gleipnir_tension,surtr_gate}.wav`。按现有Audio文件名加载规则可读取，但目前第三关还没有玩法/数据入口，文件存在不等于触发已实现。不能覆盖G6或把boss.ogg另存充当专属新曲。

- LevelDB新增第三关时music字段用vigrid，进入战斗恢复此曲；Boss登场仍使用boss，结束且仍有Boss未死时恢复vigrid。victory/defeat复用且不循环，vigrid沿现有非ONE_SHOT曲目循环。保持Audio双播放器1秒淡入淡出，不把音效作为音乐播放。
- jormungandr_hiss：毒息实际发射首帧，一次cast一个事件；预警阶段仍用boss_windup，蛇身每帧接触不能重复嘶声。
- fenrir_swallow：逃脱窗口后吞噬提交时一次；吸引预警只用boss_windup，吞噬取消不放提交声。
- gleipnir_tension：收集后束缚实际生效时一次；拾取单独用chest_open；不是每节绳索/每帧播放。
- surtr_gate：火门实际打开时一次；火门动画循环、召唤每只巨人和维持特效不重复开启声。

`audio_events.json`保存全部25个事件的触发和去重分工：4新ID，20复用事件，1可选常驻环境声明确省略。多层事件只允许按同一个event_id执行一次；火格批量爆发不能一格一个声。沿用24声音上限、同ID最小间隔0.05s、同时同ID最多4条。四新声都为低频Boss/束缚事件，不按高频普攻添加3变体；密集群怪的旧死亡声仍需整体混音测试。周期援助继续用所属神术旧声库，不新增8套声音。

用户于本对话确认四声整套及音乐连续三遍合适；records/listening_acceptance.json绑定候选、成品和试听文件哈希。此确认只覆盖这5个新音频与所述试听，不把25个复用触发点全部标成新听感验收。特别是狼皮狂战士旧boss_howl的实际播放身份仍建议接入时比较，预留在事件清单里，不冒称它是专门的人声战吼。

还需：LevelDB第三关入口、Boss/束缚事件调用、实际游戏总线音量/动态与密集混音、暂停/失焦、Boss音乐切换和循环、结局一次性胜利音乐。此批未修改生产代码，未运行第三关。
