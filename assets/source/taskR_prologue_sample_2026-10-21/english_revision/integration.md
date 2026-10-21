# 当前英语音轨接入

正式文件已替换：assets/cinematics/norse/audio/下每关music/effects/narration共9个OGG；sequences.json包含12段真实时长和字幕时序。CREDITS与assets/LICENSES.md已记录来源。locale/text.csv更新已有12条英文字幕；默认中文字幕保留。

现有ChapterIntro播放器不需要代码修改。游戏运行无需Python、模型或网络，仍通过Music、SFX与Master设置控制音量。音乐让位包络已烘焙到独立music轨，暂停、失焦、跳过继续沿用原有播放器行为。

重建顺序：records/synthesize_english.py → build_english.py → 隔离工程导入 → test_chapter_intro.gd → render_english.py → check_audio.py / check_video_audio.py / build_previews.py。需要本批work/内隔离Python、已核验的权重和本机Godot/FFmpeg。旧中文脚本只供历史重建。

本轮未改scripts、scenes和project.godot；同期其他代理代码变动记录在records/concurrent_code_changes_observed.json，禁止用before快照整体恢复。检查对象的精确输入见records/qa_runtime_inputs.json。原图、旧音轨和旧视频均保留。主观整套听感与专名发音、完整正常难度通关、物理手柄不在本次已通过项中。未提交或推送Git。
