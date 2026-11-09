class_name LevelDB
## 关卡数据：刷怪节奏、精英怪、定时事件。新关卡照着这个格式加，再登记到 ALL 里
## 关卡按 ORDER 的顺序解锁：通关上一关才能进下一关；还没做的关卡在主神空间显示「制作中」
##
##   waves   刷怪阶段：从 from 秒开始生效，interval 是刷怪间隔，weights 是各敌人的出现权重
##   elite_* 精英怪：从 elite_from 秒开始，每 elite_every 秒出现一只，
##           从 elite_pool 里挑当前阶段已经出现的敌人种类
##   events  定时事件：ring = 在玩家周围刷出一圈敌人
##   bosses  Boss 出场时间和 id（id 对应 BossDB）；上一个 Boss 还活着时，下一个等它被击败再出场；全部击败即通关，显示 clear_text
##   map     固定地图：size 是场地大小（中心在原点，玩家从中心出发），玩家和敌人都不能离开
##           border 是四周屏障带的宽度（冰崖、冰海、松林），镜头看得到但走不进去
##           landmarks 地标：pos 中心、radius 范围、name 地名
##           layout 铺地面、摆物件的脚本（继承 MapLayer），没有就画网格

const CHAPTER := "篇章一 · 诸神黄昏"
const ORDER := ["midgard", "helheim", "vigrid"]
const NAMES := {"midgard": "芬布尔之冬", "helheim": "亡者之船", "vigrid": "最后之战"}
const PLACES := {"midgard": "米德加尔特", "helheim": "赫尔海姆", "vigrid": "维格利德"}
const BOSS_NAMES := {"midgard": "斯库尔 · 哈提 · 赫列姆", "helheim": "加姆 · 尼德霍格 · 海拉", "vigrid": "耶梦加得 · 芬里尔 · 苏尔特"}

const NORSE_1 := {
	"name": "芬布尔之冬",
	"music": "midgard",  # assets/audio/music/<名字>.ogg
	# 布局草图见 docs/地图设计.md。北：峡湾冰崖，东：冰封的海，西：枯松林，南：山脚岩壁
	"map": {
		"size": Vector2(4608, 4608),
		"border": 192.0,
		"layout": "res://scripts/world/midgard_map.gd",
		"landmarks": [
			{"id": "crossroads", "name": "十字路口", "pos": Vector2(0, 0), "radius": 320.0},
			{"id": "village", "name": "被雪掩埋的村庄", "pos": Vector2(-1350, -1250), "radius": 650.0},
			{"id": "harbor", "name": "峡湾码头", "pos": Vector2(1450, -1400), "radius": 550.0},
			{"id": "stones", "name": "奥丁的符文石阵", "pos": Vector2(-1500, 950), "radius": 420.0},
			{"id": "mounds", "name": "古老的墓丘", "pos": Vector2(-100, 1450), "radius": 700.0},
			{"id": "lake", "name": "冰湖", "pos": Vector2(1350, 1100), "radius": 650.0},
		],
	},
	"boss_hp_growth": 116.0,  # Boss 的血量：每过这么多秒多 100%（小怪的成长见 game.gd 的 enemy_hp_scale）
	"max_enemies": 350,   # 同时存在的敌人上限，防止卡顿
	"waves": [
		{"from": 0, "interval": 0.8, "weights": {"draugr": 1}},
		{"from": 20, "interval": 0.6, "weights": {"draugr": 3, "wolf": 2}},
		{"from": 60, "interval": 0.5, "weights": {"draugr": 3, "wolf": 2, "ice_spirit": 1}},
		{"from": 120, "interval": 0.45, "weights": {"draugr": 3, "wolf": 2, "ice_spirit": 2, "frost_giant": 1}},
		{"from": 200, "interval": 0.45, "weights": {"draugr": 2, "wolf": 3, "ice_spirit": 2, "frost_giant": 1}},
		{"from": 320, "interval": 0.3, "weights": {"draugr": 3, "wolf": 3, "ice_spirit": 2, "frost_giant": 1}},
		{"from": 440, "interval": 0.22, "weights": {"draugr": 3, "wolf": 3, "ice_spirit": 3, "frost_giant": 1}},
		{"from": 540, "interval": 0.17, "weights": {"draugr": 3, "wolf": 3, "ice_spirit": 3, "frost_giant": 2}},
	],
	"elite_from": 40.0,
	"elite_every": 40.0,
	"elite_pool": ["draugr", "ice_spirit", "frost_giant"],
	# Boss 出场表（一关 10 分钟：3、6、9 分钟各一个）。全部击败即通关
	"bosses": [
		{"time": 180.0, "id": "skoll"},
		{"time": 360.0, "id": "hati"},
		{"time": 540.0, "id": "hrym"},
	],
	"clear_reward": 300,  # 通关额外奖励点
	"clear_text": "远方传来号角声。那是神域守门人海姆达尔吹响了加拉尔号角。\n诸神黄昏，正式开始。",
	"events": [
		{"time": 50.0, "type": "ring", "enemy": "wolf", "count": 12, "text": "狼群包围！"},
		{"time": 130.0, "type": "ring", "enemy": "draugr", "count": 20, "text": "亡者从墓丘中爬出！"},
		{"time": 230.0, "type": "ring", "enemy": "wolf", "count": 20, "text": "狼群包围！"},
		{"time": 300.0, "type": "ring", "enemy": "frost_giant", "count": 8, "text": "霜巨人的先锋到了！"},
		{"time": 410.0, "type": "ring", "enemy": "wolf", "count": 30, "text": "狼群包围！"},
		{"time": 480.0, "type": "ring", "enemy": "ice_spirit", "count": 24, "text": "暴风雪中浮现出无数精魂！"},
	],
}

