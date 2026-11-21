const items = [
  {
    id: "toughness", name: "1 · 几刀砍死",
    description: "现在剑士太刀一刀 22：尸鬼 27 血两刀死，冰霜精魂 21.6 血一刀死，敌人还没出招就倒了，谈不上威胁。房间里同屏只有 3–7 个敌人，单个要更耐打。（之后拿到神的祝福、装备，刀数会变少，这里按开局白板算。）",
    choices: [
      ["A", "尸鬼 4 刀、精魂 2 刀（推荐）：开局一个房间约 30–40 秒，尸鬼能完整出两三招，精魂能放两三发"],
      ["B", "尸鬼 6 刀、精魂 3 刀：更硬，适合配合下面的「霸体」做成要读招的敌人"],
      ["C", "保持现在的 2 刀、1 刀：快节奏割草感"],
    ],
  },
  {
    id: "draugr_moves", name: "2 · 尸鬼的招式",
    description: "现在只有一招：停在矛够得着的地方，蓄力 0.57 秒后突刺。玩家往后退一步就躲开了，招式单一。",
    choices: [
      ["A", "突刺时向前垫步 0.6 米（推荐）：往后退不一定躲得开，要横向闪或冲刺；动作不用重做，只加位移"],
      ["B", "垫步突刺 + 近身横扫：玩家贴到 1 米内时改用矛杆横扫 120°，把人推开；横扫动作要回 Mixamo 找"],
      ["C", "二连刺：第一刺之后紧跟一刺，第二刺更远；用同一个突刺动作接两遍"],
    ],
  },
  {
    id: "stagger", name: "3 · 尸鬼挨刀会不会被打断",
    description: "现在：出招过程中挨刀不打断，只闪白；没出招时挨刀会播一小段受击动作，但走路不停。",
    choices: [
      ["A", "韧性（推荐）：平时每刀都让它踉跄 0.3 秒（停步、播受击）；蓄力和出招时霸体不打断，但连续挨 3 刀会被打断、跪地 1 秒，期间受伤 +50%"],
      ["B", "完全霸体：怎么砍都不打断，只能躲开再还手（更像精英怪）"],
      ["C", "每刀都打断：蓄力时挨一刀就取消出招（玩家压制感强，尸鬼威胁小）"],
    ],
  },
  {
    id: "spirit_moves", name: "4 · 冰霜精魂的走位",
    description: "现在：在 3.2 米射程内原地不动，每 2.5 秒放一发冰锥，被近身也不跑，冲上去就砍死了。",
    choices: [
      ["A", "后飘拉开（推荐）：玩家靠近到 2 米内，它向后飘退约 2 米（有冷却），拉开后再放；逼着近战角色去追或用冲刺"],
      ["B", "化雾闪现：被近身时化成一团雪雾，在 4 米外重新凝出（冷却 6 秒），闪现那一下有明显的雾"],
      ["C", "保持原地不动"],
    ],
  },
  {
    id: "spirit_attack", name: "5 · 冰霜精魂的攻击",
    description: "现在：单发冰锥，聚能 0.45 秒，没有瞄准提示。",
    choices: [
      ["A", "单发冰锥 + 地上一条瞄准线（推荐）：聚能时地上亮起一条细的冷蓝线指向玩家，出手前 0.15 秒锁定方向，看到线就能侧闪"],
      ["B", "三发扇形冰锥：中间一发瞄准，两侧各偏 15°，也带瞄准线；对走位要求更高"],
      ["C", "脚下冰刺：在玩家脚下画一个冰圈，0.8 秒后冒出冰刺；和尸鬼的直线突刺形成「直线 + 圆圈」两种躲法"],
    ],
  },
  {
    id: "tokens", name: "6 · 一群敌人怎么配合",
    description: "现在：所有敌人一起往玩家身上冲，同时出招。",
    choices: [
      ["A", "出招名额（推荐）：同一时间最多 2 个敌人在蓄力或出招，其他尸鬼在矛距外围着玩家游走、找侧面；玩家能一次处理一两个，但会被包围"],
      ["B", "不限制：所有敌人同时上，压力最大"],
    ],
  },
  {
    id: "knockback", name: "7 · 砍中和砍死的击退",
    description: "现在：普通一刀把敌人推开一点（2D 逻辑里的击退）；砍死时尸体原地倒下。",
    choices: [
      ["A", "砍死时击飞（推荐）：最后一刀把尸体顺着刀向击飞 1–1.5 米、再倒地风化；普通一刀维持轻推"],
      ["B", "普通一刀推开更多（约 0.5 米）+ 砍死击飞：每刀都更有分量，但敌人容易被推出攻击范围"],
      ["C", "维持现状"],
    ],
  },
];

const labels = { pending: "待选", approved: "通过", revise: "另说", rejected: "不要", A: "选 A", B: "选 B", C: "选 C", D: "选 D" };
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
  const counts = { pending: 0, approved: 0, revise: 0, rejected: 0, A: 0, B: 0, C: 0, D: 0 };
  for (const item of items) {
    const state = saved[item.id]?.status || "pending";
    counts[state] += 1;
    for (const indicator of views.get(item.id)) {
      indicator.textContent = labels[state];
      indicator.dataset.state = state;
    }
  }
  document.querySelector("#progress").textContent = `已选 ${counts.A + counts.B + counts.C + counts.D} · 另说 ${counts.revise} · 待选 ${counts.pending}`;
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
  part.querySelector(".evidence").append(...(item.media || []).map(makeMedia));
  const link = document.createElement("a");
  link.href = `#${item.id}`;
  const state = document.createElement("span");
  state.className = "nav-state";
  link.append(item.name, state);
  document.querySelector("#sections").append(link);
  views.set(item.id, [part.querySelector(".item-status"), state]);

  const form = part.querySelector("form");
  if (item.choices) {
    const decisions = form.querySelector(".decisions");
    decisions.classList.add("choices");
    decisions.innerHTML = item.choices.map(([v, text]) =>
      `<label><input type="radio" name="status" value="${v}"><span><b>${v}</b> ${text}</span></label>`).join("") +
      `<label><input type="radio" name="status" value="revise"><span><b>另说</b> 都不合适，写在下面</span></label>` +
      `<input type="radio" name="status" value="pending" checked hidden>`;
    form.querySelector("legend").textContent = "选一个";
    form.querySelector("textarea").placeholder = "补充意见（可不填）";
  } else if (item.options) {
    form.querySelector(".decisions").innerHTML = ["pending", "A", "B", "revise"].map((v) =>
      `<label><input type="radio" name="status" value="${v}"${v === "pending" ? " checked" : ""}><span>${labels[v]}</span></label>`).join("");
  }
  form.setAttribute("aria-label", `${item.name}选择`);
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
