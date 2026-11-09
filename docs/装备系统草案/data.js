/* 诸界余烬装备系统草案 v4 · 数据表
   页面里所有表格、演示和模拟器都从这里读数，改数值只改这一个文件。 */
"use strict";

/* ---------- 稀有度：稀有度决定「数值」，不决定「款式」 ---------- */
// aff 随机词缀条数；bad 每条随机词缀是坏词缀的几率；prefixW 词头 [坏, 双刃, 好] 的权重；star 每条好词缀的极品几率；faith 信仰词缀几率；cap 强化上限；salvM / salvE 分解得到的部位素材 / 余烬
const RAR = [
  {n:"普通", hex:"#d1d6e0", aff:1, bad:0.35, prefixW:[35,20,45], star:0,    faith:0,   cap:4,  salvM:1,  salvE:2},
  {n:"稀有", hex:"#66a8ff", aff:2, bad:0.20, prefixW:[20,20,60], star:0.04, faith:0,   cap:6,  salvM:2,  salvE:6},
  {n:"史诗", hex:"#c773ff", aff:3, bad:0.10, prefixW:[8,17,75],  star:0.06, faith:0,   cap:8,  salvM:4,  salvE:15},
  {n:"传说", hex:"#ffbd40", aff:3, bad:0,    prefixW:[0,10,90],  star:0.08, faith:0.3, cap:10, salvM:8,  salvE:40},
  {n:"神器", hex:"#ff5a36", aff:2, bad:0,    prefixW:[0,0,100],  star:0.10, faith:1,   cap:10, salvM:15, salvE:120},
];

/* ---------- 五个部位 ---------- */
// imp 固有属性：Ⅰ阶数值，随余烬深度放大，每强化 +1 再 +10%
const SLOTS = [
  {id:"weapon", n:"武器", icon:null,    mat:"矮人精钢", matColor:"#b8c4d6", imp:{k:"wdmg",  v:8},   kind:"weapon"},
  {id:"helm",   n:"头盔", icon:"helm",  mat:"渡鸦翎",   matColor:"#4a5470", imp:{k:"vit",   v:8},   kind:"armor"},
  {id:"chest",  n:"胸甲", icon:"armor", mat:"熊魂皮",   matColor:"#a0683c", imp:{k:"vit",   v:15},  kind:"armor"},
  {id:"legs",   n:"护腿", icon:"legs",  mat:"冰狼筋",   matColor:"#9fd8ff", imp:{k:"regen", v:0.2}, kind:"armor"},
  {id:"boots",  n:"鞋子", icon:"boots", mat:"骏马鬃",   matColor:"#d9a441", imp:{k:"speed", v:3},   kind:"armor"},
];
const SLOT = Object.fromEntries(SLOTS.map(s => [s.id, s]));
const ARMOR_SLOTS = ["helm", "chest", "legs", "boots"];

/* ---------- 属性文字 ---------- */
// n 名字；u 单位；neg = 数值越大越好但显示成「-」（冷却类）；card：同名属性卡的普通档数值，用来换算「≈ 几张普通卡」
const STAT = {
  wdmg:{n:"武器伤害", u:"%"}, str:{n:"全伤害", u:"%", card:10}, crit:{n:"暴击率", u:"%", card:5}, haste:{n:"武器冷却", u:"%", neg:1, card:8},
  cdr:{n:"神术冷却", u:"%", neg:1, card:5}, vit:{n:"最大生命", u:"", card:20}, regen:{n:"每秒回复", u:"", card:1}, dodge:{n:"闪避", u:"%", card:8},
  speed:{n:"移速", u:"%", card:8}, magnet:{n:"拾取范围", u:"%", card:30}, wisdom:{n:"经验", u:"%", card:15}, luck:{n:"幸运", u:"", card:3},
  gold:{n:"金币获取", u:"%"}, boss:{n:"对 Boss 伤害", u:"%"}, elite:{n:"对精英伤害", u:"%"}, status:{n:"对异常状态敌人伤害", u:"%"},
  area:{n:"基础武器范围", u:"%"},
  sw_niten:{n:"二刀流伤害", u:"%"}, gs_card:{n:"纸牌神射暴击伤害", u:"%"}, as_formation:{n:"破阵加成上限", u:"%"}, mg_ult:{n:"大招所需击杀", u:"%", neg:1},
};

