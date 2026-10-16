class_name LevelDB
## 关卡数据：刷怪节奏、精英怪、定时事件。新关卡照着这个格式加，再登记到 ALL 里
## 关卡按 ORDER 的顺序解锁：通关上一关才能进下一关；还没做的关卡在主神空间显示「制作中」
##
##   waves   刷怪阶段：从 from 秒开始生效，interval 是刷怪间隔，weights 是各敌人的出现权重
##   elite_* 精英怪：从 elite_from 秒开始，每 elite_every 秒出现一只，
##           从 elite_pool 里挑当前阶段已经出现的敌人种类
##   events  定时事件：ring = 在玩家周围刷出一圈敌人
##   bosses  Boss 出场时间和 id（id 对应 BossDB）；击败 final_boss 即通关，显示 clear_text
##   quest_slots 支线出现的时间点（有 Boss 在场时会等 Boss 被击败），quests 是支线池（id 对应 QuestDB），随机顺序
##   hidden_quests 隐藏支线：开局就藏在地标里，hidden_from 秒之后才能触发；到了 hint 秒还没被发现，主神给一句提示
##   map     固定地图：size 是场地大小（中心在原点，玩家从中心出发），玩家和敌人都不能离开
##           border 是四周屏障带的宽度（冰崖、冰海、松林），镜头看得到但走不进去
##           landmarks 地标：pos 中心、radius 范围；写了 quest / hidden 的地标，该支线（隐藏支线）就出现在这里
##           quest 可以是一个 id，也可以是几个 id 的数组；不在任何地标上的支线出现在玩家附近
##           layout 铺地面、摆物件的脚本（继承 MapLayer），没有就画网格

const CHAPTER := "篇章一 · 诸神黄昏"
const ORDER := ["midgard", "helheim", "vigrid"]
const NAMES := {"midgard": "芬布尔之冬", "helheim": "亡者之船", "vigrid": "最后之战"}
const PLACES := {"midgard": "米德加尔特", "helheim": "赫尔海姆", "vigrid": "维格利德"}
const BOSS_NAMES := {"midgard": "斯库尔 · 哈提 · 赫列姆", "helheim": "加姆 · 尼德霍格 · 海拉", "vigrid": "耶梦加得 · 芬里尔 · 苏尔特"}

