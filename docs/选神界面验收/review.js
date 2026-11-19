const items = [
  {
    id: "cards", name: "新卡面：其余 69 张，已换进游戏",
    description: "按托尔那批的画法画完了另外 7 位神（每位 8 张）、12 张融合技和通用属性，77 张已全部换进游戏（游戏里用 768 × 1152，原图 1024 × 1536 留在 assets/source/card_art_v2_2026-11-19/）。Codex 放大检查后重画了 37 张（贴边的矛和弓、动物腿数、多出的靴子、误留的网和飞剑、重复的云纹），我又逐批看过。\n\n两点请你看一下：① 弗蕾亚「觉醒·金泪」是带伤的脸流下金色眼泪，切合卡意（受伤时掉金泪），但脸上血点偏多；② 新画法天空占比大，在石碑窗口里人物偏小，神力的标志色也比旧卡淡，靠人物和神力形状区分。如果想让人物更大，我可以把窗口里的插画再放大约 15%（只改代码，不用重画）。\n\n剑士、刺客、枪手、法师 4 张角色卡不在这次范围。",
    media: [
      { title: "实机：开局选神", image: "media/实机选神.webp", wide: true },
      { title: "实机：质变、觉醒、融合技、通用属性", image: "media/实机质变.webp", wide: true },
      { title: "奥丁：上排新、下排旧", image: "media/奥丁.webp", wide: true },
      { title: "洛基：上排新、下排旧", image: "media/洛基.webp", wide: true },
      { title: "弗蕾亚：上排新、下排旧", image: "media/弗蕾亚.webp", wide: true },
      { title: "巴德尔：上排新、下排旧", image: "media/巴德尔.webp", wide: true },
      { title: "澜：上排新、下排旧", image: "media/澜.webp", wide: true },
      { title: "弗雷：上排新、下排旧", image: "media/弗雷.webp", wide: true },
      { title: "斯卡蒂：上排新、下排旧", image: "media/斯卡蒂.webp", wide: true },
      { title: "融合技：上排新、下排旧", image: "media/融合技.webp", wide: true },
      { title: "通用：上排新、下排旧", image: "media/通用.webp", wide: true },
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
