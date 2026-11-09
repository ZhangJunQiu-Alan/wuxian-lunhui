# 剑士武器美术接入契约

## 正式游戏

从主神空间进入「化身」，选择剑士，在「武器」卡片的菜单选择武器。11 套武器可直接选用，选择随存档保存。旧存档默认太刀。按 K 或鼠标右键释放武器技，青龙偃月刀需要按住后松开，湖中剑第一次按下挥刀，收鞘蓄满后再按发动居合。其他剑按各自的说明自动出招或切换状态。

正式资源由 `scripts/weapons/swordsman_art.gd` 从下面三个清单读取。`swordsman_weapon.gd` 执行伤害、武器技和状态，`swordsman_effects.gd` 播放同版特效。仍用已有剑士卡牌属性和第四刀二刀流。预览页保留旧太刀逐帧对照，战斗默认用新版腰挂与空鞘。掉落、背包、强化和分解留在装备系统待办。

战斗机制以已审过的本地任务稿、挂点和预览时间轴实现。伤害倍率、状态持续时间和冷却使用本轮的初始平衡值。

## 入口

- 身体帧条和挂点在 `assets/sprites/characters/`。用 `swordsman_bare_<动作>.png` 和 `swordsman_sockets.json`。
- `assets/sprites/weapons/manifest.json` 列出 11 套武器。所有部件路径相对 `assets/sprites/weapons/`。
- `assets/sprites/effects/weapons/swordsman/manifest.json` 列出 46 条 FX 记录，包含新版太刀和莫邪反切。FX 的 `file` 相对 `assets/`。同名 PNG 与 WAV 分别按目录解析。
- `assets/sprites/ui/weapons/swordsman/` 是 10 个 12×12 头顶／状态条图标。`assets/audio/sfx/` 是 19 条 WAV。
- 交付目录 `manifest.json` 有文件尺寸、帧数、SHA256。正式接入使用上面三个专用 JSON。

## 身体动作

64×64 每帧，横向由 0 开始。逐帧读同下标的挂点。画布原点是左上，身体逻辑中心可用 (32, 32)。下表的速度含预览约定，战斗播放由调用方决定。

| 动作 | 帧 | 触发和播放 |
| --- | --- | --- |
| idle | 4 | 8 fps 循环，换武器时依 idle_hold 处理 |
| move | 6 | 8 fps 循环，按角色移动状态切入 |
| attack | 6 | 16 fps 单次，预备与收势帧由 mode 决定收刀 |
| hurt | 2 | 12 fps 单次，受击反馈 |
| death | 6 | 8 fps 单次，播放到末帧后保持 |
| spin | 4 | 4 帧循环，代码按转速设 fps，预览默认 12 |
| heavy | 5 | 16 fps 单次，青龙松 K 重劈 |
| sheathe | 4 | 16 fps 单次，湖中剑收剑 |
| iai_stance | 4 | 8 fps 循环，湖中剑收鞘蓄力 |
| iai_dash | 3 | 由冲刺进度推进 3 帧，预览默认 16 fps |
| throw | 4 | 16 fps 单次，莫邪副手掷剑 |
| thrust | 4 | 16 fps 单次，日月月刀前刺 |
| drink | 6 | 12 fps 单次，纯阳副手将葫芦举至嘴边 |
| off_attack | 6 | 16 fps，六帧，莫邪副手反切 |


## 挂点及图层