const NORSE_1 := {
	"name": "芬布尔之冬",
	"music": "midgard",  # assets/audio/music/<名字>.ogg
	# 布局草图见 docs/地图设计_第1关.md。北：峡湾冰崖，东：冰封的海，西：枯松林，南：山脚岩壁
	"map": {
		"size": Vector2(4608, 4608),
		"border": 192.0,
		"layout": "res://scripts/world/midgard_map.gd",
		"landmarks": [
			{"id": "crossroads", "name": "十字路口", "pos": Vector2(0, 0), "radius": 320.0, "quest": ["fate", "ember"], "hidden": "runes"},
			{"id": "village", "name": "被雪掩埋的村庄", "pos": Vector2(-1350, -1250), "radius": 650.0, "quest": "bonfire"},
			{"id": "harbor", "name": "峡湾码头", "pos": Vector2(1450, -1400), "radius": 550.0, "quest": "priests", "hidden": "sea_giant"},
			{"id": "stones", "name": "奥丁的符文石阵", "pos": Vector2(-1500, 950), "radius": 420.0, "quest": "ravens"},
			{"id": "mounds", "name": "古老的墓丘", "pos": Vector2(-100, 1450), "radius": 700.0, "quest": ["valkyrie", "nails"], "hidden": "einherjar"},
			{"id": "lake", "name": "冰湖", "pos": Vector2(1350, 1100), "radius": 650.0, "quest": "ice_warriors", "hidden": "fishing"},
		],
	},
	"hp_growth": 180.0,   # 每过这么多秒，敌人血量多 100%
	"max_enemies": 350,   # 同时存在的敌人上限，防止卡顿
	"waves": [
		{"from": 0, "interval": 1.2, "weights": {"draugr": 1}},
		{"from": 30, "interval": 0.9, "weights": {"draugr": 3, "wolf": 2}},
		{"from": 90, "interval": 0.7, "weights": {"draugr": 3, "wolf": 2, "ice_spirit": 1}},
		{"from": 180, "interval": 0.55, "weights": {"draugr": 3, "wolf": 2, "ice_spirit": 2, "frost_giant": 1}},
		{"from": 300, "interval": 0.45, "weights": {"draugr": 2, "wolf": 3, "ice_spirit": 2, "frost_giant": 1}},
		{"from": 480, "interval": 0.35, "weights": {"draugr": 3, "wolf": 3, "ice_spirit": 2, "frost_giant": 1}},
		{"from": 660, "interval": 0.28, "weights": {"draugr": 3, "wolf": 3, "ice_spirit": 3, "frost_giant": 1}},
	],
	"elite_from": 60.0,
	"elite_every": 60.0,
	"elite_pool": ["draugr", "ice_spirit", "frost_giant"],
	# Boss 出场表。击败 final_boss 即通关
	"bosses": [
		{"time": 300.0, "id": "skoll"},
		{"time": 600.0, "id": "hati"},
		{"time": 840.0, "id": "hrym"},
	],
	"final_boss": "hrym",
	"clear_reward": 300,  # 通关额外奖励点
	"quest_slots": [150.0, 450.0, 720.0],
	"quests": ["bonfire", "ravens", "valkyrie", "nails", "ice_warriors", "priests", "cold_wave", "fate", "ember"],
	"hidden_from": 30.0,
	"hidden_quests": [
		{"id": "fishing", "hint": 100.0},
		{"id": "runes", "hint": 260.0},
		{"id": "sea_giant", "hint": 380.0},
		{"id": "einherjar", "hint": 540.0},
	],
	"clear_text": "远方传来号角声。那是神域守门人海姆达尔吹响了加拉尔号角。\n诸神黄昏，正式开始。",
	"events": [
		{"time": 75.0, "type": "ring", "enemy": "wolf", "count": 12, "text": "狼群包围！"},
		{"time": 200.0, "type": "ring", "enemy": "draugr", "count": 20, "text": "亡者从墓丘中爬出！"},
		{"time": 270.0, "type": "ring", "enemy": "wolf", "count": 20, "text": "狼群包围！"},
		{"time": 420.0, "type": "ring", "enemy": "frost_giant", "count": 8, "text": "霜巨人的先锋到了！"},
		{"time": 570.0, "type": "ring", "enemy": "wolf", "count": 30, "text": "狼群包围！"},
		{"time": 720.0, "type": "ring", "enemy": "ice_spirit", "count": 24, "text": "暴风雪中浮现出无数精魂！"},
	],
}

