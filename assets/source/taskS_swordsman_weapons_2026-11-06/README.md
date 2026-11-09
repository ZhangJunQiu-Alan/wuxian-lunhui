# S–SW 剑士武器美术 · 2026-11-06

双击 [index.html](index.html) 打开中文总览。可按关卡浏览、逐帧叠挂点、切换左右朝向和三种地面、试听、看 Godot 录屏。评价存在本机浏览器，可复制成 Markdown。旧入口 [gallery.html](gallery.html) 跳到同一页。

| 交付 | 数量与位置 |
| --- | --- |
| 空手动作与挂点 | 14 条、64 帧；每帧 5 个挂点 |
| 武器部件 | 11 套，16 张手持、8 张收起、5 张空鞘、11 张图标、4 张发光、2 张配件；另有 5 条太刀旧帧还原层 |
| 特效与 HUD | 46 条 FX、10 张 HUD 图标 |
| 音效 | 19 个单声道 44.1 kHz 16 位 WAV |
| 预览 | 10 段 Godot WebM、11 张 1280×720 PNG、左右朝向 1408 帧合成图 |
| 可编辑图像 | 125 个 Aseprite 文件，含旧太刀还原与发光的独立层 |

## 新版刀光与逐把反馈

46 条特效均已更新。总览「新版刀光」展示三地块峰值帧，并链接每把武器的逐段特效。详见 [逐条反馈复核](revision-vfx-polish.md)。

## 收刀与空鞘返修

按确认图重做五把腰挂剑的入鞘和空鞘。网页顶部「收刀与空鞘复核」包含五把腰挂与 11 套武器的三地块对照、移动六帧、普攻六帧和武器技交接。太刀默认显示新版通用挂载，旧动作还原可在播放器勾选。[逐把复核与改动文件](revision-2026-11-09.md)

## 文件

- [接入契约](integration.md) 对照每个事件、帧率、锚点、平铺和图层。
- [批次清单](manifest.json) 记录正式文件及其 SHA256。
- `originals/` 保存 11 张高清概念原图。`candidates/` 保存初版退修图和原动作测点图。`approved/` 保存交付 PNG/WAV 及可编辑 `editable/`。
- `previews/` 保存录屏、无损截图、去刀差异、范围叠图和合成检查图。
- `records/` 保存图像提示词、合成和制作源程序、录制日志、校验和与验收数据。 `approved/` 为本批选定版本，用户评价独立记录。

## 核验边界

旧太刀采用逐帧拆层还原时，24 帧可见像素差为 0。使用一张通用刀图和一张通用鞘图时存在逐帧差异，挂点页同时保留两种画面。长刀背挂和鞘口先用原角色、正式三关地块在 1× 检视。技术检查及各帧差值见 [qa.json](records/qa.json) 与 [katana-pixel-check.json](records/katana-pixel-check.json)。

Godot WebM 由独立预览工程按时间轴编排录制，展示素材触发和叠层。正式项目的输入、数值和判伤接入归代码阶段。武器规则据本地任务书转述。引用的 Claude 设计稿未能打开核对原句。

## 独立预览工程

在仓库根目录运行：

```sh
godot --path "assets/source/taskS_swordsman_weapons_2026-11-06/godot_preview/runtime" \
  --log-file /dev/null -- --save-file user://sw-preview-save.json \
  --settings-file user://sw-preview-settings.cfg
```

左右键切换武器。复录整卷时，用 `--disable-render-loop --fixed-fps 24` 和用户参数 `--record --frames <帧目录> --stills <截图目录>`。帧目录和截图目录需先建好，放在同一临时目录下并分别命名 `frames`、`stills`。将 Godot 标准输出存到该目录的 `run.log` 后，运行 `python3 records/record_reels.py <临时目录>`。编码器检查帧连续后才更新网页媒体，并用同一演示时间轴和原 WAV 音效合成音轨。可用 `--weapon <ID>` 单独查看一把武器。
