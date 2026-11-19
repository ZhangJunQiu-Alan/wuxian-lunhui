const items = [
  {
    id: "ingame", name: "接进庭院：实机流程",
    description: "像素剑士已经换成 3D 模型。逻辑没动，还是原来的 2D 角色在跑，3D 模型每帧跟着它的位置和状态：移动时跑步，跑步播放速度跟着实际移速走，脚不打滑；出招时转向鼠标方向，两种斩击交替，并按游戏里的出招时间加速；空格冲刺；受击闪红并播放受击动作。身高约 1.5 个世界单位（头顶实测 1.46）。视频是自动测试走完整个庭院的录像：雪崖接敌、破门、主庭院战斗、开门、选神。\n\n着色：不吃场景灯光，按场景太阳方向自己算两级明暗，降一点饱和、偏冷色，轮廓处略加深墨色，表面有细纸纹，和手绘背景对齐。敌人还是原来的 2D 素材。",
    media: [
      { title: "庭院实机录像（46 秒，自动测试操作）", video: "media/庭院实机.mp4", poster: "media/庭院实机.webp" },
      { title: "流程截图：开场 / 雪崖接敌 / 进门 / 结算 / 主庭院 / 选神", image: "media/庭院截图.webp", wide: true },
    ],
  },
  {
    id: "closeup", name: "近景：动作和着色细节",
    description: "把镜头拉近到剑士，依次待机、跑、四次斩击、冲刺、受击。看着色、比例、动作衔接有没有怪的地方。刀和刀鞘还是程序生成的占位长条（武器 3D 模型是待办里单独一项），挂在阶段 4 的两个挂点上。受击那一帧全屏发红是游戏原有的受伤提示。",
    media: [
      { title: "近景录像（16 秒）", video: "media/近景.mp4", poster: "media/近景.webp" },
      { title: "待机 / 跑 / 斩击 1 / 斩击 2 / 冲刺 / 受击", image: "media/近景动作.webp", wide: true },
    ],
  },
  {
    id: "xray", name: "被遮挡时的剪影",
    description: "剑士走到门、墙、柱子后面时，被挡住的部分透出一层冷蓝剪影，方便在战斗里找到自己。只有前面隔着明显距离的东西才算遮挡，自己的手臂挡住身体不会触发。下图是破门那段，剑士在门板后面。",
    media: [
      { title: "门后的剪影（录像第 16 秒）", image: "media/遮挡剪影.webp", wide: true },
    ],
  },
  {
    id: "death", name: "死亡（用你选的 B）",
    description: "用的是 Tripo 的向前扑倒。原动作 5.5 秒，开头一段站着摇晃，我跳过这段，从踉跄开始，整段压进 1.6 秒。游戏一死就会暂停，所以动作在暂停状态下继续播；结算界面原来几乎立刻弹出，现在等倒地后（约 2.0 秒）再出。下图从左到右是死后 0、0.4、0.8、1.2、1.6、2.0 秒。",
    media: [
      { title: "死亡过程（每 0.4 秒一帧）", image: "media/死亡.webp", wide: true },
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