/* ---------- 词头：参考泰拉瑞亚，每件装备必有一个，决定名字前缀，有好有坏 ---------- */
// 词头的数值不随深度变化，重铸只换词头
const PREFIX_LABEL = {dmg:"伤害", spd:"攻速", area:"范围", crit:"暴击", kb:"击退", hp:"最大生命", hpP:"最大生命", eva:"闪避", mov:"移速", reg:"每秒回复", xp:"经验", luck:"幸运"};
const PREFIX_FLAT = {reg:true, luck:true};  // 这两项不是百分比
const PREFIXES = {
  weapon: [
    {n:"神铸", g:"top",   fx:{dmg:15, spd:10, crit:5, area:10}, note:"诸神亲手锻造。对应泰拉瑞亚近战最好的「传奇」"},
    {n:"英灵", g:"good",  fx:{dmg:12, crit:5}, note:"对应「神级」"},
    {n:"雷鸣", g:"good",  fx:{dmg:10, spd:6}},
    {n:"锋锐", g:"good",  fx:{dmg:8}},
    {n:"迅捷", g:"good",  fx:{spd:10}},
    {n:"致命", g:"good",  fx:{crit:6}},
    {n:"巨灵", g:"good",  fx:{area:15}},
    {n:"狂战", g:"mixed", fx:{dmg:20, hp:-10}, note:"伤害换生命，适合会走位的玩家"},
    {n:"沉雷", g:"mixed", fx:{dmg:12, kb:30, spd:-10}},
    {n:"轻灵", g:"mixed", fx:{spd:15, dmg:-6}},
    {n:"锈蚀", g:"bad",   fx:{dmg:-10}},
    {n:"迟钝", g:"bad",   fx:{spd:-12}},
    {n:"残缺", g:"bad",   fx:{dmg:-12, area:-10}},
    {n:"怯懦", g:"bad",   fx:{crit:-4, kb:-15}},
    {n:"断折", g:"bad",   fx:{dmg:-25, kb:-20}, note:"对应泰拉瑞亚的「破碎」"},
  ],
  armor: [
    {n:"瓦尔哈拉", g:"top",   fx:{hpP:8, eva:3, mov:3}, note:"英灵殿的赐福，防具里最好的词头"},
    {n:"坚韧", g:"good",  fx:{hpP:6}},
    {n:"灵巧", g:"good",  fx:{eva:3}},
    {n:"轻捷", g:"good",  fx:{mov:4}},
    {n:"回春", g:"good",  fx:{reg:0.3}},
    {n:"博识", g:"good",  fx:{xp:6}},
    {n:"受眷", g:"good",  fx:{luck:3}, note:"幸运会乘到所有掉率上，刷子最爱"},
    {n:"贪婪", g:"mixed", fx:{luck:6, hpP:-8}},
    {n:"笨重", g:"mixed", fx:{hpP:12, mov:-5}},
    {n:"轻薄", g:"mixed", fx:{mov:7, hpP:-6}},
    {n:"破旧", g:"bad",   fx:{hpP:-5}},
    {n:"沉坠", g:"bad",   fx:{mov:-4}},
    {n:"霉烂", g:"bad",   fx:{reg:-0.2}},
    {n:"不祥", g:"bad",   fx:{luck:-3}},
  ],
};
const PREFIX_GROUP = {top:{n:"顶级", c:"#7fd18b"}, good:{n:"好", c:"#7fd18b"}, mixed:{n:"双刃", c:"#e8b962"}, bad:{n:"坏", c:"#ff6b6b"}};

/* ---------- 随机词缀：好词缀池，条数由稀有度决定；坏词缀池在下面 ---------- */
const AFFIXES = [
  {k:"str",    r:[2,5],     d:0, slots:"all"},
  {k:"crit",   r:[1.5,4],   d:1, slots:["weapon","helm"]},
  {k:"haste",  r:[2,5],     d:0, slots:["weapon","boots"]},
  {k:"area",   r:[4,10],    d:0, slots:["weapon"]},
  {k:"cdr",    r:[2,4],     d:0, slots:["helm","chest"]},
  {k:"vit",    r:[6,15],    d:0, slots:["helm","chest","legs"]},
  {k:"regen",  r:[0.2,0.5], d:1, slots:["chest","legs"]},
  {k:"dodge",  r:[1.5,4],   d:1, slots:["legs","boots"]},
  {k:"speed",  r:[2,5],     d:0, slots:["boots","legs"]},
  {k:"magnet", r:[8,20],    d:0, slots:["boots","helm"]},
  {k:"wisdom", r:[3,8],     d:0, slots:["helm"]},
  {k:"luck",   r:[1,2.5],   d:1, slots:["helm","legs","boots"]},
  {k:"gold",   r:[4,10],    d:0, slots:["chest","legs"]},
  {k:"boss",   r:[4,10],    d:0, slots:["weapon"]},
  {k:"elite",  r:[5,12],    d:0, slots:["weapon","chest"]},
  {k:"status", r:[4,10],    d:0, slots:["weapon"]},
  {k:"sw_niten",     r:[8,20], d:0, slots:["weapon"], cls:"swordsman"},
  {k:"gs_card",      r:[8,20], d:0, slots:["weapon"], cls:"gunslinger"},
  {k:"as_formation", r:[5,15], d:0, slots:["weapon"], cls:"assassin"},
  {k:"mg_ult",       r:[4,10], d:0, slots:["weapon"], cls:"mage"},
];
// 坏词缀：同一批属性的减益，红字显示；数值不随深度放大，也不会出极品
const BAD_AFFIXES = [
  {k:"str",    r:[2,4],     d:0, slots:"all"},
  {k:"crit",   r:[1,3],     d:1, slots:["weapon","helm"]},
  {k:"haste",  r:[3,6],     d:0, slots:["weapon","boots"]},
  {k:"area",   r:[4,8],     d:0, slots:["weapon"]},
  {k:"cdr",    r:[2,4],     d:0, slots:["helm","chest"]},
  {k:"vit",    r:[5,10],    d:0, slots:["helm","chest","legs"]},
  {k:"regen",  r:[0.1,0.3], d:1, slots:["chest","legs"]},
  {k:"speed",  r:[2,4],     d:0, slots:["boots","legs"]},
  {k:"magnet", r:[8,15],    d:0, slots:["boots","helm"]},
  {k:"wisdom", r:[3,6],     d:0, slots:["helm"]},
  {k:"luck",   r:[1,2],     d:1, slots:["helm","legs","boots"]},
];