const NORSE_2 := {
	"name": "亡者之船",
	"music": "helheim",
	"base_enemy": "dead",  # 某种敌人到了 max_alive 上限时改刷这个
	# 布局草图见 docs/地图设计.md。北：冥海，东：赫尔之墙，西：雾之深渊，南：寒冰岩壁
	"map": {
		"size": Vector2(4608, 4608),
		"border": 192.0,
		"layout": "res://scripts/world/helheim_map.gd",
		# 冥河：y 方向的中线和半宽；crossings 是能过河的 x 范围（吉欧尔桥、结冰的浅滩）
		"river": {"y": -800.0, "half": 100.0, "crossings": [Vector2(-100, 100), Vector2(-1730, -1470)]},
		"mist": {"zones": [{"pos": Vector2(-1400, 150), "radius": 520.0}], "drifting": 3},
		"landmarks": [
			{"id": "plaza", "name": "亡者广场", "pos": Vector2(0, 0), "radius": 350.0},
			{"id": "bridge", "name": "吉欧尔桥", "pos": Vector2(0, -800), "radius": 320.0},
			{"id": "harbor", "name": "纳吉尔法尔港", "pos": Vector2(400, -1600), "radius": 650.0},
			{"id": "marsh", "name": "冥雾沼泽", "pos": Vector2(-1400, 150), "radius": 650.0},
			{"id": "hall", "name": "海拉的大厅", "pos": Vector2(1400, 100), "radius": 600.0},
			{"id": "root", "name": "世界树之根", "pos": Vector2(-1250, 1350), "radius": 550.0},
			{"id": "cave", "name": "加姆的洞窟", "pos": Vector2(1300, 1550), "radius": 500.0},
			{"id": "workshop", "name": "指甲工坊", "pos": Vector2(-1400, -1500), "radius": 500.0},
			{"id": "ford", "name": "结冰的浅滩", "pos": Vector2(-1600, -800), "radius": 250.0},
		],
	},
	"boss_hp_growth": 106.0,
	"max_enemies": 350,
	"waves": [
		{"from": 0, "interval": 2.0, "weights": {"dead": 1}},
		{"from": 25, "interval": 1.1, "weights": {"dead": 1, "dark_elf": 1}},
		{"from": 65, "interval": 0.85, "weights": {"dead": 1, "dark_elf": 2, "mist_wraith": 1}},
		{"from": 120, "interval": 0.8, "weights": {"dead": 1, "dark_elf": 2, "mist_wraith": 1, "nail_golem": 1}},
		{"from": 200, "interval": 0.8, "weights": {"dead": 1, "dark_elf": 2, "mist_wraith": 2, "nail_golem": 1}},
		{"from": 320, "interval": 0.55, "weights": {"dead": 1, "dark_elf": 3, "mist_wraith": 2, "nail_golem": 2}},
		{"from": 440, "interval": 0.4, "weights": {"dead": 2, "dark_elf": 3, "mist_wraith": 2, "nail_golem": 2}},
		{"from": 540, "interval": 0.3, "weights": {"dead": 2, "dark_elf": 3, "mist_wraith": 3, "nail_golem": 3}},
	],
	"elite_from": 40.0,
	"elite_every": 37.0,
	"elite_pool": ["dead", "dark_elf", "nail_golem"],
	"bosses": [
		{"time": 180.0, "id": "garm"},
		{"time": 360.0, "id": "nidhogg"},
		{"time": 540.0, "id": "hel"},
	],
	"clear_reward": 400,
	"clear_text": "纳吉尔法尔在火光中沉没。但远方的天空已经燃烧起来，彩虹桥正在崩塌。\n所有的神与所有的巨人，都在走向同一片平原。",
	"events": [
		{"time": 50.0, "type": "ring", "enemy": "dead", "count": 30, "text": "亡者的队伍涌了过来！"},
		{"time": 140.0, "type": "ring", "enemy": "dark_elf", "count": 14, "text": "黑暗精灵从雾中现身！"},
		{"time": 270.0, "type": "ring", "enemy": "nail_golem", "count": 8, "text": "指甲傀儡围了上来！"},
		{"time": 330.0, "type": "ring", "enemy": "mist_wraith", "count": 18, "text": "冥雾中浮现出无数幽魂！"},
		{"time": 480.0, "type": "ring", "enemy": "dead", "count": 60, "text": "海拉的亡者大军！"},
	],
}