- 角色朝右，x 向右、y 向下。显示朝左时将全部七层、挂点和局部位移一起镜像。游戏坐标的攻击方向由技能逻辑处理。
- 先把图像的 `grip` 对准帧内挂点，再围绕握把旋转 `socket.deg - base_deg`。PNG 坐标表示像素索引，绘制时两侧像素中心各加 0.5。角度 0 向右、90 向下。纹理使用最近邻采样。
- 主手 `main`、副手 `off`、腰 `hip`、背 `back` 都有角度及 z。`head` 只有中心坐标。武器可以按角度旋转。保持 1× 像素密度。
- 普通收刀武器在 `mode: stow` 按 `stow` 的腰／背挂点绘制，`held` 用主手。`idle_hold: held` 的三套武器平时双持或浮剑，`mode: none` 隐藏。死亡后沿旧帧还原的初始太刀可走专用路径。
- `stow_socket_adjust` 可覆盖 `deg/z`，`dx/dy` 加到腰或背挂点。先在朝右坐标计算，再整体镜像。
- 五把腰挂剑的 `stow_grip` 是鞘口，`stow_file` 含刀柄，`sheath_file` 为空鞘。两张图共用尺寸、鞘口和旋转。收起绘入鞘图，持刀时先绘空鞘再绘主手，`none` 两者均隐藏。
- `swordsman_sockets.json` 的 `waist_frames[action][frame].hip` 是这些动作专用的腰带参考点。缺省使用原 `hip`。有 `feed_px` 时，以鞘角单位向量 `u` 计算握点 `mouth - feed_px × u`，刀图局部裁到 `grip.x + feed_px + 1`，最多裁到刀尖列。发光图跟同一裁剪。该动作有 `waist_bodies` 时使用对应身体条。
- 湖中剑 `excalibur_charge_full` 的世界锚点是角色帧原点加变换后的鞘口坐标。收鞘闪光使用同一个 `stow_grip`。
- 纯阳葫芦通常以 `props.gourd.hip_adjust` 修正腰点，饮酒六帧切到 `off`，首尾与腰点重合。干将莫邪与日月的待机和跑动副手采用 `off_idle_adjust`。诛仙备用剑使用 `reserve_offsets`，当前手持变体从候选中剔除。攻击显示待机身体，按 `flight_px` 限制出剑最远剑尖，发剑完成后回到主手。
- 各层由后往前是 1 收起背层、2 手持背层、3 身体、4 前层武器／葫芦、5 发光、6 头部叠加、7 全身叠加。腰鞘和手持剑可同时位于层 4，先画鞘。
- `spin.main` 是双拳中点。代码给连续旋转角度。武器转到身后半圈走层 2，前半圈走层 4。
- 诛仙当前剑取 `variants.zhu/lu/xian/jue`，另外三把用层 1，以清单里的三个偏移挂在背点旁，朝 −90°。状态只切换当前剑。
- 干将莫邪用 `main`／`off`。莫邪掷出时隐藏副手图，用手持图当飞行体并按路径转向。插地时换 `planted`，锚点是剑尖。回到角色后恢复副手图。
- 干将莫邪的两次普攻依次用 `attack` 与 `off_attack`，分别配 `ganjiang_slash` 和 `moye_slash`。
- 日月双刀将当前日／月图放主手，另一把放副手，换手时同步状态 UI。日刀配 `riyue_sun_sweep`，月刀配 `riyue_moon_thrust`。发光文件与对应图同尺寸同锚点，允许按状态调透明度。
- 太刀的 `legacy_layers` 是从旧条拆出的 5 张武器遮盖帧条，均对齐身体帧原点。用于旧五动作逐像素还原时，在层 4 用同帧号叠加这张条，取代该帧的通用手持或腰挂。8 个新增动作和其他武器使用统一挂点。两种太刀模式均在网页可切换。

## 武器部件

下面的文件名均在 `assets/sprites/weapons/swordsman/`，精确像素坐标见正式清单。

