const key = "fimbulwinter-model-review-v1";
const byId = (id) => document.getElementById(id);
let review = {};
try {
  review = JSON.parse(localStorage.getItem(key) || "{}");
} catch {
  byId("count").textContent = "浏览器未开放本地保存，请导出审核";
}
const pathFor = (path) => "../../" + path;
const allModels = [...qualityModels, ...darkModels, ...originalModels];
let lastFiltered = [];
const statusFor = model => {
  const entry = review[model.id];
  if (entry?.assetSha256 && entry.assetSha256 !== model.sha256) return "待审核";
  return entry?.status || "待审核";
};
function updateProgress() {
  const approved = models.filter(model => statusFor(model) === "通过").length;
  const revision = models.filter(model => statusFor(model) === "需修改").length;
  byId("review-progress").textContent = `通过 ${approved} / ${models.length} · 需修改 ${revision} · 待审核 ${models.length-approved-revision}`;
  byId("review-progress-meter").max = models.length || 1;
  byId("review-progress-meter").value = approved;
}
const styles = {
  quality: {models: qualityModels, batch: "task3d_mythic_production_2026-11-15", note: "37 件精细模型 · 本批新增 23 件角色、兵器、神话建筑与环境设施，均待人工审批。", title: "神话建筑 · 组合评审", description: "奥丁门廊、世界树祭坛、命运之井、彩虹桥与神祇祭坛的原创组合展示。图中为 Blender 渲染；角色和建筑均可逐件旋转查看。本批造型与动作仍待审批，尚未接入实际战斗和房间生成。"},
  dark: {models: darkModels, batch: "task3d_rooms_dark_2026-11-14", note: "冷灰黑石、焦木、脏雪与暗橙符文。"},
  original: {models: originalModels, batch: "task3d_rooms_2026-11-14", note: "原版的圆润石材、暖木与亮雪。"}
};
let activeStyle = "quality";
models = qualityModels;

function setStyle(style) {
  activeStyle = style;
  byId("new-only").disabled = style !== "quality";
  byId("engine-preview").hidden = style !== "quality";
  const selectedStyle = styles[style];
  models = selectedStyle.models;
  for (const name of Object.keys(styles)) byId(name + "-style").setAttribute("aria-pressed", String(style === name));
  byId("style-note").textContent = selectedStyle.note;
  byId("assembly-title").textContent = selectedStyle.title || "房间组合样例";
  byId("assembly-description").textContent = selectedStyle.description || "中央石桥穿过虚空，左右两侧留出绕行路线。地刺在左侧通道，拉杆和符文陷阱在右侧，出口闸门位于远端。机关关联可在关卡编辑时配置。";
  const all = document.createElement("option");
  all.value = "";
  all.textContent = "全部类型";
  byId("category").replaceChildren(all);
  for (const category of new Set(models.map((model) => model.category))) {
    const option = document.createElement("option");
    option.value = option.textContent = category;
    byId("category").append(option);
  }
  const batch = selectedStyle.batch;
  byId("assembly-art").querySelector("img").src = pathFor("assets/source/" + batch + "/previews/room_assembly.png");
  byId("assembly-art").querySelector("img").alt = byId("assembly-title").textContent;
  byId("assembly-download").href = pathFor("assets/source/" + batch + "/room_assembly.blend");
  byId("manifest-download").href = pathFor("assets/source/" + batch + "/manifest.json");
  render();
}

function openImage(src, caption) {
  byId("full-image").src = src;
  byId("full-image").alt = caption;
  byId("caption").textContent = caption;
  byId("viewer").showModal();
}

function store(id, entry, label) {
  review[id] = {...entry, assetSha256: allModels.find(model => model.id === id)?.sha256 || ""};
  try {
    localStorage.setItem(key, JSON.stringify(review));
    label.textContent = "已保存到当前浏览器";
    updateProgress();
    return true;
  } catch {
    label.textContent = "本地保存失败，请导出审核";
    return false;
  }
}

