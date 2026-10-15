class_name UpgradeDB
## 升级卡牌数据库：所有升级选项都在这里定义和生效
##
## 每张卡的字段：
##   kind      卡牌类别：weapon = 人物基础武器，stat = 通用属性，god = 神明卡
##   character 基础武器卡属于哪个角色，只有这个角色升级时才会出现
##   god       所属神明 id（仅神明卡），选了会增加该神的信仰值
##   name/desc 卡牌标题和说明
##   max       最多能选几次
##   requires  需要先拥有的升级 id（例如强化落雷前必须先获得落雷）
##   skill     true = 获得神明技能的卡，第一次升级只从这些卡里选
##   awaken    true = 觉醒卡，信仰值满了才会出现，且必定出现
##
## 信仰规则：选神明卡给该神 +1 信仰；一局最多信仰 MAX_GODS 位神

const FAITH_MAX := 5
const MAX_GODS := 3  # 一局最多信仰几位神（不算初始武器太刀）

const UPGRADES := {
	# ———— 人物基础武器：太刀（宫本武藏）————
	"katana_damage": {"kind": "weapon", "character": "musashi", "god": "", "name": "太刀·锋利", "desc": "太刀伤害 +25%", "max": 5},
	"katana_speed": {"kind": "weapon", "character": "musashi", "god": "", "name": "太刀·居合", "desc": "太刀挥砍间隔 -12%", "max": 4},
	"katana_range": {"kind": "weapon", "character": "musashi", "god": "", "name": "太刀·长刃", "desc": "太刀攻击范围 +20%", "max": 3},
	"katana_back": {"kind": "weapon", "character": "musashi", "god": "", "name": "太刀·回身斩", "desc": "挥砍时同时斩向身后", "max": 1},

	# ———— 人物基础武器：左轮手枪（安妮·奥克利）————
	"revolver_damage": {"kind": "weapon", "character": "annie", "god": "", "name": "左轮·重弹", "desc": "子弹伤害 +25%", "max": 5},
	"revolver_rate": {"kind": "weapon", "character": "annie", "god": "", "name": "左轮·快拔", "desc": "射击间隔 -12%", "max": 4},
	"revolver_mag": {"kind": "weapon", "character": "annie", "god": "", "name": "左轮·扩容", "desc": "弹匣 +2 发，换弹时间 -10%", "max": 3},
	"revolver_pierce": {"kind": "weapon", "character": "annie", "god": "", "name": "左轮·穿甲", "desc": "子弹穿透 +1", "max": 2},
	"revolver_twin": {"kind": "weapon", "character": "annie", "god": "", "name": "左轮·双枪", "desc": "双手持枪，每次同时射出两发", "max": 1},

	# ———— 人物基础武器：双刃（兰陵王）————
	"blades_damage": {"kind": "weapon", "character": "lanling", "god": "", "name": "双刃·淬锋", "desc": "双刃伤害 +25%", "max": 5},
	"blades_speed": {"kind": "weapon", "character": "lanling", "god": "", "name": "双刃·疾袭", "desc": "出手间隔 -12%", "max": 4},
	"blades_reach": {"kind": "weapon", "character": "lanling", "god": "", "name": "双刃·突进", "desc": "攻击范围 +15%", "max": 3},
	"blades_flurry": {"kind": "weapon", "character": "lanling", "god": "", "name": "双刃·三连刺", "desc": "每次出手对目标追加一击（50% 伤害）", "max": 1},

	# ———— 人物基础武器：奥术新星（梅林）————
	"nova_damage": {"kind": "weapon", "character": "merlin", "god": "", "name": "新星·增幅", "desc": "新星伤害 +25%", "max": 5},
	"nova_cooldown": {"kind": "weapon", "character": "merlin", "god": "", "name": "新星·吟唱", "desc": "新星间隔 -12%", "max": 4},
	"nova_radius": {"kind": "weapon", "character": "merlin", "god": "", "name": "新星·扩散", "desc": "新星范围 +15%", "max": 3},
	"nova_echo": {"kind": "weapon", "character": "merlin", "god": "", "name": "新星·回响", "desc": "每次释放后再放一圈新星", "max": 1},

	# ———— 通用属性 ————
	"might": {"kind": "stat", "god": "", "name": "力量", "desc": "所有伤害 +10%", "max": 5},
	"swift": {"kind": "stat", "god": "", "name": "迅捷", "desc": "移动速度 +10%", "max": 3},
	"vigor": {"kind": "stat", "god": "", "name": "体魄", "desc": "最大生命 +20，并回复 20 生命", "max": 5},
	"magnet": {"kind": "stat", "god": "", "name": "引力", "desc": "拾取范围 +30%", "max": 3},
	"haste": {"kind": "stat", "god": "", "name": "急速", "desc": "所有攻击冷却 -8%", "max": 3},
	"wisdom": {"kind": "stat", "god": "", "name": "智慧", "desc": "获得的经验 +15%", "max": 3},
	"evasion": {"kind": "stat", "god": "", "name": "闪避", "desc": "受到攻击时有 15% 几率闪避", "max": 2},
	"regen": {"kind": "stat", "god": "", "name": "再生", "desc": "每秒回复 1 点生命", "max": 3},

	# ———— 托尔：雷电 ————
	"thor_lightning": {"kind": "god", "god": "thor", "name": "落雷", "desc": "周期性召唤雷电劈向附近的敌人，造成范围伤害", "max": 1, "skill": true},
	"thor_damage": {"kind": "god", "god": "thor", "name": "雷霆万钧", "desc": "落雷伤害 +30%", "max": 3, "requires": "thor_lightning"},
	"thor_count": {"kind": "god", "god": "thor", "name": "风暴", "desc": "每次多劈下 1 道雷", "max": 3, "requires": "thor_lightning"},
	"thor_speed": {"kind": "god", "god": "thor", "name": "疾雷", "desc": "落雷间隔 -15%", "max": 2, "requires": "thor_lightning"},
	"thor_awaken": {"kind": "god", "god": "thor", "name": "觉醒·雷神之锤", "desc": "落雷伤害翻倍，并连锁跳向附近 3 个敌人", "max": 1, "requires": "thor_lightning", "awaken": true},

	# ———— 奥丁：符文与智慧 ————
	"odin_bolt": {"kind": "god", "god": "odin", "name": "符文飞弹", "desc": "向最近的敌人发射符文飞弹", "max": 1, "skill": true},
	"odin_count": {"kind": "god", "god": "odin", "name": "符文增殖", "desc": "每次多发射 1 枚符文", "max": 3, "requires": "odin_bolt"},
	"odin_pierce": {"kind": "god", "god": "odin", "name": "破甲符文", "desc": "符文穿透 +1", "max": 3, "requires": "odin_bolt"},
	"odin_awaken": {"kind": "god", "god": "odin", "name": "觉醒·冈格尼尔", "desc": "符文无限穿透，数量 +2，伤害 +50%", "max": 1, "requires": "odin_bolt", "awaken": true},

	# ———— 洛基：火焰与诡计 ————
	"loki_aura": {"kind": "god", "god": "loki", "name": "诡火", "desc": "身边燃起火焰，持续灼烧靠近的敌人", "max": 1, "skill": true},
	"loki_radius": {"kind": "god", "god": "loki", "name": "野火蔓延", "desc": "火焰范围 +20%", "max": 3, "requires": "loki_aura"},
	"loki_damage": {"kind": "god", "god": "loki", "name": "炽焰", "desc": "火焰伤害 +30%", "max": 3, "requires": "loki_aura"},
	"loki_awaken": {"kind": "god", "god": "loki", "name": "觉醒·诸神黄昏之火", "desc": "火焰范围 +50%，伤害翻倍", "max": 1, "requires": "loki_aura", "awaken": true},

	# ———— 弗蕾亚：羽刃与生命 ————
	"freyja_feathers": {"kind": "god", "god": "freyja", "name": "女武神之羽", "desc": "2 片羽刃环绕身边，切割碰到的敌人", "max": 1, "skill": true},
	"freyja_count": {"kind": "god", "god": "freyja", "name": "羽翼丰满", "desc": "羽刃 +1", "max": 3, "requires": "freyja_feathers"},
	"freyja_speed": {"kind": "god", "god": "freyja", "name": "疾风之羽", "desc": "羽刃转速和伤害 +20%", "max": 3, "requires": "freyja_feathers"},
	"freyja_awaken": {"kind": "god", "god": "freyja", "name": "觉醒·弗尔克范格", "desc": "羽刃 +3，每秒额外回复 3 点生命", "max": 1, "requires": "freyja_feathers", "awaken": true},
}

