const rooms = [
  { id: "crossroads", name: "十字路口", type: "起始房", reward: "选择路线", intro: "积雪盖住了车辙，两道木门通向不同的战场。",
    details: ["开放雪地作为移动与挥砍的练习区，远端两扇门都在视野里。", "安全区域。玩家可在第一场战斗前熟悉控制。", "门上预览候选奖励，选门后进入第一场小规模遭遇。"] },
  { id: "village", name: "雪村长屋", type: "普通遭遇", reward: "武器强化", intro: "长屋之间的主路便于聚怪，侧巷给了剑士切入远程敌人身边的机会。",
    details: ["中央主路和两条可绕行的侧巷。屋檐遮挡角色时淡出。", "尸鬼沿主路压近，冰霜精魂从侧后方射击。", "清场后试选刀伤或挥砍速度，再看下一房的门标。"] },
  { id: "mounds", name: "古老墓丘", type: "普通遭遇", reward: "最大生命", intro: "两座墓丘把战场分成环路，守住一边就能避免被两侧的尸鬼夹击。",
    details: ["两组墓石把场地分成可绕行的环路，入口留出转身空间。", "尸鬼从两侧分批出现，霜巨人斥候可作为后段变体。", "清场后提高本局最大生命，适合提前为 Boss 战留容错。"] },
  { id: "harbor", name: "峡湾码头", type: "普通遭遇", reward: "神恩强化", intro: "冬狼抢占栈道，沿岸的雪路则能绕到远程敌人的侧面。",
    details: ["栈道与岸边形成两条路线，中间保留至少两个换道口。", "冬狼逼近，冰霜精魂封直线。不同局可抽到不同刷怪顺序。", "强化已持有的神恩。尚无神恩时，此门可提供首次神恩。"] },
  { id: "shrine", name: "奥丁石阵", type: "安全奖励房", reward: "选择神恩", intro: "符文立石围着低矮祭坛，留出开阔的环形通道。",
    details: ["入口与出口错开，祭坛在中央，门和祭坛同时可见。", "安全区域。靠近祭坛进入神恩选择。", "可选托尔落雷或斯卡蒂冰箭等本局能力，再选择下一扇门。"] },
  { id: "camp", name: "旅人营火", type: "安全补给房", reward: "恢复生命", intro: "背风的岩壁藏着一处营火，给残血玩家一次整备机会。",
    details: ["营火是视线焦点，补给靠边摆放，进出口之间保持畅通。", "安全区域。靠近营火领取一次回复。", "回复生命后继续选门。选择这条路会占用一个中段房间。"] },
  { id: "lake", name: "冰湖 · 斯库尔", type: "关底 Boss", reward: "关卡结算", intro: "开阔冰面让玩家看清冲锋路线，湖岸为双方划出明确的边界。",
    details: ["主战区保留大片空地，断冰和树线布置在边缘。", "斯库尔蓄力后直线冲锋，低血量阶段会召唤冬狼。", "击败斯库尔，完成芬布尔之冬并进入关卡结算。"] }
];

const get = (id) => document.getElementById(id);
const artPath = (room) => `images/${room.id}.webp`;
const detailLabels = ["场地与走位", "敌人与节奏", "奖励与出口"];
let activeRoom;
let path;
let roomCleared;
let offers;

function selectRoom(room) {
  activeRoom = room;
  for (const button of get("rooms").children) {
    button.setAttribute("aria-current", String(button.dataset.room === room.id));
  }
  get("room-art").src = artPath(room);
  get("room-art").alt = `${room.name}斜俯视场景概念图`;
  get("room-type").textContent = room.type;
  get("room-name").textContent = room.name;
  get("room-description").textContent = room.intro;
  get("room-details").replaceChildren(...room.details.map((text, i) => {
    const group = document.createElement("div");
    const label = document.createElement("dt");
    const content = document.createElement("dd");
    label.textContent = detailLabels[i];
    content.textContent = text;
    group.append(label, content);
    return group;
  }));
}

for (const room of rooms) {
  const button = document.createElement("button");
  button.type = "button";
  button.dataset.room = room.id;
  const image = new Image();
  image.src = artPath(room);
  image.alt = "";
  const info = document.createElement("span");
  const name = document.createElement("strong");
  const type = document.createElement("small");
  name.textContent = room.name;
  type.textContent = room.type;
  info.append(name, type);
  button.append(image, info);
  button.addEventListener("click", () => selectRoom(room));
  get("rooms").append(button);
}
selectRoom(rooms[1]);

get("open-art").addEventListener("click", () => {
  get("full-art").src = artPath(activeRoom);
  get("full-art").alt = get("room-art").alt;
  get("art-caption").textContent = activeRoom.name;
  get("art-dialog").showModal();
});

function shuffle(pool) {
  const result = [...pool];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

function chooseOffers() {
  if (path.length === 5) return [rooms.at(-1)];
  let pool = rooms.slice(1, -1).filter((room) => !path.includes(room));
  if (path.length === 1) pool = pool.filter((room) => room.type === "普通遭遇");
  if (path.length === 2) {
    const combat = shuffle(pool.filter((room) => room.type === "普通遭遇"));
    const safe = shuffle(pool.filter((room) => room.type !== "普通遭遇"));
    return [combat[0], safe[0]];
  }
  return shuffle(pool).slice(0, 2);
}

function addAction(title, caption, handler) {
  const button = document.createElement("button");
  button.type = "button";
  const name = document.createElement("strong");
  name.textContent = title;
  button.append(name);
  if (caption) {
    const text = document.createElement("small");
    text.textContent = caption;
    button.append(text);
  }
  button.addEventListener("click", handler);
  get("route-actions").append(button);
}

function renderRoute() {
  const room = path.at(-1);
  get("path").replaceChildren(...Array.from({length: 6}, (_, index) => {
    const item = document.createElement("li");
    const order = document.createElement("small");
    order.textContent = String(index + 1).padStart(2, "0");
    item.append(order, path[index]?.name || (index === 5 ? "关底 Boss" : "待选择"));
    if (index === path.length - 1) item.setAttribute("aria-current", "step");
    if (index < path.length - 1) item.classList.add("done");
    return item;
  }));
  get("route-room").textContent = room.name;
  get("route-actions").replaceChildren();
  if (room.id === "lake" && roomCleared) {
    get("route-status").textContent = "路线预演完成。已击败斯库尔。";
    get("reset").focus();
  } else if (!roomCleared) {
    get("route-status").textContent = room.type.startsWith("安全") ? "领取奖励后可以继续。" : "模拟清场后开启出口。";
    addAction(room.id === "lake" ? "模拟击败斯库尔" : room.type.startsWith("安全") ? "领取奖励" : "模拟清场", room.reward, () => {
      roomCleared = true;
      if (room.id !== "lake") offers = chooseOffers();
      renderRoute();
      get("route-actions").querySelector("button")?.focus();
    });
  } else {
    get("route-status").textContent = path.length === 1 ? "选一道门开始这局路线。" : "奖励已领取，选择下一扇门。";
    for (const next of offers) {
      addAction(next.reward, "选择此门 →", () => {
        path.push(next);
        roomCleared = false;
        selectRoom(next);
        renderRoute();
        get("route-actions").querySelector("button")?.focus();
      });
    }
  }
}

function resetRoute() {
  path = [rooms[0]];
  roomCleared = true;
  offers = chooseOffers();
  renderRoute();
}
get("reset").addEventListener("click", resetRoute);
resetRoute();
