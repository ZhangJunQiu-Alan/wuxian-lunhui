/* 诸界余烬装备系统草案 v4 · 交互逻辑（数据在 data.js） */
(() => {
"use strict";

/* ---------- 基础 ---------- */
const $ = s => document.querySelector(s);
const el = (tag, attrs = {}, html = "") => { const e = document.createElement(tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (html) e.innerHTML = html; return e; };
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}
const pick = (rng, arr) => arr[Math.floor(rng() * arr.length)];
const ROMAN = ["", "Ⅰ","Ⅱ","Ⅲ","Ⅳ","Ⅴ","Ⅵ","Ⅶ","Ⅷ","Ⅸ","Ⅹ"];
const fmtT = s => `${String(Math.floor(s/60)).padStart(2,"0")}:${String(Math.floor(s%60)).padStart(2,"0")}`;
const round = (v, d) => d ? Math.round(v * 10) / 10 : Math.round(v);
const pct = v => `${Math.round(v * 1000) / 10}%`;
function setupCanvas(cv, w, h){
  const dpr = Math.max(1, Math.round(window.devicePixelRatio || 1));
  cv.width = w * dpr; cv.height = h * dpr;
  const ctx = cv.getContext("2d"); ctx.scale(dpr, dpr); ctx.imageSmoothingEnabled = false;
  return ctx;
}
const IMG = {};
function img(name){ if (!IMG[name]){ const i = new Image(); i.src = `img/${name}`; IMG[name] = i; } return IMG[name]; }

/* ---------- 像素图标（12×12 示意，r = 强调色） ---------- */
const PIX = {
  blade:["..........bb",".........bba","........bba.",".......bba..","......bba...",".....bba....","..r.bba.....","...rba......","...wr.......","..ww.r......",".ww.........","ww.........."],
  gun:["............","............",".aaaaaaaaaa.",".abbbbbbbbba",".arrcccaaaa.",".aacca......","..awwa......","..awwa......",".awwa.......",".awwa.......",".aaa........","............"],
  dagger:["b..........b","bb........bb",".bb......bb.","..bb....bb..","...bb..bb...","....bbbb....","....rbbr....","...rr..rr...","..ww....ww..",".ww......ww.","ww........ww","............"],
  staff:[".....rr.....","....rbbr....","....rbbr....",".....rr.....",".....wa.....",".....wa.....","....gwag....",".....wa.....",".....wa.....",".....wa.....",".....wa.....",".....aa....."],
  helm:["............","h..........h","hh........hh",".hh.aaaa.hh.","..haccccah..","..acbbbbca..",".acbbbbbbca.",".arrrrrrrra.",".acaa..aaca.",".aca....aca.","..a......a..","............"],
  armor:["............",".aaa....aaa.","acca....acca","accaaaaaacca","aacbbbbbbcaa",".acbbrrbbca.",".acbbrrbbca.",".acbbbbbbca.",".accrrrrcca.",".acccccccca.","..aaaaaaaa..","............"],
  legs:["............",".aaaaaaaaaa.",".arrrrrrrra.",".acbbbbbbca.",".acbbaabbca.",".acba..abca.",".acba..abca.",".acba..abca.",".acca..acca.",".acca..acca.",".aaaa..aaaa.","............"],
  boots:["............","..aaaa......","..awwa......","..awwa......","..awwa......","..arra......","..awwa......","..awwwaa....","..awwwwwa...","..accccca...","..aaaaaaa...","............"],
  coin:["............","....aaaa....","..aayyyyaa..",".ayyyyyyyya.",".ayyggggyya.",".ayygyyyyya.",".ayyggggyya.",".ayyyyyyyya.",".ayyyyyyyya.","..aayyyyaa..","....aaaa....","............"],
  gem:["............",".....aa.....","....arra....","...arhrra...","..arhrrrra..",".arhrrrrrra.",".arrrrrrrra.","..arrrrrra..","...arrrra...","....arra....",".....aa.....","............"],
  ember:["............",".....r......",".....rr.....","....rrr.....","....rrrr....","...rryrr....","...ryyyrr...","..rryyyyr...","..ryykyyr...","..ryykkyr...","...ryyyr....","....rrr....."],
};
const PAL = {a:"#17110c", b:"#eef1f5", c:"#8b93a1", w:"#7a5233", g:"#d9a441", h:"#e8dcc0", y:"#ffd27a", k:"#fff3d6"};
const iconCache = {};
function icon(key, accent){
  const id = key + accent;
  if (iconCache[id]) return iconCache[id];
  const c = document.createElement("canvas"); c.width = 12; c.height = 12;
  const x = c.getContext("2d");
  PIX[key].forEach((row, y) => [...row].forEach((ch, i) => {
    if (ch === ".") return;
    x.fillStyle = ch === "r" ? accent : PAL[ch];
    x.fillRect(i, y, 1, 1);
  }));
  iconCache[id] = {canvas:c, url:c.toDataURL()};
  return iconCache[id];
}
const WICON = {swordsman:"blade", gunslinger:"gun", assassin:"dagger", mage:"staff"};
const wColor = w => { const c = w.p[0].c; return c === "rainbow" ? "#ff9adf" : c; };
const COIN = () => icon("coin", "#d9a441").url;
const EMBER = () => icon("ember", "#ff7a3d").url;
const MAT = slot => icon("gem", SLOT[slot].matColor).url;
const BOSSMAT = () => icon("gem", "#ff5a36").url;

/* ---------- 物品生成 ---------- */
let uid = 1;
const LV_OF = {midgard:1, helheim:2, vigrid:3};
const weaponPool = (cls, lv) => WEAPONS[cls].filter(w => !w.init && w.lv === lv);
const findWeapon = (cls, id) => WEAPONS[cls].find(w => w.id === id);
function weightedPick(rng, items, weights){
  const total = weights.reduce((a, b) => a + b, 0);
  let r = rng() * total;
  for (let i = 0; i < items.length; i++){ if ((r -= weights[i]) < 0) return items[i]; }
  return items[items.length - 1];
}
function rollPrefix(rng, kind, rar){
  const grp = weightedPick(rng, ["bad", "mixed", "good"], RAR[rar].prefixW);
  const pool = PREFIXES[kind].filter(p => grp === "good" ? (p.g === "good" || p.g === "top") : p.g === grp);
  return weightedPick(rng, pool, pool.map(p => p.g === "top" ? 1 : 3));
}
function rollAffixes(rng, slot, cls, rar, depth){
  const pool = AFFIXES.filter(a => (a.slots === "all" || a.slots.includes(slot)) && (!a.cls || a.cls === cls));
  const badPool = BAD_AFFIXES.filter(a => a.slots === "all" || a.slots.includes(slot));
  const starChance = RAR[rar].star * (depth >= 5 ? 2 : 1);
  const out = [], used = new Set();
  for (let guard = 0; out.length < RAR[rar].aff && guard < 60; guard++){
    const bad = rng() < RAR[rar].bad;
    const a = pick(rng, bad ? badPool : pool);
    if (used.has(a.k)) continue;
    used.add(a.k);
    if (bad){ out.push({k:a.k, v:-round(a.r[0] + rng() * (a.r[1] - a.r[0]), a.d), star:false, bad:true}); continue; }
    let v = (a.r[0] + rng() * (a.r[1] - a.r[0])) * DEPTH.aff(depth);
    const star = rng() < starChance;
    if (star) v *= 1.5;
    out.push({k:a.k, v:round(v, a.d), star});
  }
  return out;
}
function rollRarity(rng, minute, depth, floor, luck){
  const bonus = minute * 2 + DEPTH.high(depth) + (luck || 0);
  const high = RARITY_BASE_W[1] + RARITY_BASE_W[2] + RARITY_BASE_W[3];
  const scale = (high + bonus) / high;
  const w = [0, RARITY_BASE_W[1] * scale, RARITY_BASE_W[2] * scale, RARITY_BASE_W[3] * scale];
  w[0] = Math.max(5, 100 - w[1] - w[2] - w[3]);
  for (let i = 0; i < floor; i++) w[i] = 0;
  return weightedPick(rng, [0, 1, 2, 3], w);
}
// 幸运按选卡的同一条公式：史诗、传说的权重 ×（高档合计 + 幸运）/ 高档合计，稀有补足剩下的
function bossGearRarity(rng, depth, luck){
  const w = DROP.bossW.slice(); w[3] += 3 * (depth - 1);
  const high = w[2] + w[3], scale = (high + (luck || 0)) / high;
  w[2] *= scale; w[3] *= scale; w[1] = Math.max(0, 100 - w[2] - w[3]);
  return weightedPick(rng, [0, 1, 2, 3], w);
}
// o: {rar, slot, depth, cls, weapon, set, boss, src, t}
function makeItem(rng, o){
  const depth = o.depth || 1;
  let slot = o.slot, base, ic, codex, cls = null, weapon = null, set = null, boss = null, eff = null;
  if (o.boss){
    boss = o.boss; const B = BOSSES[boss];
    slot = B.slot; base = B.item; eff = B.eff; codex = "b:" + boss;
    ic = slot === "weapon" ? WICON[o.cls] : SLOT[slot].icon;
  } else if (slot === "weapon"){
    weapon = o.weapon; cls = o.cls; base = weapon.n; ic = WICON[cls]; codex = "w:" + weapon.id;
  } else {
    set = o.set; base = SETS[set].pieces[slot]; ic = SLOT[slot].icon; codex = `s:${set}:${slot}`;
  }
  const prefix = rollPrefix(rng, slot === "weapon" ? "weapon" : "armor", o.rar);
  const affixes = rollAffixes(rng, slot, o.cls, o.rar, depth);
  let faith = null;
  const fc = o.rar === 3 && depth >= 7 ? 0.5 : RAR[o.rar].faith;
  if (rng() < fc) faith = {g:pick(rng, Object.keys(GODS)), v:round(FAITH_BASE * DEPTH.aff(depth), 0)};
  const imp = {k:SLOT[slot].imp.k, v:SLOT[slot].imp.v * DEPTH.aff(depth)};
  return {id:uid++, rar:o.rar, slot, icon:ic, base, prefix, affixes, faith, imp, enh:0, invested:0, depth, cls, weapon, set, boss, eff, codex, src:o.src || "", t:o.t || 0};
}
function makeGear(rng, rar, cls, levelKey, depth, src, t){
  const L = LEVELS[levelKey];
  if (rng() < DROP.weaponShare) return makeItem(rng, {rar, slot:"weapon", weapon:pick(rng, weaponPool(cls, L.lv)), cls, depth, src, t});
  return makeItem(rng, {rar, slot:pick(rng, ARMOR_SLOTS), set:pick(rng, L.sets), cls, depth, src, t});
}
const hasStar = it => it.affixes.some(a => a.star);
const itemName = it => `${hasStar(it) ? "★" : ""}${it.prefix.n}的${it.base}`;
function fmtStat(k, v){
  const S = STAT[k], x = Math.round(Math.abs(v) * 10) / 10;
  return `${S.n} ${(v >= 0) !== !!S.neg ? "+" : "-"}${x}${S.u}`;
}
function fmtFx(fx, mult = 1){
  return Object.entries(fx).map(([k, v]) => { const x = Math.round(v * mult * 10) / 10; return `${PREFIX_LABEL[k]} ${x > 0 ? "+" : ""}${x}${PREFIX_FLAT[k] ? "" : "%"}`; }).join("、");
}
const pfxClass = g => g === "bad" ? "pfx-bad" : g === "mixed" ? "pfx-mixed" : "pfx-good";
function prefixLine(p, mult = 1){
  return `<div class="pfx"><span class="pfx-tag ${pfxClass(p.g)}">${PREFIX_GROUP[p.g].n}</span><b class="${pfxClass(p.g)}">${p.n}</b>：${fmtFx(p.fx, mult)}</div>`;
}
function faithText(f){ const G = GODS[f.g]; return `${G.n}之誓：若本局信仰${G.n}，${G.sig} +${f.v}%；首次选神时${G.n}必定在候选里`; }
function srcLabel(it){ return it.src ? `${fmtT(it.t)} ${it.src}` : ""; }
// 卡片正文（模拟器和问题 1 共用）
function itemBody(it, forCls){
  const L = [];
  L.push(prefixLine(it.prefix, it.enh >= 10 ? 1.5 : 1));
  L.push(`<div class="imp">${fmtStat(it.imp.k, it.imp.v * (1 + 0.1 * it.enh))}${it.enh ? ` <span class="r3">(+${it.enh})</span>` : ""}</div>`);
  if (it.weapon) L.push(`<div class="wl">攻击：${it.weapon.atk}</div>`);
  if (it.eff) L.push(`<div class="uq">${it.eff}</div>`);
  it.affixes.forEach(a => L.push(a.bad ? `<div class="aff pfx-bad">▼ ${fmtStat(a.k, a.v)}</div>` : `<div class="aff">${a.star ? '<span class="star">★ </span>' : ""}${fmtStat(a.k, a.v * (it.enh >= 5 ? 1.1 : 1))}</div>`));
  if (it.faith) L.push(`<div class="faith">${faithText(it.faith)}</div>`);
  if (it.set) L.push(`<div class="setl">套装：<span style="color:${SETS[it.set].c}">${SETS[it.set].n}</span>（4 件共鸣）</div>`);
  if (it.boss && it.slot !== "weapon") L.push(`<div class="setl">神器不属于任何套装</div>`);
  return L.join("");
}

/* ---------- 01 时间轴 ---------- */
function timelineSVG(withGear){
  const W = 1000, rows = withGear ? 4 : 3, H = 26 + rows * 34;
  const X = t => 92 + t / 600 * 890;
  let s = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${withGear ? "加入装备后" : "现状"}的一局奖励时间轴">`;
  s += `<text x="0" y="16" fill="#efe5d4" font-size="15" font-weight="700">${withGear ? "加入装备后" : "现状"}</text>`;
  for (let m = 0; m <= 10; m++){ const x = X(m*60); s += `<line x1="${x}" x2="${x}" y1="24" y2="${H-4}" stroke="#2b221b"/><text x="${x}" y="16" fill="#a6978a" font-size="11" text-anchor="middle">${m}:00</text>`; }
  const row = (i, label) => { const y = 40 + i * 34; s += `<text x="0" y="${y+4}" fill="#a6978a" font-size="12">${label}</text><line x1="92" x2="982" y1="${y}" y2="${y}" stroke="#3a2e23"/>`; return y; };
  let y = row(0, "升级选卡");
  for (let L = 2; L <= 40; L++){ const cum = 5*(L-1) + 3*(L-1)*(L-2); const t = 600 * Math.sqrt(cum / 4641); s += `<line x1="${X(t)}" x2="${X(t)}" y1="${y-7}" y2="${y+7}" stroke="#6b5d50" stroke-width="2"/>`; }
  y = row(1, "精英");
  const rng = mulberry32(42);
  const drops = [];
  for (let k = 0; k < 15; k++){
    const t = 40 + 40*k; s += `<circle cx="${X(t)}" cy="${y}" r="4" fill="#a6978a"/>`;
    if (rng() < DROP.elite) drops.push([t, rollRarity(rng, t/60, 1, 0, 0)]);
  }
  y = row(2, "Boss");
  [180, 360, 540].forEach(t => s += `<path d="M${X(t)} ${y-8}L${X(t)+8} ${y}L${X(t)} ${y+8}L${X(t)-8} ${y}Z" fill="#ff7a3d"/>`);
  let surprises = 3;
  if (withGear){
    y = row(3, "装备掉落");
    [180, 360, 540].forEach(t => { drops.push([t - 6, bossGearRarity(rng, 1)]); drops.push([t + 6, 4]); });
    drops.forEach(([t, r]) => {
      const rr = r === 4 ? 7 : r >= 2 ? 6 : 4.5;
      s += `<circle cx="${X(t)}" cy="${y}" r="${rr}" fill="${RAR[r].hex}" ${r === 4 ? 'stroke="#fff" stroke-width="1.5"' : ""}/>`;
    });
    s += `<text x="${X(540)}" y="${y-12}" fill="#ff5a36" font-size="11" text-anchor="middle">装备 + 神器</text>`;
    surprises += drops.length;
  }
  s += `<text x="982" y="${H-2}" fill="${withGear ? "#ff7a3d" : "#a6978a"}" font-size="12" text-anchor="end">结果不确定的奖励：${surprises} 次</text>`;
  return s + "</svg>";
}
$("#tl-now").innerHTML = timelineSVG(false);
$("#tl-gear").innerHTML = timelineSVG(true);

/* ---------- 02 竞品 ---------- */
const PATTERNS = [
  {id:"ritual", n:"掉落仪式", d:"光柱、颜色、音效、名字飘字，决定「爆了」那一刻有多爽。"},
  {id:"affix", n:"随机词缀", d:"同名装备每次属性不同，会出极品，重复刷才有意义。"},
  {id:"prefix", n:"好坏词头", d:"名字前缀就是一组属性，有好有坏，地上一看就懂，可以花钱重铸。"},
  {id:"rule", n:"规则改变", d:"暗金或神器直接改写技能行为，而不是只加数值。"},
  {id:"set", n:"套装共鸣", d:"凑齐几件触发额外效果，引导玩家规划搭配。"},
  {id:"target", n:"定向刷取", d:"知道去哪打、打谁、为了什么。"},
  {id:"pity", n:"保底", d:"运气再差也有上限，防止「刷不到」的挫败。"},
  {id:"craft", n:"打造升级", d:"强化、洗练、打造，把重复掉落转为进度。"},
  {id:"codex", n:"收录解锁", d:"图纸、宝典、图鉴，留下永久的横向进度。"},
  {id:"ladder", n:"难度阶梯", d:"更高难度掉更好的东西，装备才有用武之地。"},
  {id:"filter", n:"拾取过滤", d:"自动隐藏或分解垃圾，减轻整理负担。本草案暂不做。"},
  {id:"local", n:"局内装备", d:"掉落在本局立即生效。"},
];
const GAMES = [
  {n:"热血传奇", m:"2001 · MMORPG", c:"#e8b962", p:["ritual","affix","target","craft"],
   mech:"怪物死亡后装备散落在地，名字直接显示；同名装备可能带随机「极品」属性；Boss 定时刷新，玩家蹲点打宝；武器强化到高等级会发光。",
   learn:"爆装备那一下最上头：地上一闪、名字一亮。极品属性让同名装备也分高低。",
   avoid:"纯概率没有保底，刷不到只能一直蹲；死亡掉装备在单机里只会劝退。",
   take:"地面掉落、名字直接显示、极品★、强化 +7 发光。"},
  {n:"泰拉瑞亚", m:"2011 · 沙盒动作", c:"#7fbf5f", p:["affix","prefix","craft","target","ladder"],
   mech:"武器和饰品随机带一个修饰语，写在名字最前面：「传奇」「神级」最好，「破碎」「损坏」是坏的，饰品只出好的；哥布林工匠可以花钱重铸，换一个但不能去掉；Boss 掉专属武器，专家、大师模式掉得更好。",
   learn:"好坏写在名字上，捡起来一眼就懂；重铸是简单又上瘾的金币消耗。",
   avoid:"修饰语只看数值，后期大家都刷同一个最好的。",
   take:"词头系统、坏词缀、金币重铸；加了「双刃」词头，让最优解不止一个。"},
  {n:"暗黑破坏神 II", m:"2000 · ARPG", c:"#c9a46a", p:["ritual","affix","prefix","rule","set","ladder"],
   mech:"白、蓝、黄、暗金、绿五种颜色区分品质；魔法装备的名字由词缀前后缀拼成；绿色套装凑齐才有完整效果；普通、噩梦、地狱三档难度。",
   learn:"颜色就是语言，扫一眼地面就知道值不值得捡。",
   avoid:"背包格子管理太重，绝大部分掉落是垃圾。",
   take:"稀有度颜色沿用卡牌四色 + 神器色；4 件套装共鸣。"},
  {n:"暗黑破坏神 IV", m:"2023 · 第 4 赛季「战利品重生」", c:"#d0574a", p:["affix","rule","target","craft","codex","ladder"],
   mech:"第 4 赛季把掉落改成少而精：高阶装备可带「巨型词缀」；回火加词缀，精造在固定等级给额外提升；拆解传奇装备会把威能收进「力量宝典」。",
   learn:"少掉，但每件都值得看。拆解不是销毁，而是收录。",
   avoid:"上线初期词缀又多又杂，玩家读不过来，后来才大改。",
   take:"极品★ 对应巨型词缀；强化 +5 / +7 / +10 里程碑对应精造；图鉴收录。"},
  {n:"流放之路", m:"2013 · ARPG", c:"#a88a5a", p:["affix","rule","craft","ladder","filter"],
   mech:"掉落的「通货」本身就是改造装备的材料；暗金装备常常改写技能规则；地图系统构成无限难度阶梯；拾取过滤器决定地上显示什么。",
   learn:"暗金不是数值更大，而是玩法不同。材料即货币，每次掉落都有用。",
   avoid:"复杂度极高，新手看不懂；10 分钟一局承受不了这种深度。",
   take:"神器作为规则改变器；部位素材既是掉落，也是强化消耗。"},
  {n:"最后纪元", m:"2024 · ARPG", c:"#5fa3a8", p:["affix","rule","target","craft","filter","ladder"],
   mech:"内置拾取过滤；暗金装备带「传奇潜能」；「命运之环」阵营提高掉率，并用「预言」换取指定掉落。",
   learn:"预言给玩家一个明确的刷取目标。",
   avoid:"阵营设计依赖交易，单机用不上。",
   take:"Boss 素材加定向打造，相当于单机版预言。"},
  {n:"怪物猎人", m:"2004 起 · 动作", c:"#8fb06a", p:["target","craft","set","pity"],
   mech:"装备用特定怪物的素材打造；同一套防具凑齐会激活技能；稀有素材概率低，但素材会一直累积。",
   learn:"想要那把刀就去打那只龙，刷的过程有方向。素材累积本身就是保底。",
   avoid:"稀有素材概率太低时同样折磨。",
   take:"每位 Boss 掉专属素材，攒 5 个必能打造神器；防具成套。"},
  {n:"死亡细胞", m:"2018 · 类 Rogue", c:"#6fb3d8", p:["ritual","codex","ladder","local"],
   mech:"敌人有概率掉「图纸」，解锁后这件物品才进入以后的随机池；武器决定攻击方式；部分图纸只在高难度掉。",
   learn:"横向成长：解锁的是可能性而不是数值。每把武器手感完全不同。",
   avoid:"解锁完就到头，后期缺少追求。",
   take:"图鉴点亮后可以定向打造；武器改变攻击方式。"},
  {n:"Halls of Torment", m:"2023 · 类幸存者", c:"#b07a52", p:["local","rule","target"],
   mech:"宝箱多来自 Boss 和任务，打开后三选一装备，共 7 个部位；死亡后局内装备丢失，但每局可通过水井永久带出一件。",
   learn:"和我们同品类，证明局内装备可行。",
   avoid:"带出的装备没有成长，收集完就没目标。",
   take:"局内就能换装；但我们带出局的就是同一件，不限件数。"},
  {n:"Death Must Die", m:"2023 · 类幸存者", c:"#9a6bc4", p:["ritual","affix","rule","local"],
   mech:"类幸存者加暗黑式掉落：5 种稀有度，精英和 Boss 掉率高得多；局外成长主要靠装备，而不是买属性。",
   learn:"证明了「幸存者 + 刷装备」在同品类可行，而且能当卖点。",
   avoid:"掉落多了以后，整理背包会拖慢节奏。",
   take:"精英掉率远高于小怪，Boss 必掉。"},
  {n:"哈迪斯", m:"2020 · 类 Rogue", c:"#d86a4a", p:["local","craft"],
   mech:"每局带一件「信物」，戴着它通过的战斗越多，信物等级越高；击败区域 Boss 后可以更换。",
   learn:"复杂度极低：一件东西、一个效果、越用越强。",
   avoid:"信物数量固定，没有掉落的惊喜。",
   take:"强化靠资源而不是随机；装备只占 5 格。"},
  {n:"雨中冒险 2", m:"2020 · 类 Rogue", c:"#7aa0c8", p:["rule","local","codex"],
   mech:"道具可以无限叠层，颜色区分稀有度；「月球道具」强力但有明确代价；完成挑战才解锁新道具。",
   learn:"带代价的强力道具会制造有意思的抉择。",
   avoid:"叠层数值容易爆炸，后期画面失控。",
   take:"双刃词头：大加一项、扣一项。"},
  {n:"无主之地", m:"2009 起 · 射击", c:"#e0a03a", p:["ritual","affix","prefix","rule","ladder"],
   mech:"枪械由随机部件组合生成，名字前缀来自部件；每个厂商有固定风格；传奇装备掉落时有橙色光柱。",
   learn:"厂商风格让玩家一眼知道这把枪怎么用。",
   avoid:"数量太多，大部分枪捡起就卖。",
   take:"武器款式决定攻击方式；神器光柱。"},
  {n:"Megabonk", m:"2025 · 类幸存者", c:"#c0c75a", p:["ritual","local","codex"],
   mech:"局内道具约 78 件、5 种稀有度；普通宝箱越开越贵，精英和 Boss 掉免费的金宝箱；完成任务解锁新道具进入池子。",
   learn:"精英和 Boss 的掉落要明显更香，玩家才会主动找精英打。",
   avoid:"全是局内道具，局外仍然只有解锁清单。",
   take:"小怪不掉装备，装备只来自精英和 Boss。"},
  {n:"原神 · 圣遗物", m:"2020 · 开放世界", c:"#7fc4b0", p:["affix","set","target","craft"],
   mech:"主词条加副词条，两件套、四件套效果；在指定秘境定向刷套装，但副词条完全随机。",
   learn:"件数阈值非常好理解；秘境就是定向刷取。",
   avoid:"副词条随机太极端，刷几个月也凑不齐，被玩家称为「坐牢」。",
   take:"四件套共鸣；每关两套，等于定向刷套装；重铸只动词头，不让人坐牢。"},
];
let activePattern = null;
function renderMarket(){
  const chips = $("#pattern-chips"); chips.innerHTML = "";
  PATTERNS.forEach(p => {
    const b = el("button", {class:"chip", type:"button", "aria-pressed": String(activePattern === p.id)}, p.n);
    b.addEventListener("click", () => { activePattern = activePattern === p.id ? null : p.id; renderMarket(); });
    chips.appendChild(b);
  });
  const ap = PATTERNS.find(p => p.id === activePattern);
  $("#pattern-desc").textContent = ap ? `${ap.n}：${ap.d}` : "选择一个模式查看说明；再次点击取消筛选。";
  let t = "<thead><tr><th>游戏</th>" + PATTERNS.map(p => `<th class="${p.id === activePattern ? "hl" : ""}">${p.n}</th>`).join("") + "</tr></thead><tbody>";
  GAMES.forEach(g => {
    const dim = activePattern && !g.p.includes(activePattern);
    t += `<tr class="${dim ? "dim" : ""}"><td>${g.n}</td>` + PATTERNS.map(p => g.p.includes(p.id) ? `<td class="y" aria-label="有">●</td>` : `<td class="n" aria-label="无">·</td>`).join("") + "</tr>";
  });
  $("#matrix").innerHTML = t + "</tbody>";
  const box = $("#games"); box.innerHTML = "";
  GAMES.forEach(g => {
    const dim = activePattern && !g.p.includes(activePattern);
    const c = el("article", {class:`card game${dim ? " dim" : ""}`});
    c.innerHTML = `<header><span class="mono-badge" style="background:${g.c}">${g.n[0]}</span><div><h3>${g.n}</h3><div class="meta">${g.m}</div></div></header>
      <dl><dt>核心机制</dt><dd>${g.mech}</dd><dt>值得学</dt><dd>${g.learn}</dd><dt>要避开</dt><dd>${g.avoid}</dd><dt>我们借用</dt><dd class="take">${g.take}</dd></dl>
      <div class="tags">${g.p.map(id => `<span class="pill${id === activePattern ? " on" : ""}">${PATTERNS.find(p => p.id === id).n}</span>`).join("")}</div>`;
    box.appendChild(c);
  });
}
renderMarket();

/* ---------- 04 表格 ---------- */
$("#slot-table").innerHTML = SLOTS.map(s => {
  const ic = icon(s.icon || "blade", RAR[1].hex).url;
  const lean = s.id === "weapon" ? "暴击、对 Boss / 精英、职业专属" : AFFIXES.filter(a => a.slots !== "all" && a.slots.includes(s.id)).map(a => STAT[a.k].n).join("、");
  return `<tr><td class="nowrap"><img class="px" src="${ic}" width="24" height="24" alt="" style="vertical-align:middle;margin-right:6px">${s.n}</td><td>${fmtStat(s.imp.k, s.imp.v)}</td><td class="nowrap"><img class="px" src="${MAT(s.id)}" width="18" height="18" alt="" style="vertical-align:middle;margin-right:4px">${s.mat}</td><td class="muted small">${lean}</td></tr>`;
}).join("");
$("#rarity-table").innerHTML = RAR.map((r, i) => `<tr><td class="r${i} rar-name">${r.n}</td><td class="num nowrap">${i === 4 ? "2 + 专属" : r.aff}</td><td class="num">${r.bad ? pct(r.bad) : "—"}</td><td class="mono small">${r.prefixW.join(" / ")}</td><td class="num">${r.star ? pct(r.star) : "—"}</td><td>${r.faith === 1 ? "必带" : r.faith ? "30%" : "—"}</td><td class="num">+${r.cap}</td></tr>`).join("");
function pfxRows(kind){
  return ["top", "good", "mixed", "bad"].map(g => PREFIXES[kind].filter(p => p.g === g).map(p =>
    `<tr><td class="nowrap"><span class="pfx-tag ${pfxClass(p.g)}">${PREFIX_GROUP[p.g].n}</span><b class="${pfxClass(p.g)}">${p.n}</b></td><td>${fmtFx(p.fx)}${p.note ? `<div class="small muted">${p.note}</div>` : ""}</td></tr>`).join("")).join("");
}
$("#pfx-weapon").innerHTML = pfxRows("weapon");
$("#pfx-armor").innerHTML = pfxRows("armor");
$("#affix-table").innerHTML = AFFIXES.map(a => {
  const sl = a.slots === "all" ? "全部" : a.slots.map(s => SLOT[s].n).join("、");
  const max = round(a.r[1] * DEPTH.aff(10) * 1.5, a.d);
  const card = STAT[a.k].card ? fmtStat(a.k, STAT[a.k].card) : "新属性";
  const name = STAT[a.k].n + (a.cls ? `（${CLASSES[a.cls].n}）` : "");
  return `<tr><td>${name}</td><td class="num">${a.r[0]}–${a.r[1]}</td><td class="num">${max}</td><td class="muted">${sl}</td><td class="num">${card}</td></tr>`;
}).join("");
$("#bad-affix-table").innerHTML = BAD_AFFIXES.map(a => {
  const sl = a.slots === "all" ? "全部" : a.slots.map(s => SLOT[s].n).join("、");
  const sign = fmtStat(a.k, -1).includes("+") ? "+" : "-";
  return `<tr><td class="pfx-bad">▼ ${STAT[a.k].n} ${sign}${a.r[0]}${STAT[a.k].u} ~ ${sign}${a.r[1]}${STAT[a.k].u}</td><td class="muted">${sl}</td></tr>`;
}).join("");

/* ---------- 04 问题 1：同一款式切换稀有度 ---------- */
const Q1 = {base:"swordsman:frostfang", rar:1};
const Q1_OPTIONS = [
  ...["swordsman","gunslinger","assassin","mage"].flatMap(c => WEAPONS[c].filter(w => !w.init).slice(0, 2).map(w => [`${c}:${w.id}`, `${CLASSES[c].n} · ${w.n}`])),
  ["set:wolf:chest", "防具 · 霜狼皮袄（霜狼猎装）"], ["set:einherjar:helm", "防具 · 英灵翼盔（英灵战甲）"],
  ["boss:hel", "神器 · 半面冠（海拉）"],
];
$("#q1-base").innerHTML = Q1_OPTIONS.map(([v, n]) => `<option value="${v}">${n}</option>`).join("");
function q1Item(rar){
  const rng = mulberry32(5150 + rar);
  const [kind, a, b] = Q1.base.split(":");
  if (kind === "boss") return makeItem(rng, {rar:4, boss:a, depth:1, cls:"swordsman"});
  if (kind === "set") return makeItem(rng, {rar, slot:b, set:a, depth:1, cls:"swordsman"});
  return makeItem(rng, {rar, slot:"weapon", weapon:findWeapon(kind, a), cls:kind, depth:1});
}
function renderQ1(){
  const isBoss = Q1.base.startsWith("boss");
  if (isBoss) Q1.rar = 4; else if (Q1.rar === 4) Q1.rar = 3;
  $("#q1-rar").innerHTML = RAR.map((r, i) => {
    const dis = isBoss ? i !== 4 : i === 4;
    return `<button type="button" class="rar-btn" style="--rc:${r.hex}" data-r="${i}" aria-pressed="${Q1.rar === i}" ${dis ? "disabled" : ""}>${r.n}</button>`;
  }).join("") + `<span class="small muted">${isBoss ? "神器只有这一档" : "神器是另一类装备，普通款式没有这一档"}</span>`;
  const it = q1Item(Q1.rar);
  $("#q1-item").innerHTML = `<div class="item" style="--rc:${RAR[it.rar].hex}">
    <div class="top"><img class="px" src="${icon(it.icon, RAR[it.rar].hex).url}" alt=""><div><div class="nm" style="color:${RAR[it.rar].hex}">${itemName(it)}</div>
    <div class="sub">${RAR[it.rar].n} · ${SLOT[it.slot].n} · Ⅰ阶 · 强化上限 +${RAR[it.rar].cap}</div></div></div>${itemBody(it)}</div>`;
}
$("#q1-base").addEventListener("change", e => { Q1.base = e.target.value; renderQ1(); });
$("#q1-rar").addEventListener("click", e => { const b = e.target.closest("button[data-r]"); if (!b || b.disabled) return; Q1.rar = +b.dataset.r; renderQ1(); });
renderQ1();

/* ---------- 05 表格 ---------- */
$("#drop-table").innerHTML = [
  ["小怪", `<img class="px" src="${COIN()}" width="18" height="18" alt=""> 金币 ×${DROP.goldPile}`, pct(DROP.gold), "金币堆数额随深度 ×(1 + 0.1 ×（深度 − 1）)"],
  ["小怪", `<img class="px" src="${MAT("legs")}" width="18" height="18" alt=""> 部位素材 ×1`, pct(DROP.mat), "五个部位随机，一局约 18 个"],
  ["小怪", `<img class="px" src="img/pk_healing_mead.png" width="18" height="18" alt=""> 蜜酒 / 聚魂磁石 / 守护符文`, "1% / 1% / 0.8%", "见下方「补给调整」"],
  ["精英", "装备 ×1", pct(DROP.elite), "35% 是本职业武器（本关那几把），65% 是本关两套里的防具；稀有度随战斗时间、深度、幸运提高（和选卡同一条公式）；深度 Ⅲ 起 50%"],
  ["Boss", `<img class="px" src="${COIN()}" width="18" height="18" alt=""> 金币`, "必掉", "100–400，等于现在的 Boss 奖励点"],
  ["Boss", "装备 ×1", "必掉", "武器、防具比例同精英；稀有以上：稀有 50 / 史诗 38 / 传说 12，深度每级传说 +3；幸运提高史诗、传说的几率"],
  ["Boss", `<img class="px" src="${BOSSMAT()}" width="18" height="18" alt=""> Boss 素材 ×1`, "必掉", "攒 5 个打造该 Boss 的神器"],
  ["Boss", '<span class="r4">专属神器</span>', "首杀必掉，之后 12% 起", "和上面的装备分开判定，见第 07 节"],
  ["第三关命运", '<span class="r4">命运神器</span>', "达成时必掉", "见第 07 节"],
].map(r => `<tr><td class="nowrap">${r[0]}</td><td class="nowrap">${r[1]}</td><td class="num nowrap">${r[2]}</td><td class="muted small">${r[3]}</td></tr>`).join("");
$("#supply-table").innerHTML = SUPPLY.map(s => `<tr><td class="nowrap"><img class="px" src="img/${s.img}" width="24" height="24" alt="" style="vertical-align:middle;margin-right:6px">${s.n}</td><td class="muted">${s.before}</td><td><b>${s.after}</b></td><td class="muted small">${s.keep}</td></tr>`).join("");

/* ---------- 05 掉落演示 ---------- */
["snow.png","char_swordsman.png","char_gunslinger.png","char_assassin.png","char_mage.png","en_draugr.png","en_wolf.png","en_draugr_elite.png","en_frost_giant.png","boss_hel.png","pk_xp_gem.png"].forEach(img);
const cv = $("#demo-canvas");
const DW = 880, DH = 300;
const ctx = setupCanvas(cv, DW, DH);
const PLAYER = {x:110, y:150};
const WAVE = [{k:"en_draugr.png",x:430,y:95},{k:"en_wolf.png",x:520,y:205},{k:"en_draugr.png",x:610,y:120},{k:"en_draugr_elite.png",x:690,y:215,elite:true},{k:"en_frost_giant.png",x:790,y:110,elite:true}];
const demo = {enemies:[], drops:[], fx:[], boss:null, t:0, running:false, visible:true, banner:null};
const demoRng = mulberry32(1106);
const demoCls = () => $("#s-class").value || "swordsman";
function resetWave(){ demo.enemies = WAVE.map(e => ({...e, dying:0})); }
function demoGear(rar){ return makeGear(demoRng, rar, demoCls(), "midgard", 1); }
function demoWave(){
  if (!demo.enemies.length || demo.enemies.every(e => e.dying)) resetWave();
  demo.fx.push({t0:demo.t});
  demo.enemies.forEach((e, i) => e.dying = demo.t + 0.15 + i * 0.06);
  setTimeout(() => {
    demo.enemies.forEach((e, i) => {
      demo.drops.push({x:e.x - 14, y:e.y + 26, kind:"gem", born:demo.t, fly:0});
      if (e.elite){
        const it = demoGear(rollRarity(demoRng, 5, 1, 1, 0));
        demo.drops.push({x:e.x, y:e.y + 22 + (i % 2) * 6, kind:"item", item:it, rar:it.rar, label:itemName(it), born:demo.t, fly:0});
      } else {
        if (demoRng() < 0.6) demo.drops.push({x:e.x + 16, y:e.y + 30, kind:"coin", n:DROP.goldPile, born:demo.t, fly:0});
        if (demoRng() < 0.4){ const s = pick(demoRng, SLOTS).id; demo.drops.push({x:e.x + 2, y:e.y + 40, kind:"mat", slot:s, born:demo.t, fly:0}); }
      }
    });
    demo.enemies = [];
    kick();
  }, reduceMotion ? 0 : 520);
  kick();
}
function demoBoss(){
  demo.boss = {x:620, y:150, t0:demo.t, dying:0};
  kick();
  setTimeout(() => {
    demo.boss.dying = demo.t;
    setTimeout(() => {
      const cls = demoCls();
      const sig = makeItem(demoRng, {rar:4, boss:"hel", depth:1, cls});
      const w = makeGear(demoRng, bossGearRarity(demoRng, 1), cls, "helheim", 1);
      demo.drops.push({x:640, y:195, kind:"item", item:sig, rar:4, label:itemName(sig), born:demo.t, fly:0});
      demo.drops.push({x:520, y:225, kind:"item", item:w, rar:w.rar, label:itemName(w), born:demo.t, fly:0});
      demo.drops.push({x:720, y:228, kind:"coin", n:BOSSES.hel.gold, big:true, born:demo.t, fly:0});
      demo.drops.push({x:575, y:262, kind:"bossmat", born:demo.t, fly:0});
      demo.banner = {t0:demo.t, text:`海拉掉落神器 · ${sig.base}`};
      demo.boss = null;
      kick();
    }, reduceMotion ? 0 : 450);
  }, reduceMotion ? 0 : 650);
}
function demoPick(){
  if (!demo.drops.length) return;
  demo.drops.forEach(d => d.fly = d.fly || demo.t);
  const log = $("#demo-log");
  if (log.querySelector(".muted")) log.innerHTML = "";
  let gold = 0; const mats = {};
  demo.drops.forEach(d => {
    if (d.kind === "item") log.prepend(el("span", {}, `<span class="r${d.rar}">${d.label}</span> 进入行囊`));
    if (d.kind === "coin") gold += d.n;
    if (d.kind === "mat") mats[SLOT[d.slot].mat] = (mats[SLOT[d.slot].mat] || 0) + 1;
    if (d.kind === "bossmat") log.prepend(el("span", {}, `<span class="r4">${BOSSES.hel.mat}</span> ×1`));
  });
  Object.entries(mats).forEach(([n, c]) => log.prepend(el("span", {}, `${n} ×${c}`)));
  if (gold) log.prepend(el("span", {}, `<span style="color:var(--gold)">金币 +${gold}</span>`));
  while (log.children.length > 16) log.lastChild.remove();
  kick();
}
$("#demo-wave").addEventListener("click", demoWave);
$("#demo-boss").addEventListener("click", demoBoss);
$("#demo-pick").addEventListener("click", demoPick);

const BEAM_H = [0, 46, 80, 130, 190], BEAM_W = [0, 8, 10, 14, 18];
function drawSprite(c, im, x, y, scale = 1, alpha = 1, flip = false){
  if (!im.complete || !im.naturalWidth) return;
  const w = im.naturalWidth * scale, h = im.naturalHeight * scale;
  c.save(); c.globalAlpha = alpha;
  if (flip){ c.translate(x, 0); c.scale(-1, 1); c.drawImage(im, -w/2, y - h, w, h); }
  else c.drawImage(im, x - w/2, y - h, w, h);
  c.restore();
}
function drawDemo(){
  ctx.imageSmoothingEnabled = false;
  const snow = IMG["snow.png"];
  if (snow.complete && snow.naturalWidth){ for (let x = 0; x < DW; x += 64) for (let y = 0; y < DH; y += 64) ctx.drawImage(snow, x, y); }
  else { ctx.fillStyle = "#cfd8e0"; ctx.fillRect(0, 0, DW, DH); }
  ctx.fillStyle = "rgba(10,14,22,.22)"; ctx.fillRect(0, 0, DW, DH);
  const t = demo.t;
  ctx.fillStyle = "rgba(0,0,0,.25)"; ctx.beginPath(); ctx.ellipse(PLAYER.x, PLAYER.y + 30, 18, 6, 0, 0, Math.PI*2); ctx.fill();
  drawSprite(ctx, img(`char_${demoCls()}.png`), PLAYER.x, PLAYER.y + 34);
  demo.enemies.forEach((e, i) => {
    const bob = reduceMotion ? 0 : Math.round(Math.sin(t * 4 + i) * 2);
    let a = 1;
    if (e.dying && t > e.dying) a = Math.max(0, 1 - (t - e.dying) / 0.3);
    if (a <= 0) return;
    const im = IMG[e.k]; const h = im.naturalHeight || 64;
    ctx.fillStyle = `rgba(0,0,0,${.22*a})`; ctx.beginPath(); ctx.ellipse(e.x, e.y + h/2 - 4, h/3.2, 6, 0, 0, Math.PI*2); ctx.fill();
    drawSprite(ctx, im, e.x, e.y + h/2 + bob, 1, a, true);
    if (e.elite && !e.dying){ ctx.font = "500 11px 'Noto Sans SC',sans-serif"; ctx.textAlign = "center"; ctx.fillStyle = "#ffd27a"; ctx.fillText("精英", e.x, e.y - h/2 - 4); }
  });
  if (demo.boss){
    const b = demo.boss; let a = Math.min(1, (t - b.t0) / 0.3);
    if (b.dying) a = Math.max(0, 1 - (t - b.dying) / 0.4);
    drawSprite(ctx, IMG["boss_hel.png"], b.x, b.y + 96, 1, a, true);
  }
  demo.fx = demo.fx.filter(f => t - f.t0 < 0.35);
  demo.fx.forEach(f => {
    const k = (t - f.t0) / 0.35;
    ctx.strokeStyle = `rgba(255,240,210,${1-k})`; ctx.lineWidth = 6 * (1 - k) + 1;
    ctx.beginPath(); ctx.arc(PLAYER.x + 20, PLAYER.y, 90 + k * 260, -0.9, 0.9); ctx.stroke();
  });
  demo.drops.forEach(d => {
    if (d.kind !== "item" || !d.rar) return;
    const k = d.fly ? Math.min(1, (t - d.fly) / 0.4) : 0;
    const grow = Math.min(1, (t - d.born) / 0.25);
    const h = BEAM_H[d.rar] * grow * (1 - k), w = BEAM_W[d.rar];
    const pulse = reduceMotion ? 1 : 0.75 + 0.25 * Math.sin(t * 5 + d.x);
    const g = ctx.createLinearGradient(0, d.y, 0, d.y - h);
    g.addColorStop(0, RAR[d.rar].hex + "dd"); g.addColorStop(1, RAR[d.rar].hex + "00");
    ctx.globalAlpha = pulse; ctx.fillStyle = g; ctx.fillRect(d.x - w/2, d.y - h, w, h); ctx.globalAlpha = 1;
    if (d.rar >= 2){ ctx.strokeStyle = RAR[d.rar].hex + "99"; ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(d.x, d.y + 2, 16 + (d.rar === 4 && !reduceMotion ? 6 * Math.sin(t * 6) : 0), 5, 0, 0, Math.PI*2); ctx.stroke(); }
    if (d.rar >= 3 && !reduceMotion && !d.fly){
      for (let p = 0; p < 6; p++){ const ph = (t * 0.8 + p / 6 + d.x * 0.01) % 1; ctx.fillStyle = RAR[d.rar].hex; ctx.globalAlpha = 1 - ph; ctx.fillRect(d.x - 10 + ((p * 37) % 20), d.y - ph * h, 2, 2); }
      ctx.globalAlpha = 1;
    }
  });
  demo.drops.forEach(d => {
    let x = d.x, y = d.y;
    if (d.fly){ const k = Math.min(1, (t - d.fly) / 0.4); x += (PLAYER.x - x) * k; y += (PLAYER.y - y) * k; if (k >= 1) d.gone = true; }
    if (d.kind === "gem"){ drawSprite(ctx, IMG["pk_xp_gem.png"], x, y + 8); return; }
    if (d.kind === "coin"){ const n = d.big ? 3 : 1; for (let i = 0; i < n; i++) ctx.drawImage(icon("coin", "#d9a441").canvas, x - 8 + i * 7, y - 8 - (i % 2) * 4, 16, 16); return; }
    if (d.kind === "mat"){ ctx.drawImage(icon("gem", SLOT[d.slot].matColor).canvas, x - 8, y - 8, 16, 16); return; }
    if (d.kind === "bossmat"){ ctx.drawImage(icon("gem", "#ff5a36").canvas, x - 9, y - 9, 18, 18); return; }
    ctx.drawImage(icon(d.item.icon, RAR[d.rar].hex).canvas, x - 12, y - 14, 24, 24);
  });
  ctx.textAlign = "center";
  demo.drops.forEach((d, i) => {
    if (d.fly) return;
    let label = null, color = null, font = "500 13px 'Noto Sans SC','PingFang SC',sans-serif";
    if (d.kind === "item"){ label = d.label; color = RAR[d.rar].hex; }
    else if (d.kind === "coin" && d.big){ label = `金币 ${d.n}`; color = "#ffd27a"; }
    else if (d.kind === "bossmat"){ label = BOSSES.hel.mat; color = "#ff8a6a"; font = "500 11px 'Noto Sans SC',sans-serif"; }
    if (!label) return;
    ctx.font = font;
    const ly = d.y - 22 - (d.kind === "item" ? Math.min(BEAM_H[d.rar], 40) : 0) - (i % 2) * 14;
    const tw = ctx.measureText(label).width + 10;
    ctx.fillStyle = "rgba(12,9,7,.78)"; ctx.fillRect(d.x - tw/2, ly - 13, tw, 18);
    ctx.fillStyle = color; ctx.fillText(label, d.x, ly);
  });
  demo.drops = demo.drops.filter(d => !d.gone);
  if (demo.banner){
    const k = t - demo.banner.t0;
    if (k > 2.2) demo.banner = null;
    else {
      const a = Math.min(1, k / 0.2) * Math.min(1, (2.2 - k) / 0.4);
      ctx.fillStyle = `rgba(12,9,7,${0.75 * a})`; ctx.fillRect(DW/2 - 170, 10, 340, 30);
      ctx.font = "900 16px 'Noto Serif SC','Songti SC',serif"; ctx.fillStyle = `rgba(255,140,90,${a})`; ctx.fillText(demo.banner.text, DW/2, 31);
    }
  }
  if (!demo.enemies.length && !demo.boss && !demo.drops.length && !demo.fx.length && !demo.banner){
    ctx.font = "13px 'Noto Sans SC',sans-serif"; ctx.fillStyle = "rgba(255,255,255,.85)"; ctx.fillText("点「清一波怪」刷新敌人", DW * 0.6, DH / 2);
  }
}
let last = 0;
function loop(ts){
  const dt = last ? Math.min(0.05, (ts - last) / 1000) : 0; last = ts;
  demo.t += dt;
  drawDemo();
  const busy = demo.fx.length || demo.banner || demo.boss || demo.drops.some(d => d.fly) || demo.enemies.some(e => e.dying);
  const ambient = !reduceMotion && (demo.enemies.length || demo.drops.length);
  if (demo.visible && (busy || ambient)) requestAnimationFrame(loop); else { demo.running = false; last = 0; }
}
function kick(){ if (!demo.running){ demo.running = true; requestAnimationFrame(loop); } }
resetWave();
new IntersectionObserver(ents => { demo.visible = ents[0].isIntersecting; if (demo.visible) kick(); }).observe(cv);
drawDemo();

/* ---------- 05 装备栏示意 ---------- */
(function panelMock(){
  const rng = mulberry32(77);
  const cls = "swordsman";
  const eq = {
    weapon: makeItem(rng, {rar:1, slot:"weapon", weapon:findWeapon(cls, "frostfang"), cls, depth:1}),
    helm: makeItem(rng, {rar:2, slot:"helm", set:"wolf", cls, depth:1}),
    chest: makeItem(rng, {rar:1, slot:"chest", set:"wolf", cls, depth:1}),
  };
  const nw = makeItem(rng, {rar:2, slot:"weapon", weapon:findWeapon(cls, "nodachi"), cls, depth:1});
  const bag = [nw];
  for (let i = 0; i < 7; i++){
    const rar = [0, 0, 1, 1, 2, 0, 3][i];
    bag.push(i % 3 === 0 ? makeItem(rng, {rar, slot:"weapon", weapon:pick(rng, weaponPool(cls, 1)), cls, depth:1}) : makeItem(rng, {rar, slot:pick(rng, ARMOR_SLOTS), set:pick(rng, ["wolf","barrow"]), cls, depth:1}));
  }
  const slotCell = id => {
    const it = eq[id];
    return it ? `<div class="slot filled" style="--rc:${RAR[it.rar].hex};min-height:48px"><img class="px" src="${icon(it.icon, RAR[it.rar].hex).url}" alt=""><div><div class="sn">${SLOT[id].n}</div><div class="in" style="color:${RAR[it.rar].hex};font-size:12px">${itemName(it)}</div></div></div>`
      : `<div class="slot" style="min-height:48px"><img class="px" src="${icon(SLOT[id].icon, "#555").url}" alt="" style="opacity:.25"><div><div class="sn">${SLOT[id].n}</div><div class="muted">空</div></div></div>`;
  };
  const old = eq.weapon;
  const cmpRows = [
    `<div>攻击方式：${nw.weapon.atk}</div>`,
    `<div class="${PREFIX_GROUP[nw.prefix.g].n === "坏" ? "down" : "up"}">词头：${old.prefix.n} → ${nw.prefix.n}</div>`,
    `<div class="${nw.affixes.length >= old.affixes.length ? "up" : "down"}">随机词缀：${old.affixes.length} 条 → ${nw.affixes.length} 条 ${nw.affixes.length > old.affixes.length ? "▲" : ""}</div>`,
  ];
  $("#panel-mock").innerHTML = `<span class="paused">已暂停 · I</span>
    <div style="display:grid;gap:6px;width:200px">${["weapon","helm","chest","legs","boots"].map(slotCell).join("")}</div>
    <div style="display:grid;gap:10px;align-content:start">
      <div class="small muted">行囊 ${bag.length} / 30</div>
      <div class="bag">${bag.map((it, i) => `<div class="cell has" style="--rc:${RAR[it.rar].hex}" title="${itemName(it)}"><img class="px" src="${icon(it.icon, RAR[it.rar].hex).url}" alt="${itemName(it)}">${i === 0 ? '<span class="nw">新</span>' : ""}</div>`).join("")}${Array.from({length:18 - bag.length}, () => '<div class="cell"></div>').join("")}</div>
      <div class="detail-panel"><b style="color:${RAR[nw.rar].hex}">${itemName(nw)}</b> <span class="small muted">对比当前：${itemName(old)}</span><div class="cmp">${cmpRows.join("")}</div></div>
    </div>`;
})();

/* ---------- 05 M 地图 ---------- */
const MAP = {cv:$("#map-canvas"), level:"midgard", drops:[], seed:31, hover:null};
const MW = 640;
const mctx = setupCanvas(MAP.cv, MW, MW);
function mapScale(){ const L = LEVELS[MAP.level]; return {s:(MW - 40) / L.size, L}; }
const toMap = (x, y) => { const {s} = mapScale(); return [MW/2 + x * s, MW/2 + y * s]; };
function areaAt(x, y){
  const L = LEVELS[MAP.level];
  let best = null;
  L.marks.forEach(m => { const d = Math.hypot(x - m[1], y - m[2]); if (d <= m[3] && (!best || d < best.d)) best = {n:m[0], d}; });
  return best ? best.n : "野外";
}
function scatterMap(n){
  const L = LEVELS[MAP.level], rng = mulberry32(MAP.seed++);
  const half = L.size / 2 - 300, cls = demoCls();
  for (let i = 0; i < n; i++){
    let x, y;
    if (rng() < 0.6){ const m = pick(rng, L.marks); const a = rng() * Math.PI * 2, r = Math.sqrt(rng()) * m[3]; x = m[1] + Math.cos(a) * r; y = m[2] + Math.sin(a) * r; }
    else { x = (rng() * 2 - 1) * half; y = (rng() * 2 - 1) * half; }
    x = Math.max(-half, Math.min(half, x)); y = Math.max(-half, Math.min(half, y));
    const roll = rng();
    if (roll < 0.5) MAP.drops.push({x, y, kind:"coin"});
    else if (roll < 0.75) MAP.drops.push({x, y, kind:"mat", slot:pick(rng, SLOTS).id});
    else {
      const rar = rollRarity(rng, rng() * 10, 1, 0, 0);
      const it = makeGear(rng, rar, cls, MAP.level, 1);
      MAP.drops.push({x, y, kind:"item", item:it});
    }
  }
  if (!MAP.drops.some(d => d.kind === "item" && d.item.rar === 4)){
    const b = L.bosses[1], m = L.marks[Math.min(4, L.marks.length - 1)];
    const it = makeItem(rng, {rar:4, boss:b, depth:1, cls});
    MAP.drops.push({x:m[1] + m[3] * 0.45, y:m[2] + m[3] * 0.35, kind:"item", item:it});
  }
}
function drawMap(){
  const c = mctx, {s, L} = mapScale();
  c.clearRect(0, 0, MW, MW);
  c.fillStyle = "#0b0907"; c.fillRect(0, 0, MW, MW);
  const [x0, y0] = toMap(-L.size/2, -L.size/2);
  c.fillStyle = L.ground; c.globalAlpha = 0.28; c.fillRect(x0, y0, L.size * s, L.size * s); c.globalAlpha = 1;
  c.strokeStyle = "#3a2e23"; c.lineWidth = 6; c.strokeRect(x0 + 3, y0 + 3, L.size * s - 6, L.size * s - 6);
  // 小路
  c.strokeStyle = "rgba(200,170,120,.35)"; c.lineWidth = 3;
  const routes = MAP.level === "vigrid"
    ? [[0,1],[0,2],[0,3],[0,4],[0,5],[1,2],[2,4],[4,5],[5,3],[3,1]]
    : L.marks.slice(1).map((_, i) => [0, i + 1]);
  routes.forEach(([a, b]) => { const A = toMap(L.marks[a][1], L.marks[a][2]), B = toMap(L.marks[b][1], L.marks[b][2]); c.beginPath(); c.moveTo(A[0], A[1]); c.lineTo(B[0], B[1]); c.stroke(); });
  // 地标
  L.marks.forEach((m, i) => {
    const [x, y] = toMap(m[1], m[2]);
    c.fillStyle = i === 0 ? "rgba(232,185,98,.12)" : "rgba(239,229,212,.07)"; c.strokeStyle = "rgba(239,229,212,.35)"; c.lineWidth = 1.5;
    c.beginPath(); c.arc(x, y, m[3] * s, 0, Math.PI * 2); c.fill(); c.setLineDash([4, 4]); c.stroke(); c.setLineDash([]);
  });
  // 掉落：金币、素材
  if ($("#map-small").checked){
    MAP.drops.forEach(d => {
      if (d.kind === "item") return;
      const [x, y] = toMap(d.x, d.y);
      c.fillStyle = d.kind === "coin" ? "#d9a441" : SLOT[d.slot].matColor;
      c.fillRect(x - 1.5, y - 1.5, 3, 3);
    });
  }
  // 地标名字
  c.textAlign = "center"; c.font = "600 13px 'Noto Serif SC','Songti SC',serif";
  L.marks.forEach((m, i) => {
    const [x, y] = toMap(m[1], m[2]);
    const ty = i === 0 && MAP.level === "vigrid" ? y - m[3] * s + 18 : y + 4;
    c.lineWidth = 3; c.strokeStyle = "rgba(11,9,7,.85)"; c.strokeText(m[0], x, ty);
    c.fillStyle = "#efe5d4"; c.fillText(m[0], x, ty);
  });
  // 装备
  MAP.drops.filter(d => d.kind === "item").sort((a, b) => a.item.rar - b.item.rar).forEach(d => {
    const [x, y] = toMap(d.x, d.y);
    const r = 4 + d.item.rar * 1.5;
    if (d.item.rar >= 2){ c.strokeStyle = RAR[d.item.rar].hex; c.globalAlpha = 0.6; c.lineWidth = 1.5; c.beginPath(); c.moveTo(x, y - r); c.lineTo(x, y - r - 6 - d.item.rar * 3); c.stroke(); c.globalAlpha = 1; }
    c.fillStyle = RAR[d.item.rar].hex; c.strokeStyle = MAP.hover === d ? "#fff" : "#0b0907"; c.lineWidth = MAP.hover === d ? 2 : 1;
    c.beginPath(); c.moveTo(x, y - r); c.lineTo(x + r, y); c.lineTo(x, y + r); c.lineTo(x - r, y); c.closePath(); c.fill(); c.stroke();
  });
  // 玩家与 Boss
  const [px, py] = toMap(260, 420);
  c.fillStyle = "#7fd18b"; c.beginPath(); c.moveTo(px, py - 8); c.lineTo(px + 6, py + 6); c.lineTo(px - 6, py + 6); c.closePath(); c.fill();
  c.font = "500 11px 'Noto Sans SC',sans-serif"; c.fillStyle = "#7fd18b"; c.fillText("你", px, py + 18);
  const bm = L.marks[2];
  const [bx, by] = toMap(bm[1], bm[2] + bm[3] * 0.55);
  c.fillStyle = "#ff7a3d"; c.beginPath(); c.arc(bx, by, 6, 0, Math.PI * 2); c.fill();
  c.fillStyle = "#ff7a3d"; c.fillText(BOSSES[L.bosses[0]].n, bx, by - 10);
  c.textAlign = "left"; c.font = "500 12px 'IBM Plex Mono',monospace"; c.fillStyle = "#a6978a";
  c.fillText(`M · ${L.n} · ${L.size}×${L.size}`, 14, MW - 12);
}
function mapLegend(){
  $("#map-legend").innerHTML = RAR.map(r => `<span class="legend-row"><i style="background:${r.hex}"></i>${r.n}装备</span>`).join("") +
    `<span class="legend-row"><i style="background:#d9a441;transform:none;width:6px;height:6px"></i>金币</span><span class="legend-row"><i style="background:#9fd8ff;transform:none;width:6px;height:6px"></i>部位素材</span><span class="legend-row" style="color:#7fd18b">▲ 你</span><span class="legend-row" style="color:#ff7a3d">● Boss</span>`;
}
function mapReset(){ MAP.drops = []; MAP.seed = 31 + LV_OF[MAP.level] * 100; scatterMap(70); MAP.hover = null; $("#map-tip").textContent = "把鼠标移到菱形上，查看地上是什么。"; drawMap(); }
$("#map-level").addEventListener("change", e => { MAP.level = e.target.value; mapReset(); });
$("#map-scatter").addEventListener("click", () => { scatterMap(25); drawMap(); });
$("#map-small").addEventListener("change", drawMap);
MAP.cv.addEventListener("mousemove", e => {
  const rect = MAP.cv.getBoundingClientRect();
  const mx = (e.clientX - rect.left) * MW / rect.width, my = (e.clientY - rect.top) * MW / rect.height;
  let best = null, bd = 12;
  MAP.drops.forEach(d => { if (d.kind !== "item") return; const [x, y] = toMap(d.x, d.y); const dd = Math.hypot(mx - x, my - y); if (dd < bd){ bd = dd; best = d; } });
  if (best !== MAP.hover){
    MAP.hover = best;
    $("#map-tip").innerHTML = best ? `<b style="color:${RAR[best.item.rar].hex}">${itemName(best.item)}</b><div class="small muted">${RAR[best.item.rar].n} · ${SLOT[best.item.slot].n} · 位于「${areaAt(best.x, best.y)}」</div>` : "把鼠标移到菱形上，查看地上是什么。";
    drawMap();
  }
});
mapLegend(); mapReset();

/* ---------- 06 武器 ---------- */
const WP = {cls:"swordsman", id:"katana", t:0, running:false, visible:true, hits:new Set(), last:0};
const wcv = $("#w-canvas");
const WWd = 440, WHt = 240;
const wctx = setupCanvas(wcv, WWd, WHt);
const PP = {x:150, y:125};
const ENEMIES = [[235,105],[258,152],[205,62],[322,88],[350,165],[398,118],[72,82],[86,172]];
const AIM_A = Math.atan2(ENEMIES[0][1] - PP.y, ENEMIES[0][0] - PP.x);
const CYCLE = 1.3;
const colorAt = (c, i) => c === "rainbow" ? `hsl(${(i * 51) % 360},90%,72%)` : c;
const angDiff = (a, b) => { let d = a - b; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2; return d; };
function curDef(){ return findWeapon(WP.cls, WP.id); }
function blinkPos(t){
  const def = curDef(); if (!def.p.some(p => p.t === "blink")) return null;
  if (t < 0.2 || t > 0.8) return null;
  return {x:ENEMIES[0][0] + Math.cos(AIM_A) * 30, y:ENEMIES[0][1] + Math.sin(AIM_A) * 30};
}
function enemyPos(i, t){
  let [x, y] = ENEMIES[i];
  curDef().p.forEach(s => {
    if (s.t === "proj" && s.pull && i === 0){
      const th = (Math.hypot(x - PP.x, y - PP.y) - 10) / s.speed;
      const k = Math.max(0, Math.min(1, (t - th) / 0.25)) * (t < CYCLE - 0.15 ? 1 : 0);
      x += (PP.x + 40 * Math.cos(AIM_A) - x) * k; y += (PP.y + 40 * Math.sin(AIM_A) - y) * k;
    }
    if (s.t === "ring" && s.at === "self"){
      const d = Math.hypot(x - PP.x, y - PP.y);
      if (d < s.r + 10){
        const k = Math.max(0, Math.min(1, (t - (s.delay || 0)) / 0.45));
        const bump = s.inward ? -24 * k : 16 * Math.sin(Math.min(1, k) * Math.PI);
        const ux = (x - PP.x) / d, uy = (y - PP.y) / d;
        x += ux * bump; y += uy * bump;
      }
    }
  });
  return [x, y];
}
function starts(s){
  const n = s.rate || 1, base = s.delay || 0, out = [];
  for (let i = 0; i < n; i++) out.push(base + (s.ramp ? CYCLE * 0.8 * Math.sqrt(i / n) : i * (CYCLE * 0.8 / n)));
  return out;
}
function hitTest(px, py, r, hits, t){ ENEMIES.forEach((_, i) => { const [x, y] = enemyPos(i, t); if (Math.hypot(x - px, y - py) < r) hits.add(i); }); }
function drawFan(c, s, age, i, origin, hits, t){
  const d = 0.26, k = age / d; if (k > 1.4) return;
  const A = s.arc * Math.PI / 180;
  const dirs = [s.blinkAim != null ? s.blinkAim : AIM_A]; if (s.back) dirs.push(dirs[0] + Math.PI);
  const sign = ((i % 2) ? -1 : 1) * (s.rev ? -1 : 1);
  const fade = k > 1 ? 1 - (k - 1) / 0.4 : 1;
  dirs.forEach(dir => {
    const a0 = s.arc >= 360 ? dir - Math.PI : dir - sign * A / 2;
    const a1 = a0 + sign * A * Math.min(1, k);
    const lo = Math.min(a0, a1), hi = Math.max(a0, a1);
    c.globalAlpha = 0.22 * fade; c.fillStyle = colorAt(s.c, i);
    c.beginPath(); c.moveTo(origin.x, origin.y); c.arc(origin.x, origin.y, s.reach, lo, hi); c.closePath(); c.fill();
    c.globalAlpha = fade; c.lineWidth = (s.w || 7) * (1 - Math.min(1, k) * 0.5); c.lineCap = "round";
    if (s.c === "rainbow"){
      for (let q = 0; q < 6; q++){ c.strokeStyle = colorAt("rainbow", q); c.beginPath(); c.arc(origin.x, origin.y, s.reach * (0.82 + q * 0.03), lo, hi); c.stroke(); }
    } else { c.strokeStyle = s.c; c.beginPath(); c.arc(origin.x, origin.y, s.reach * 0.88, lo, hi); c.stroke(); }
    c.globalAlpha = 1;
    if (k <= 1) ENEMIES.forEach((_, j) => { const [x, y] = enemyPos(j, t); const dd = Math.hypot(x - origin.x, y - origin.y); const a = Math.atan2(y - origin.y, x - origin.x); if (dd < s.reach + 8 && (s.arc >= 360 || (angDiff(a, (lo + hi) / 2) >= -(hi - lo) / 2 - 0.05 && angDiff(a, (lo + hi) / 2) <= (hi - lo) / 2 + 0.05))) hits.add(j); });
  });
}
function drawPrim(c, s, t, hits, gt){
  const origin = blinkPos(t) || PP;
  starts(s).forEach((st, i) => {
    const age = t - st; if (age < 0) return;
    switch (s.t){
      case "fan": drawFan(c, s, age, i, origin, hits, t); break;
      case "wave": {
        const d = 0.45, k = age / d; if (k > 1) return;
        const r = 50 + (s.reach - 50) * k;
        c.globalAlpha = 1 - k * 0.6; c.strokeStyle = s.c; c.lineWidth = 7; c.lineCap = "round";
        c.beginPath(); c.arc(PP.x, PP.y, r, AIM_A - 0.45, AIM_A + 0.45); c.stroke(); c.globalAlpha = 1;
        ENEMIES.forEach((_, j) => { const [x, y] = enemyPos(j, t); const dd = Math.hypot(x - PP.x, y - PP.y); if (Math.abs(dd - r) < 12 && Math.abs(angDiff(Math.atan2(y - PP.y, x - PP.x), AIM_A)) < 0.5) hits.add(j); });
        break;
      }
      case "line": {
        const d = 0.6, k = age / d; if (k > 1) return;
        const len = s.reach * Math.min(1, k / 0.25);
        const ex = PP.x + Math.cos(AIM_A) * len, ey = PP.y + Math.sin(AIM_A) * len;
        c.globalAlpha = 1 - Math.max(0, k - 0.4); c.strokeStyle = "rgba(200,220,255,.5)"; c.lineWidth = 10; c.beginPath(); c.moveTo(PP.x, PP.y); c.lineTo(ex, ey); c.stroke();
        c.strokeStyle = s.c; c.lineWidth = 3; c.beginPath(); c.moveTo(PP.x, PP.y); c.lineTo(ex, ey); c.stroke(); c.globalAlpha = 1;
        if (k > 0.35){ ENEMIES.forEach((_, j) => { const [x, y] = enemyPos(j, t); const rx = x - PP.x, ry = y - PP.y; const proj = rx * Math.cos(AIM_A) + ry * Math.sin(AIM_A); const perp = Math.abs(-rx * Math.sin(AIM_A) + ry * Math.cos(AIM_A)); if (proj > 0 && proj < s.reach && perp < 16){ hits.add(j); c.strokeStyle = "#fff"; c.lineWidth = 2; c.beginPath(); c.moveTo(x - 9, y - 9); c.lineTo(x + 9, y + 9); c.stroke(); } }); }
        break;
      }
      case "proj": {
        const n = s.n || 1, size = s.size || 3;
        for (let j = 0; j < n; j++){
          const off = n > 1 ? (j / (n - 1) - 0.5) * (s.spread || 0) * Math.PI / 180 : 0;
          const ang = AIM_A + off, dist = s.speed * age;
          let x, y, done = false, endX, endY, hitAge = 0;
          if (s.homing){
            const tgt = enemyPos([0, 1, 2, 3, 4][j % 5], t);
            const total = Math.hypot(tgt[0] - PP.x, tgt[1] - PP.y) * 1.3; const u = Math.min(1, dist / total);
            const cx = PP.x + Math.cos(ang) * 90, cy = PP.y + Math.sin(ang) * 90;
            x = (1-u)*(1-u)*PP.x + 2*(1-u)*u*cx + u*u*tgt[0]; y = (1-u)*(1-u)*PP.y + 2*(1-u)*u*cy + u*u*tgt[1];
            done = u >= 1; endX = tgt[0]; endY = tgt[1]; hitAge = total / s.speed;
          } else if (s.boomerang){
            const R = 200, u = dist / (2 * R); if (u > 1) continue;
            x = PP.x + Math.cos(ang) * R * Math.sin(Math.PI * u); y = PP.y + Math.sin(ang) * R * Math.sin(Math.PI * u);
            c.strokeStyle = s.c; c.lineWidth = 2; c.beginPath(); c.arc(x, y, size + 2, gt * 20, gt * 20 + 4.5); c.stroke();
          } else {
            const tgt = enemyPos(0, 0);
            const maxd = s.reach || (s.pierce ? 320 : Math.hypot(tgt[0] - PP.x, tgt[1] - PP.y));
            const dd = Math.min(dist, maxd);
            x = PP.x + Math.cos(ang) * dd; y = PP.y + Math.sin(ang) * dd;
            done = dist >= maxd; endX = x; endY = y; hitAge = maxd / s.speed;
          }
          if (s.pull){ const [tx, ty] = enemyPos(0, t); if (dist > 20){ c.strokeStyle = "rgba(201,214,224,.6)"; c.lineWidth = 1.5; c.beginPath(); c.moveTo(PP.x, PP.y); c.lineTo(done ? tx : x, done ? ty : y); c.stroke(); } if (done) continue; }
          if (done){
            if (s.blast){ const bk = Math.min(1, (age - hitAge) / 0.3); if (bk < 1){ c.globalAlpha = 1 - bk; c.strokeStyle = s.c; c.lineWidth = 4; c.beginPath(); c.arc(endX, endY, s.blast * bk, 0, Math.PI * 2); c.stroke(); c.fillStyle = s.c; c.globalAlpha = (1 - bk) * 0.25; c.fill(); c.globalAlpha = 1; hitTest(endX, endY, s.blast * bk + 8, hits, t); } }
            continue;
          }
          c.strokeStyle = s.c; c.globalAlpha = 0.5; c.lineWidth = Math.max(1, size - 1);
          c.beginPath(); c.moveTo(x - Math.cos(ang) * 12, y - Math.sin(ang) * 12); c.lineTo(x, y); c.stroke(); c.globalAlpha = 1;
          c.fillStyle = s.c; c.beginPath(); c.arc(x, y, size, 0, Math.PI * 2); c.fill();
          hitTest(x, y, 12, hits, t);
        }
        break;
      }
      case "ring": {
        const cnt = s.count || 1;
        for (let q = 0; q < cnt; q++){
          const a2 = age - q * 0.18, d = 0.4, k = a2 / d; if (k < 0 || k > 1) continue;
          const at = s.at === "target" ? enemyPos(0, t) : [PP.x, PP.y];
          const R = s.r * (cnt > 1 ? (0.55 + 0.45 * q / (cnt - 1)) : 1);
          const r = s.inward ? R * (1 - k) + 8 : R * k;
          c.globalAlpha = 1 - k * 0.6; c.strokeStyle = s.c; c.lineWidth = 5 * (1 - k) + 1.5;
          c.beginPath(); c.arc(at[0], at[1], r, 0, Math.PI * 2); c.stroke();
          c.globalAlpha = 0.12 * (1 - k); c.fillStyle = s.c; c.fill(); c.globalAlpha = 1;
          ENEMIES.forEach((_, j) => { const [x, y] = enemyPos(j, t); if (Math.abs(Math.hypot(x - at[0], y - at[1]) - r) < 14) hits.add(j); });
        }
        break;
      }
      case "rays": {
        const d = 0.55, k = age / d; if (k > 1) return;
        const base = AIM_A + (s.spin ? k * Math.PI * 2 / 3 : 0);
        for (let q = 0; q < s.n; q++){
          const a = base + q * Math.PI * 2 / s.n; const len = s.len * Math.min(1, k / 0.2);
          c.globalAlpha = 1 - k * 0.5; c.strokeStyle = colorAt(s.c, q); c.lineWidth = 6 * (1 - k) + 2; c.lineCap = "round";
          c.beginPath(); c.moveTo(PP.x, PP.y); c.lineTo(PP.x + Math.cos(a) * len, PP.y + Math.sin(a) * len); c.stroke(); c.globalAlpha = 1;
          ENEMIES.forEach((_, j) => { const [x, y] = enemyPos(j, t); const rx = x - PP.x, ry = y - PP.y; const pr = rx * Math.cos(a) + ry * Math.sin(a); const pe = Math.abs(-rx * Math.sin(a) + ry * Math.cos(a)); if (pr > 0 && pr < len && pe < 12) hits.add(j); });
        }
        break;
      }
      case "orbit": {
        for (let q = 0; q < s.n; q++){
          const a = gt * 3 + q * Math.PI * 2 / s.n;
          const x = PP.x + Math.cos(a) * s.r, y = PP.y + Math.sin(a) * s.r;
          c.strokeStyle = s.c; c.globalAlpha = 0.35; c.lineWidth = 3; c.beginPath(); c.arc(PP.x, PP.y, s.r, a - 0.6, a); c.stroke(); c.globalAlpha = 1;
          c.fillStyle = s.c; c.beginPath(); c.arc(x, y, 5, 0, Math.PI * 2); c.fill();
          hitTest(x, y, 14, hits, t);
        }
        break;
      }
      case "chain": {
        const d = 0.35, k = age / d; if (k > 1) return;
        const pts = [enemyPos(0, t), enemyPos(1, t), enemyPos(3, t), enemyPos(4, t)];
        c.globalAlpha = 1 - k * 0.7; c.strokeStyle = s.c; c.lineWidth = 2;
        for (let q = 0; q < pts.length - 1; q++){
          const [ax, ay] = pts[q], [bx, by] = pts[q + 1];
          c.beginPath(); c.moveTo(ax, ay);
          for (let z = 1; z < 6; z++){ const u = z / 6; c.lineTo(ax + (bx - ax) * u + Math.sin(gt * 40 + z * 7 + q) * 6, ay + (by - ay) * u + Math.cos(gt * 37 + z * 5) * 6); }
          c.lineTo(bx, by); c.stroke(); hits.add([0, 1, 3, 4][q + 1]);
        }
        c.globalAlpha = 1;
        break;
      }
      case "ground": {
        const k = age / (CYCLE - (s.delay || 0)); if (k > 1) return;
        const flick = s.c.includes("6a2a") && !reduceMotion ? 0.8 + 0.2 * Math.sin(gt * 18) : 1;
        c.globalAlpha = 0.3 * (1 - k) * flick; c.fillStyle = s.c;
        if (s.at === "arc"){ c.beginPath(); c.moveTo(PP.x, PP.y); c.arc(PP.x, PP.y, 112, AIM_A - 1.05, AIM_A + 1.05); c.closePath(); c.fill(); }
        else { const at = s.at === "target" ? enemyPos(0, t) : [PP.x, PP.y]; c.beginPath(); c.arc(at[0], at[1], s.r || 40, 0, Math.PI * 2); c.fill(); }
        c.globalAlpha = 1;
        break;
      }
      case "tick": {
        const d = 1.0, k = (age - 0.25) / d; if (k < 0 || k > 1) return;
        [0, 1, 2].forEach(j => { const [x, y] = enemyPos(j, t); for (let q = 0; q < 3; q++){ const ph = (k * 2 + q / 3) % 1; c.globalAlpha = 1 - ph; c.fillStyle = s.c; c.fillRect(x - 6 + q * 5, y - 10 - ph * 16, 3, 3); } });
        c.globalAlpha = 1;
        break;
      }
      case "claw": {
        const d = 0.22, k = age / d; if (k > 1.5) return;
        const [x, y] = enemyPos(0, t); const pa = AIM_A + Math.PI / 2 + 0.5;
        c.globalAlpha = k > 1 ? 1 - (k - 1) / 0.5 : 1; c.strokeStyle = s.c; c.lineWidth = 3; c.lineCap = "round";
        [-8, 0, 8].forEach((o, q) => { const len = 26 * Math.min(1, k * 1.5 - q * 0.15); if (len <= 0) return; const ox = x + Math.cos(AIM_A) * o, oy = y + Math.sin(AIM_A) * o; c.beginPath(); c.moveTo(ox - Math.cos(pa) * 13, oy - Math.sin(pa) * 13); c.lineTo(ox - Math.cos(pa) * 13 + Math.cos(pa) * len, oy - Math.sin(pa) * 13 + Math.sin(pa) * len); c.stroke(); });
        c.globalAlpha = 1; if (k <= 1) hits.add(0);
        break;
      }
      case "blink": {
        if (age > 0.18 && age < 0.85){
          c.globalAlpha = 0.35; drawSprite(c, img(`char_${WP.cls}.png`), PP.x, PP.y + 28, 0.75, 0.35); c.globalAlpha = 1;
          c.strokeStyle = s.c; c.globalAlpha = 0.5; c.setLineDash([3, 5]); c.lineWidth = 2; const bp = blinkPos(t) || PP; c.beginPath(); c.moveTo(PP.x, PP.y); c.lineTo(bp.x, bp.y); c.stroke(); c.setLineDash([]); c.globalAlpha = 1;
          drawFan(c, {arc:80, reach:60, c:s.c, w:9, blinkAim:AIM_A + Math.PI}, age - 0.25, 0, bp, hits, t);
        } else drawFan(c, {arc:80, reach:75, c:"#ff7f8a"}, age < 0.18 ? age : age - 0.85, 0, PP, hits, t);
        break;
      }
    }
  });
}
function drawWeapon(gt){
  const c = wctx, def = curDef();
  const t = reduceMotion ? 0.3 : gt % CYCLE;
  c.clearRect(0, 0, WWd, WHt);
  c.fillStyle = "#1b1612"; c.fillRect(0, 0, WWd, WHt);
  c.strokeStyle = "#241d17"; c.lineWidth = 1;
  for (let x = 0; x < WWd; x += 32){ c.beginPath(); c.moveTo(x, 0); c.lineTo(x, WHt); c.stroke(); }
  for (let y = 0; y < WHt; y += 32){ c.beginPath(); c.moveTo(0, y); c.lineTo(WWd, y); c.stroke(); }
  const hits = new Set();
  def.p.filter(s => s.t === "ground").forEach(s => drawPrim(c, s, t, hits, gt));
  ENEMIES.forEach((_, i) => {
    const [x, y] = enemyPos(i, t);
    c.fillStyle = "rgba(0,0,0,.35)"; c.beginPath(); c.ellipse(x, y + 9, 9, 3, 0, 0, Math.PI * 2); c.fill();
    c.fillStyle = WP.hits.has(i) ? "#fff2e0" : "#6b3b34"; c.strokeStyle = "#c86a5a"; c.lineWidth = 1.5;
    c.beginPath(); c.arc(x, y, 9, 0, Math.PI * 2); c.fill(); c.stroke();
  });
  const bp = blinkPos(t);
  drawSprite(c, img(`char_${WP.cls}.png`), bp ? bp.x : PP.x, (bp ? bp.y : PP.y) + 28, 0.75, 1, bp ? true : false);
  def.p.filter(s => s.t !== "ground").forEach(s => drawPrim(c, s, t, hits, gt));
  WP.hits = hits;
  c.font = "500 11px 'IBM Plex Mono',monospace"; c.fillStyle = "#6b5d50"; c.textAlign = "left";
  c.fillText("示意动画 · 圆点是敌人，被击中时变白", 10, WHt - 10);
}
function wLoop(ts){
  const dt = WP.last ? Math.min(0.05, (ts - WP.last) / 1000) : 0; WP.last = ts;
  WP.t += dt; drawWeapon(WP.t);
  if (WP.visible && !reduceMotion) requestAnimationFrame(wLoop); else { WP.running = false; WP.last = 0; }
}
function wKick(){ if (!WP.running){ WP.running = true; requestAnimationFrame(wLoop); } }
new IntersectionObserver(ents => { WP.visible = ents[0].isIntersecting; if (WP.visible) wKick(); }).observe(wcv);
function bar(label, v, lowGood){
  const w = Math.min(100, v / 3.6 * 100);
  const txt = `×${v}`;
  return `<span>${label}</span><span class="stbar"><i style="width:${w}%;background:${(lowGood ? v <= 1 : v >= 1) ? "var(--gold)" : "#8b6f52"}"></i><b style="left:${100 / 3.6}%"></b></span><span class="mono">${txt}</span>`;
}
function renderWeapons(){
  $("#w-tabs").innerHTML = Object.entries(CLASSES).map(([id, C]) => `<button type="button" class="w-tab" data-c="${id}" aria-pressed="${WP.cls === id}"><img class="px" src="img/char_${id}.png" alt=""><span><b>${C.n}</b><br><span class="small muted">${C.passive}</span></span></button>`).join("");
  const list = WEAPONS[WP.cls];
  let html = "";
  [0, 1, 2, 3].forEach(lv => {
    const ws = lv === 0 ? list.filter(w => w.init) : list.filter(w => w.lv === lv);
    html += `<div class="w-item lvl-h">${lv === 0 ? "初始武器" : `${["", "第一关", "第二关", "第三关"][lv]}掉落`}</div>`;
    ws.forEach(w => html += `<button type="button" class="w-item" data-w="${w.id}" aria-pressed="${WP.id === w.id}"><img class="px" src="${icon(WICON[WP.cls], wColor(w)).url}" alt=""><span>${w.n}<small>${w.cost}</small></span></button>`);
  });
  $("#w-list").innerHTML = html;
  const w = curDef();
  $("#w-body").innerHTML = `<h3>${w.n}<span class="pill">${w.init ? "初始" : ["", "第一关", "第二关", "第三关"][w.lv]}</span><span class="pill">${w.cost}</span></h3>
    <div><span class="muted">外观：</span>${w.look}</div>
    <div><span class="muted">攻击：</span>${w.atk}</div>
    ${w.fx ? `<div><span class="muted">特效：</span>${w.fx}</div>` : ""}
    ${w.reuse ? `<div><span class="muted">可复用：</span><span class="code">${w.reuse}</span></div>` : ""}
    <div class="stbars" style="margin-top:4px">${bar("单次伤害", w.st[0])}${bar("出手间隔", w.st[1], true)}${bar("范围", w.st[2])}</div>
    <p class="small muted">相对初始武器的倍率，竖线是 ×1。间隔越短越好。数字只表示方向，没有做平衡。</p>`;
  drawWeapon(WP.t); wKick();
}
$("#w-tabs").addEventListener("click", e => { const b = e.target.closest("button[data-c]"); if (!b) return; WP.cls = b.dataset.c; WP.id = WEAPONS[WP.cls][0].id; renderWeapons(); });
$("#w-list").addEventListener("click", e => { const b = e.target.closest("button[data-w]"); if (!b) return; WP.id = b.dataset.w; WP.t = 0; renderWeapons(); });
renderWeapons();

/* ---------- 06 武器外观：分层 + 挂点示意 ---------- */
const LK = {cv:$("#look-canvas"), k:1, t:0, running:false, visible:true, last:0};
const LW = 640, LH = 220;
const lctx = setupCanvas(LK.cv, LW, LH);
const STYLE = {swordsman:"挥砍", gunslinger:"瞄准射击", assassin:"突刺", mage:"举杖施法"};
function lookPose(cls, p){
  if (cls === "swordsman"){ const k = p < 0.22 ? p / 0.22 : p < 0.55 ? 1 : 1 - (p - 0.55) / 0.45; return {a:-2.0 + 2.6 * k, ext:0, swing:p < 0.3 ? p / 0.3 : 0}; }
  if (cls === "gunslinger"){ const q = p % 0.34, r = q < 0.07; return {a:r ? -0.22 : 0, ext:r ? -4 : 0, flash:r}; }
  if (cls === "assassin"){ const q = p % 0.5; const k = q < 0.08 ? q / 0.08 : q < 0.22 ? 1 - (q - 0.08) / 0.14 : 0; return {a:0.12, ext:14 * k}; }
  const k = p < 0.3 ? p / 0.3 : p < 0.7 ? 1 : 1 - (p - 0.7) / 0.3; return {a:0.7 - 2.3 * k, ext:0, glow:k};
}
function drawLook(gt){
  const c = lctx;
  c.clearRect(0, 0, LW, LH); c.fillStyle = "#1b1612"; c.fillRect(0, 0, LW, LH);
  const p = reduceMotion ? 0.2 : (gt % 1.4) / 1.4;
  Object.keys(CLASSES).forEach((cls, i) => {
    const list = WEAPONS[cls], w = list[LK.k % list.length], col = wColor(w), len = Math.sqrt(w.st[2]);
    const x = 80 + i * 160, y = 150, A = lookPose(cls, p);
    c.fillStyle = "rgba(0,0,0,.35)"; c.beginPath(); c.ellipse(x, y + 4, 18, 5, 0, 0, Math.PI * 2); c.fill();
    c.fillStyle = "#3a3f4a"; c.fillRect(x - 9, y - 14, 7, 18); c.fillRect(x + 2, y - 14, 7, 18);
    c.fillStyle = CLASSES[cls].color; c.fillRect(x - 11, y - 42, 22, 30);
    c.fillStyle = "#e8cfae"; c.fillRect(x - 8, y - 60, 16, 16);
    c.fillStyle = "#17110c"; c.fillRect(x + 2, y - 54, 3, 3);
    const sx = x + 6, sy = y - 36;
    const hx = sx + Math.cos(A.a) * 18 + A.ext, hy = sy + Math.sin(A.a) * 18;
    if (A.swing && !reduceMotion){
      c.strokeStyle = col; c.globalAlpha = 0.45 * (1 - A.swing); c.lineWidth = 6;
      c.beginPath(); c.arc(sx, sy, 18 + 30 * len, -2.0, -2.0 + 2.6 * Math.min(1, A.swing * 1.4)); c.stroke(); c.globalAlpha = 1;
    }
    c.save(); c.translate(hx, hy); c.rotate(A.a);
    if (cls === "swordsman"){ const L = 30 * len; c.fillStyle = "#7a5233"; c.fillRect(-6, -2, 8, 4); c.fillStyle = "#d9a441"; c.fillRect(1, -5, 3, 10); c.fillStyle = col; c.fillRect(4, -2, L, 4); }
    else if (cls === "gunslinger"){ const L = 14 + 10 * len; c.fillStyle = "#7a5233"; c.fillRect(-3, 0, 6, 10); c.fillStyle = "#8b93a1"; c.fillRect(-3, -4, L, 6); c.fillStyle = col; c.fillRect(2, -3, 6, 4); if (A.flash){ c.fillStyle = "#ffd27a"; c.beginPath(); c.arc(L + 2, -1, 5, 0, Math.PI * 2); c.fill(); } }
    else if (cls === "assassin"){ const L = 12 + 6 * len; c.fillStyle = "#3a2e23"; c.fillRect(-4, -2, 6, 4); c.fillStyle = col; c.beginPath(); c.moveTo(2, -3); c.lineTo(2 + L, 0); c.lineTo(2, 3); c.closePath(); c.fill(); }
    else { c.fillStyle = "#7a5233"; c.fillRect(-10, -2, 36, 4); c.fillStyle = col; c.beginPath(); c.arc(28, 0, 5 + 3 * (A.glow || 0), 0, Math.PI * 2); c.fill(); if (A.glow){ c.globalAlpha = 0.3 * A.glow; c.beginPath(); c.arc(28, 0, 14, 0, Math.PI * 2); c.fill(); c.globalAlpha = 1; } }
    c.restore();
    c.strokeStyle = "#e8cfae"; c.lineWidth = 6; c.beginPath(); c.moveTo(sx, sy); c.lineTo(hx, hy); c.stroke();
    c.strokeStyle = "#ff7a3d"; c.lineWidth = 1.5; c.strokeRect(hx - 3, hy - 3, 6, 6);
    c.textAlign = "center";
    c.fillStyle = col === "#ffffff" ? "#efe5d4" : col; c.font = "600 14px 'Noto Serif SC','Songti SC',serif"; c.fillText(w.n, x, y + 32);
    c.fillStyle = "#a6978a"; c.font = "12px 'Noto Sans SC',sans-serif"; c.fillText(`${CLASSES[cls].n} · ${STYLE[cls]}`, x, y + 50);
  });
}
function lookLoop(ts){
  const dt = LK.last ? Math.min(0.05, (ts - LK.last) / 1000) : 0; LK.last = ts;
  LK.t += dt; drawLook(LK.t);
  if (LK.visible && !reduceMotion) requestAnimationFrame(lookLoop); else { LK.running = false; LK.last = 0; }
}
function lookKick(){ if (!LK.running){ LK.running = true; requestAnimationFrame(lookLoop); } }
new IntersectionObserver(ents => { LK.visible = ents[0].isIntersecting; if (LK.visible) lookKick(); }).observe(LK.cv);
$("#look-next").addEventListener("click", () => { LK.k++; drawLook(LK.t); lookKick(); });
drawLook(0);

/* ---------- 06 套装 ---------- */
$("#set-grid").innerHTML = Object.entries(SETS).map(([id, S]) => `<div class="card set-card" style="--sc:${S.c}">
  <div><span class="pill">${["", "第一关", "第二关", "第三关"][S.lv]}</span> <b style="font-family:var(--f-display);font-size:18px;color:${S.c}">${S.n}</b></div>
  <div class="pcs">${ARMOR_SLOTS.map(s => `<div class="pc"><img class="px" src="${icon(SLOT[s].icon, S.c).url}" alt=""><span>${S.pieces[s]}</span></div>`).join("")}</div>
  <div class="bonus"><b>4 件共鸣：</b>${S.bonus}</div>
  <div class="small muted">${S.why}</div>
</div>`).join("");

/* ---------- 06 信仰词缀 ---------- */
let activeGod = "thor";
function renderGods(){
  const row = $("#god-row"); row.innerHTML = "";
  Object.entries(GODS).forEach(([id, g]) => {
    const b = el("button", {class:"god", type:"button", "aria-pressed": String(id === activeGod)}, `<img src="img/${g.img}" alt=""><span>${g.n}</span>`);
    b.addEventListener("click", () => { activeGod = id; renderGods(); });
    row.appendChild(b);
  });
  const g = GODS[activeGod];
  $("#god-detail").innerHTML = `<img src="img/${g.img}" alt="${g.n}">
    <div style="display:grid;gap:8px;align-content:start">
      <h3>${g.n} · ${g.title}</h3>
      <p class="muted small">${g.tag}</p>
      <p><span class="pill on">${g.n}之誓</span> <b class="r3">若本局信仰${g.n}：${g.sig} +${FAITH_BASE}%</b>（Ⅰ阶，随深度放大）；首次选神时${g.n}必定出现在候选里。</p>
      <p>例：<span class="r3">受眷的英灵翼盔</span>（传说，带「${g.n}之誓」）、<span class="r4">雷鸣的半面冠</span>（神器，必带一条信仰词缀）</p>
      <p class="small muted">没有信仰${g.n}时这条词缀不生效，但「出现在候选里」仍然有用：开局就能决定要不要走${g.n}。</p>
    </div>`;
}
renderGods();

/* ---------- 07 Boss ---------- */
$("#boss-grid").innerHTML = Object.values(BOSSES).map(b => `<div class="card boss">
  <div class="portrait"><img class="px" src="img/${b.img}" alt="${b.n}"></div>
  <div style="display:grid;gap:3px">
    <div class="meta">${b.at} · ${b.n} · 金币 ${b.gold}</div>
    <div class="item-name">${b.item}<span class="muted small" style="font-family:var(--f-body)"> · ${SLOT[b.slot].n}${b.adaptive ? " · 随职业变形" : ""}</span></div>
    <div class="eff">${b.eff}</div>
    <div class="meta">${b.why}</div>
    <div class="mat"><img class="px" src="${BOSSMAT()}" width="14" height="14" alt="" style="vertical-align:-2px"> 素材：${b.mat}</div>
  </div></div>`).join("");
$("#fate-grid").innerHTML = FATE_ITEMS.map(f => `<div class="card boss">
  <div class="portrait"><img class="${f.img.endsWith(".jpg") ? "" : "px"}" src="img/${f.img}" alt="" style="${f.img.endsWith(".jpg") ? "object-fit:cover" : ""}"></div>
  <div style="display:grid;gap:3px">
    <div class="meta">${f.src}</div>
    <div class="item-name">${f.n}<span class="muted small" style="font-family:var(--f-body)"> · ${f.slot}</span></div>
    <div class="eff">${f.eff}</div>
    <div class="meta">${f.note}</div>
  </div></div>`).join("");

/* ---------- 09 表格 ---------- */
$("#res-table").innerHTML = [
  [`<img class="px" src="${COIN()}" width="18" height="18" alt=""> 金币`, "小怪 5%；Boss 必掉；存活、通关、命运结算（原奖励点）；图鉴每点亮 10 格 +300", "永久强化（原价不变）、装备强化、重铸词头、打造"],
  [`<img class="px" src="${EMBER()}" width="18" height="18" alt=""> 余烬`, "分解任意装备", "强化、打造"],
  [SLOTS.map(s => `<img class="px" src="${MAT(s.id)}" width="18" height="18" alt="" title="${s.mat}">`).join("") + " 部位素材 ×5", `小怪 1.5%（部位随机）；分解同部位的装备。${SLOTS.map(s => `${s.n}「${s.mat}」`).join("、")}`, "强化同部位的装备；定向打造"],
  [`<img class="px" src="${BOSSMAT()}" width="18" height="18" alt=""> Boss 素材 ×9`, "每次击败该 Boss 必掉 1 个", "打造该 Boss 的神器"],
].map(r => `<tr><td class="nowrap">${r[0]}</td><td class="small">${r[1]}</td><td class="small">${r[2]}</td></tr>`).join("");
let cum = {m:0, e:0, g:0}, exp = {m:0, e:0, g:0};
$("#enh-table").innerHTML = ENH.map((e, i) => { cum.m += e.m; cum.e += e.e; cum.g += e.g; exp.m += e.m / e.p; exp.e += e.e / e.p; exp.g += e.g / e.p; return `<tr><td class="nowrap">+${i+1}${ENH_NOTE[i+1] ? `<div class="small r3">${ENH_NOTE[i+1]}</div>` : ""}</td><td class="num">${e.m}</td><td class="num">${e.e}</td><td class="num">${e.g}</td><td class="num">${Math.round(e.p*100)}%</td></tr>`; }).join("") +
  `<tr><td class="muted">合计</td><td class="num muted">${cum.m}</td><td class="num muted">${cum.e}</td><td class="num muted">${cum.g.toLocaleString()}</td><td class="muted small">全部成功</td></tr>` +
  `<tr><td class="muted">期望</td><td class="num muted">${Math.round(exp.m)}</td><td class="num muted">${Math.round(exp.e)}</td><td class="num muted">${Math.round(exp.g).toLocaleString()}</td><td class="muted small">含失败重试</td></tr>`;
$("#reforge-cost").textContent = "金币：" + RAR.map((r, i) => `${r.n} ${REFORGE[i]}`).join("、") + "。神器只会重铸出好词头。";
$("#salv-line").textContent = "素材 / 余烬：" + RAR.map(r => `${r.n} ${r.salvM} / ${r.salvE}`).join("、") + "。";
let dt = "";
for (let d = 1; d <= 10; d++){
  dt += `<tr><td>${ROMAN[d]}</td><td class="num">×${DEPTH.hp(d).toFixed(2)}</td><td class="num">×${DEPTH.dmg(d).toFixed(2)}</td><td class="num">×${DEPTH.aff(d).toFixed(2)}</td><td class="num">×${DEPTH.drop(d).toFixed(2)}</td><td class="num">×${DEPTH.gold(d).toFixed(1)}</td><td class="num">+${DEPTH.high(d)}</td><td class="num">${Math.round(DEPTH.sig(d)*100)}%</td><td class="muted">${DEPTH.unlock(d)}</td></tr>`;
}
$("#depth-table").innerHTML = dt;

/* ---------- 08 模拟器 ---------- */
const CODEX_TOTAL = 40 + 24 + Object.keys(BOSSES).length + FATE_ITEMS.length;
const fresh = () => ({gold:0, embers:0, mats:Object.fromEntries(SLOTS.map(s => [s.id, 0])), bossMats:{}, bossKills:{}, pityMiss:{}, codex:new Set(), equipped:{}, bag:[], drops:[], runs:0, seed:20261106, last:null});
const SIM = fresh();
const opts = () => ({level:$("#s-level").value, cls:$("#s-class").value, depth:+$("#s-depth").value, kills:+$("#s-kills").value, luck:+$("#s-luck").value});
function totals(){
  const st = {}, pf = {};
  const add = (o, k, v) => o[k] = (o[k] || 0) + v;
  Object.values(SIM.equipped).forEach(it => {
    add(st, it.imp.k, it.imp.v * (1 + 0.1 * it.enh));
    it.affixes.forEach(a => add(st, a.k, a.v * (!a.bad && it.enh >= 5 ? 1.1 : 1)));
    Object.entries(it.prefix.fx).forEach(([k, v]) => add(pf, k, v * (it.enh >= 10 ? 1.5 : 1)));
  });
  return {st, pf};
}
function collect(it, res){
  if (!SIM.codex.has(it.codex)){
    SIM.codex.add(it.codex); res.newCodex++;
    if (SIM.codex.size % 10 === 0){ SIM.gold += 300; res.milestone += 300; }
  }
}
function simulateRun(o){
  const rng = mulberry32(SIM.seed++);
  const L = LEVELS[o.level];
  const {st, pf} = totals();
  const luck = o.luck + (st.luck || 0) + (pf.luck || 0);
  const lm = 1 + luck / 100, dm = DEPTH.drop(o.depth);
  const goldMult = DEPTH.gold(o.depth) * (1 + (st.gold || 0) / 100);
  const res = {items:[], gold:0, mats:0, sigs:0, firsts:0, newCodex:0, milestone:0, luck};
  for (let i = 0; i < o.kills; i++){
    if (rng() < DROP.gold * lm * dm) res.gold += DROP.goldPile * goldMult;
    if (rng() < DROP.mat * lm * dm){ SIM.mats[pick(rng, SLOTS).id]++; res.mats++; }
  }
  for (let e = 0; e < L.elites; e++){
    const t = 40 + e * L.every;
    if (rng() >= Math.min(1, DEPTH.elite(o.depth) * lm * dm)) continue;
    res.items.push(makeGear(rng, rollRarity(rng, t / 60, o.depth, 0, luck), o.cls, o.level, o.depth, "精英", t));
  }
  L.bosses.forEach((b, i) => {
    const t = 180 * (i + 1) + 5, B = BOSSES[b];
    res.gold += B.gold * goldMult;
    res.items.push(makeGear(rng, bossGearRarity(rng, o.depth, luck), o.cls, o.level, o.depth, `Boss · ${B.n}`, t));
    SIM.bossMats[b] = (SIM.bossMats[b] || 0) + 1;
    const kills = SIM.bossKills[b] || 0;
    let hit;
    if (kills === 0){ hit = true; res.firsts++; }
    else { const miss = SIM.pityMiss[b] || 0; hit = miss + 1 >= DROP.pityHard || rng() < DEPTH.sig(o.depth) * lm + DROP.pityStep * miss; }
    SIM.bossKills[b] = kills + 1;
    if (hit){ SIM.pityMiss[b] = 0; res.sigs++; res.items.push(makeItem(rng, {rar:4, boss:b, depth:o.depth, cls:o.cls, src: kills === 0 ? `首杀 · ${B.n}` : `神器 · ${B.n}`, t:t + 1})); }
    else SIM.pityMiss[b] = (SIM.pityMiss[b] || 0) + 1;
  });
  res.settle = 150 + L.clear;
  res.gold = Math.round(res.gold + res.settle);
  SIM.gold += res.gold;
  res.items.sort((a, b) => a.t - b.t);
  res.items.forEach(it => { SIM.bag.push(it); collect(it, res); });
  SIM.runs++;
  return res;
}
const PFX_SCORE = {top:30, good:15, mixed:5, bad:-20};
function score(it){ return it.rar * 100 + PFX_SCORE[it.prefix.g] + it.affixes.reduce((n, a) => n + (a.bad ? -12 : 10), 0) + it.affixes.filter(a => a.star).length * 15 + it.enh * 8 + (it.faith ? 10 : 0); }
const usable = (it, cls) => it.slot !== "weapon" || !it.cls || it.cls === cls;
function itemCard(it, i){
  const o = opts();
  const eq = SIM.equipped[it.slot] && SIM.equipped[it.slot].id === it.id;
  const ok = usable(it, o.cls);
  const acts = it.salvaged ? '<span class="sub">已分解</span>' : eq ? '<span class="sub">已穿戴</span>'
    : `<button class="btn sm" type="button" data-act="equip" ${ok ? "" : "disabled"}>${ok ? "装备" : `仅限${CLASSES[it.cls].n}`}</button><button class="btn sm" type="button" data-act="salvage">分解</button>`;
  return `<div class="item${it.salvaged ? " salvaged" : ""}" style="--rc:${RAR[it.rar].hex};--i:${i}" data-id="${it.id}">
    <div class="top"><img class="px" src="${icon(it.icon, RAR[it.rar].hex).url}" alt=""><div><div class="nm" style="color:${RAR[it.rar].hex}">${itemName(it)}</div>
    <div class="sub">${RAR[it.rar].n} · ${SLOT[it.slot].n} · ${ROMAN[it.depth]}阶 · ${srcLabel(it)}</div></div></div>
    ${itemBody(it)}
    <div class="acts">${acts}</div></div>`;
}
function renderDrops(){
  const r = SIM.last;
  const counts = [0,0,0,0,0]; SIM.drops.forEach(it => counts[it.rar]++);
  $("#s-summary").innerHTML = `<span class="pill">第 ${SIM.runs} 局</span>` + (r ? `<span class="pill" style="color:var(--gold)">金币 +${r.gold.toLocaleString()}</span><span class="pill">部位素材 +${r.mats}</span>` : "") +
    counts.map((c, i) => `<span class="pill" style="color:${RAR[i].hex}">${RAR[i].n} ${c}</span>`).join("") +
    (r ? `${r.firsts ? `<span class="pill on">首杀神器 ${r.firsts}</span>` : ""}${r.newCodex ? `<span class="pill">图鉴新点亮 ${r.newCodex}</span>` : ""}<span class="pill">掉落用幸运 ${r.luck}</span>` : "");
  $("#s-drops").innerHTML = SIM.drops.length ? SIM.drops.map(itemCard).join("") : '<p class="muted small">这一局什么也没掉。</p>';
}
function enhCost(it){ return ENH[it.enh]; }
function canEnh(it){ const c = enhCost(it); return c && it.enh < RAR[it.rar].cap && SIM.mats[it.slot] >= c.m && SIM.embers >= c.e && SIM.gold >= c.g; }
function renderDoll(){
  const o = opts();
  const slotBox = id => {
    const it = SIM.equipped[id];
    if (!it) return `<div class="slot"><img class="px" src="${icon(id === "weapon" ? WICON[o.cls] : SLOT[id].icon, "#555").url}" alt="" style="opacity:.25"><div><div class="sn">${SLOT[id].n}</div><div class="muted">空</div></div></div>`;
    const c = enhCost(it), capped = it.enh >= RAR[it.rar].cap;
    return `<div class="slot filled" style="--rc:${RAR[it.rar].hex}"><img class="px" src="${icon(it.icon, RAR[it.rar].hex).url}" alt=""><div><div class="sn">${SLOT[id].n}${it.enh ? ` · +${it.enh}` : ""}</div><div class="in" style="color:${RAR[it.rar].hex}">${itemName(it)}</div></div>
      <div class="acts">${capped ? `<span class="sub r3">已到上限 +${RAR[it.rar].cap}</span>` : `<button class="btn sm" type="button" data-enh="${id}" ${canEnh(it) ? "" : "disabled"} title="${SLOT[id].mat} ${c.m}、余烬 ${c.e}、金币 ${c.g}，成功率 ${Math.round(c.p * 100)}%">强化 ${c.m}/${c.e}/${c.g}</button>`}<button class="btn sm" type="button" data-ref="${id}" ${SIM.gold >= REFORGE[it.rar] ? "" : "disabled"}>重铸 ${REFORGE[it.rar]}</button><button class="btn sm" type="button" data-off="${id}">卸下</button></div></div>`;
  };
  $("#s-doll").innerHTML = `<img class="px hero-sprite" src="img/char_${o.cls}.png" alt="${CLASSES[o.cls].n}">
    <div class="col">${["weapon","helm","chest","legs","boots"].map(slotBox).join("")}</div>`;
  $("#s-wallet").innerHTML = `<div class="wallet">
      <span><img class="px" src="${COIN()}" alt="">金币 <b class="mono" style="color:var(--gold)">${SIM.gold.toLocaleString()}</b></span>
      <span><img class="px" src="${EMBER()}" alt="">余烬 <b class="mono">${SIM.embers}</b></span>
      ${SLOTS.map(s => `<span><img class="px" src="${MAT(s.id)}" alt="">${s.mat} <b class="mono">${SIM.mats[s.id]}</b></span>`).join("")}
    </div>
    <div class="small muted">行囊 ${SIM.bag.filter(it => !it.salvaged).length} 件 · 图鉴 ${SIM.codex.size} / ${CODEX_TOTAL} · 强化按钮是「素材 / 余烬 / 金币」。模拟存档只存在于当前页面。</div>`;
  const {st, pf} = totals();
  const keys = Object.keys(STAT).filter(k => Math.abs(st[k] || 0) > 0.001);
  const pfs = Object.entries(pf).filter(([, v]) => Math.abs(v) > 0.001);
  $("#s-stats").innerHTML = (keys.length ? keys.map(k => `<span class="${st[k] < 0 ? "pfx-bad" : ""}">${fmtStat(k, st[k])}</span><span></span><span class="eq">${STAT[k].card ? `≈ ${(st[k] / STAT[k].card).toFixed(1)} 张普通卡` : ""}</span>`).join("") : '<span class="muted">还没有穿戴装备。</span><span></span><span></span>') +
    (pfs.length ? `<span style="grid-column:1/-1;margin-top:4px">词头合计：${pfs.map(([k, v]) => `<span class="${v < 0 ? "pfx-bad" : "pfx-good"}">${PREFIX_LABEL[k]} ${v > 0 ? "+" : ""}${Math.round(v * 10) / 10}${PREFIX_FLAT[k] ? "" : "%"}</span>`).join("、")}</span>` : "");
  const sets = {};
  ARMOR_SLOTS.forEach(s => { const it = SIM.equipped[s]; if (it && it.set) sets[it.set] = (sets[it.set] || 0) + 1; });
  const rows = Object.entries(sets).map(([id, n]) => `<div class="res${n >= 4 ? " on" : ""}"><b style="color:${SETS[id].c}">${SETS[id].n} ${n}/4</b> · ${n >= 4 ? `共鸣：${SETS[id].bonus}` : `还差 ${4 - n} 件`}</div>`);
  Object.values(SIM.equipped).forEach(it => { if (it.faith) rows.push(`<div class="res on"><b class="r3">${GODS[it.faith.g].n}之誓</b>（${itemName(it)}）· ${GODS[it.faith.g].sig} +${it.faith.v}%</div>`); });
  $("#s-res").innerHTML = rows.length ? rows.join("") : '<p class="muted small">穿戴防具后显示套装进度；传说、神器的信仰词缀也列在这里。</p>';
  const L = LEVELS[o.level];
  $("#s-pity").innerHTML = L.bosses.map(b => {
    const B = BOSSES[b], kills = SIM.bossKills[b] || 0, miss = SIM.pityMiss[b] || 0, m = SIM.bossMats[b] || 0;
    const lm = 1 + (o.luck + (st.luck || 0) + (pf.luck || 0)) / 100;
    const chance = kills === 0 ? 1 : (miss + 1 >= DROP.pityHard ? 1 : Math.min(1, DEPTH.sig(o.depth) * lm + DROP.pityStep * miss));
    const can = m >= DROP.bossMatNeed && SIM.embers >= DROP.craftEmbers && SIM.gold >= DROP.craftGold;
    return `<div class="pity-row"><img class="px" src="img/${B.img}" alt="${B.n}"><div style="display:grid;gap:3px">
      <div><b>${B.n}</b> · <span class="r4">${B.item}</span> <span class="muted">击败 ${kills} 次</span></div>
      <div class="small">下次神器几率 <b class="mono">${Math.round(chance * 100)}%</b>${kills === 0 ? "（首杀必掉）" : ""}</div>
      <div class="bar"><i style="width:${Math.round(chance * 100)}%"></i></div>
      <div class="small">${B.mat} <b class="mono">${Math.min(m, 99)}</b> / ${DROP.bossMatNeed} <button class="btn sm" type="button" data-craft="${b}" ${can ? "" : "disabled"}>打造（余烬 ${DROP.craftEmbers}、金币 ${DROP.craftGold}）</button></div>
      <div class="bar mat"><i style="width:${Math.min(100, m / DROP.bossMatNeed * 100)}%"></i></div>
    </div></div>`;
  }).join("");
}
const render = () => { renderDrops(); renderDoll(); };
function toast(msg){ $("#s-toast").textContent = msg; }
function autoEquip(){
  const cls = opts().cls;
  SIM.bag.forEach(it => { if (it.salvaged || !usable(it, cls)) return; const cur = SIM.equipped[it.slot]; if (!cur || score(it) > score(cur)) SIM.equipped[it.slot] = it; });
}
function salvage(it){
  it.salvaged = true;
  const back = Math.floor(it.invested / 2);
  SIM.mats[it.slot] += RAR[it.rar].salvM + back; SIM.embers += RAR[it.rar].salvE;
  return RAR[it.rar].salvM + back;
}
function runOnce(){
  const res = simulateRun(opts());
  SIM.drops = res.items; SIM.last = res;
  render();
  toast(`${res.sigs ? `本局掉落神器 ${res.sigs} 件。` : "本局没有掉神器，保底几率已提高。"}${res.milestone ? `图鉴里程碑金币 +${res.milestone}。` : ""}`);
}
$("#s-run").addEventListener("click", runOnce);
$("#s-run10").addEventListener("click", () => {
  const o = opts(); let all = [], gold = 0, mats = 0, sigs = 0, firsts = 0, newCodex = 0, milestone = 0, luck = 0;
  for (let i = 0; i < 10; i++){ const r = simulateRun(o); all = all.concat(r.items); gold += r.gold; mats += r.mats; sigs += r.sigs; firsts += r.firsts; newCodex += r.newCodex; milestone += r.milestone; luck = r.luck; }
  const counts = [0,0,0,0,0]; all.forEach(it => counts[it.rar]++);
  SIM.drops = all.slice().sort((a, b) => score(b) - score(a)).slice(0, 24);
  SIM.last = {gold, mats, sigs, firsts, newCodex, milestone, luck};
  render();
  toast(`10 局共掉落装备 ${all.length} 件（${counts.map((c, i) => `${RAR[i].n} ${c}`).join("、")}），神器 ${sigs} 件，金币 +${gold.toLocaleString()}。下方只列出评分最高的 24 件。`);
});
$("#s-bulk-go").addEventListener("click", () => {
  const max = +$("#s-bulk").value; let n = 0, m = 0, e = 0;
  const eqIds = new Set(Object.values(SIM.equipped).map(it => it.id));
  SIM.bag.forEach(it => { if (it.salvaged || eqIds.has(it.id) || it.rar > max) return; n++; e += RAR[it.rar].salvE; m += salvage(it); });
  render(); toast(n ? `统一分解 ${n} 件：部位素材 +${m}，余烬 +${e}。穿着的装备不会被分解。` : "没有符合条件的装备。");
});
$("#s-reset").addEventListener("click", () => { Object.assign(SIM, fresh()); render(); toast("模拟存档已清空，下一局所有 Boss 都是首杀。"); });
const findItem = id => SIM.bag.find(it => it.id === id) || Object.values(SIM.equipped).find(it => it.id === id);
$("#s-drops").addEventListener("click", e => {
  const b = e.target.closest("button[data-act]"); if (!b || b.disabled) return;
  const it = findItem(+b.closest(".item").dataset.id); if (!it) return;
  if (b.dataset.act === "equip"){ SIM.equipped[it.slot] = it; toast(`已穿戴 ${itemName(it)}。${it.weapon ? `攻击方式变为：${it.weapon.atk}` : ""}`); }
  else { const m = salvage(it); toast(`分解 ${itemName(it)}：${SLOT[it.slot].mat} +${m}，余烬 +${RAR[it.rar].salvE}。`); }
  render();
});
$("#s-doll").addEventListener("click", e => {
  const enh = e.target.closest("button[data-enh]"), ref = e.target.closest("button[data-ref]"), off = e.target.closest("button[data-off]");
  if (enh && !enh.disabled){
    const it = SIM.equipped[enh.dataset.enh], c = enhCost(it);
    SIM.mats[it.slot] -= c.m; SIM.embers -= c.e; SIM.gold -= c.g; it.invested += c.m;
    if (Math.random() < c.p){ it.enh++; toast(`强化成功：${itemName(it)} +${it.enh}。${ENH_NOTE[it.enh] ? `解锁：${ENH_NOTE[it.enh]}。` : ""}`); }
    else toast(`强化失败：材料已消耗，${itemName(it)} 保持 +${it.enh}，不降级。`);
  }
  if (ref && !ref.disabled){
    const it = SIM.equipped[ref.dataset.ref], old = it.prefix.n;
    SIM.gold -= REFORGE[it.rar];
    it.prefix = rollPrefix(Math.random, it.slot === "weapon" ? "weapon" : "armor", it.rar);
    toast(`重铸：${old} → ${it.prefix.n}（${PREFIX_GROUP[it.prefix.g].n}）。`);
  }
  if (off){ delete SIM.equipped[off.dataset.off]; toast("已卸下，放回行囊。"); }
  render();
});
$("#s-pity").addEventListener("click", e => {
  const b = e.target.closest("button[data-craft]"); if (!b || b.disabled) return;
  const id = b.dataset.craft, o = opts();
  SIM.bossMats[id] -= DROP.bossMatNeed; SIM.embers -= DROP.craftEmbers; SIM.gold -= DROP.craftGold;
  const it = makeItem(mulberry32(SIM.seed++), {rar:4, boss:id, depth:o.depth, cls:o.cls, src:"打造", t:0});
  SIM.bag.push(it); SIM.drops.unshift(it);
  const res = {newCodex:0, milestone:0}; collect(it, res);
  toast(`用 ${DROP.bossMatNeed} 个${BOSSES[id].mat}打造了 ${itemName(it)}。`);
  render();
});
const outs = () => { $("#o-depth").textContent = ROMAN[+$("#s-depth").value]; $("#o-kills").textContent = $("#s-kills").value; $("#o-luck").textContent = $("#s-luck").value; };
["#s-depth","#s-kills","#s-luck"].forEach(s => $(s).addEventListener("input", () => { outs(); renderDoll(); }));
$("#s-level").addEventListener("change", renderDoll);
$("#s-class").addEventListener("change", () => {
  const cls = opts().cls, w = SIM.equipped.weapon;
  if (w && !usable(w, cls)){ delete SIM.equipped.weapon; toast(`${CLASSES[w.cls].n}的武器已卸下，${CLASSES[cls].n}不能用。`); }
  render(); mapReset();
  if (!demo.drops.length) drawDemo();
});
outs();
runOnce();
autoEquip();
render();
toast("已模拟第一关首通：三位 Boss 首杀必掉神器，并自动穿上了每个部位评分最高的装备。");
})();
