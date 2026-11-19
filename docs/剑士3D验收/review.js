const items = [
  {
    id: "aim", name: "四个角色改成手动瞄准",
    description: "四个角色的普通攻击都改成玩家自己出：按住鼠标左键持续出招，方向朝鼠标；单击至少出一招（冷却没好时会在 0.15 秒内补上）。手柄推右摇杆就是朝摇杆方向出招。不再自动锁定最近的敌人。\n\n剑士、刺客：朝瞄准方向扇形斩 / 连刺。枪手：朝瞄准方向射击，不再要求敌人在射程内。法师：奥术新星本来就以自身为中心，改成按住攻击才释放。\n\n大招的范围从「屏幕内」改成「房间内」：剑士次元斩定住并重创房间里所有敌人（镜头外的也算）；刺客入阵曲找房间里的敌人瞬移斩，五百骑从房间一侧冲到另一侧。房间就是当前的活动范围：冻石庭院、雪村里是这一场遭遇的区域；旧的开放地图还没拆成房间，现在等于整张地图。\n\n角色介绍里太刀、左轮的说明同步改了（中英文）。录像是冻石庭院的近景，后半段绕着角色每个方向点一下，角色转身朝点击方向出招。",
    media: [
      { title: "近景录像：待机、跑、出招、绕一圈手动瞄准、冲刺、受击", video: "media/近景.mp4", poster: "media/近景.webp" },
      { title: "待机 / 跑 / 出招 / 朝下瞄准 / 朝上瞄准 / 冲刺", image: "media/近景动作.webp", wide: true },
    ],
  },
  {
    id: "katana", name: "太刀 3D 模型（替换占位长条）",
    description: "照三视图里的长刀做：刀身 0.70 m、带弧度的棱形截面，黄铜刀铐、刀镡、柄头，黑色柄卷配红色鲛皮，暗红棕漆面的刀鞘两端包铜。刀出鞘拿在右手，腰上挂的是空鞘。\n\n没有用 Tripo：细长的刀用图片转 3D 容易糊，几何也简单，我直接在 Blender 里建模，更干净，也不花积分。在游戏里墨意着色器下，刀身是浅钢色，鞘是深红棕。另外 10 把武器以后照同样的挂点和坐标做。",
    media: [
      { title: "侧视（照参考图排版：刀在上、鞘在下）", image: "media/太刀侧视.webp", wide: true },
      { title: "挂在身上：举刀、出招、待机侧面", image: "media/挂上身.webp", wide: true },
      { title: "待机、两种斩击、跑步的正面和侧面", image: "media/动作总览.webp", wide: true },
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