/* ---------- 信仰词缀：传说 30% 带一条，神器必带一条；只看单件，不按件数叠加门槛 ---------- */
const GODS = {
  thor:  {n:"托尔",   title:"雷神",         tag:"爆发、范围、连锁",     sig:"落雷伤害",       img:"card_thor.jpg"},
  odin:  {n:"奥丁",   title:"众神之父",     tag:"印记、贯穿、召唤",     sig:"符文引爆伤害",   img:"card_odin.jpg"},
  loki:  {n:"洛基",   title:"诡计之神",     tag:"灼烧、迷惑、分身",     sig:"灼烧伤害",       img:"card_loki.jpg"},
  freyja:{n:"弗蕾亚", title:"爱与战争女神", tag:"环绕、防护、治疗",     sig:"金羽治疗量",     img:"card_freyja.jpg"},
  baldr: {n:"巴德尔", title:"光明之神",     tag:"贯穿、光痕、护盾",     sig:"光束伤害",       img:"card_baldr.jpg"},
  ran:   {n:"澜",     title:"海之女神",     tag:"聚怪、范围增伤、召唤", sig:"网的范围",       img:"card_ran.jpg"},
  freyr: {n:"弗雷",   title:"丰饶之神",     tag:"自动追击、经验、续航", sig:"自战之剑伤害",   img:"card_freyr.jpg"},
  skadi: {n:"斯卡蒂", title:"冬与狩猎女神", tag:"远射、冻结、移动输出", sig:"冰箭伤害",       img:"card_skadi.jpg"},
};
const FAITH_BASE = 12;  // Ⅰ阶数值（%），随深度放大