## 卡池抽空时的保底卡
const FALLBACK := "mead"
const FALLBACK_INFO := {"kind": "stat", "god": "", "name": "蜜酒", "desc": "回复 30 生命", "max": 0}


static func get_info(id: String) -> Dictionary:
	return FALLBACK_INFO if id == FALLBACK else UPGRADES[id]


## 抽出 count 张可选的卡
static func get_choices(player: Player, count: int) -> Array[String]:
	var first_choice := player.faith.is_empty()  # 还没有任何信仰：只出神明技能卡
	var result: Array[String] = []
	var pool: Array[String] = []
	for id: String in UPGRADES:
		if not _is_available(id, player):
			continue
		var info: Dictionary = UPGRADES[id]
		if info.get("awaken", false):
			result.append(id)  # 觉醒卡必定出现
		elif not first_choice or info.get("skill", false):
			pool.append(id)
	pool.shuffle()
	while result.size() < count and not pool.is_empty():
		result.append(pool.pop_back())
	if result.is_empty():
		result.append(FALLBACK)
	return result.slice(0, count)


static func _is_available(id: String, player: Player) -> bool:
	var info: Dictionary = UPGRADES[id]
	if info.kind == "weapon" and info.character != player.character_id:
		return false  # 别的角色的武器卡
	if player.upgrade_levels.get(id, 0) >= info.max:
		return false
	if info.has("requires") and not player.upgrade_levels.has(info.requires):
		return false
	if info.god != "" and not player.faith.has(info.god) and player.faith.size() >= MAX_GODS:
		return false  # 已经信仰了 3 位神，其他神的卡不再出现
	if info.get("awaken", false) and player.faith.get(info.god, 0) < FAITH_MAX:
		return false
	return true