## 三个 Boss 都被实际击败后播放篇章结局（ending），结算显示改写的命运（fates）
## 地图布局见 assets/source/taskK0_vigrid_plan_2026-10-20/layout.json；刷怪权重、成长是暂定值（见 VigridTuning 的说明）
const NORSE_3 := {
	"name": "最后之战",
	"music": "vigrid",
	"base_enemy": "dead",
	"map": {
		"size": Vector2(5120, 5120),
		"border": 256.0,
		"layout": "res://scripts/world/vigrid_map.gd",
		"routes": [[Vector2(0, 0), Vector2(-1536, -1408)], [Vector2(0, 0), Vector2(1536, -1280)], [Vector2(0, 0), Vector2(-1536, 1024)],
			[Vector2(0, 0), Vector2(1536, 1280)], [Vector2(0, 0), Vector2(0, 1792)], [Vector2(-1536, -1408), Vector2(1536, -1280)],
			[Vector2(1536, -1280), Vector2(1536, 1280)], [Vector2(1536, 1280), Vector2(0, 1792)], [Vector2(0, 1792), Vector2(-1536, 1024)],
			[Vector2(-1536, 1024), Vector2(-1536, -1408)]],
		"horizon": Rect2(-768, -2480, 1536, 128),  # 北侧远景：神与巨人交战，不能走、不能打
		"landmarks": [
			{"id": "battlefield", "name": "中央燃烧平原", "pos": Vector2(0, 0), "radius": 1088.0},
			{"id": "bifrost", "name": "崩塌彩虹桥残端", "pos": Vector2(-1536, -1408), "radius": 384.0},
			{"id": "giant_graveyard", "name": "诸神与巨人残骸带", "pos": Vector2(1536, -1280), "radius": 384.0},
			{"id": "frost_remnants", "name": "霜巨人残部", "pos": Vector2(-1536, 1024), "radius": 384.0},
			{"id": "muspel_edge", "name": "穆斯贝尔前线", "pos": Vector2(1536, 1280), "radius": 448.0},
			{"id": "dead_march", "name": "亡者残余行军带", "pos": Vector2(0, 1792), "radius": 256.0},
		],
	},
	"boss_hp_growth": 100.0,
	# 【暂定】小怪成长比前两关陡：血量 3 分钟约 2.7 倍、6 分钟约 6.0 倍、9 分钟约 11 倍（前两关 2.4 / 4.6 / 7.8）；攻击力每分钟 +15%（9 分钟 2.35 倍）
	"enemy_growth": {"hp_linear": 0.3, "hp_square": 0.09, "damage_per_minute": 0.15},
	"max_enemies": 350,
	"waves": [
		{"from": 0, "interval": 1.7, "weights": {"dead": 1}},
		{"from": 20, "interval": 0.95, "weights": {"dead": 2, "wolf_berserker": 2}},
		{"from": 60, "interval": 0.7, "weights": {"dead": 2, "wolf_berserker": 3, "fire_giant": 1}},
		{"from": 120, "interval": 0.65, "weights": {"dead": 2, "wolf_berserker": 3, "fire_giant": 1, "frost_veteran": 1}},
		{"from": 200, "interval": 0.65, "weights": {"dead": 2, "wolf_berserker": 3, "fire_giant": 2, "frost_veteran": 1}},
		{"from": 320, "interval": 0.45, "weights": {"dead": 2, "wolf_berserker": 3, "fire_giant": 2, "frost_veteran": 2}},
		{"from": 440, "interval": 0.3, "weights": {"dead": 3, "wolf_berserker": 3, "fire_giant": 2, "frost_veteran": 2}},
		{"from": 540, "interval": 0.22, "weights": {"dead": 3, "wolf_berserker": 3, "fire_giant": 3, "frost_veteran": 2}},
	],
	"elite_from": 40.0,
	"elite_every": 28.0,
	"elite_pool": ["wolf_berserker", "fire_giant", "frost_veteran"],
	"bosses": [
		{"time": 180.0, "id": "jormungandr"},
		{"time": 360.0, "id": "fenrir"},
		{"time": 540.0, "id": "surtr"},
	],
	"clear_reward": 500,
	"clear_text": "",
	"ending": "res://scripts/data/vigrid_ending_timeline.json",
	"fates": ["thor_saved", "vidar_intervened", "freyr_assisted"],
	"events": [
		{"time": 50.0, "type": "ring", "enemy": "dead", "count": 30, "text": "纳吉尔法尔的幸存者涌了过来！"},
		{"time": 140.0, "type": "ring", "enemy": "wolf_berserker", "count": 14, "text": "披着狼皮的狂战士围了上来！"},
		{"time": 270.0, "type": "ring", "enemy": "fire_giant", "count": 8, "text": "穆斯贝尔的火焰巨人越过了前线！"},
		{"time": 330.0, "type": "ring", "enemy": "frost_veteran", "count": 8, "text": "霜巨人的残部举起了盾牌！"},
		{"time": 480.0, "type": "ring", "enemy": "dead", "count": 60, "text": "整片平原的亡者都站了起来！"},
	],
}

const ALL := {"midgard": NORSE_1, "helheim": NORSE_2, "vigrid": NORSE_3}


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