function link(label, path) {
  const a = document.createElement("a");
  a.textContent = label;
  a.href = pathFor(path);
  a.download = path.split("/").at(-1);
  return a;
}

function render() {
  const search = byId("search").value.trim().toLowerCase();
  const category = byId("category").value;
  const filter = byId("review-filter").value;
  const selected = models.filter((model) =>
    (!category || model.category === category) &&
    (!filter || statusFor(model) === filter) &&
    (!(activeStyle === "quality" && byId("new-only").checked) || model.current_batch) &&
    (!search || [model.name, model.id, model.rooms, model.description].join(" ").toLowerCase().includes(search))
  );
  lastFiltered = selected;
  updateProgress();
  byId("count").textContent = `${selected.length} / ${models.length} 件`;
  byId("empty").hidden = selected.length !== 0;
  byId("models").replaceChildren(...selected.map((model) => {
    const row = document.createElement("article");
    row.className = "model";
    row.dataset.id = model.id;
    const art = document.createElement("button");
    art.className = "image-button";
    art.type = "button";
    art.setAttribute("aria-label", "放大" + model.name);
    const image = new Image();
    image.src = pathFor(model.preview) + "?v=" + model.sha256;
    image.alt = model.name + "模型渲染预览";
    image.loading = "lazy";
    art.append(image);
    art.addEventListener("click", () => openImage(image.src, model.name));
    const info = document.createElement("div");
    info.className = "info";
    for (const [tag, className, text] of [
      ["p", "kind", model.category],
      ["h3", "", model.name],
      ["p", "filename", model.glb.split("/").at(-1)],
      ["p", "description", model.description],
      ["p", "usage", "适用房间 · " + model.rooms]
    ]) {
      const element = document.createElement(tag);
      element.className = className;
      element.textContent = text;
      info.append(element);
    }
    for (const preview of model.additional_previews || []) {
      const detail = document.createElement("button");
      detail.type = "button";
      detail.className = "engine-preview detail-preview";
      detail.textContent = preview.label;
      detail.addEventListener("click", () => openImage(pathFor(preview.path), model.name + " · " + preview.label));
      info.append(detail);
    }
    const specs = document.createElement("div");
    specs.className = "specs";
    const geometry = document.createElement("strong");
    geometry.textContent = model.triangles.toLocaleString() + " 三角形";
    const dimensions = document.createElement("p");
    dimensions.textContent = model.dimensions_blender_xyz.join(" × ") + " m";
    const status = document.createElement("p");
    status.className = "status";
    status.textContent = model.status;
    const links = document.createElement("div");
    links.className = "links";
    links.append(link(".blend", model.blend), link(".glb", model.glb));
    const inspect = document.createElement("button");
    inspect.className = "inspect-model";
    inspect.type = "button";
    inspect.textContent = "旋转查看 / 动画";
    inspect.addEventListener("click", () => window.openModel3D(model));
    specs.append(geometry, dimensions, status, links, inspect);
    const editor = document.createElement("div");
    editor.className = "review";
    const label = document.createElement("label");
    label.textContent = "审核结果";
    const select = document.createElement("select");
    select.setAttribute("aria-label", model.name + "审核结果");
    for (const value of ["待审核", "通过", "需修改"]) {
      const option = document.createElement("option");
      option.textContent = value;
      select.append(option);
    }
    select.value = statusFor(model);
    const note = document.createElement("textarea");
    note.setAttribute("aria-label", model.name + "修改意见");
    note.placeholder = "记录造型、比例或材质修改意见";
    note.value = review[model.id]?.note || "";
    const saved = document.createElement("span");
    saved.className = "saved";
    saved.setAttribute("role", "status");
    if (review[model.id]?.assetSha256 && review[model.id].assetSha256 !== model.sha256) saved.textContent = "模型已更新，旧意见保留，请复核";
    label.append(select);
    editor.append(label, note, saved);
    const save = () => store(model.id, {
      status: select.value, note: note.value, updatedAt: new Date().toISOString()
    }, saved);
    select.addEventListener("change", () => {
      save();
      if (byId("review-filter").value) render();
    });
    note.addEventListener("input", save);
    row.append(art, info, specs, editor);
    return row;
  }));
}

