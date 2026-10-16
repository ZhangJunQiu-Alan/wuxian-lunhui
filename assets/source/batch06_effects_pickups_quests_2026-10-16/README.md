# 第6批：特效、拾取物与支线物件

2026-10-16。本任务依据用户明确指定制作第6批。**34/34项通过美术自检：14条四帧动画、20张静态，共76个输出单元。** 状态为美术交付，尚未由本代理接入Godot或在游戏中实测；由Claude继续审核、接入与实测。

- [交互验收页 gallery.html](gallery.html)：真实1倍、最近邻4倍、#121721背景、8fps播放、全局/单项暂停和单步切帧。
- [manifest.json](manifest.json)：逐项最终路径、工具、实际Prompt/生成记录、参考图、尺寸、颜色数、帧数、锚点、自检、SHA256。
- [技术核验结果](records/final_audit.json)：34项通过，成品/approved/候选字节及哈希一致，14份GIF逐帧像素与PNG深底4倍合成一致。
- [实际自检记录](records/reviews.json)、[退回及修正原因](records/rejected_candidates.json)。
- [特效总览](previews/effects_overview.png)、[物件总览](previews/objects_overview.png)、[交付选图](previews/delivery_overview.png)。这些总览仅作浏览，图下注明整数显示倍率；逐项1×/4×以gallery及各review PNG为准。

## 文件与制作方式

原图来自**用户已批准的内置image_gen**，43次实际生成的原始PNG均在originals中。49张originals PNG还包含Piskel导出和明确记名的整帧排版派生图，不能把49张均当成模型原始输出。三个Piskel可编辑工程对应篝火、铁火盆、英灵攻击；均实际通过Chrome免费Piskel导入、选区修正并导出。Pillow仅做裁切、最近邻尺寸、二值透明、共享调色板、整帧定位/排帧、预览与验证，没有用Python重画角色或特效。

每项生成提示词在records/generation_<id>_<version>.json；波次计划也保留实际Prompt。Piskel和整帧定位派生项记录其输入、父级原图、操作、工程及导出。渡鸦最终originals/raven_v04_raw.png是由三张独立生成原图组成的**未缩小排版图**，不是第四张新生成原图；三张直接原图和三次Prompt均另存。

风格参考是本项目已接入的精魂、霜巨人、尸鬼、火焰巨人Boss、符文石与倒塌木屋，见refs/style_reference.png。开合宝箱、唤醒墓碑、五色线团、英灵攻击和渡鸦后续姿势均上传本批对应原图或精灵参考。提示词只描述职业、物件或生物，未引用现代作品角色造型、真实人物或传说人物名称。没有新增注册、付费或收费API。

商用依据见[assets/LICENSES.md](../../LICENSES.md)：OpenAI内容输出权利条款、Piskel作品归用户条款及Pillow MIT-CMU；总览文字使用本项目已登记OFL授权NotoSansSC字体。

## 实际检查与退回

最终PNG均为RGBA，透明值只有0/255，每个单元四边至少2像素空白，不透明颜色数不超过32。同一英灵的待机/攻击使用完全相同的RGB色板。已对照现有素材检查上左光照、暗轮廓、冷色冰晶与暖色金火点缀，并在#121721上看过1倍与整数放大。全部动画检查了逐帧内容与锚点，Chrome交互页用于检查放大表现和相位切换；GIF计时为120/130/120/130毫秒，总时长500毫秒，平均8fps。

本批实际退回、修正的问题：

- 落雷初稿分支跨网格、主体缩短，第二稿改为分离四条连通主干及火花，统一横纵缩放并固定打击落点；主神标记初稿过短，使用窄柱排版重做。
- 篝火初稿石圈/木柴改变，铁火盆初稿盆体改变；在Chrome Piskel固定实体区域。篝火下34行完全一致，火盆三块固定区域完全一致。火盆一次选区过大导致火焰平切，已撤销该尝试并改用三个小选区。
- 符文弹亮核、冰柱底座、余烬热核位置偏移，通过不改图案的整帧定位修正。
- 金色线团初稿像金块，重做线带；第二种符文初稿与第三种同为菱形，重做为折线轮廓。
- 英灵攻击第四帧悬空残刃，在Piskel实际选区清除。
- 渡鸦前三版因身体转动、喙不清楚退回。最终采用一张清晰侧面鸟参考生成平翼、下拍，再按原图白眼位置共同比例排成“上拍—平翼—下拍—平翼”。这是**四相、三张独立姿势**的可逆循环，回程相复用平翼。四相眼睛均在(24,15)，保留原图白眼RGB到共享色板，避免减色吞掉该像素。

失败原图及仍存在的候选都保留在originals/candidates；被后续规范化覆盖的早期排版状态或撤销后未导出的Piskel尝试，只记录操作/原因，不声称另有导出文件。

**4×4平铺检查不适用**：本批无地块，均为独立透明精灵，未把物件/角色重复拼接伪称无缝地块。无文字、水印、签名或背景场景是对美术主体的检查；原图参考总览及验收页标签不属于游戏成品。

## 接入说明

静态PNG直接使用；动画PNG从左到右无间隔切4格，按下表单格尺寸处理。所有预览8fps；英灵攻击在游戏中按任务书16fps。其他特效时长与逻辑需由接入代理结合实际技能确定。

