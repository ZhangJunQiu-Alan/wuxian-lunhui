const items = [
  {
    id: "draugr_idle", name: "尸鬼 · 待机 A（复查）",
    description: "你选了 A 大剑待机。这版修了握矛：\n· 长矛对准两只手的掌心，左臂加了 IK，左手全程握在矛杆上；\n· 两只手的手指都收成拳，包住矛杆；\n· 双手比原动作往身前挪了最多 18 厘米，让矛杆不再擦到大腿甲。\n\n逐帧按真实模型检测：0 帧穿身体。",
    media: [{ title: "待机 A", video: "media/尸鬼待机A.mp4", poster: "media/尸鬼待机A.webp" }],
  },
  {
    id: "draugr_walk", name: "尸鬼 · 持矛推进走：选一个", options: true,
    description: "按你的意见重做：不要僵尸走，像斯巴达方阵持矛推进，正常走路速度。\n\nMixamo 没有现成的持矛走路，三个端枪走路挂上长矛后矛尖都朝地，已放弃。所以这两个是拼出来的：腿和身体用真实的走路动作，双臂每帧用 IK 摆成平端长矛——右拳在右胯旁、左拳在前，矛尖朝正前方略向上。逐帧检测 0 帧穿模。\n\n左 A：腿用「腰间持枪走」，身体挺直、步子沉稳，3.4 秒三步一循环。\n右 B：腿用「普通男性走路」，步子更大更有劲，1.3 秒一循环。\n\n这一项的镜头换成了侧面，能看清长矛是平端的。",
    media: [{ title: "左 A 沉稳推进 · 右 B 大步推进", video: "media/尸鬼持矛走.mp4", poster: "media/尸鬼持矛走.webp" }],
  },
  {
    id: "draugr_attack", name: "尸鬼 · 攻击 A（复查）",
    description: "你选了 A 刺刀突刺，意见是「还是有点穿模」。\n\n原因：剩下的穿模全在左手——长矛之前对准的是左手腕而不是掌心，突刺时左手又是张开的，矛杆从手指中间穿过去；另外长矛模型本身的杆子偏离中轴 4 厘米。\n\n这版：长矛模型重新对中；左臂 IK 让左手全程握在杆上；两只手的手指收拢包住矛杆。逐帧按真实模型检测：0 帧穿身体。",
    media: [{ title: "攻击 A", video: "media/尸鬼攻击A.mp4", poster: "media/尸鬼攻击A.webp" }],
  },
  {
    id: "draugr_other", name: "尸鬼 · 受击和死亡（复查）",
    description: "你已经通过了。握矛的改动（左手 IK、手指握拳）也作用到这两段上，所以重新渲染了一次。\n\n受击：4 帧矛杆边缘擦到大腿甲，不到 1 厘米。死亡：倒地时有几帧和大腿、地面有少量交叠；游戏里会在倒地瞬间让尸鬼松手，长矛单独掉在地上。",
    media: [{ title: "左 受击 · 右 死亡", video: "media/尸鬼受击死亡.mp4", poster: "media/尸鬼受击死亡.webp" }],
  },
  {
    id: "spirit_cast", name: "冰霜精魂 · 施法：选一个", options: true,
    description: "左 A：双手施法 01。双手先举过头顶蓄力，再向前推出，蓄力段明显。\n右 B：双手施法 02。直接向前推，更快。\n\n精魂的腿部骨骼保持不动，只用上半身动作，所以冰尾在所有动作里都是直的，没有被拉宽或折弯。施法时身体会侧着，这是原动作的站姿；我按双手推出的方向把动作转正了，冰锥会朝正前方飞。",
    media: [{ title: "左 A 双手施法 01 · 右 B 双手施法 02", video: "media/精魂施法.mp4", poster: "media/精魂施法.webp" }],
  },
  {
    id: "spirit_other", name: "冰霜精魂 · 待机、受击、死亡",
    description: "左：悬浮待机（Floating），双臂缓慢摆动。\n中：正面受击（Standing React Large From Front）。\n右：向后倒下（Falling Back Death）。\n\n离地 0.3 米。死亡现在是直接倒在地上，以后可以在游戏里加碎冰崩散的特效。雪雾、绕身碎冰和胸口发光都还没加，阶段 5 在 Godot 里做。",
    media: [{ title: "左 待机 · 中 受击 · 右 死亡", video: "media/精魂其他.mp4", poster: "media/精魂其他.webp" }],
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
