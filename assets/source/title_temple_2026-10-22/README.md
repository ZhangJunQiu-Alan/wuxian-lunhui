# 《诸界余烬》神殿首页

用户于 2026-10-22 选择图二神殿方案并授权修改游戏代码。新版首页已接入，待用户实际体验。

- 正式背景：`assets/ui/title/temple_background.png`，1672×941，RGB，无界面文字。
- 正式标题：`assets/ui/title/embers_logo.png`，2202×714，RGBA，真实透明背景。
- 两张素材均使用内置 image_gen 编辑自已选方案；原始输出在 `originals/`，完整提示词在 `prompts.md`，来源和 SHA-256 在 `manifest.json`。
- 标题、背景和原生菜单分层。背景使用线性过滤和保持比例铺满；菜单按 1280×720 基准等比居中，保留五项功能。
- 支持鼠标、方向键、Tab、Enter；弹窗期间禁用背景按钮，关闭后恢复所选菜单项。
- 首次进入短暂淡入，返回首页跳过淡入；不显示章节行和“按任意键开始”。
- 首次接入前的代码保存在 `before/`，该目录由 `.gdignore` 排除导入。

验证：Godot 4.7.2；无界面 91 项检查通过；实际 OpenGL 渲染 99 项检查通过；退出按钮独立进程验证通过。翻译检查 853 条，缺失 0，未使用 0。最终运行日志没有脚本错误或退出资源泄漏；macOS 渲染进程有一条输入法服务诊断信息。

`screenshots/` 保存中文四种尺寸及英文菜单的实际引擎画面。小窗口、16:10、宽屏、中英文显示已检查。本次验证仅覆盖首页及其菜单跳转，不代表完整游戏通关验收。

复现功能检查（使用独立测试数据）：

```sh
godot --headless --path . --script res://tools/test_title_menu.gd -- --save-file=/tmp/embers_title_test_save.json --settings-file=/tmp/embers_title_test_settings.cfg
```

实际渲染检查在相同命令中移除 `--headless`，并添加 `--capture-dir=<绝对路径>`。退出按钮独立检查添加 `--test-quit`。