- 刀光、落雷、霜冻冲击波是单次动作，播完清除；冰柱升起播完保持末相，直到逻辑销毁。没有把特效画入角色动作。
- 诡火、符文飞弹、标记、篝火、渡鸦、火盆、余烬、冰涡、英灵idle为循环。
- 表中锚点是**单格局部坐标**。bottom锚点y表示靠近底部的落地参考，PNG不透明像素最下行为y-1。符文飞弹以亮核(21,15)定位，不以变长尾迹的包围盒定位。渡鸦飞行以眼(24,15)作固定定位参考，脚底基线不适用。
- 英灵待机和攻击位于quests/；现有脚本尚为程序形状，需要Claude接入。冰封战士严格使用enemies/ice_block.png，与任务书的自动替换约定一致；此处不声称游戏已加载。

| 素材 | 成品路径（相对assets/） | 单格尺寸 | 格数 | RGB色数 | 单格锚点 |
| --- | --- | --- | --- | --- | --- |
| 扇形刀光 | `sprites/effects/katana_slash.png` | 128×128 | 4 | 28 | [64, 64] |
| 落雷 | `sprites/effects/lightning.png` | 64×256 | 4 | 30 | [32, 254] |
| 符文飞弹 | `sprites/effects/rune_missile.png` | 32×32 | 4 | 32 | [21, 15] |
| 冰锥 | `sprites/effects/ice_shard.png` | 32×32 | 1 | 29 | [16, 16] |
| 诡火光环 | `sprites/effects/will_o_wisp_aura.png` | 128×128 | 4 | 31 | [64, 64] |
| 羽刃 | `sprites/effects/feather_blade.png` | 32×32 | 1 | 31 | [16, 16] |
| 霜冻冲击波环 | `sprites/effects/frost_shockwave.png` | 128×128 | 4 | 31 | [64, 64] |
| 冰柱 | `sprites/effects/ice_pillar.png` | 48×64 | 4 | 32 | [24, 62] |
| 经验宝石 | `sprites/pickups/xp_gem.png` | 16×16 | 1 | 27 | [8, 8] |
| 大经验宝石 | `sprites/pickups/xp_gem_large.png` | 24×24 | 1 | 30 | [12, 12] |
| 宝箱关闭 | `sprites/pickups/chest_closed.png` | 32×32 | 1 | 32 | [16, 30] |
| 宝箱打开 | `sprites/pickups/chest_open.png` | 32×32 | 1 | 30 | [16, 30] |
| 光柱标记 | `sprites/quests/quest_beacon.png` | 32×128 | 4 | 31 | [16, 126] |
| 篝火 | `sprites/quests/campfire.png` | 64×64 | 4 | 32 | [32, 62] |
| 渡鸦 | `sprites/quests/raven.png` | 32×32 | 4 | 24 | [24, 15] |
| 死者指甲 | `sprites/quests/dead_nail.png` | 16×16 | 1 | 29 | [8, 8] |
| 铁火盆 | `sprites/quests/iron_brazier.png` | 48×48 | 4 | 31 | [24, 46] |
| 太阳余烬 | `sprites/quests/sun_ember.png` | 32×32 | 4 | 32 | [16, 16] |
| 金色线团 | `sprites/quests/fate_thread_gold.png` | 16×16 | 1 | 27 | [8, 8] |
| 银色线团 | `sprites/quests/fate_thread_silver.png` | 16×16 | 1 | 29 | [8, 8] |
| 黑色线团 | `sprites/quests/fate_thread_black.png` | 16×16 | 1 | 25 | [8, 8] |
| 白色线团 | `sprites/quests/fate_thread_white.png` | 16×16 | 1 | 27 | [8, 8] |
| 灰色线团 | `sprites/quests/fate_thread_gray.png` | 16×16 | 1 | 24 | [8, 8] |
| 祭司冰涡 | `sprites/quests/ice_vortex.png` | 96×96 | 4 | 32 | [48, 48] |
| 冰洞鱼竿 | `sprites/quests/ice_fishing_hole.png` | 64×48 | 1 | 30 | [32, 46] |
| 巨人脚印 | `sprites/quests/giant_footprint.png` | 32×32 | 1 | 32 | [16, 16] |
| 墓碑暗淡 | `sprites/quests/tombstone_dormant.png` | 32×48 | 1 | 32 | [16, 46] |
| 墓碑唤醒 | `sprites/quests/tombstone_awakened.png` | 32×48 | 1 | 32 | [16, 46] |
| 发光符文一 | `sprites/quests/glowing_rune_01.png` | 32×32 | 1 | 32 | [16, 16] |
| 发光符文二 | `sprites/quests/glowing_rune_02.png` | 32×32 | 1 | 31 | [16, 16] |
| 发光符文三 | `sprites/quests/glowing_rune_03.png` | 32×32 | 1 | 32 | [16, 16] |
| 冰封战士 | `sprites/enemies/ice_block.png` | 64×64 | 1 | 32 | [32, 62] |
| 英灵待机 | `sprites/quests/einherjar_idle.png` | 48×48 | 4 | 32 | [24, 46] |
| 英灵攻击 | `sprites/quests/einherjar_attack.png` | 48×48 | 4 | 32 | [24, 46] |

## 复核

在项目根目录运行以下命令只检查本批资产与快照，不修改游戏代码：

```sh
PYTHONWARNINGS=ignore python3 assets/source/batch06_effects_pickups_quests_2026-10-16/records/audit_delivery.py
```

全部34项已交付，剩余为Claude接入游戏并进行同屏可读性、遮挡、实际技能节奏及碰撞位置验收。本代理没有执行git commit、git push，未修改scripts/、scenes/、docs/或project.godot。
