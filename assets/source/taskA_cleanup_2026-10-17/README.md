# 任务 A：历史人物名清理

2026-10-17。已完成：78份文字文件修改，491个文件/目录路径改为职业标识；530个清理前已存在的游戏素材文件逐个SHA256不变。没有修改sprites/或audio/的素材内容，没有修改代码、场景、docs或project.godot，未commit/push。

- 文件名、目录名、标识符、manifest路径、HTML引用及脚本内路径统一到`swordsman`、`gunslinger`、`assassin`、`mage`。
- 历史Prompt中的人物全名遮盖为`[已删除人物名]`，其余措辞保留；不会把旧记录伪装成新Prompt。
- LICENSES中的旧名说明按任务书改为「早期文件名用了原型人物名，已统一改为职业名」。
- 原图图像字节保持不变。为满足全assets不残留姓名，不另留包含原姓名的明文备份；变更前后哈希、匿名化旧路径哈希与新路径记录在manifest中。

## 实际复搜

规则以Unicode码点保存于rules.json，避免搜索报告自身再次引入被清理的拼写。包括四个旧英文标识、对应全名、中文与繁体变体；不区分英文大小写。执行：

```sh
python3 assets/source/taskA_cleanup_2026-10-17/audit.py
rg -a -i -n -f <(python3 assets/source/taskA_cleanup_2026-10-17/audit.py --patterns) assets
rg --files --hidden assets | rg -i -f <(python3 assets/source/taskA_cleanup_2026-10-17/audit.py --patterns)
```

全量文件路径与二进制内容扫描：0命中。JSON与Piskel解析失败：0。清理前530个运行时文件哈希变化：0。历史HTML中的本地链接逐个解析验证，无本次清理范围内失效链接。

另一代理正在制作的C/D/E源目录不做链接改写；其尚未写完的临时页面若出现待补README引用，单独记录在audit.json的other_agents_in_progress_links，不算作已修复或已经验收。

详细记录：manifest.json、runtime_hashes.json、audit.json。audit.py可再次执行全量复核。
