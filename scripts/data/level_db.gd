class_name LevelDB
## 关卡数据：刷怪节奏、精英怪、定时事件。新关卡照着这个格式加
##
##   waves   刷怪阶段：从 from 秒开始生效，interval 是刷怪间隔，weights 是各敌人的出现权重
##   elite_* 精英怪：从 elite_from 秒开始，每 elite_every 秒出现一只，
##           从 elite_pool 里挑当前阶段已经出现的敌人种类
##   events  定时事件：ring = 在玩家周围刷出一圈敌人
##   bosses  Boss 出场时间和 id（id 对应 BossDB）；击败 final_boss 即通关，显示 clear_text
##   quest_slots 支线出现的时间点（有 Boss 在场时会等 Boss 被击败），quests 是支线池（id 对应 QuestDB），随机顺序

const NORSE_1 := {
	"name": "芬布尔之冬",
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
	"quest_slots": [150.0, 450.0, 720.0],
	"quests": ["bonfire", "ravens", "valkyrie"],
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