/* ---------- 四个职业，每个职业 1 把初始武器 + 10 把专属武器 ---------- */
// lv：在哪一关掉落（1 芬布尔之冬 / 2 亡者之船 / 3 最后之战）
// st：相对初始武器的 [单次伤害, 出手间隔, 范围]，只表示方向
// p：预览动画的图元；cost：「参数」= 改现有武器脚本的数值即可，「新逻辑」= 需要写新的攻击代码
const CLASSES = {
  swordsman:{n:"剑士", icon:"blade", color:"#f4ead2", passive:"二刀流：每第 4 刀前后双斩"},
  gunslinger:{n:"枪手", icon:"gun", color:"#ffbf73", passive:"纸牌神射：每弹匣最后一发必暴击并分裂"},
  assassin:{n:"刺客", icon:"dagger", color:"#ff7f8a", passive:"破阵：身边每个敌人伤害 +6%"},
  mage:{n:"法师", icon:"staff", color:"#a99bff", passive:"先知：升级时四选一"},
};
const WEAPONS = {
  swordsman: [
    {id:"katana", n:"太刀", init:true, look:"现有太刀", atk:"朝最近的敌人挥出 120° 扇形斩，每第 4 刀前后双斩。", st:[1,1,1], cost:"现有", p:[{t:"fan", arc:120, reach:110, c:"#f4ead2"}]},
    {id:"frostfang", n:"霜牙", lv:1, look:"冰蓝刀身，刀镡结霜", atk:"扇形斩不变；刀光扫过的地面留下 1.5 秒霜痕，踩上去的敌人减速 30%。", fx:"冰蓝刀光 + 地面霜痕", st:[0.9,1,1], cost:"参数 + 地面效果", reuse:"skadi_ice、ice_shard", p:[{t:"fan", arc:120, reach:110, c:"#9fd8ff"},{t:"ground", at:"arc", c:"#9fd8ff"}]},
    {id:"nodachi", n:"狼首野太刀", lv:1, look:"比人还长的大刀，刀柄雕着狼头", atk:"半圆形 180° 大斩，范围 +35%，出手间隔 +40%，击退翻倍。", fx:"橙色厚刀光", st:[1.5,1.4,1.35], cost:"参数", p:[{t:"fan", arc:180, reach:150, c:"#ffc27a", w:14}]},
    {id:"runesword", n:"符文直剑", lv:1, look:"维京式双刃直剑，剑脊刻符文", atk:"改为 50° 窄扇形突刺，射程 +60%，伤害 +20%。", fx:"细长白光", st:[1.2,1,1.6], cost:"参数", p:[{t:"fan", arc:50, reach:180, c:"#e8dcc0"}]},
    {id:"barrowblade", n:"墓丘古剑", lv:1, look:"布满铜绿的古剑，散发幽光", atk:"每次挥砍同时射出一道剑气，飞行 300 像素，穿透 3 个敌人。", fx:"幽绿剑气", st:[0.8,1,2.7], cost:"新逻辑（复用 Projectile）", p:[{t:"fan", arc:90, reach:80, c:"#9fe6b0"},{t:"wave", c:"#9fe6b0", reach:230}]},
    {id:"moonblade", n:"冥月弯刀", lv:2, look:"半月形的灰白弯刀", atk:"每一刀都是 360° 回旋斩，单次伤害 -25%。", fx:"环形灰白刀光", st:[0.75,1,0.9], cost:"参数", p:[{t:"fan", arc:360, reach:100, c:"#d8d0ff"}]},
    {id:"iai", n:"鞘鸣", lv:2, look:"黑漆刀鞘，拔刀时刀鸣", atk:"居合：每 2.4 秒拔刀一次，沿直线贯穿 280 像素，伤害 ×3.5。", fx:"一道白线 + 延迟爆开的刀痕", st:[3.5,2.4,2.5], cost:"新逻辑", p:[{t:"line", reach:260, c:"#ffffff"}]},
    {id:"nailsaw", n:"指甲锯刃", lv:2, look:"刀刃上嵌满死者的指甲", atk:"命中叠加流血，每层每秒 15% 伤害，最多 5 层，持续 3 秒。", fx:"暗红刀光 + 流血粒子", st:[0.85,1,1], cost:"参数 + 持续伤害", reuse:"nail_bolt", p:[{t:"fan", arc:120, reach:110, c:"#e07070"},{t:"tick", c:"#ff4d4d"}]},
    {id:"emberblade", n:"焰刃", lv:3, look:"刀身像未冷却的铁", atk:"刀光留下 2 秒火焰地面，敌人站在上面持续灼烧。", fx:"橙红刀光 + 火焰地面", st:[0.9,1,1], cost:"参数 + 地面效果", reuse:"loki_fire_patch（改色）", p:[{t:"fan", arc:120, reach:110, c:"#ff8a3d"},{t:"ground", at:"arc", c:"#ff6a2a"}]},
    {id:"giantbone", n:"巨人骨刀", lv:3, look:"用巨人肋骨磨成的刀", atk:"每第 3 刀砸地，在落点放出半径 120 的冲击波。", fx:"白色冲击环", st:[1.1,1.1,1], cost:"新逻辑（复用 Shockwave）", reuse:"frost_shockwave", p:[{t:"fan", arc:120, reach:110, c:"#e8e2d4"},{t:"ring", at:"target", r:70, c:"#e8e2d4", delay:0.35}]},
    {id:"bifrost", n:"虹光残刃", lv:3, look:"彩虹桥碎片磨成的刀，七色流转", atk:"每一刀 0.25 秒后有一道残影回斩，残影伤害 50%。", fx:"七色残影", st:[0.8,1,1], cost:"新逻辑", p:[{t:"fan", arc:120, reach:110, c:"#ffffff"},{t:"fan", arc:120, reach:110, c:"rainbow", delay:0.3, rev:true}]},
  ],
  gunslinger: [
    {id:"revolver", n:"左轮手枪", init:true, look:"现有左轮", atk:"快速单发，6 发一换弹，最后一发必暴击并分裂。", st:[1,1,1], cost:"现有", p:[{t:"proj", n:1, speed:520, c:"#ffbf73", rate:3}]},
    {id:"rifle", n:"猎熊长铳", lv:1, look:"枪管很长的猎枪，枪托包熊皮", atk:"射速 -50%，伤害 ×2.2，射程 +40%，穿透 +3。", fx:"粗弹道 + 枪口火焰", st:[2.2,2,1.4], cost:"参数", p:[{t:"proj", n:1, speed:760, c:"#ffd27a", size:5, pierce:true}]},
    {id:"shotgun", n:"截短霰弹枪", lv:1, look:"锯短的双管枪", atk:"一次喷出 5 发弹丸，扇形 40°，射程 -45%，近距离击退强。", fx:"扇形弹丸", st:[0.5,1.6,0.55], cost:"参数（复用双枪逻辑）", p:[{t:"proj", n:5, spread:40, speed:520, c:"#ffcf8a", reach:150}]},
    {id:"harpoon", n:"捕鲸鱼叉枪", lv:1, look:"峡湾码头的捕鲸枪，拖着绳子", atk:"射出鱼叉，命中后把目标拽到身前并定身 0.5 秒；弹匣 1 发，换弹 0.6 秒。", fx:"鱼叉 + 绳索", st:[1.8,1.8,1.1], cost:"新逻辑", p:[{t:"proj", n:1, speed:600, c:"#c9d6e0", size:4, pull:true}]},
    {id:"pepperbox", n:"连珠短铳", lv:1, look:"六根枪管转着打", atk:"弹匣 12 发，射速 +40%，单发伤害 -35%。", fx:"密集小弹", st:[0.65,0.7,1], cost:"参数", p:[{t:"proj", n:1, speed:560, c:"#ffb067", rate:6, size:2}]},
    {id:"nailgun", n:"指甲钉枪", lv:2, look:"用纳吉尔法尔的指甲当弹药", atk:"高速连射铁钉，每颗钉子叠一层「钉住」，5 层时定身 1 秒。", fx:"灰白钉子", st:[0.45,0.5,0.9], cost:"参数 + 叠层状态", reuse:"nail_bolt", p:[{t:"proj", n:1, speed:700, c:"#e8e2d4", rate:8, size:2}]},
    {id:"soullamp", n:"魂火铳", lv:2, look:"枪口挂着一盏青灯", atk:"子弹变慢但会追踪，命中后爆出半径 50 的魂火。", fx:"青绿追踪弹 + 小爆炸", st:[1.1,1.2,1], cost:"新逻辑", reuse:"will_o_wisp_aura", p:[{t:"proj", n:1, speed:300, c:"#8fe3d0", homing:true, blast:28}]},
    {id:"flare", n:"冥火信号枪", lv:2, look:"粗短的信号枪", atk:"子弹落地爆炸，留下 2 秒冥火地面。", fx:"抛物线弹 + 绿色火焰", st:[1.3,1.5,1], cost:"新逻辑", reuse:"hel_death_ground", p:[{t:"proj", n:1, speed:380, c:"#7cf0a0", blast:30},{t:"ground", at:"target", c:"#3fbf7f", delay:0.45}]},
    {id:"ricochet", n:"霹雳转轮", lv:3, look:"弹巢里有电光", atk:"子弹命中后在敌人之间弹射 2 次，每次 70% 伤害。", fx:"蓝白电弧", st:[0.9,1,1], cost:"新逻辑", reuse:"lightning", p:[{t:"proj", n:1, speed:620, c:"#9cc8ff"},{t:"chain", c:"#9cc8ff", delay:0.35}]},
    {id:"cannon", n:"巨人臼炮", lv:3, look:"霜巨人遗落的手炮", atk:"射速极慢，炮弹爆炸半径 120，击退。", fx:"大炮弹 + 爆炸", st:[3,2.6,1], cost:"新逻辑", reuse:"fire_giant_explosion", p:[{t:"proj", n:1, speed:340, c:"#ff9a4a", size:7, blast:70}]},
    {id:"gatling", n:"黄昏连铳", lv:3, look:"多管转轮枪，越打越烫", atk:"不用换弹；持续射击时射速越来越快，最多 ×3；停火 1 秒后回落。", fx:"枪管发红", st:[0.55,0.6,1], cost:"新逻辑", p:[{t:"proj", n:1, speed:640, c:"#ffcf6a", rate:10, size:2, ramp:true}]},
  ],
  assassin: [
    {id:"blades", n:"双刃", init:true, look:"现有双刃", atk:"射程极短、出手极快的近身连刺，左右手交替。", st:[1,1,1], cost:"现有", p:[{t:"fan", arc:80, reach:75, c:"#ff7f8a", rate:3}]},
    {id:"claws", n:"霜狼爪", lv:1, look:"缝在护手上的狼爪", atk:"三道平行爪痕，每第 4 击撕裂目标，流血 3 秒。", fx:"三道爪痕", st:[0.9,1,1], cost:"参数 + 持续伤害", reuse:"hit_claw", p:[{t:"claw", c:"#dfe8f0", rate:3}]},
    {id:"ravenknife", n:"渡鸦飞刀", lv:1, look:"黑羽装饰的投刀", atk:"近身连刺不变；每第 3 次出手额外掷出一把会追踪的飞刀。", fx:"黑色飞刀", st:[0.9,1,1], cost:"新逻辑（复用 Projectile）", p:[{t:"fan", arc:80, reach:75, c:"#ff7f8a", rate:2},{t:"proj", n:1, speed:420, c:"#5a5f7a", homing:true, delay:0.4}]},
    {id:"kusarigama", n:"锁镰", lv:1, look:"镰刀连着铁链", atk:"射程 +80%，出手间隔 +25%，160° 弧形横扫。", fx:"铁链 + 弧光", st:[1.2,1.25,1.8], cost:"参数", p:[{t:"fan", arc:160, reach:135, c:"#c9d6e0"}]},
    {id:"viper", n:"毒牙短剑", lv:1, look:"剑尖滴着绿液", atk:"每击叠一层毒，5 层时引爆，造成 300% 伤害。", fx:"绿色毒雾", st:[0.85,1,1], cost:"参数 + 叠层状态", reuse:"poison_pool", p:[{t:"fan", arc:80, reach:75, c:"#9ad66b", rate:3},{t:"tick", c:"#7fd18b"}]},
    {id:"shadow", n:"冥影刃", lv:2, look:"像影子一样没有反光", atk:"出手时 20% 几率瞬移到目标背后，这一击伤害 ×2。", fx:"黑色残影", st:[1,1,1], cost:"新逻辑（复用闪现）", p:[{t:"blink", c:"#b48cff"}]},
    {id:"chakram", n:"双月轮", lv:2, look:"一对边缘锋利的圆环", atk:"投出两枚回旋刃，飞出 220 像素后返回，往返各命中一次。", fx:"旋转银环", st:[0.8,1.3,2.9], cost:"新逻辑", p:[{t:"proj", n:2, spread:30, speed:420, c:"#e8e2d4", boomerang:true, size:4}]},
    {id:"bonespike", n:"骨刺", lv:2, look:"磨尖的长骨", atk:"直线突刺，射程 +60%，贯穿路上 3 个敌人。", fx:"骨白直线", st:[1.1,1.1,1.6], cost:"参数", reuse:"death_shards", p:[{t:"fan", arc:20, reach:150, c:"#efe5d4", rate:2}]},
    {id:"axes", n:"狂战双斧", lv:3, look:"两把短柄战斧", atk:"120° 大弧斩，出手间隔 0.55 秒，伤害 ×1.7。", fx:"厚重红弧", st:[1.7,1.7,1.25], cost:"参数", p:[{t:"fan", arc:120, reach:95, c:"#ff6a5a", w:12}]},
    {id:"katar", n:"余烬拳刃", lv:3, look:"拳套前端是烧红的刃", atk:"每击在命中点引发半径 50 的小爆炸，附带灼烧。", fx:"小火花爆炸", st:[0.9,1,1], cost:"参数 + 爆炸", reuse:"fire_giant_explosion（缩小）", p:[{t:"fan", arc:80, reach:75, c:"#ff9a4a", rate:2},{t:"ring", at:"target", r:30, c:"#ff7a3d", delay:0.15}]},
    {id:"twinfang", n:"双生蛇牙", lv:3, look:"两把弯成蛇牙的短刃", atk:"每次出手同时刺向身前和身后。", fx:"前后两道红光", st:[0.9,1,1], cost:"参数（复用回身斩）", p:[{t:"fan", arc:80, reach:75, c:"#ff7f8a", back:true, rate:2}]},
  ],
  mage: [
    {id:"nova", n:"奥术新星", init:true, look:"现有法杖", atk:"以自身为中心扩散魔法环，伤害并击退。", st:[1,1,1], cost:"现有", p:[{t:"ring", at:"self", r:170, c:"#a99bff"}]},
    {id:"frostorb", n:"霜晶宝珠", lv:1, look:"杖头嵌着不化的冰晶", atk:"新星冻结敌人 0.4 秒，击退 -60%。", fx:"冰蓝新星 + 冰晶", st:[0.9,1,1], cost:"参数 + 冻结", reuse:"frost_shockwave", p:[{t:"ring", at:"self", r:160, c:"#9fd8ff"},{t:"tick", c:"#cfefff"}]},
    {id:"snowfly", n:"萤雪杖", lv:1, look:"杖头飘着几点雪光", atk:"不再放新星，改为 3 颗雪萤绕身旋转，碰到敌人造成伤害。", fx:"环绕光点", st:[0.4,0.2,0.6], cost:"新逻辑", p:[{t:"orbit", n:3, r:62, c:"#e6f4ff"}]},
    {id:"runestaff", n:"符文石杖", lv:1, look:"一截刻满符文的石柱", atk:"新星变为 3 道奥术射线，绕身旋转扫过一圈。", fx:"三道紫光", st:[0.8,1,1.1], cost:"新逻辑", p:[{t:"rays", n:3, len:170, c:"#c7b8ff", spin:true}]},
    {id:"icemirror", n:"冰湖之镜", lv:1, look:"一面结霜的圆镜", atk:"新星收拢成朝前 90° 的冲击锥，距离 +80%。", fx:"锥形冲击波", st:[1.1,1,1.8], cost:"参数", p:[{t:"fan", arc:90, reach:230, c:"#a99bff", w:6}]},
    {id:"rootstaff", n:"世界树根杖", lv:2, look:"缠着根须的木杖", atk:"新星反向收缩：从外圈向你收拢，把敌人拉向你，击退变为牵引。", fx:"向内收的绿环", st:[0.9,1,1], cost:"参数（击退取反）", p:[{t:"ring", at:"self", r:170, c:"#9fe6b0", inward:true}]},
    {id:"soulbeacon", n:"冥雾提灯", lv:2, look:"挑着一盏青灯的长杖", atk:"新星之后留下 2.5 秒冥光光环，光环里的敌人每秒受到伤害。", fx:"新星 + 青色光环", st:[0.8,1,1], cost:"参数 + 光环", reuse:"will_o_wisp_aura", p:[{t:"ring", at:"self", r:150, c:"#8fe3d0"},{t:"ground", at:"self", r:110, c:"#8fe3d0", delay:0.3}]},
    {id:"grimoire", n:"亡者之书", lv:2, look:"人皮装订的书", atk:"不再放新星，改为射出 5 枚自动追踪的魔弹。", fx:"紫色魔弹", st:[0.5,1,2], cost:"新逻辑（复用 Projectile）", p:[{t:"proj", n:5, spread:140, speed:300, c:"#c7b8ff", homing:true, size:3}]},
    {id:"muspell", n:"穆斯贝尔火杖", lv:3, look:"杖头是一团不灭的火", atk:"火焰新星，范围 -20%，留下 2 秒灼烧地面。", fx:"橙色新星 + 火焰地面", st:[1,1,0.8], cost:"参数 + 地面效果", reuse:"loki_fire_patch（改色）", p:[{t:"ring", at:"self", r:136, c:"#ff8a3d"},{t:"ground", at:"self", r:120, c:"#ff6a2a", delay:0.3}]},
    {id:"prism", n:"虹光棱镜", lv:3, look:"彩虹桥碎片磨成的棱镜", atk:"新星变为 7 道彩色光束同时放射。", fx:"七色光束", st:[0.7,1,1.3], cost:"新逻辑", reuse:"baldr_beam（改色）", p:[{t:"rays", n:7, len:190, c:"rainbow"}]},
    {id:"heartstone", n:"巨人心石", lv:3, look:"杖头是一块搏动的石心", atk:"新星连爆 3 圈，每圈 60% 伤害，范围 +50%。", fx:"三重环", st:[0.6,1.2,1.5], cost:"参数（复用回响）", p:[{t:"ring", at:"self", r:240, c:"#d9a441", count:3}]},
  ],
};