| 武器 | 手持帧 | 收起 | 图标 | 附加部件 |
| --- | --- | --- | --- | --- |
| 太刀 | katana.png 握 (3, 2) 尖 (20, 1) | katana_stow.png · hip · (10, 4) | katana_icon.png | katana_sheath.png |
| 村正 | muramasa.png 握 (2, 5) 尖 (26, 1) | muramasa_stow.png · hip · (10, 4) | muramasa_icon.png | muramasa_glow.png / muramasa_sheath.png |
| 物干竿 | monohoshizao.png 握 (2, 3) 尖 (34, 1) | monohoshizao_stow.png · back · (5, 4) | monohoshizao_icon.png | — |
| 断水 | duanshui.png 握 (2, 4) 尖 (26, 4) | duanshui_stow.png · hip · (10, 4) | duanshui_icon.png | duanshui_sheath.png |
| 髭切 | higekiri.png 握 (2, 5) 尖 (22, 0) | higekiri_stow.png · hip · (10, 4) | higekiri_icon.png | higekiri_glow.png / higekiri_sheath.png |
| 干将莫邪 | ganjiang.png 握 (2, 4) 尖 (18, 4) / moye.png 握 (2, 4) 尖 (18, 4) | — | ganjiang_moye_icon.png | moye_planted.png |
| 诛仙四剑 | zhuxian_zhu.png 握 (2, 4) 尖 (20, 4) / zhuxian_lu.png 握 (2, 4) 尖 (20, 4) / zhuxian_xian.png 握 (2, 4) 尖 (20, 4) / zhuxian_jue.png 握 (2, 4) 尖 (20, 4) | — | zhuxian_icon.png | — |
| 青龙偃月刀 | qinglong.png 握 (20, 9) 尖 (51, 0) | qinglong_stow.png · back · (17, 9) | qinglong_icon.png | qinglong_glow.png |
| 湖中剑 | excalibur.png 握 (2, 4) 尖 (22, 4) | excalibur_stow.png · hip · (10, 4) | excalibur_icon.png | excalibur_stow_glow.png / excalibur_sheath.png |
| 日月双刀 | riyue_sun.png 握 (2, 5) 尖 (18, 2) / riyue_moon.png 握 (2, 5) 尖 (18, 0) | — | riyue_icon.png | — |
| 纯阳剑 | chunyang.png 握 (2, 4) 尖 (22, 4) | chunyang_stow.png · back · (5, 4) | chunyang_icon.png | chunyang_gourd.png |


## 特效事件

FX 帧条按 manifest 的 `size` 切横条。绘制点减 `anchor` 得左上角。朝右 0°，可随攻击方向旋转；标半径的帧保持 1×，范围由战斗代码按表判断。FX 的 `layer: 0` 表示世界空间 FX；收在角色层的 6、7 按上节。新版太刀清单使用 R110 / 120° 的预览脚印；正式游戏原太刀仍读取原素材路径。

- 目标／命中效果由调用方传入命中点，葫芦酒花从嘴边出，醉步从脚底出，蓄满闪光以鞘口为中心。
- 断水斩痕用 0–1 出现、2–5 循环、6–7 消失。贴符用 0–1 出现、2–3 停留共 0.5 秒。
- 32 像素平铺段的首尾像素按同一周期绘制。沿连线、冲刺或爆斩方向旋转，从起点以 31 px 步长排布，末片裁齐终点。莫邪剑气连线最长 450 px。
- 湖中剑冲刺从起点延展到 300 px；爆发段在 0.3 秒后整段同帧触发。两端分别盖 `excalibur_line_cap`，起端镜像、末端正向。播放期禁止按段错帧。

