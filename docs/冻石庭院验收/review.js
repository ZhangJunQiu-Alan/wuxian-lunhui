const items = [
  {
    id: "brazier", name: "火盆位置",
    description: "入口木闸西侧的火盆原来叠进了左立柱，现在挪到立柱外侧的地面上。巡检时另外两只也有轻微贴边：雪崖火盆压住矮墙，东闸火盆贴着斜撑，一起挪开了。长厅旁和前路中段两只没动。",
    media: [
      { title: "入口木闸 · 修好后，角色站在旁边", image: "media/r9-brazier-entry.webp", wide: true },
      { title: "雪崖", image: "media/r9-brazier-snowcliff.webp" },
      { title: "前路中段（未动）", image: "media/r9-brazier-approach.webp" },
      { title: "长厅旁（未动）", image: "media/r9-brazier-longhouse.webp" },
      { title: "东闸旁", image: "media/r9-brazier-east.webp" },
    ],
  },
  {
    id: "exit", name: "碰到光门就离开",
    description: "选完赐福后，角色脚下一碰到门洞里光幕的底边就结算离开，门柱外侧不触发。光门后面的琥珀色光圈去掉了，因为蓝色光幕本身已经标出出口。",
    media: [
      { title: "完整实机 · 从出生点到出口", video: "media/r9-traversal.mp4", poster: "media/r9-poster.webp" },
      { title: "走到门槛前", image: "media/r9-threshold-before.webp" },
      { title: "碰到光幕 · 结算", image: "media/r9-threshold-after.webp" },
    ],
  },
];

const labels = { pending: "待验收", approved: "通过", revise: "需修改" };
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
  const counts = { pending: 0, approved: 0, revise: 0 };
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
