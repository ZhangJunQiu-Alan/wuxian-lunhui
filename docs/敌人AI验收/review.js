const items = [
  {
    id: "draugr_moves", name: "尸鬼 · 垫步突刺、近身横扫、硬直和跪地",
    description: "近景。剑士开了 5000 血只是为了录完，挨打反馈照常。\n\n· 血量 80：太刀一刀 22，4 刀死（每第 4 刀是二刀流双斩，伤害翻倍）。\n· 垫步突刺：停在离剑士约 2.3 米处（矛长 1.9 米 + 垫步 0.6 米），起手蓄力 0.36 秒后往前垫一步刺出，0.57 秒时矛尖到最远才判定。方向在起手时定死，侧闪就能躲。\n· 近身横扫（新动作，Mixamo「Great Sword Low Slash」套上长矛）：剑士贴到 1.3 米内就不刺了，把矛甩到左后方，0.56 秒后低扫过身前，扫到 1.5 米、左右各约 70°。\n· 挨刀：平时每刀踉跄 0.3 秒（停步、不能起手）；蓄力和出招时霸体，只闪白不打断；2 秒内连挨 3 刀就单膝跪地 1 秒（新动作，Mixamo「Livershot Knockdown」），跪着时受到的伤害 +50%，起身后连击数清零。\n· 砍死：尸体被击飞 1–1.5 米（不穿墙），边飞边倒，之后和以前一样掉矛、风化消散。\n· 现在只有招式打中才掉血，身体碰到不再算伤害。",
    media: [{ title: "尸鬼：走近突刺 → 贴身挨横扫 → 踉跄、跪地 → 第 4 刀砍死击飞", video: "media/尸鬼招式.mp4", poster: "media/尸鬼招式.webp" }],
  },
  {
    id: "spirit_moves", name: "冰霜精魂 · 后飘、冰锥瞄准线、脚下冰刺",
    description: "· 血量 40：太刀 2 刀死。\n· 冰锥：施法 0.6 秒，地上从精魂脚下沿出手方向铺一条瞄准线，越来越亮，一直跟着剑士转；出手前 0.15 秒方向锁定，线变白变粗，这时侧步就能躲开。\n· 冰刺：施法 0.55 秒，在剑士脚下画一圈预警，圈里慢慢填满，0.8 秒后一簇冰棱从地里刺出来，那时还站在圈里就挨打。\n· 两种法术轮流放，每次施法后歇约 1.9 秒。\n· 后飘：剑士近到 2 米内，精魂往后仰着飘开 2 米（0.7 秒，正后方是墙就往两边偏），之后 3 秒内不会再飘，追上去能砍到。\n· 视频里：冰锥（侧步躲开）→ 冰刺（站着挨了一下）→ 冲上去它飘开 → 追上去两刀砍死。",
    media: [{ title: "冰霜精魂：冰锥瞄准线 · 冰刺预警 · 后飘 · 两刀砍死", video: "media/精魂招式.mp4", poster: "media/精魂招式.webp" }],
  },
  {
    id: "court_fight", name: "庭院实战 · 正常镜头",
    description: "进庭院后 3 尸鬼 + 1 精魂一起上，正常游戏镜头。剑士是脚本控制的（挑最近的敌人、抓空当砍），不会闪避，所以挨打很多；同时出招的敌人数量不设上限（按你选的 B）。\n\n请看：敌人有没有威胁感、出招前的预兆够不够看清、打击感（命中闪白、火花、镜头顿挫、击飞）还缺什么。有想调的地方直接写在下面。",
    media: [{ title: "冻石庭院：四只敌人一起上", video: "media/庭院实战.mp4", poster: "media/庭院实战.webp" }],
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
