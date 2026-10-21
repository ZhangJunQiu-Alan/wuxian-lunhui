# 2026-10-22 发布、清理与 Windows 导出

本轮用户授权：提交并推送目前内容，清理可重建冗余文件，导出Windows版本。已完成。原制作档案里的“未提交”说明属于当时状态，本轮源码已统一发布。

## Git 与版本

源代码提交：`6a2795e0697a4790f0cc99d6d082627b5c0bd6df`。已核对远端main一致；新增1274个LFS对象上传成功，约1.12GB。包括第三关、M美术优化、性能调整、新标题菜单和英语三关旁白，以及现有任务档案/文档。记录收尾另作提交，游戏运行代码与此源码提交一致。Windows二进制和ZIP保存在被Git忽略的build目录，未把构建产物塞进源码仓库。

## Windows 交付

- 目标：Windows x86_64 release，Godot 4.7.2官方模板。模板SHA256与官方GitHub发布digest一致。
- ZIP：`build/windows_2026-10-22/诸界余烬_Windows_x86_64_2026-10-22.zip`，245,117,839字节（约245.1MB）。
- ZIP SHA256：`e481d2d7381c47cb8615a01191231738342e229363261be129880f412f72b011`。
- 解压后进入ZhujieYujin-Windows-x86_64文件夹，双击ZhujieYujin.exe；EXE和PCK需放在同一目录。
- 包含启动说明、BUILD_INFO、运行文件校验值、素材/字体/旁白/引擎及第三方许可。
- ZIP全体成员CRC有效，包内EXE/PCK的SHA256与已测试文件一致。EXE验证为PE32+、AMD64、Windows GUI子系统。
- 导出过滤排除assets/source、docs、tools、制作视频和缓存；所需剧情JSON、结局JSON及鸣谢随包交付。

## 实际自检

13套当前工作区自动检查，合计8836项、0失败；使用绝对路径隔离save-file/settings-file，不使用默认玩家存档。测试期间运行代码哈希无变化。

| 检查 | 项数 | 失败 |
| --- | ---: | ---: |
| test_combat_regressions | 2451 | 0 |
| test_vigrid | 368 | 0 |
| test_chapter_intro | 230 | 0 |
| test_title_menu | 91 | 0 |
| test_run_supplies | 171 | 0 |
| test_supply_guard | 81 | 0 |
| test_actor_scale | 408 | 0 |
| test_environment_scale | 1903 | 0 |
| test_god_fx_cadence | 2270 | 0 |
| test_spatial_queries | 481 | 0 |
| test_density_buffers | 352 | 0 |
| test_odin_density | 17 | 0 |
| test_skadi_balance | 13 | 0 |

Windows目标PCK另在macOS Godot无窗口和实际OpenGL窗口各完成1821项检查、0失败：包内没有开发档案；首页、主神空间、三关英语音轨与时序、剧情跳过和三关战斗入口均能加载。见records/pack_smoke.json和pack_window.json。

本轮未在Windows真机或Wine中执行EXE；上述macOS资源包检查不替代Windows驱动、输入、音频或正常难度真人通关。原始日志保留，macOS窗口日志只有系统输入法mach-port诊断，未发现游戏SCRIPT ERROR/ERROR/WARNING或退出资源泄漏。

## 清理结果

确认源码已推送后，移除1092项缓存/无引用生成元数据，逻辑体积6.95GB；本机磁盘空闲实测增加6.40GB。包括本地TTS权重和依赖/测试工作目录、制作预览工程的Godot缓存、Python字节码、无引用.import/.uid、已核验并安装后的模板下载包。

15,647个已提交文件清理前后聚合SHA256一致。正式素材、所有原图/Prompt/许可/清单/QA记录、被清单引用的221份元数据、玩家存档、共享根.godot和.git/LFS均保留。详情见records/cleanup_result.json。

旁白模型/虚拟环境从未是游戏运行依赖。需要重做语音时，应按原英语制作记录恢复隔离环境、重新下载指定公开模型revision，并验证保留的权重哈希；原始WAV和现成音轨仍在源档案中。

## 重建

在安装匹配4.7.2.stable Windows模板后，从项目根目录执行：

```sh
mkdir -p build/windows_2026-10-22/package
godot --headless --path . --export-release "Windows Desktop" build/windows_2026-10-22/package/ZhujieYujin.exe
```

export_presets.cfg已纳入版本控制，不含证书、付款或登录信息。实际模板出处和校验见records/template_release.json、template_verification.json；当前源码与检查输入见records/test_inputs.json。
