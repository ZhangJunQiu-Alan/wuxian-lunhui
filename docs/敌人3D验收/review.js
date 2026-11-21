const items = [
  {
    id: "draugr_game", name: "尸鬼 · 矛尖刺中（第二次修改）",
    description: "按你的意见重做了出招距离：\n\n· 先在 Godot 里逐帧量了长矛顶点：突刺到最远时矛尖离尸鬼身体中心 1.9 米（上一版按骨骼方向估成 1.25 米，估短了），而且这个动作是斜着往左前方刺的，偏了 19°。\n· 现在尸鬼出招时身体右转 19°，让矛尖正对剑士；它停在约 1.76 米外（端着矛走路时矛尖伸出 1.52，碰不到人），1.87 米内开始突刺，刺到最远那一刻矛尖正好扎到剑士胸口，这一刻才判定掉血。\n· 剑士挨打：全身闪红、做受击动作，胸口从挨打的那一侧迸出红白碎屑和一圈冲击波，镜头往被刺的方向顿一下。\n· 上一版视频里剑士开了无敌，所以没有受伤反应；这次关掉了。\n· 原来每次掉血整个屏幕泛红 0.3 秒，也属于全屏闪烁，冻石庭院里已关掉（其他像素关卡还保留着）。\n\n倒地扬雪、风化消散和上一版一样。",
    media: [{ title: "尸鬼：推进 · 矛尖刺中剑士 · 受击 · 倒地 · 风化消散", video: "media/尸鬼实机.mp4", poster: "media/尸鬼实机.webp" }],
  },
  {
    id: "spirit_game", name: "冰霜精魂 · 游戏里",
    description: "· 离地 0.25 悬浮，上下轻轻起伏；移动时身体前倾；\n· 冰的身体：暗部比尸鬼浅，轮廓透出冷蓝光；\n· 胸口一团冰光，四片碎冰绕身旋转，冰尾下面贴地一层淡雪雾（上一版脚下那团黑斑是雪雾粒子的颜色出错，已修）；\n· 聚能 0.45 秒：胸口冰光变大变亮、碎冰转快收紧，双手推出的那一刻射出冰棱（发亮的冰锥，后面拖一串冷雾）；\n· 被砍死：向后倒下落地，胸口冰光一闪熄灭，碎冰向外炸开；之后和尸鬼一样风化消散。",
    media: [{ title: "冰霜精魂：悬浮 · 施法 · 冰棱 · 受击 · 倒下消散", video: "media/精魂实机.mp4", poster: "media/精魂实机.webp" }],
  },
  {
    id: "court_game", name: "整段实战（正常镜头）",
    description: "自动测试打完整个庭院的录像：雪崖前路 2 尸鬼 + 1 精魂，进庭院后 3 尸鬼 + 1 精魂，清完后开门、选赐福、离开。看正常镜头距离下敌人是否清楚、地面清晰度、和场景是否协调。\n\n打击感（顿帧、火花、击退等）除了去掉全屏闪烁，其余没改，下一步和你一起调。",
    media: [{ title: "冻石庭院全流程", video: "media/庭院实战.mp4", poster: "media/庭院实战.webp" }],
  },
];

const labels = { pending: "待验收", approved: "通过", revise: "需修改", rejected: "不要", A: "选左 A", B: "选右 B" };
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
    video.loop = true;
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
  const counts = { pending: 0, approved: 0, revise: 0, rejected: 0, A: 0, B: 0 };
  for (const item of items) {
    const state = saved[item.id]?.status || "pending";
    counts[state] += 1;
    for (const indicator of views.get(item.id)) {
      indicator.textContent = labels[state];
      indicator.dataset.state = state;
    }
  }
  document.querySelector("#progress").textContent = `已定 ${counts.approved + counts.A + counts.B} · 需修改 ${counts.revise} · 待验收 ${counts.pending}`;
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
  if (item.options) {
    form.querySelector(".decisions").innerHTML = ["pending", "A", "B", "revise"].map((v) =>
      `<label><input type="radio" name="status" value="${v}"${v === "pending" ? " checked" : ""}><span>${labels[v]}</span></label>`).join("");
  }
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
