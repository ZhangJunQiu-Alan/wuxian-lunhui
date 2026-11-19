const items = [
  {
    id: "turnaround", name: "三视图与正面图",
    description: "正、侧、背三面，A-pose，平光浅灰底，两把刀插在腰间。这两张会喂给图片生成 3D 工具，所以故意画得干净写实，不带水墨笔触；水墨感之后由游戏里的着色器做。已知问题：三视图的手臂比正面单图更下垂，背面短刀位置和刀鞘比例也没完全对齐。",
    media: [
      { title: "三视图", image: "media/三视图.webp", wide: true },
      { title: "正面单图（建模主要用这张）", image: "media/正面单图.webp" },
    ],
  },
  {
    id: "readability", name: "缩小后的识别点",
    description: "阶段 1 发现两处问题：短刀和地面颜色太近，朱砂碎点缩小后看不见。现在改成：短刀用浅色缠柄加朱砂刀穗，朱砂集中在一条宽腰带上，披肩背后加了一枝梅花。",
    media: [
      { title: "太刀与短刀，出鞘和带鞘", image: "media/武器.webp", wide: true },
    ],
  },
  {
    id: "face", name: "五官与发型",
    description: "壮年浪人，高束发髻配朱砂发绳，脸上有旧伤，留短须。这张用完整的墨意东方笔触，也是着色器风格的参考。",
    media: [
      { title: "头肩特写", image: "media/头像.webp" },
    ],
  },
  {
    id: "render", name: "游戏内渲染目标",
    description: "想象做成 3D 后，在游戏里用水墨风格着色器渲染出来的样子，是阶段 5 写着色器时的对照目标，不是实机画面。镜头和大小这次对了：斜俯视，角色约占画面三分之一。但水墨感仍偏弱，更像细描插画，墨色晕染和宣纸感不如头像那张。AI 生图在这点上很难再推，水墨感最终要靠着色器做出来。你觉得方向对就通过，不对就写下想要的感觉。",
    media: [
      { title: "游戏镜头 · 冻石庭院中", image: "media/渲染目标.webp", wide: true },
      { title: "近景 · 着色器细节", image: "media/渲染目标-近景.webp", wide: true },
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