| 事件文件 | 事件 | 单帧 | 帧数 / fps | 方式 | 锚点 / 空间 | 半径/角度 |
| --- | --- | --- | --- | --- | --- | --- |
| qinglong_sweep.png | 普攻横扫 | 143×281 | 4 / 16 | once | (2, 140) player | 138 px / 180° |
| qinglong_sweep_360.png | 青龙附体横扫 | 281×281 | 4 / 16 | once | (140, 140) player | 138 px / 360° |
| qinglong_spin.png | 偃月风暴 | 281×281 | 4 / 16 | loop | (140, 140) player | 138 px / 360° |
| qinglong_heavy.png | 松手重劈与地裂 | 155×305 | 6 / 16 | once | (2, 152) player | 150 px / 180° |
| qinglong_avatar.png | 青龙附体外圈 | 128×128 | 6 / 12 | loop | (64, 64) body_frame | — |
| excalibur_slash.png | 手动挥砍 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| excalibur_guard.png | 收鞘护体 | 64×64 | 4 / 8 | loop | (32, 32) body_frame | — |
| excalibur_charge_full.png | 四秒蓄满闪光 | 48×48 | 4 / 16 | once | (24, 24) scabbard_mouth | — |
| excalibur_dash_trail.png | 拔剑冲刺尾迹 | 32×24 | 4 / 16 | once · tile | (0, 12) effect_origin | — |
| excalibur_line_burst.png | 延迟刀痕爆开 | 32×48 | 6 / 16 | once · tile | (0, 24) effect_origin | — |
| excalibur_line_cap.png | 爆开线段端帽 | 32×48 | 6 / 16 | once | (5, 24) effect_origin | — |
| katana_slash.png | 太刀 · 银白回锋 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| muramasa_slash.png | 普攻细红刃线 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| muramasa_thirst.png | 断连 · 渴 | 64×64 | 4 / 8 | loop | (32, 32) body_frame | — |
| monohoshizao_slash.png | 刀尖伤害区 | 170×335 | 4 / 16 | once | (2, 167) player | 165 px / 90° |
| monohoshizao_tip.png | 刀尖命中 · 燕形闪光 | 32×32 | 4 / 16 | once | (16, 16) hit | — |
| duanshui_slash.png | 分水横斩 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| duanshui_scar.png | 水壁斩痕 | 115×225 | 8 / 16 | phased | (2, 112) player | 110 px / 120° |
| duanshui_splash.png | 斩痕命中水花 | 24×24 | 4 / 16 | once | (12, 12) hit | — |
| higekiri_slash.png | 普通刀光 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| higekiri_oni_slash.png | 鬼化交叉双刀线 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| higekiri_oni_aura.png | 鬼气绕身 | 64×64 | 4 / 8 | loop | (32, 32) body_frame | — |
| higekiri_oni_horns.png | 鬼角 | 14×10 | 2 / 6 | loop | (7, 8) head | — |
| higekiri_exhaust.png | 脱力白气 | 64×64 | 4 / 8 | loop | (32, 32) body_frame | — |
| ganjiang_slash.png | 雄剑普攻 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| moye_slash.png | 莫邪 · 霜蓝反切 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| moye_trail.png | 莫邪飞行拖尾 | 48×16 | 4 / 16 | loop | (0, 8) effect_origin | — |
| moye_planted_ring.png | 莫邪插地 | 48×24 | 4 / 8 | loop | (24, 12) effect_origin | — |
| ganjiang_link.png | 金蓝剑气连线 | 32×16 | 4 / 12 | loop · tile | (0, 8) effect_origin | — |
| zhuxian_slash_zhu.png | 诛 · 厚金 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| zhuxian_slash_lu.png | 戮 · 绯红 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| zhuxian_slash_xian.png | 陷 · 靛紫 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| zhuxian_slash_jue.png | 绝 · 墨痕 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| zhuxian_bleed.png | 戮 · 流血 | 24×24 | 4 / 16 | loop | (12, 12) target | — |
| zhuxian_talisman.png | 陷 · 贴符定身 | 24×32 | 4 / 8 | once | (12, 16) target | — |
| zhuxian_execute.png | 绝 · 墨斩处决 | 96×96 | 6 / 16 | once | (48, 48) target | — |
| riyue_sun_sweep.png | 日刀横扫 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 180° |
| riyue_moon_thrust.png | 月刀窄刺 | 148×291 | 4 / 16 | once | (2, 145) player | 143 px / 60° |
| riyue_sun_wheel.png | 日轮环斩 | 225×225 | 6 / 16 | once | (112, 112) player | 110 px / 360° |
| riyue_moon_lunge.png | 月牙突进与三连刺 | 160×48 | 6 / 16 | once | (16, 24) effect_origin | — |
| riyue_swap.png | 日月交错换手 | 48×48 | 4 / 16 | once | (24, 24) hand | — |
| chunyang_slash.png | 清白剑光 | 115×225 | 4 / 16 | once | (2, 112) player | 110 px / 120° |
| chunyang_qi.png | 一醉脱手剑气 | 48×24 | 4 / 16 | loop | (24, 12) effect_origin | — |
| chunyang_drink.png | 饮酒酒花 | 24×24 | 6 / 12 | once | (12, 12) mouth | — |
| chunyang_tipsy.png | 醉红与酒泡 | 16×12 | 2 / 6 | loop | (8, 4) head | — |
| chunyang_dodge.png | 三醉脚下酒雾 | 32×32 | 4 / 16 | once | (16, 16) feet | — |


