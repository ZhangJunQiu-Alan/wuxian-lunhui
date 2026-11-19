const items = [
  {
    id: "unarmed", name: "无武器设定图",
    description: "按你的决定，身体模型不带刀和刀鞘，朱红腰带保留。在阶段 2 定稿图上把太刀、短刀、刀鞘和刀穗去掉，腰间衣物补全。放大检查过，没有残留。衣服褶皱纹理被重新画了一部分，和原图不是逐像素相同。",
    media: [
      { title: "三视图 · 无武器（喂给 Tripo 多视图）", image: "media/三视图-无武器.webp", wide: true },
      { title: "正面单图 · 无武器（喂给 Tripo 单图）", image: "media/正面单图-无武器.webp" },
      { title: "对照：阶段 2 带刀原图", image: "media/三视图-旧.webp" },
    ],
  },
  {
    id: "candidate", name: "候选：选 B 多视图",
    description: "Tripo Pro 出了两个候选，都在 2.8 万三角面左右，带 4K 贴图。A 只用正面单图，背面是工具自己猜的：披肩整片盖住后背，左腰垂着一根细线（像原来刀穗的位置），披肩上还有一块灰色贴图空洞。B 用正、侧、背三张图，背面和三视图一致，后腰露出朱红腰带，没有这些缺陷。推荐 B。同意就点通过；想要 A 就选需修改并写明，我用 A 重新定稿。",
    media: [
      { title: "候选对比 · 上 A 单图，下 B 多视图", image: "media/候选对比.webp", wide: true },
      { title: "A 的缺陷：细线和灰色空洞", image: "media/A_缺陷.webp" },
      { title: "A 背面", image: "media/A_背面.webp" },
      { title: "B 背面", image: "media/B_背面.webp" },
      { title: "B 侧面", image: "media/B_侧面.webp" },
    ],
  },
  {
    id: "final", name: "定稿模型",
    description: "B 在 Blender 里修整：正面朝前、脚底在原点、身高 1.8 m，合并重复顶点，2.8 万三角面没减。发现一个问题：原文件的发丝和衣摆是单面薄片，从背后看马尾只剩几段碎片，像飘在头顶的毛刺；材质改成双面后正常了（右图）。还剩后颈和领口之间一道细缝，游戏镜头下看不到，先不修。\n\n你说脚有问题，查出来是 B 的脚两头都长了脚趾，长 0.36 m：Tripo 把背面图的脚跟当成了脚趾。已把 B 的脚删掉，换上 A 的脚（A 是从正面图猜的，脚跟正常），脚长变成 0.25 m，切口藏在绑腿里。脚用的是 A 的贴图，所以模型现在有两个材质，颜色看起来接得上。转台和八个角度都已重新渲染。",
    media: [
      { title: "转台 · 4 秒一圈", video: "media/定稿转台.mp4", poster: "media/定稿转台.webp" },
      { title: "八个角度", image: "media/定稿转台.webp", wide: true },
      { title: "脚：上改前，下改后", image: "media/脚部修正.webp", wide: true },
      { title: "马尾背面：左改前，右改后", image: "media/头部修正.webp", wide: true },
    ],
  },
  {
    id: "rigplan", name: "阶段 4 绑骨方案",
    description: "建议先用 Tripo 自带的自动绑骨（Mixamo 骨骼规范，每次 20 积分，模型已经在工作台里），效果不好再拿 Mixamo 对比。重点看跑步、挥刀、翻滚时衣摆会不会被腿撕开、披肩会不会穿进身体。衣摆、披肩和马尾先跟着身体动，之后再决定是否加摆动骨骼。武器挂点放两个：右手掌心 weapon_r，左腰腰带外侧 sheath_l（收刀时挂这里），11 把武器都按同一个握点建模。同意就点通过，阶段 4 按这个做。",
    media: [
      { title: "B 正面（绑骨用这个姿势）", image: "media/B_正面.webp" },
    ],
  },
];

const labels = { pending: "待验收", approved: "通过", revise: "需修改", rejected: "不要" };
const views = new Map();
let saved = {};

function makeMedia(asset) {
  const figure = document.createElement("figure");
  if (asset.wide || asset.video) figure.classList.add("wide");
  if (asset.material) figure.classList.add("material");
  if (asset.video) {
    const video = document.createElement("video");
    video.src = asset.video;
    video.poster = asset.poster;
    video.controls = true;
    video.playsInline = true;
    video.preload = "metadata";
    video.setAttribute("aria-label", asset.title);
    figure.append(video);
  } else {
    const link = document.createElement("a");
    link.href = asset.image;
    link.target = "_blank";
    link.rel = "noopener";
    const image = document.createElement("img");
    image.src = asset.image;
    image.alt = asset.title;
    image.loading = "lazy";
    link.append(image);
    figure.append(link);
  }
  const caption = document.createElement("figcaption");
  caption.textContent = asset.title;
  figure.append(caption);
  return figure;
}

function refreshProgress() {
  const counts = { pending: 0, approved: 0, revise: 0, rejected: 0 };
  for (const item of items) {
    const state = saved[item.id]?.status || "pending";
    counts[state] += 1;
    for (const indicator of views.get(item.id)) {
      indicator.textContent = labels[state];
      indicator.dataset.state = state;
    }
  }
  document.querySelector("#progress").textContent = `通过 ${counts.approved} · 需修改 ${counts.revise} · 待验收 ${counts.pending}`;
}

function addItem(item) {
  const part = document.querySelector("#review-item").content.cloneNode(true);
  const section = part.querySelector("section");
  section.id = item.id;
  section.setAttribute("aria-labelledby", `${item.id}-title`);
  const title = part.querySelector("h2");
  title.id = `${item.id}-title`;
  title.textContent = item.name;
  part.querySelector(".description").textContent = item.description;
  part.querySelector(".evidence").append(...item.media.map(makeMedia));
  const link = document.createElement("a");
  link.href = `#${item.id}`;
  const state = document.createElement("span");
  state.className = "nav-state";
  link.append(item.name, state);
  document.querySelector("#sections").append(link);
  views.set(item.id, [part.querySelector(".item-status"), state]);

  const form = part.querySelector("form");
  form.setAttribute("aria-label", `${item.name}验收`);
  const entry = saved[item.id];
  if (entry) {
    form.elements.status.value = entry.status;
    form.elements.note.value = entry.note;
  }
  const footer = form.querySelector(".save-result");
  form.addEventListener("input", () => { footer.textContent = "有修改待保存"; });
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const button = form.querySelector("button");
    button.disabled = true;
    try {
      const payload = { id: item.id, status: form.elements.status.value, note: form.elements.note.value };
      const request = await fetch("api/review", {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload),
      });
      if (!request.ok) throw new Error("save");
      saved[item.id] = await request.json();
      refreshProgress();
      footer.textContent = "已保存到本机";
    } catch {
      footer.textContent = "保存失败。请确认本地验收服务正在运行后重试。";
    } finally {
      button.disabled = false;
    }
  });
  document.querySelector("#work").append(part);
}

(async () => {
  let connected = false;
  try {
    const response = await fetch("api/review", { cache: "no-store" });
    if (response.ok) {
      const data = await response.json();
      saved = data.items || {};
      connected = true;
    }
  } catch {
    // Evidence remains viewable when opened directly from disk.
  }
  items.forEach(addItem);
  refreshProgress();
  if (!connected) {
    const hint = document.createElement("p");
    hint.textContent = "从「启动验收.command」打开网站后即可保存反馈。";
    document.querySelector("#progress").after(hint);
  }
})();