/* ---------- 套装：头盔、胸甲、护腿、鞋子凑齐同一套 4 件 = 共鸣 ---------- */
const SETS = {
  wolf:     {lv:1, n:"霜狼猎装",       c:"#9fd8ff", pieces:{helm:"霜狼皮帽", chest:"霜狼皮袄", legs:"霜狼绑腿", boots:"踏雪靴"}, bonus:"每击杀 40 个敌人，召唤一只霜狼伙伴随行 12 秒（最多 2 只）。", why:"第一关的狼群，和斯库尔、哈提同一主题。"},
  barrow:   {lv:1, n:"墓丘守卫",       c:"#c9d6e0", pieces:{helm:"守墓人铁盔", chest:"守墓人鳞甲", legs:"守墓人胫甲", boots:"守墓人重靴"}, bonus:"受到伤害后 1 秒无敌，并冻结周围 150 像素内的敌人（冷却 12 秒）。", why:"古老的墓丘里不得安息的战士。"},
  naglfar:  {lv:2, n:"纳吉尔法尔水手", c:"#8fb3c9", pieces:{helm:"水手头巾", chest:"指甲缀甲", legs:"水手长裤", boots:"湿透的靴子"}, bonus:"闪现落点留下一枚船锚，1 秒后把周围敌人拽向船锚并造成伤害。", why:"纳吉尔法尔港，死者排队上船。"},
  mist:     {lv:2, n:"冥雾行者",       c:"#8fe3d0", pieces:{helm:"冥雾兜帽", chest:"冥雾长袍", legs:"冥雾裹腿", boots:"冥雾软鞋"}, bonus:"敌人死亡时 8% 几率留下魂火，拾取后所有神术冷却 -1 秒。", why:"冥雾沼泽里游荡的灵魂。"},
  einherjar:{lv:3, n:"英灵战甲",       c:"#ffd27a", pieces:{helm:"英灵翼盔", chest:"英灵锁甲", legs:"英灵护腿", boots:"英灵战靴"}, bonus:"生命低于 30% 时英灵殿号角响起：3 秒无敌、伤害 +50%（每 90 秒一次）。", why:"诸神黄昏里与众神并肩的英灵。"},
  valkyrie: {lv:3, n:"女武神羽衣",     c:"#f2e6ff", pieces:{helm:"女武神羽冠", chest:"女武神羽衣", legs:"女武神护膝", boots:"女武神长靴"}, bonus:"闪现变为一次短距飞掠，经过的敌人受到伤害；闪现冷却 -30%。", why:"挑选英灵的女武神。"},
};

