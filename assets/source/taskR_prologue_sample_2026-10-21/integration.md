# 正式代码接入

## 已完成

| 路径 | 行为 |
| --- | --- |
| assets/cinematics/norse/art/ | 16张原生返回尺寸的PNG，线性+mipmap；不冒称1080p/4K原生输出 |
| assets/cinematics/norse/audio/ | 三关各music/effects/narration，9个48kHz立体声Vorbis音轨 |
| assets/cinematics/norse/sequences.json | 每关4镜头、12段字幕/旁白的实际时序 |
| scripts/ui/chapter_intro.gd | 分层绘画演出、音轨、字幕、暂停、跳过、失焦、完成路由 |
| scenes/chapter_intro.tscn | 正式入口场景 |
| scripts/ui/hub.gd | 开战先进入对应剧情；关卡页新增已解锁剧情回看 |
| scripts/ui/hud.gd | 结算再来一次也经过剧情入口，沿用原先LevelDB选择规则 |
| locale/text.csv | 12段剧情字幕和4条界面文字的英文翻译 |
| tools/check_translations.py | 将cinematics下JSON字幕纳入翻译检查；保留其他代理原有改动 |

关卡选择来自LevelDB.selected；回看传入所选关卡且不改变战斗选择。开战去重与结束去重防止重复创建战斗。演出期间战斗场景尚未创建，关卡时间、刷怪、Boss计时和初始选神都不提前开始。不新增奖励、解锁或存档字段。自然结束/跳过进入scenes/main.tscn，回看结束返回scenes/hub.tscn。

音乐与旁白不使用同一音量通道：Music控制音乐，SFX控制旁白和音效；Master总音量仍生效。暂停和失焦同时暂停画面与三条音轨。游戏播放使用AnimationPlayer实际时间；仅开发导出模式用deferred RenderingServer.force_draw保证离屏画面更新。导出24fps，在CPU/窗口受影响时以ffprobe帧数和完整解码核实，不能把Godot日志的绘制次数当作容器帧数。

## 复现与测试

记录里的work/qa_runtime为当前工作区的隔离副本，custom_user_dir=ChapterCinematicQA20261021，显式save-file/settings-file；生产存档和用户语言设置未用于测试。

```sh
godot --headless --path 隔离副本 --script tools/test_chapter_intro.gd -- --save-file=user://qa.json --settings-file=user://qa.cfg --output=结果绝对路径
godot --path 隔离副本 --script tools/test_chapter_intro.gd -- --save-file=user://window_qa.json --settings-file=user://window_qa.cfg --output=结果绝对路径
```

正式项目中通过主神空间正常进入即可播放。完整开发导出由records/render_all.py顺序执行，依赖已记录的本机Godot/FFmpeg。当前英语旁白重建由english_revision/records/synthesize_english.py、build_english.py执行，完整视频由同处render_english.py执行；原records下的中文脚本仅用于历史重建；模型和隔离Python环境仅在work/，不作为游戏运行依赖。

## 尚未标记通过

人工整套旁白听感、北欧专名逐字发音与最终表演风格；实际物理手柄；其他硬件与打包发行。当前默认英语配音，默认中文字幕及英文UI字幕切换保留。用户选择B试音方向；该确认不代表整套配音或专名已人工听验。此次检查没有重跑完整正常难度通关；不把剧情演出验收当作战斗平衡或整款游戏发布验收。

此次未提交/推送。生产改动范围见records/code_scope.json，其余代理的代码、文档和素材不归本任务。before/的文件是制作前快照，含别人的未提交内容，只供追溯，不可整体覆盖回生产。


## 英语修订接入

本轮只替换assets/cinematics/norse/audio下9条音轨、sequences.json时序与CREDITS，并更新locale/text.csv已有12条字幕的英文列。播放器和战斗代码无需新接口；进入各关即使用英语旁白。音乐在离线混音时按各句语音时间生成平滑让位包络，运行时仍使用原Music/SFX设置。旧音轨和视频已备份于english_revision/before/。

本轮隔离副本采用records/qa_runtime_inputs.json（该路径相对于english_revision）的代码哈希；期间观察到其他代理修改脚本，记录于同处concurrent_code_changes_observed.json，本轮未覆盖这些改动。主观音色确认、机器检查、实际窗口运行与完整游戏验收分别记录。