for (const id of ["search", "category", "review-filter", "new-only"]) {
  byId(id).addEventListener(id === "search" ? "input" : "change", render);
}

byId("export").addEventListener("click", () => {
  const output = {
    schemaVersion: 2,
    batch: styles.quality.batch,
    visibleStyle: activeStyle,
    exportedAt: new Date().toISOString(),
    models: allModels.map((model) => ({
      id: model.id, name: model.name, glb: model.glb,
      status: statusFor(model),
      note: review[model.id]?.note || "",
      assetSha256: review[model.id]?.assetSha256 || "",
      updatedAt: review[model.id]?.updatedAt || ""
    }))
  };
  const url = URL.createObjectURL(new Blob([JSON.stringify(output, null, 2)], {type:"application/json"}));
  const a = document.createElement("a");
  a.href = url;
  a.download = "芬布尔之冬-模型审核.json";
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 5000);
});

byId("assembly-art").addEventListener("click", () => {
  const image = byId("assembly-art").querySelector("img");
  openImage(image.src, byId("assembly-title").textContent);
});
byId("dark-style").addEventListener("click", () => setStyle("dark"));
byId("original-style").addEventListener("click", () => setStyle("original"));
setStyle("quality");

byId("quality-style").addEventListener("click", () => setStyle("quality"));

byId("engine-preview").addEventListener("click", () => openImage(pathFor("assets/source/task3d_mythic_production_2026-11-15/previews/godot_assets.png"), "Godot 组合预览 · 独立检查场景，非最终游戏灯光"));

window.assetReview = {
  get: id => review[id] || {},
  status: statusFor,
  filtered: () => lastFiltered,
  save: (model, entry) => {
    const success = store(model.id, {...entry, updatedAt: new Date().toISOString()}, byId("import-status"));
    render();
    return success;
  }
};
byId("import-review").addEventListener("change", async event => {
  const file = event.target.files[0];
  if (!file) return;
  try {
    if (file.size > 2_000_000) throw new Error("文件超过 2 MB");
    const input = JSON.parse(await file.text());
    if (!Array.isArray(input.models)) throw new Error("缺少 models 审核清单");
    const known = new Set(allModels.map(model => model.id));
    const statuses = new Set(["待审核", "通过", "需修改"]);
    const time = value => typeof value === "string" && Number.isFinite(Date.parse(value)) ? Date.parse(value) : 0;
    const entries = input.models.map(item => {
      if (!item || !known.has(item.id)) return null;
      if (!statuses.has(item.status) || typeof item.note !== "string" || item.note.length > 10000) throw new Error("审核状态或意见格式不正确");
      const stamp = typeof item.updatedAt === "string" && time(item.updatedAt) ? item.updatedAt : typeof input.exportedAt === "string" ? input.exportedAt : "";
      return [item.id, {status:item.status, note:item.note, updatedAt:stamp, assetSha256:typeof item.assetSha256 === "string" && /^[a-f0-9]{64}$/.test(item.assetSha256) ? item.assetSha256 : ""}];
    }).filter(Boolean);
    let imported = 0;
    for (const [id, entry] of entries) {
      if (review[id] && time(review[id].updatedAt) > time(entry.updatedAt)) continue;
      review[id] = entry; imported++;
    }
    try { localStorage.setItem(key, JSON.stringify(review)); }
    catch { byId("import-status").textContent = "已读入意见，但本地保存失败，请立即导出备份"; render(); return; }
    byId("import-status").textContent = `已导入 ${imported} 条审核，更新的本地意见予以保留`;
    render();
  } catch (error) {
    byId("import-status").textContent = "无法导入：" + error.message;
  } finally { event.target.value = ""; }
});
