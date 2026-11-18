# S–SET 套装防具接入

## 物品与状态图标

正式图标放入 `assets/sprites/items/armor/`。部位依次为 `helm`、`chest`、`legs`、`boots`。第二轮返修图使用 `_r2.png` 后缀，以表和 manifest 的路径为准。装备掉地及背包使用同一张 32×32 图。底框和光柱由装备系统绘制。

套装集齐四件后，血条旁使用 `assets/sprites/ui/sets/<套装id>.png`。12×12，中心锚点 (6,6)，近邻采样。猛志层数、龙鳞冷却和无瑕变灰由代码控制。

| 套装 | 掉落 | 头盔 | 胸甲 | 护腿 | 鞋子 | 血条图标 |
| --- | --- | --- | --- | --- | --- | --- |
| 荆誓骑士 | 第一关 | `thornoath_helm.png` 荆冠盔 | `thornoath_chest.png` 荆誓胸甲 | `thornoath_legs.png` 缠刺护腿 | `thornoath_boots.png` 荆根战靴 | `thornoath.png` |
| 刑天 | 第一关 | `xingtian_helm_r2.png` 无首盔 | `xingtian_chest_r2.png` 怒目胸甲 | `xingtian_legs_r2.png` 常羊护腿 | `xingtian_boots_r2.png` 战舞靴 | `xingtian.png` |
| 夜之伯爵 | 第一关 | `nightcount_helm.png` 伯爵高领 | `nightcount_chest.png` 蝠翼斗篷 | `nightcount_legs_r2.png` 黑呢马裤 | `nightcount_boots_r2.png` 夜行长靴 | `nightcount.png` |
| 涅墨亚狮皮 | 第一关 | `nemean_helm.png` 狮首盔 | `nemean_chest.png` 狮皮披挂 | `nemean_legs.png` 青铜胫甲 | `nemean_boots_r2.png` 远征凉鞋 | `nemean.png` |
| 屠龙者 | 第二关 | `dragonslayer_helm.png` 龙鳞盔 | `dragonslayer_chest.png` 龙血锁甲 | `dragonslayer_legs.png` 龙鳞护腿 | `dragonslayer_boots.png` 屠龙靴 | `dragonslayer.png` |
| 黄风大王 | 第二关 | `yellowwind_helm_r2.png` 貂鼠皮帽 | `yellowwind_chest.png` 黄风袍 | `yellowwind_legs.png` 沙行绑腿 | `yellowwind_boots.png` 卷沙靴 | `yellowwind.png` |
| 圣杯骑士 | 第二关 | `grail_helm.png` 白羽盔 | `grail_chest.png` 白十字罩袍 | `grail_legs.png` 银胫甲 | `grail_boots.png` 朝圣靴 | `grail.png` |
| 莲花化身 | 第三关 | `lotus_helm.png` 莲花冠 | `lotus_chest.png` 混天绫 | `lotus_legs.png` 莲藕护腿 | `lotus_boots.png` 风火轮 | `lotus.png` |
| 英灵殿 | 第三关 | `valhalla_helm.png` 英灵翼盔 | `valhalla_chest.png` 英灵锁甲 | `valhalla_legs.png` 英灵护腿 | `valhalla_boots.png` 英灵战靴 | `valhalla.png` |
| 熊皮狂战士 | 第三关 | `bearskin_helm.png` 熊首帽 | `bearskin_chest.png` 熊皮衫 | `bearskin_legs.png` 毛皮绑腿 | `bearskin_boots.png` 熊爪靴 | `bearskin.png` |

## 特效帧条

正式目录 `assets/sprites/effects/sets/`。帧从左至右，坐标以每帧左上为原点，锚点是贴到世界位置的整数像素。按 1× 最近邻采样，不自动缩放、旋转或镜像。保持帧条本身的透明区域。

