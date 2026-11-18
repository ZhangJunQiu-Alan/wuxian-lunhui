const items = [
  {
    id: "layout", name: "从出生点到出口",
    description: "沿石路穿过前路遭遇和入口木闸，清理中庭后经过点亮的出口。全程巡检按约 1.5 秒间隔取自同一次实机运行。",
    media: [
      { title: "完整实机 · 从出生点到出口", video: "media/v5-traversal.mp4", poster: "media/v5-approach-fight.webp" },
      { title: "全程巡检总览", image: "media/v5-survey.webp", wide: true },
      { title: "第四版与第五版 · 前路和入口", image: "media/v5-compare-layout.webp", wide: true },
      { title: "内门敞开", image: "media/v5-entry-open.webp" },
      { title: "入庭后木闸落下", image: "media/v5-entry-sealed.webp" },
    ],
  },
  {
    id: "approach", name: "手绘雪崖前路",
    description: "复核出生点、弯路、干砌墙、石碑、火盆和冷杉林。经过木闸时，地面、墙线和雪坡应延续到中庭。",
    media: [
      { title: "第四版与第五版 · 前路交战", image: "media/v5-compare-layout.webp", wide: true },
      { title: "前路战场", image: "media/v5-approach-fight.webp" },
      { title: "出生点", image: "media/v5-courtyard.webp" },
      { title: "游戏镜头下的石碑底稿", image: "media/v5-stele.webp" },
    ],
  },
  {
    id: "architecture", name: "遗迹与双态出口",
    description: "破败态保留左侧落木。清场后出口木梁归位，符文亮起，竖向光幕照亮门前雪地。",
    media: [
      { title: "第四版与第五版 · 双态出口", image: "media/v5-compare-architecture.webp", wide: true },
      { title: "清场前 · 断梁与木门", image: "media/v5-dormant-gate.webp" },
      { title: "清场后 · 冰蓝光幕", image: "media/v5-restored-gate.webp" },
    ],
  },
  {
    id: "flagstones", name: "石板、雪地与路沿",
    description: "检查两区的积雪石板、墙脚和雪缘，以及前路到内门的连续铺地。",
    media: [
      { title: "第四版与第五版 · 中庭铺地", image: "media/v5-compare-flagstones.webp", wide: true },
      { title: "前路至内门", image: "media/v5-entry-open.webp", wide: true },
    ],
  },
  {
    id: "fjord", name: "冷杉林、断崖与冰海",
    description: "检查不同高度和积雪轮廓的冷杉、崖壁纹层及崖下浮冰，并沿全程巡检核对画面边界。",
    media: [
      { title: "第四版与第五版 · 出生点视野", image: "media/v5-compare-fjord.webp", wide: true },
      { title: "出口后的雪崖", image: "media/v5-open-gate.webp", wide: true },
    ],
  },
  {
    id: "combat", name: "战斗可读性与遮挡",
    description: "前路与中庭保留战斗空地。角色在被前景物件挡住时显示冷色剪影。",
    media: [
      { title: "第四版与第五版 · 门边出刀", image: "media/v5-compare-combat.webp", wide: true },
      { title: "长厅木架后的剪影", image: "media/v5-longhouse-occlusion.webp" },
      { title: "中庭命中反馈", image: "media/v5-strike.webp" },
    ],
  },
  {
    id: "concept", name: "选定目标图与实机",
    description: "对照 A1、B1 和 C1 检查构图、颜色与笔触密度。A1 的战斗和光幕同框，实机在清场后点亮出口。",
    media: [
      { title: "A1 · 中庭", image: "media/v5-concept-court.webp", wide: true },
      { title: "B1 · 雪崖前路", image: "media/v5-concept-approach.webp", wide: true },
      { title: "C1 · 出口两态", image: "media/v5-concept-exit.webp", wide: true },
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
