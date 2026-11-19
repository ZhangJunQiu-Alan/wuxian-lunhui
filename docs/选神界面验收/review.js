const items = [
  {
    id: "panel", name: "选卡界面：游戏里的石碑卡",
    description: "按你选的 A 立石神谕做进了游戏，选神、升级强化、质变、觉醒、融合技都用这一种石碑卡。下面全是 Godot 实机截图和录像，插画还是旧卡面（新卡面见下一项，全部画完后一起换）。\n\n品质按游戏里已有的四档：普通白、稀有蓝、史诗紫、传说金，刻纹的颜色就是品质色，品质越高越华丽：普通只有淡淡的刻纹；稀有刻纹发光、缓慢呼吸，背后飘几粒光点；史诗再加沿刻纹往上走的光带、石面扫过的高光、背后光晕；传说再加两侧符文逐个亮起、背后转动的光芒和更多光点。神明的技能、质变用神明自己的颜色和史诗的特效，觉醒、融合技用传说的特效。\n\n悬停不改颜色：石碑浮起、略微放大，悬停期间轻轻上下飘，移开后落回原位。录像里依次把鼠标停在每张卡上。\n\n你说的「白、绿、蓝」：游戏现在是白、蓝、紫、金四档，我沿用了；如果想改成白绿蓝紫金五档，在意见里说。",
    media: [
      { title: "实机录像：开局选神、四档品质、质变 / 觉醒 / 融合技，依次悬停", video: "media/面板动效.mp4", poster: "media/面板动效.webp" },
      { title: "四档品质：普通 / 稀有 / 史诗 / 传说", image: "media/四档品质.webp", wide: true },
      { title: "质变、觉醒、融合技、传说通用属性", image: "media/质变觉醒融合.webp", wide: true },
      { title: "开局选神", image: "media/开局选神.webp", wide: true },
      { title: "悬停：第 2 张浮起", image: "media/悬停.webp", wide: true },
    ],
  },
  {
    id: "cards", name: "新卡面：托尔第一批（B 电影厚涂）",
    description: "托尔的 8 张已按 B 画完：基础像、觉醒，以及三条质变（妙尔尼尔、雷暴云、静电场）和各自的觉醒。构图不再全是仰视半身，掷锤、雷云、山羊战车、电网都画出来了。我检查过手、锤子、山羊的腿；云海有一点重复的鱼鳞纹，已让后面几批避开。\n\n其余 69 张（另外 7 位神、12 张融合技、通用属性）Codex 正在按同样的画法画，画完我检查后一起换进游戏。如果托尔这批有要调整的方向（比如更亮、人物更大），现在说还来得及影响后面的批次。",
    media: [
      { title: "托尔 8 张：上排新、下排旧", image: "media/托尔卡面.webp", wide: true },
      { title: "托尔 · 基础像", image: "media/thor.webp" },
      { title: "觉醒 · 雷神", image: "media/thor_awaken.webp" },
      { title: "质变 · 妙尔尼尔", image: "media/thor_mjolnir.webp" },
      { title: "觉醒 · 山羊战车", image: "media/thor_cloud_awaken.webp" },
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
