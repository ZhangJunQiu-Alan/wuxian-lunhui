from pathlib import Path
BATCH=Path(__file__).resolve().parent
ROOT=BATCH.parents[2]
p=ROOT/'docs/芬布尔之冬模型清单/review.js'
s=p.read_text()
s=s.replace('batch: "task3d_rooms_quality_2026-11-15", note:', 'batch: "task3d_architecture_quality_2026-11-15", note:')
s=s.replace('精细房间模块 · 砌石、老木、锻铁结构与扫描 PBR 材质。','14 件精细模型 · 新增建筑、掩体、补给箱与刻槽立碑。')
s=s.replace('title: "精细房间 · 组合评审"','title: "建筑与掩体 · 组合评审"')
s=s.replace('已确认的拱门与新制作的地面、断桥、地刺、祭盘、踏板、拉杆和火盆组合摆放。图中为 Blender 渲染；可另看 Godot 导入预览。碰撞、伤害、机关联动和房间生成尚未接入。','本批残墙、承重柱、石阶、路障、补给箱和立碑，与已有地面、门和火盆组合摆放。图中为 Blender 渲染；可另看 Godot 导入预览。组合布局用于美术评审，碰撞、掩体、掉落和随机房间生成尚未接入。')
s=s.replace('assets/source/task3d_rooms_quality_2026-11-15/previews/godot_assets.png','assets/source/task3d_architecture_quality_2026-11-15/previews/godot_assets.png')
if 'model.additional_previews' not in s:
    s=s.replace('    const specs = document.createElement("div");','''    for (const preview of model.additional_previews || []) {
      const detail = document.createElement("button");
      detail.type = "button";
      detail.className = "engine-preview detail-preview";
      detail.textContent = preview.label;
      detail.addEventListener("click", () => openImage(pathFor(preview.path), model.name + " · " + preview.label));
      info.append(detail);
    }
    const specs = document.createElement("div");''')
p.write_text(s)
print('REVIEW_UPDATED architecture batch and chest detail')
