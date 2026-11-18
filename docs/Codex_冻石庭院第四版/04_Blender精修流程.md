# 04 · Blender 精修流程

第三版的问题之一是：所有建筑都由 `build_headland.py` 用倒角方块拼出来。第四版的分工：

- **程序化**：只负责地形、摆放、散布（树、碎石、雪堆）和碰撞标记。
- **手工精修**：符文石碑、长厅残骸、出口门、入口木闸、岩体这些主资产，在 Blender 里逐个建模、雕刻、出贴图。

## 打开 Blender

- 路径：`/Applications/Blender.app/Contents/MacOS/Blender`（`blender` 不在 PATH 里）
- 打开图形界面精修：`open -a Blender <文件.blend>`，也可以直接用电脑操作 Blender 窗口。
- 批量导出或运行脚本：
  ```zsh
  /Applications/Blender.app/Contents/MacOS/Blender --background <文件.blend> --python <脚本.py>
  ```
- 第三版的构建脚本在 `assets/source/midgard_courtyard/v3/build_headland.py`，可以作为摆放和碰撞标记的参考，**不要直接改它**，复制到 `v4/` 再改。

## 文件组织

```
assets/source/midgard_courtyard/v4/
  制作记录.md          # 每个资产的来源、提示词、修改记录
  props/
    rune_stone_a.blend  # 每个主资产一个 .blend
    rune_stone_b.blend
    longhouse_ruin.blend
    exit_gate.blend     # 包含 dormant / awakened 两套
    entry_shutter.blend
    basalt_rocks.blend
  build_headland_v4.py  # 地形 + 摆放 + 碰撞，引用 props/ 下的资产
  headland_v4.blend

assets/models/midgard/courtyard/v4/
  headland.glb          # 运行时
  *.png                 # 贴图
```

## 资产规范

| 项目 | 要求 |
| --- | --- |
| 比例 | 1 Blender 单位 = 1 Godot 米。玩家精灵约 1.7 米高，符文石碑 2.5–4 米，出口门 4–5 米 |
| 面数 | 主资产 3k–15k 三角面；散布物 500–2k。镜头是中远距离，形体比微细节重要（风格文档第 12 节原则二） |
| 形体 | 每个主资产必须有清楚的大中小三级形体：大剪影 → 中等结构（雕刻带、断口、木梁接头）→ 小细节（裂纹、凿痕，用法线贴图） |
| 雕刻 | 交织纹和符文用高模烘焙法线，或用实际几何凹凸，**不能**只画在颜色贴图上 |
| 积雪 | 主资产的顶面朝上部分加积雪：几何堆雪或顶面遮罩材质，二选一，全场统一 |
| 贴图 | Albedo + Normal + Roughness（可合并 ORM），1K–2K。颜色走插画风格：明暗分块清楚，不要照片质感 |
| 材质区分 | 石材、木材、金属（铁箍、钉）三种质感必须看得出不同（风格文档第 11 节） |
| 原点 | 放在底部中心，方便摆放 |
| 命名 | 节点名沿用 v3 的分组习惯（`Terrain`、碰撞标记、门分组），代码靠 `find_child` 查找，改名要同步改 `fimbulwinter_courtyard_stage.gd` |
| 导出 | glTF 2.0 二进制（.glb），+Y 向上，应用变换 |

## 出口门的两种状态

- 同一个 `exit_gate.blend` 里放两个集合：`Gate_Dormant` 和 `Gate_Awakened`。
- 破败态的碎块要能对应到完整态的部件，方便在 Godot 里做「碎块归位」的复原动画。每个碎块单独成一个节点，命名成对，例如 `lintel_L_broken` ↔ `lintel_L`。
- 符文槽单独成一个网格，方便在 Godot 里换发光材质。

## 每个资产完成后

1. 在 Blender 里渲染一张与游戏镜头同角度的预览（正交，约 50° 俯角，冬夜光照），保存到 `assets/source/midgard_courtyard/v4/previews/<资产名>.png`。
2. 和目标图放在一起看：剪影、比例、材质是否一致。
3. 导入 Godot，在实机里截一张图（见 05）。只在 Blender 里好看不算完成。
4. 在 `制作记录.md` 里记一行：资产名、面数、贴图尺寸、预览图路径。

## 不要做的事

- 不要用 Python 拼方块代替雕刻；程序化只用来摆放和散布。
- 不要把同一块石碑原样复制十几次。至少 2–3 个变体，再加旋转、缩放、积雪量的随机。
- 不要下载外部素材库模型直接使用。若必须用，先在 `进度.md` 里列出来源和授权，等制作人同意，并登记到 `assets/LICENSES.md`。