const NORSE_2 := {
	"name": "亡者之船",
	"music": "helheim",
	"base_enemy": "dead",  # 某种敌人到了 max_alive 上限时改刷这个
	# 布局草图见 docs/地图设计_第2关.md。北：冥海，东：赫尔之墙，西：雾之深渊，南：寒冰岩壁
	"map": {
		"size": Vector2(4608, 4608),
		"border": 192.0,
		"layout": "res://scripts/world/helheim_map.gd",
		# 冥河：y 方向的中线和半宽；crossings 是能过河的 x 范围（吉欧尔桥、结冰的浅滩）
		"river": {"y": -800.0, "half": 100.0, "crossings": [Vector2(-100, 100), Vector2(-1730, -1470)]},
		"mist": {"zones": [{"pos": Vector2(-1400, 150), "radius": 520.0}], "drifting": 3},
		"landmarks": [
			{"id": "plaza", "name": "亡者广场", "pos": Vector2(0, 0), "radius": 350.0, "quest": "soul_lamps"},
			{"id": "bridge", "name": "吉欧尔桥", "pos": Vector2(0, -800), "radius": 320.0, "quest": "bridge_guard"},
			{"id": "harbor", "name": "纳吉尔法尔港", "pos": Vector2(400, -1600), "radius": 650.0, "quest": "anchor_chains"},
			{"id": "marsh", "name": "冥雾沼泽", "pos": Vector2(-1400, 150), "radius": 650.0},
			{"id": "hall", "name": "海拉的大厅", "pos": Vector2(1400, 100), "radius": 600.0, "quest": "baldr", "hidden": "hoof_tracks"},
			{"id": "root", "name": "世界树之根", "pos": Vector2(-1250, 1350), "radius": 550.0, "quest": "ratatoskr"},
			{"id": "cave", "name": "加姆的洞窟", "pos": Vector2(1300, 1550), "radius": 500.0, "hidden": "thokk"},
			{"id": "workshop", "name": "指甲工坊", "pos": Vector2(-1400, -1500), "radius": 500.0, "quest": "nail_heaps"},
			{"id": "ford", "name": "结冰的浅滩", "pos": Vector2(-1600, -800), "radius": 250.0, "hidden": "river_sword"},
		],
	},
	"hp_growth": 165.0,
	"max_enemies": 350,
	"waves": [
		{"from": 0, "interval": 3.0, "weights": {"dead": 1}},
		{"from": 40, "interval": 1.6, "weights": {"dead": 1, "dark_elf": 1}},
		{"from": 100, "interval": 1.2, "weights": {"dead": 1, "dark_elf": 2, "mist_wraith": 1}},
		{"from": 180, "interval": 0.95, "weights": {"dead": 1, "dark_elf": 2, "mist_wraith": 1, "nail_golem": 1}},
		{"from": 300, "interval": 0.8, "weights": {"dead": 1, "dark_elf": 2, "mist_wraith": 2, "nail_golem": 1}},
		{"from": 480, "interval": 0.65, "weights": {"dead": 1, "dark_elf": 3, "mist_wraith": 2, "nail_golem": 2}},
		{"from": 660, "interval": 0.5, "weights": {"dead": 2, "dark_elf": 3, "mist_wraith": 2, "nail_golem": 2}},
	],
	"elite_from": 60.0,
	"elite_every": 55.0,
	"elite_pool": ["dead", "dark_elf", "nail_golem"],
	"bosses": [
		{"time": 300.0, "id": "garm"},
		{"time": 600.0, "id": "nidhogg"},
		{"time": 840.0, "id": "hel"},
	],
	"final_boss": "hel",
	"clear_reward": 400,
	"quest_slots": [150.0, 450.0, 720.0],
	"quests": ["soul_lamps", "bridge_guard", "anchor_chains", "baldr", "ratatoskr", "nail_heaps"],
	"hidden_from": 30.0,
	"hidden_quests": [
		{"id": "hoof_tracks", "hint": 150.0},
		{"id": "river_sword", "hint": 280.0},
		{"id": "thokk", "hint": 480.0},
	],
	"clear_text": "纳吉尔法尔在火光中沉没。但远方的天空已经燃烧起来，彩虹桥正在崩塌。\n所有的神与所有的巨人，都在走向同一片平原。",
	"events": [
		{"time": 70.0, "type": "ring", "enemy": "dead", "count": 30, "text": "亡者的队伍涌了过来！"},
		{"time": 210.0, "type": "ring", "enemy": "dark_elf", "count": 14, "text": "黑暗精灵从雾中现身！"},
		{"time": 400.0, "type": "ring", "enemy": "nail_golem", "count": 8, "text": "指甲傀儡围了上来！"},
		{"time": 540.0, "type": "ring", "enemy": "mist_wraith", "count": 18, "text": "冥雾中浮现出无数幽魂！"},
		{"time": 720.0, "type": "ring", "enemy": "dead", "count": 60, "text": "海拉的亡者大军！"},
	],
}

const ALL := {"midgard": NORSE_1, "helheim": NORSE_2}


static func is_built(id: String) -> bool:
	return ALL.has(id)


static func is_unlocked(id: String) -> bool:
	var index := ORDER.find(id)
	return index == 0 or (index > 0 and Save.cleared_levels.has(ORDER[index - 1]))


## 这一关的下一关 id，没有就返回空字符串
static func next_of(id: String) -> String:
	var index := ORDER.find(id)
	return ORDER[index + 1] if index >= 0 and index + 1 < ORDER.size() else ""


## 主神空间里选的关卡；选的关还没做或没解锁时退回第 1 关
static func selected() -> String:
	var id: String = Save.selected_level
	return id if is_built(id) and is_unlocked(id) else ORDER[0]
