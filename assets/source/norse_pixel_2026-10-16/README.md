# 北欧像素精灵批处理

处理日期：2026-10-16，Asia/Singapore。

使用 Chrome 中 4 个 Pixel Asset Studio 页面导入原始 PNG，完成像素尺寸转换、原色调色板量化、无抖动、透明边缘清理，并同步到编辑工作区，以 1× 原尺寸导出。所有素材的像素转换均通过网站完成，本地脚本仅用于文件复制、检验与预览索引。

- 64×64：11 种小怪、3 种精英，共 14 张。
- 128×128：9 位 Boss。
- 全部为 RGBA PNG，透明度仅有 0 与 255，图像内容无重复，主体与画布边缘之间保留空白。
- 转换器设定颜色预算为 32；边缘清理后的实际 RGBA 色值数量见 manifest.json，不宣称严格为 32 色。
- 本轮产物为批量像素化静态候选；没有逐像素手绘修整，没有动作动画，没有完成游戏内验收。
- 耶梦加得仍是完整造型，需要另做绕场用的蛇头、蛇身段与蛇尾。

打开 gallery.html 查看原尺寸与放大对照。原图保存在相邻 norse_2026-10-16 文件夹。

| 名称 | 尺寸 | 文件 |
| --- | --- | --- |
| 墓丘誓卫 | 64×64 | [draugr_elite](64/elites/draugr_elite.png) |
| 凛冬咒灵 | 64×64 | [ice_spirit_elite](64/elites/ice_spirit_elite.png) |
| 冰川破阵者 | 64×64 | [frost_giant_elite](64/elites/frost_giant_elite.png) |
| 尸鬼 | 64×64 | [draugr](64/mobs/draugr.png) |
| 冬狼 | 64×64 | [wolf](64/mobs/wolf.png) |
| 冰霜精魂 | 64×64 | [ice_spirit](64/mobs/ice_spirit.png) |
| 霜巨人斥候 | 64×64 | [frost_giant](64/mobs/frost_giant.png) |
| 亡者 | 64×64 | [dead](64/mobs/dead.png) |
| 冥雾幽魂 | 64×64 | [mist_ghost](64/mobs/mist_ghost.png) |
| 黑暗精灵弓手 | 64×64 | [dark_elf](64/mobs/dark_elf.png) |
| 指甲傀儡 | 64×64 | [nail_golem](64/mobs/nail_golem.png) |
| 火焰巨人 | 64×64 | [fire_giant](64/mobs/fire_giant.png) |
| 霜巨人精锐 | 64×64 | [frost_veteran](64/mobs/frost_veteran.png) |
| 狂狼战士 | 64×64 | [berserker](64/mobs/berserker.png) |
| 斯库尔 | 128×128 | [skoll](128/bosses/skoll.png) |
| 哈提 | 128×128 | [hati](128/bosses/hati.png) |
| 赫列姆 | 128×128 | [hrym](128/bosses/hrym.png) |
| 加姆 | 128×128 | [garm](128/bosses/garm.png) |
| 尼德霍格 | 128×128 | [nidhogg](128/bosses/nidhogg.png) |
| 海拉 | 128×128 | [hel](128/bosses/hel.png) |
| 耶梦加得 | 128×128 | [jormungandr](128/bosses/jormungandr.png) |
| 芬里尔 | 128×128 | [fenrir](128/bosses/fenrir.png) |
| 苏尔特 | 128×128 | [surtr](128/bosses/surtr.png) |