/* ---------- Boss 专属神器：掉落与普通装备分开判定 ---------- */
const BOSSES = {
  skoll:{n:"斯库尔", lv:"midgard", at:"第一关 03:00", img:"boss_skoll.png", gold:100, item:"逐日之靴", slot:"boots", eff:"闪现冷却 -0.4 秒；闪现后 2 秒内全伤害 +20%。", mat:"斯库尔之牙", why:"追逐太阳的狼，绕位扑咬、从不停步。"},
  hati:{n:"哈提", lv:"midgard", at:"第一关 06:00", img:"boss_hati.png", gold:150, item:"月影披风", slot:"chest", eff:"受击时 20% 几率留下月影分身，吸引周围敌人 3 秒（冷却 6 秒）。", mat:"月影狼毛", why:"哈提会分出月影。"},
  hrym:{n:"赫列姆", lv:"midgard", at:"第一关 09:00", img:"boss_hrym.png", gold:300, item:"霜王盔", slot:"helm", eff:"每 12 秒凝结冰甲，抵挡一次直接伤害，并冻结 150 像素内的敌人。", mat:"冰柱残片", why:"巨盾与冰柱牢笼；机制和守护符文共用。"},
  garm:{n:"加姆", lv:"helheim", at:"第二关 03:00", img:"boss_garm.png", gold:120, item:"冥犬胫甲", slot:"legs", eff:"基础武器每第 3 次攻击追加一次扑咬，造成 60% 伤害。", mat:"断裂锁桩", why:"三段扑咬，被锁在冥界门口的看门犬。"},
  nidhogg:{n:"尼德霍格", lv:"helheim", at:"第二关 06:00", img:"boss_nidhogg.png", gold:150, item:"啃根者鳞甲", slot:"chest", eff:"受到的持续伤害减半；你造成的灼烧与毒伤害有 5% 转为治疗。", mat:"世界树根须", why:"毒息、毒池、啃根回血。"},
  hel:{n:"海拉", lv:"helheim", at:"第二关 09:00", img:"boss_hel.png", gold:300, item:"半面冠", slot:"helm", eff:"生命高于 50% 时全伤害 +15%；低于 50% 时受到伤害 -20%。", mat:"亡者之冠碎片", why:"生死二相，一半活人一半朽骨。"},
  jormungandr:{n:"耶梦加得", lv:"vigrid", at:"第三关 03:00", img:"boss_jormungandr_head.png", gold:200, item:"巨蟒鳞靴", slot:"boots", eff:"每移动 1,200 像素，以自身为中心收紧一圈毒环，造成伤害并减速。", mat:"尘世巨蟒之鳞", why:"收紧包围的巨蛇，效果跟着移动走，所以做成鞋子。"},
  fenrir:{n:"芬里尔", lv:"vigrid", at:"第三关 06:00", img:"boss_fenrir.png", gold:220, item:"格莱普尼尔绑腿", slot:"legs", eff:"你施加的减速、定身、冻结、麻痹持续 +30%，对 Boss 生效一半。", mat:"格莱普尼尔碎片", why:"束缚巨狼的丝带缠在腿上；碎片素材已有。"},
  surtr:{n:"苏尔特", lv:"vigrid", at:"第三关 09:00", img:"boss_surtr.png", gold:400, item:"炎剑余烬", slot:"weapon", adaptive:true, eff:"随职业变形：剑士炎之太刀、枪手熔火左轮、刺客余烬双刃、法师焚天新星。沿用初始武器的攻击方式，命中附加灼烧，每第 10 次攻击挥出一道炎剑横扫。", mat:"穆斯贝尔余火", why:"终焉之火，也是「余烬」这个名字的来处。"},
};
const FATE_ITEMS = [
  {img:"card_thor.jpg", n:"梅金吉尔德", slot:"护腿", src:"命运 · 托尔获救", eff:"托尔的力量腰带。每次闪现在落点降下一道雷；全伤害 +5%。", note:"原稿是项链，五部位里没有项链，改成腰带算护腿。"},
  {img:"boss_fenrir.png", n:"维达的厚靴", slot:"鞋子", src:"命运 · 维达介入", eff:"闪现可以穿过 Boss 并造成伤害；对 Boss 伤害 +10%。", note:"神话里维达用这只厚靴撑开芬里尔的巨口。"},
  {img:"card_freyr.jpg", n:"弗雷的鹿角盔", slot:"头盔", src:"命运 · 弗雷参战", eff:"基础武器击杀时 3% 几率掉落治疗苹果。", note:"原稿是武器，武器分职业后改成头盔；苹果素材 pickup_apple 已有。"},
];

