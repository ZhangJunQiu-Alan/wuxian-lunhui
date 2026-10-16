class_name LevelDB
## 关卡数据：刷怪节奏、精英怪、定时事件。新关卡照着这个格式加
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

const NORSE_1 := {
	"name": "芬布尔之冬",
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
