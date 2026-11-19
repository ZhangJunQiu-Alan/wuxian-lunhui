const items = [
  {
    id: "hitfeel", name: "打击感（按参考视频的六层调）",
    description: "参考视频（B 站那个 Godot 打击感拆解）我下载后交给 Gemini 逐帧分析，拿到了每一层的具体数值，按它调了一版：\n\n① 顿帧：打中的一瞬间整个游戏停住。剑士普通一刀 90 ms，砍死 120 ms，第 4 刀二刀流约 235 ms（参考是 100 / 130 / 250 ms）。刺客出手快，45 ms；法师每圈新星 50 ms；枪手射击不顿。\n② 震屏：重击更猛；庭院的 3D 镜头还会顺着出刀方向冲一下。\n③ 闪白：敌人从全白在 0.12 秒内褪回原色（原来是 0.08 秒硬切）。\n④ 压扁回弹：被砍中先压成 1.4 宽、0.6 高，再弹几下回原形。\n⑤ 火花和冲击波：火花从原来 8 根加到 14 根（砍死 22 根），顺着刀向喷出，命中点扩散一圈冲击波。\n⑥ 分层音效：挥刀（高频）+ 受击（中频）之外加了一层低频闷响，重击和砍死时更响。\n另外参考视频压轴那一刀的「反色冲击帧」也加了：二刀流那一刀画面反色约两帧再闪一下白；设置里关掉屏幕震动会一起关。\n\n录像是 60 帧，庭院里刷了几只加厚血量的尸鬼连砍。敌人还是旧的 2D 像素图：你说得对，敌人也要建模，敌人 3D 试点已经开了（先做尸鬼和冰霜精魂），流程和剑士一样分五个阶段。Codex 今晚额度用完了，4 点恢复后自动开始出设计方案，出来后我放到验收网站给你选。受击表情、受击动作等 3D 模型有了再加。\n\n数值都记在 docs/打击感.md，觉得哪一层太重或太轻，在意见里说就行。",
    media: [
      { title: "实机录像（60 帧）：连砍、第 4 刀二刀流、砍死", video: "media/打击感.mp4", poster: "media/打击感.webp" },
      { title: "每秒 6 帧抽帧：能看到压扁、金色二刀流、冲击波", image: "media/打击感帧.webp", wide: true },
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
