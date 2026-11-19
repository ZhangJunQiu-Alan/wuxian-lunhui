const items = [
  {
    id: "motions", name: "持刀动作（已修双手交叉）",
    description: "你说待机时双手交叉过头、别的动作也有。原因：Mixamo 骨架静止时是 T-pose（双臂水平），Tripo 骨架是 A-pose（双臂斜向下），我原来按「相对静止姿势的旋转差」转动作，手臂整体多转了 45°，于是交叉、插进身体。现在改成按骨骼指向对齐：每根骨头指向和 Mixamo 原动作一样的方向。待机变成双手在身前合握刀柄，和 Mixamo 原版一致；所有动作都重新转换、重新渲染了。\n\n仍有的问题：大步站姿时衣摆被两腿撑开；冲刺是持弓动作，刀会朝侧后方。白色长条是占位刀。",
    media: [
      { title: "待机 · Great Sword Idle", video: "media/mx_idle.mp4", poster: "media/mx_idle.webp" },
      { title: "跑步 · Great Sword Run", video: "media/mx_run.mp4", poster: "media/mx_run.webp" },
      { title: "攻击 · 低位斩", video: "media/mx_attack.mp4", poster: "media/mx_attack.webp" },
      { title: "攻击 2 · 下劈（以后做连击）", video: "media/mx_attack2.mp4", poster: "media/mx_attack2.webp" },
      { title: "受击 · Great Sword Impact", video: "media/mx_hit.mp4", poster: "media/mx_hit.webp" },
      { title: "七个动作逐帧总览", image: "media/动作总览.webp", wide: true },
    ],
  },
  {
    id: "dash", name: "冲刺：A（脸部变形第二次修）",
    description: "上一版没修对，抱歉：我改的是头发部件，真正的脸和脖子是另一块网格，脸上平均约四成权重在颈骨上；而且删旧权重的脚本有 bug，没删干净。这次：脸在下巴线以上全部跟头骨走，只有脖子（下巴以下）和颈骨过渡。验证方法换了：在头骨坐标里量脸部 372 个顶点在所有动作每一帧的偏移，改前冲刺最大约 6 cm、死亡约 9 cm，改后全部为 0。下图前两行用跟着头走的相机拍：改前下巴明显歪，改后和静止姿势一模一样；第三行是预览视频的角度。所有动作视频都已按新权重重新渲染。",
    media: [
      { title: "A · Mixamo 前闪避（1.0 秒，已修）", video: "media/mx_dash.mp4", poster: "media/mx_dash.webp" },
      { title: "脸部：改前 / 改后 / 预览角度", image: "media/脸部修正.webp", wide: true },
      { title: "B · Tripo 前滚翻（2.7 秒）", video: "media/dash.mp4", poster: "media/dash.webp" },
    ],
  },
  {
    id: "death", name: "死亡：选 A",
    description: "Mixamo 也没有单独的大剑死亡。A 是 Mixamo 的剑盾后倒，2.3 秒，握刀姿势正常。B 是 Tripo 的「战败」向前扑倒，5.5 秒，节奏慢，前面还有一段站着摇晃。推荐 A。同意就点通过；想要 B 就选需修改写「用 B」。",
    media: [
      { title: "A · Mixamo 向后倒（2.3 秒）", video: "media/mx_death.mp4", poster: "media/mx_death.webp" },
      { title: "B · Tripo 向前扑倒（5.5 秒）", video: "media/death.mp4", poster: "media/death.webp" },
    ],
  },
  {
    id: "rig", name: "骨骼、权重和挂点",
    description: "骨骼和权重用 Tripo 的（65 根骨骼，手指也有权重，换过的脚也蒙上了）。Mixamo 也给我们的模型绑了一套，但手指没有权重，就没用。右手 weapon_r 在握拳的拳心，刀身从食指一侧伸出；左腰 sheath_l 插在腰带里，往后斜约 30°（深色长条是占位刀鞘）。导出的 swordsman_rigged.glb 已在 Godot 里实测：7 个动作、65 根骨骼都在，两个挂点自动变成 BoneAttachment3D。顺手修了一个问题：Blender 导出的 JPEG 贴图 Godot 读不了，已重新编码，阶段 3 的模型也一起修了。同意就点通过，进入阶段 5 接入游戏。",
    media: [
      { title: "挂点：待机和跑步的正、侧、背面", image: "media/挂点.webp", wide: true },
      { title: "对照：Tripo 自带的 6 个动作（没用）", image: "media/tripo动作总览.webp", wide: true },
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