/* ---------- 关卡：地标坐标来自 scripts/data/level_db.gd 的 map.landmarks ---------- */
const LEVELS = {
  midgard:{n:"第一关 · 芬布尔之冬", lv:1, elites:15, every:40, clear:300, size:4608, bosses:["skoll","hati","hrym"], sets:["wolf","barrow"], ground:"#c9d3dc",
    marks:[["十字路口",0,0,320],["被雪掩埋的村庄",-1350,-1250,650],["峡湾码头",1450,-1400,550],["奥丁的符文石阵",-1500,950,420],["古老的墓丘",-100,1450,700],["冰湖",1350,1100,650]]},
  helheim:{n:"第二关 · 亡者之船", lv:2, elites:16, every:37, clear:400, size:4608, bosses:["garm","nidhogg","hel"], sets:["naglfar","mist"], ground:"#5f6a73",
    marks:[["亡者广场",0,0,350],["吉欧尔桥",0,-800,320],["纳吉尔法尔港",400,-1600,650],["冥雾沼泽",-1400,150,650],["海拉的大厅",1400,100,600],["世界树之根",-1250,1350,550],["加姆的洞窟",1300,1550,500],["指甲工坊",-1400,-1500,500],["结冰的浅滩",-1600,-800,250]]},
  vigrid:{n:"第三关 · 最后之战", lv:3, elites:21, every:28, clear:500, size:5120, bosses:["jormungandr","fenrir","surtr"], sets:["einherjar","valkyrie"], ground:"#4a3a33",
    marks:[["中央燃烧平原",0,0,1088],["崩塌彩虹桥残端",-1536,-1408,384],["诸神与巨人残骸带",1536,-1280,384],["霜巨人残部",-1536,1024,384],["穆斯贝尔前线",1536,1280,448],["亡者残余行军带",0,1792,256]]},
};