| 文件 | 触发 | 每帧尺寸 | 帧数 / fps | 播放 | 锚点 | 图层 |
| --- | --- | --- | --- | --- | --- | --- |
| `thornoath_burst.png` | 受击触发，以玩家为中心 | 248×248 | 6 / 16 | 单次 | (124, 124) | 地面和角色之间 |
| `thornoath_stab.png` | 反刺命中攻击者，以受击目标的地面投影为锚 | 24×32 | 4 / 16 | 单次 | (12, 27) | 敌人前方 |
| `xingtian_mengzhi.png` | 刑天套装受击叠加或刷新猛志 | 64×64 | 6 / 16 | 单次 | (32, 32) | 身体后方叠加 |
| `dragonslayer_scale_r2.png` | 龙鳞充能完毕，鳞片闪在胸腰与身侧，头部留空 | 64×64 | 4 / 8 | 循环 | (32, 32) | 身体前方叠加 |
| `dragonslayer_shatter.png` | 龙鳞挡下伤害的瞬间 | 64×64 | 6 / 16 | 单次 | (32, 32) | 身体前方叠加 |
| `yellowwind_storm_r2.png` | 持续期间随判定中心移动。独立龙卷，无可见地环 | 96×112 | 6 / 12 | 循环 | (48, 62) | 地面特效层，角色与敌人之下 |
| `yellowwind_storm_start_r2.png` | 风柱由下向上卷起，无可见地环 | 96×112 | 3 / 12 | 单次 | (48, 62) | 地面特效层，角色与敌人之下 |
| `yellowwind_storm_end_r2.png` | 风柱被拉散成沙尘，无可见地环 | 96×112 | 3 / 12 | 单次 | (48, 62) | 地面特效层，角色与敌人之下 |
| `lotus_proc_r2.png` | 追加攻击触发，角色背后绽放莲花 | 64×64 | 4 / 16 | 单次 | (32, 32) | 身体后方叠加 |
| `valhalla_ring_r2.png` | 独立英灵脚下的符文光环 | 64×32 | 8 / 12 | 循环 | (32, 19) | 地面和分身之间 |

- 荆棘反刺以玩家位置为圆心，第四帧刺尖达到 120 px。攻击者身上的刺用另一条帧条，锚点放在目标地面投影处。
- 黄风沙尘暴三条帧条共用 (48, 62) 锚点。生成时播放卷起，随 4 秒效果计时播放循环。伤害结束后转消散，地面中心始终对齐。三段素材均是无地环的风柱。48 px 是玩法判定半径，预览只在手动打开判定开关时显示。帧条整体绘制在地面特效层。
- 屠龙者两条身体叠加层使用 64×64 角色帧中心。「龙鳞已备」只在胸腰与身侧显示。猛志叠层与莲花绽放在角色身体后方绘制。
- 表内素材已按任务尺寸输出。正式装备系统仍需接入装备选择、伤害和冷却；本批的 Godot 图形验证只运行独立画面。

## 英灵分身形象

`assets/sprites/allies/` 下两张帧条为独立、空手的英灵本体。每帧 64×64，默认朝右，脚底点 (32, 55)。`valhalla_ring_r2.png` 的 (32, 19) 对齐这个脚底点。环在身后。角色朝左时，镜像身体和持武器挂点，光环保持原朝向。

| 帧条 | 帧数 / fps | 播放 | 主手挂点 |
| --- | --- | --- | --- |
| `valhalla_guardian_idle.png` | 4 / 8 | 循环 | (41,34) → (41,33) → (42,34) → (41,34) |
| `valhalla_guardian_attack.png` | 6 / 16 | 单次 | (38,33) → (34,24) → (40,18) → (48,28) → (48,37) → (43,35) |

挂点和建议角度也逐帧记录在 manifest 的 `guardian` 条目。英灵仍按原设计使用玩家当前基础武器。正式接入时将武器挂在英灵手上。像素素材和独立预览已交付，攻击逻辑与伤害数值由装备系统接入。