## HUD 与声音

HUD 只换贴图。鬼气条和蓄力条由调用方绘制。纯阳 0–3 用当前醉意下标，诛仙显示下一刀下标。

| HUD 文件 | 事件 |
| --- | --- |
| excalibur_charge.png | 蓄力表 · 剑鞘 |
| higekiri_oni_gauge.png | 鬼气表 · 鬼面 |
| zhuxian_next_zhu.png | 下一剑 · zhu |
| zhuxian_next_lu.png | 下一剑 · lu |
| zhuxian_next_xian.png | 下一剑 · xian |
| zhuxian_next_jue.png | 下一剑 · jue |
| chunyang_gourd_0.png | 醉意 0 |
| chunyang_gourd_1.png | 醉意 1 |
| chunyang_gourd_2.png | 醉意 2 |
| chunyang_gourd_3.png | 醉意 3 |


新增音频为 44.1 kHz、单声道、16 位 PCM。普通挥砍沿用已有 `katana_slash_01–03`。青龙循环用全文件首尾，退出 K 持续态即停；连线音降低响度，可与命中节流合用。

| WAV | 播放事件 | 时长 / 模式 |
| --- | --- | --- |
| muramasa_thirst.wav | 连杀断开 · 低心跳 | 0.42 s / 单次 |
| monohoshizao_tip.wav | 刀尖命中 · 清亮高音 | 0.28 s / 单次 |
| duanshui_scar.wav | 水壁留下 · 短促劈水 | 0.43 s / 单次 |
| higekiri_oni_on.wav | 鬼化 · 低吼与刀鸣 | 0.81 s / 单次 |
| higekiri_oni_off.wav | 主动收手 · 短收刀 | 0.24 s / 单次 |
| higekiri_exhaust.wav | 鬼气耗尽 · 喘息 | 0.84 s / 单次 |
| moye_throw.wav | 掷出莫邪 · 破风 | 0.4 s / 单次 |
| moye_return.wav | 飞回入手 · 金属嗡鸣 | 0.62 s / 单次 |
| ganjiang_link.wav | 剑气命中 · 轻双音 | 0.24 s / 单次 |
| zhuxian_xian.wav | 符箓贴上 · 封印 | 0.45 s / 单次 |
| zhuxian_jue.wav | 处决 · 刀斩与墨溅 | 0.43 s / 单次 |
| qinglong_spin_loop.wav | 偃月风暴 · 无缝循环 | 1.2 s / 循环 |
| qinglong_heavy.wav | 松手重劈 · 落地回响 | 0.92 s / 单次 |
| qinglong_avatar.wav | 青龙附体 · 龙吟 | 1.37 s / 单次 |
| excalibur_sheathe.wav | 收剑 · 鞘口咔哒 | 0.42 s / 单次 |
| excalibur_charge_full.wav | 蓄满 · 明亮共鸣 | 0.82 s / 单次 |
| excalibur_iai.wav | 拔剑 · 长音接爆斩 | 0.78 s / 单次 |
| riyue_swap.wav | 日月换手 · 双刀相击 | 0.49 s / 单次 |
| chunyang_drink.wav | 饮酒 · 咕嘟 | 0.53 s / 单次 |


## 预览

- `index.html` 从正式 PNG 和 WAV 本地加载。挂点和清单副本内联；更新后运行 `python3 records/catalog.py` 重建页面。
- `godot_preview/runtime/` 是独立渲染工程。左右键换武器，自动播放示范。它按 `timelines.json` 编排画面、目标与触发顺序，作为素材演示。
- 在正式工程接入输入、技能状态、真实战斗判伤、旋转速度和残影同步，由代码侧验证。
