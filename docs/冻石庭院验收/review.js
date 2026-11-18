const items = [
  {
    id: "layout", name: "从出生点到出口",
    description: "沿石路穿过前路遭遇和入口木闸，进入扩建后的中庭清场，再从点亮的东门离开。视频和巡检取自石碑接入后的同一次实机运行。",
    media: [
      { title: "完整实机 · 从出生点到出口", video: "media/v8-traversal.mp4", poster: "media/v8-approach-fight.webp" },
      { title: "全程巡检总览", image: "media/v8-survey.webp", wide: true },
      { title: "内门敞开", image: "media/v8-entry-open.webp" },
      { title: "入庭后木闸落下", image: "media/v8-entry-sealed.webp" },
    ],
  },
  {
    id: "court", name: "中庭扩建与镜头",
    description: "可走面积扩到上一版的 1.76 倍，东西门之间宽 20.3 世界单位，南北纵深多了 31%。进门时看不到东门，走到中央和东侧时镜头会跟着移动。",
    media: [
      { title: "新旧中庭俯视布局", image: "media/v8-plan.webp", wide: true },
      { title: "进门 · 敌人出现", image: "media/v8-broad-court.webp" },
      { title: "中庭中央 · 符文圆环", image: "media/v8-court-pan-center.webp" },
      { title: "东侧 · 冰井与出口", image: "media/v8-court-pan-east.webp" },
    ],
  },
  {
    id: "cover", name: "掩体、地面与边缘叙事",
    description: "三处掩体：西北高断碑、东南矮裂石、东北冰井，约为角色身高的 1.6–2 倍，最窄通道约 3.9 个冲刺距离。地面有薄冰、翘起的裂石板、踩雪路和背风积雪。墙边有倒塌的武器架、断矛、圆盾、冻旗和头盔。",
    media: [
      { title: "战斗 · 断碑旁挥砍", image: "media/v8-strike.webp" },
      { title: "断碑后的剪影", image: "media/v8-cover-occlusion.webp" },
      { title: "东侧 · 薄冰、踩雪路与北墙武器架", image: "media/v8-court-pan-east.webp", wide: true },
    ],
  },
  {
    id: "approach", name: "手绘雪崖前路",
    description: "复核出生点、弯路、干砌墙、火盆和冷杉林。前路为暮色冷蓝调，靠近木闸时逐渐回到中庭色温。",
    media: [
      { title: "前路战场", image: "media/v8-approach-fight.webp" },
      { title: "前路", image: "media/v8-approach.webp" },
      { title: "出生点", image: "media/v8-courtyard.webp" },
    ],
  },
  {
    id: "stelae", name: "前路五块石碑",
    description: "五块碑各用一种碑面：双股交织、紧编绳、素面符文碑、狼首兽纹、斜裂残纹，符文都是正向。碑后补地按原画补出树枝和雪面笔触。",
    media: [
      { title: "接入前后对比", image: "media/v8-stele-compare.webp", wide: true },
      { title: "1 · 双股交织", image: "media/v8-stele-a.webp" },
      { title: "2 · 紧编绳", image: "media/v8-stele-b.webp" },
      { title: "3 · 素面符文碑", image: "media/v8-stele-c.webp" },
      { title: "4 · 狼首兽纹", image: "media/v8-stele-d.webp" },
      { title: "5 · 斜裂残纹", image: "media/v8-stele-e.webp" },
      { title: "主碑后的剪影", image: "media/v8-stele-occlusion.webp" },
    ],
  },
  {
    id: "architecture", name: "遗迹与双态出口",
    description: "破败态保留左侧落木。清场后出口木梁归位，符文亮起，竖向光幕照亮门前雪地。",
    media: [
      { title: "清场前 · 断梁与木门", image: "media/v8-dormant-gate.webp" },
      { title: "清场后 · 冰蓝光幕", image: "media/v8-restored-gate.webp" },
      { title: "出口后的雪崖", image: "media/v8-open-gate.webp", wide: true },
    ],
  },
  {
    id: "combat", name: "战斗可读性与遮挡",
    description: "中庭中间保留大片空地。角色被长厅、冷杉、石碑或掩体挡住时显示冷色剪影。",
    media: [
      { title: "中庭命中反馈", image: "media/v8-strike.webp" },
      { title: "长厅木架后的剪影（轮次 07，扩建前）", image: "media/v5-longhouse-occlusion.webp" },
      { title: "前路冷杉后的剪影（轮次 07）", image: "media/v5-approach-fir-occlusion.webp" },
    ],
  },
  {
    id: "concept", name: "选定目标图与实机",
    description: "对照 A1、B1 和 C1 检查构图、颜色与笔触密度。",
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