## 让一张卡生效：记录次数、增加信仰、修改玩家或技能的数值
static func apply(id: String, player: Player) -> void:
	player.upgrade_levels[id] = player.upgrade_levels.get(id, 0) + 1
	var info := get_info(id)
	if info.god != "" and not info.get("awaken", false):
		player.faith[info.god] = mini(player.faith.get(info.god, 0) + 1, FAITH_MAX)

	match id:
		"mead":
			player.heal(30.0)

		"katana_damage":
			player.katana.damage *= 1.25
		"katana_speed":
			player.katana.cooldown *= 0.88
		"katana_range":
			player.katana.reach *= 1.2
		"katana_back":
			player.katana.back_slash = true

		"revolver_damage":
			player.revolver.damage *= 1.25
		"revolver_rate":
			player.revolver.fire_interval *= 0.88
		"revolver_mag":
			player.revolver.magazine += 2
			player.revolver.reload_time *= 0.9
		"revolver_pierce":
			player.revolver.pierce += 1
		"revolver_twin":
			player.revolver.twin = true

		"blades_damage":
			player.blades.damage *= 1.25
		"blades_speed":
			player.blades.cooldown *= 0.88
		"blades_reach":
			player.blades.reach *= 1.15
		"blades_flurry":
			player.blades.flurry = true

		"nova_damage":
			player.nova.damage *= 1.25
		"nova_cooldown":
			player.nova.cooldown *= 0.88
		"nova_radius":
			player.nova.radius *= 1.15
		"nova_echo":
			player.nova.echo = true

		"might":
			player.damage_mult += 0.1
		"swift":
			player.move_speed *= 1.1
		"vigor":
			player.max_hp += 20.0
			player.heal(20.0)
		"magnet":
			player.pickup_radius *= 1.3
		"haste":
			player.cooldown_mult *= 0.92

		"thor_lightning":
			player.lightning = LightningStrike.new()
			player.add_child(player.lightning)
		"thor_damage":
			player.lightning.damage *= 1.3
		"thor_count":
			player.lightning.strikes += 1
		"thor_speed":
			player.lightning.cooldown *= 0.85
		"thor_awaken":
			player.lightning.damage *= 2.0
			player.lightning.chain = 3

		"odin_bolt":
			player.rune_bolt = RuneBolt.new()
			player.add_child(player.rune_bolt)
		"odin_count":
			player.rune_bolt.count += 1
		"odin_pierce":
			player.rune_bolt.pierce += 1
		"wisdom":
			player.xp_mult += 0.15
		"odin_awaken":
			player.rune_bolt.pierce = 9999
			player.rune_bolt.count += 2
			player.rune_bolt.damage *= 1.5

		"loki_aura":
			player.fire_aura = FireAura.new()
			player.add_child(player.fire_aura)
		"loki_radius":
			player.fire_aura.radius *= 1.2
		"loki_damage":
			player.fire_aura.damage *= 1.3
		"evasion":
			player.dodge_chance += 0.15
		"loki_awaken":
			player.fire_aura.radius *= 1.5
			player.fire_aura.damage *= 2.0

		"freyja_feathers":
			player.feathers = FeatherOrbit.new()
			player.add_child(player.feathers)
		"freyja_count":
			player.feathers.count += 1
		"freyja_speed":
			player.feathers.spin_speed *= 1.2
			player.feathers.damage *= 1.2
		"regen":
			player.regen += 1.0
		"freyja_awaken":
			player.feathers.count += 3
			player.regen += 3.0
