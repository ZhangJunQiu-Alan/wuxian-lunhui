# Chrome：Work设置禁用的排查

2026-10-19实测：用户答复已开启后，Chrome工具listTabs仍返回“Local browser use is disabled in Work settings”。本轮没有恢复成功，不是网页或素材错误。

只读检查：~/.codex/config.toml（含profiles）未找到browser/computer/work相关显式features；项目.codex/config.toml、/etc/codex/requirements.toml不存在。没有改任何配置。企业远程/MDM策略未检查，不能宣称没有管理员限制。

1. 已开启开关后仍失败：先保存工作，完全退出桌面应用和Chrome（macOS用⌘Q，关窗口不等于退出），再重新打开。官方建议连接异常时重启浏览器；若多份桌面应用，确认当前Chrome扩展连接的是正在使用的那份。
2. 在桌面应用Settings → Computer Use → Google Chrome确认显示Manage，使用安装ChatGPT扩展的同一Chrome配置。若本版本把本地浏览器使用总开关放在Work里，确认总开关开启；Chrome连接显示Manage并不能独立证明总开关可用。Settings → Browser是内置浏览器设置，与Chrome路径区分。
3. 重开本会话复测；若仍旧禁用，官方建议新建Work/Codex聊天并@Chrome测试，让浏览器连接重新建立。本轮已有素材和验证都已落盘，新聊天可以读取本README接续。
4. 若开关灰色、显示组织管理，或新会话仍返回同一Work禁用：管理员需检查Workspace settings → Permissions & roles及浏览器受管策略。features.browser_use=false会关浏览器控制；browser_use_external=false会关外部浏览器控制。用户开启不能覆盖管理员拒绝；不要强行改配置绕过。
5. 浏览器控制恢复后再检查文件导入：Chrome扩展“允许访问文件网址”只解决本地文件导入，不能解开Work总开关。此前已经授权过，无需为当前报错反复开启这项。

官方依据：
- https://learn.chatgpt.com/docs/chrome-extension （设置/Manage/配置/重启/新聊天排查）
- https://learn.chatgpt.com/docs/browser （内置Browser设置路径）
- https://learn.chatgpt.com/docs/enterprise/chatgpt-work-local-security （工作区权限、用户不能覆盖管理员拒绝）
- https://learn.chatgpt.com/docs/enterprise/managed-configuration#control-browser-and-computer-use （browser_use及browser_use_external受管开关）

“当前会话尚未刷新开关或连接”的解释是排查假设，不是已确认原因。恢复的判据是Chrome工具实际列出标签并成功打开/读取本批图库；只有设置截图或用户答复，不标记恢复通过。