/* ---------- 掉落规则（Ⅰ阶，幸运 0） ---------- */
const DROP = {
  gold:0.05, goldPile:5,        // 小怪：5% 掉一堆金币
  mat:0.015,                    // 小怪：1.5% 掉一个部位素材（部位随机）
  elite:0.40,                   // 精英：40% 掉一件装备
  weaponShare:0.35,             // 精英和 Boss 掉的装备：35% 是本职业武器（本关那几把），65% 是本关两套里的防具
  bossW:[0, 50, 38, 12],        // Boss 必掉一件装备：稀有 / 史诗 / 传说权重，传说每级深度 +3；幸运按选卡公式放大史诗、传说
  sig:0.12, sigDepth:0.03, pityStep:0.08, pityHard:8,  // 专属神器：独立判定
  bossMatNeed:5, craftEmbers:100, craftGold:500,
};
const RARITY_BASE_W = [60, 28, 10, 2];  // 与 UpgradeDB.RARITY_WEIGHTS 相同

/* ---------- 余烬深度 ---------- */
const DEPTH = {
  hp:   d => 1 + 0.3 * (d - 1),
  dmg:  d => 1 + 0.12 * (d - 1),
  aff:  d => 1 + 0.12 * (d - 1),
  drop: d => 1 + 0.06 * (d - 1),
  gold: d => 1 + 0.1 * (d - 1),
  high: d => 2 * (d - 1),
  sig:  d => DROP.sig + DROP.sigDepth * (d - 1),
  elite: d => DROP.elite + (d >= 3 ? 0.1 : 0),
  unlock: d => ({1:"当前难度", 3:"精英掉装备 40% → 50%", 5:"极品★ 几率翻倍", 7:"传说的信仰词缀几率 30% → 50%", 10:"后续篇章的跨世界掉落"})[d] || "",
};

/* ---------- 养成 ---------- */
// 强化 +1 ~ +10：部位素材、余烬、金币、成功率；失败只扣材料，不降级
const ENH = [
  {m:1, e:5,   g:80,  p:1},   {m:1, e:10,  g:120, p:1},   {m:2, e:15,  g:180, p:1},   {m:2, e:25,  g:250, p:1},
  {m:3, e:35,  g:330, p:0.85},{m:4, e:45,  g:420, p:0.75},{m:5, e:60,  g:520, p:0.65},{m:6, e:80,  g:630, p:0.55},
  {m:8, e:100, g:750, p:0.45},{m:10,e:125, g:900, p:0.35},
];
const ENH_NOTE = {5:"随机词缀数值 ×1.1", 7:"武器发光（传奇的 +7 光，加在武器层上）", 10:"词头效果 ×1.5；武器攻击特效换成金色"};
const REFORGE = [40, 80, 150, 250, 400];  // 重铸词头的金币，按稀有度
const TARGET_CRAFT = {m:10, e:60, g:300};  // 定向打造一件已收录的款式

/* ---------- 补给调整 ---------- */
const SUPPLY = [
  {img:"pk_healing_mead.png", n:"蜜酒", before:"2.5%；75 秒或 40 杀保底", after:"1%；无保底", keep:"首次 20 秒、冷却 35 秒、场上最多 2 个"},
  {img:"pk_soul_magnet.png", n:"聚魂磁石", before:"0.8%；150 秒或 120 杀保底", after:"1%；无保底", keep:"首次 60 秒、冷却 90 秒、场上最多 1 个；满级不掉"},
  {img:"pk_guard_rune.png", n:"守护符文", before:"0.8%；135 秒或 100 杀保底", after:"不变", keep:"意见里没提到，保持原样"},
];
