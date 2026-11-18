# 诸界余烬 · S–SET 套装防具美术

2026-11-10 · 第二轮返修。双击 [index.html](index.html) 可进入离线总览。点击套装名打开详情，按 1×、4×、8× 查看图标。动画可以切换地面、调慢、逐帧查看。评价保存在当前浏览器，可复制成 Markdown。

## 交付目录

| 内容 | 数量 | 正式位置 |
| --- | --- | --- |
| 32×32 防具图标 | 40 张 | `assets/sprites/items/armor/` |
| 套装特效 | 10 条横向帧条 | `assets/sprites/effects/sets/` |
| 12×12 状态图标 | 10 张 | `assets/sprites/ui/sets/` |
| 独立英灵分身 | 待机 4 帧，出手 6 帧 | `assets/sprites/allies/valhalla_guardian_*.png` |
| 高清概念图 | 12 张 | `originals/` |
| 总览与接入契约 | 1 套 | [index.html](index.html) · [integration.md](integration.md) |

`approved/` 为本批拟交付 PNG。人工评价在总览中独立保存。`candidates/` 留初稿和加工候选。`manifest.json` 记录尺寸、帧数、挂点、用色、正式路径和 SHA256。`records/concept-prompts.json` 保存 10 张概念图的实际英文提示词，图像由内置 imagegen 生成。图标按原图取样后做限定色板和逐像素修订，特效及小状态图标逐像素绘制。

第二轮处理 [15 条反馈](records/review-r2.json)。8 张防具图标和 6 条特效以 `_r2.png` 另存，初版路径保留。新增猛志特效与英灵的待机、出手。英灵手部挂点在 manifest，英灵本体和光环可在总览里一起预览。本轮另有两张由内置 imagegen 生成的设计稿，提示词见 [返修概念提示词](records/revision-concept-prompts.json)。

## 验收证据

- [剪影对照](previews/silhouettes.png)和 [雪地](previews/midgard-1x.png)、[冥界](previews/helheim-1x.png)、[焦土](previews/vigrid-1x.png)均使用本项目的实际地块与 1× 防具像素。
- [Godot 独立预览](previews/godot-r2-3-frame-7.png)用了实际角色帧和地块，以近邻 1× 渲染。三种地面共检查 30 张逐帧画面，保留各地面第 2、4、7 帧。正式装备系统接入和用户验收另记。
- 浏览器在本机 HTTP 预览中验证了逐帧、地面切换、评价持久化和 Markdown 复制。本地 HTML 使用嵌入数据与相对资源路径。
- 见 [QA 报告](records/qa.json)核对 PNG 尺寸、二值 alpha、色数、帧数、哈希及荆棘 120 px 外缘和黄风 48 px 判定。已有素材核对以制作前快照为准，授权台账为本批新增登记。

## 重建

从项目根目录运行批次 `records/catalog.py` 更新网页与清单，运行 `records/qa.py --complete --baseline` 重做素材校验与 1× 对照。第二轮成品可由 `records/revision_pixels.py`、`records/effects.py --revision` 与 `records/guardian.py` 重建。正式目录如有同名且不同内容，发布脚本会在写入前拒绝。

`records/godot_qa.gd` 可以复制到独立 Godot 4 项目运行，窗口和视口为 1152×900，Compatibility 渲染，传入 `-- --batch=<批次绝对路径> --output=<预览目录绝对路径>`。
