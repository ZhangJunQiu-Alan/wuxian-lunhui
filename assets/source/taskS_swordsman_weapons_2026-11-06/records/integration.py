from catalog import B, ITEMS
import json

d=json.loads((B/'manifest.json').read_text())
def table(head,rows):
    return '\n'.join(['| '+' | '.join(head)+' |','| '+' | '.join(['---']*len(head))+' |',
        *['| '+' | '.join(map(str,x))+' |' for x in rows]])+'\n'
def pair(v):
    return '('+', '.join(map(str,v))+')'
actions={
 'idle':'8 fps 循环，换武器时依 idle_hold 处理',
 'move':'8 fps 循环，按角色移动状态切入',
 'attack':'16 fps 单次，预备与收势帧由 mode 决定收刀',
 'off_attack':'16 fps，六帧，莫邪副手反切',
 'hurt':'12 fps 单次，受击反馈',
 'death':'8 fps 单次，播放到末帧后保持',
 'spin':'4 帧循环，代码按转速设 fps，预览默认 12',
 'heavy':'16 fps 单次，青龙松 K 重劈',
 'sheathe':'16 fps 单次，湖中剑收剑',
 'iai_stance':'8 fps 循环，湖中剑收鞘蓄力',
 'iai_dash':'由冲刺进度推进 3 帧，预览默认 16 fps',
 'thrust':'16 fps 单次，日月月刀前刺',
 'throw':'16 fps 单次，莫邪副手掷剑',
 'drink':'12 fps 单次，纯阳副手将葫芦举至嘴边',
}
parts=['''# 剑士武器美术接入契约

## 入口

- 身体帧条和挂点在 `assets/sprites/characters/`。用 `swordsman_bare_<动作>.png` 和 `swordsman_sockets.json`。
- `assets/sprites/weapons/manifest.json` 列出 11 套武器。所有部件路径相对 `assets/sprites/weapons/`。
- `assets/sprites/effects/weapons/swordsman/manifest.json` 列出 46 条 FX 记录，包含新版太刀和莫邪反切。FX 的 `file` 相对 `assets/`。同名 PNG 与 WAV 分别按目录解析。
- `assets/sprites/ui/weapons/swordsman/` 是 10 个 12×12 头顶／状态条图标。`assets/audio/sfx/` 是 19 条 WAV。
- 交付目录 `manifest.json` 有文件尺寸、帧数、SHA256。正式接入使用上面三个专用 JSON。

## 身体动作

64×64 每帧，横向由 0 开始。逐帧读同下标的挂点。画布原点是左上，身体逻辑中心可用 (32, 32)。下表的速度含预览约定，战斗播放由调用方决定。''']
parts.append(table(['动作','帧','触发和播放'],[(a,f['frames'],actions[a]) for a,f in d['actions'].items()]))
parts.append('''## 挂点及图层

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

下面的文件名均在 `assets/sprites/weapons/swordsman/`，精确像素坐标见正式清单。''')
rows=[]
for id,name,*_ in ITEMS:
    w=d['weapons'][id]
    variants=w.get('variants',{})
    refs=list(variants.values()) if variants else [w['main']]
    hand=' / '.join(f"{r['file'].split('/')[-1]} 握 {pair(r['grip'])} 尖 {pair(r['tip'])}" for r in refs)
    stow=w.get('stow_file','').split('/')[-1]
    if stow:stow=f"{stow} · {w['stow']} · {pair(w['stow_grip'])}"
    extra=[v for v in [w.get('main',{}).get('glow'),w.get('stow_glow'),w.get('sheath_file'),w.get('planted',{}).get('file'),w.get('props',{}).get('gourd',{}).get('file')] if v]
    rows.append((name,hand,stow or '—',w['icon'].split('/')[-1],' / '.join(v.split('/')[-1] for v in extra) or '—'))
parts.append(table(['武器','手持帧','收起','图标','附加部件'],rows))
parts.append('''## 特效事件

FX 帧条按 manifest 的 `size` 切横条。绘制点减 `anchor` 得左上角。朝右 0°，可随攻击方向旋转；标半径的帧保持 1×，范围由战斗代码按表判断。FX 的 `layer: 0` 表示世界空间 FX；收在角色层的 6、7 按上节。新版太刀清单使用 R110 / 120° 的预览脚印；正式游戏原太刀仍读取原素材路径。

- 目标／命中效果由调用方传入命中点，葫芦酒花从嘴边出，醉步从脚底出，蓄满闪光以鞘口为中心。
- 断水斩痕用 0–1 出现、2–5 循环、6–7 消失。贴符用 0–1 出现、2–3 停留共 0.5 秒。
- 32 像素平铺段的首尾像素按同一周期绘制。沿连线、冲刺或爆斩方向旋转，从起点以 31 px 步长排布，末片裁齐终点。莫邪剑气连线最长 450 px。
- 湖中剑冲刺从起点延展到 300 px；爆发段在 0.3 秒后整段同帧触发。两端分别盖 `excalibur_line_cap`，起端镜像、末端正向。播放期禁止按段错帧。''')
parts.append(table(['事件文件','事件','单帧','帧数 / fps','方式','锚点 / 空间','半径/角度'],[
    (e['id']+'.png',e['label'],'×'.join(map(str,e['size'])),f"{e['frames']} / {e['fps']}",
     e['play']+(' · tile' if e.get('tile') else ''),pair(e['anchor'])+' '+e['anchor_type'],
     f"{e['radius']} px / {e['angle']}°" if e.get('radius') else '—') for e in d['effects']]))
parts.append('''## HUD 与声音

HUD 只换贴图。鬼气条和蓄力条由调用方绘制。纯阳 0–3 用当前醉意下标，诛仙显示下一刀下标。''')
parts.append(table(['HUD 文件','事件'],[(e['id']+'.png',e['label']) for e in d['ui']]))
parts.append('''新增音频为 44.1 kHz、单声道、16 位 PCM。普通挥砍沿用已有 `katana_slash_01–03`。青龙循环用全文件首尾，退出 K 持续态即停；连线音降低响度，可与命中节流合用。''')
parts.append(table(['WAV','播放事件','时长 / 模式'],[(e['id']+'.wav',e['label'],str(e['seconds'])+' s / '+('循环' if e['loop'] else '单次')) for e in d['audio']]))
parts.append('''## 预览

- `index.html` 从正式 PNG 和 WAV 本地加载。挂点和清单副本内联；更新后运行 `python3 records/catalog.py` 重建页面。
- `godot_preview/runtime/` 是独立渲染工程。左右键换武器，自动播放示范。它按 `timelines.json` 编排画面、目标与触发顺序，作为素材演示。
- 在正式工程接入输入、技能状态、真实战斗判伤、旋转速度和残影同步，由代码侧验证。''')
(B/'integration.md').write_text('\n\n'.join(parts)+'\n')
