class_name MetaDB
## 主神空间的永久强化：用奖励点购买，每局开始时生效
##   max   最高等级
##   cost  第 1 级的价格；每升一级价格增加一份（第 n 级 = cost × n）

const UPGRADES := {
	"vitality": {"name": "体质强化", "desc": "最大生命 +10", "max": 5, "cost": 60},
	"strength": {"name": "力量强化", "desc": "所有伤害 +5%", "max": 5, "cost": 80},
	"agility": {"name": "敏捷强化", "desc": "移动速度 +4%", "max": 5, "cost": 60},
	"focus": {"name": "专注", "desc": "所有攻击冷却 -3%", "max": 3, "cost": 100},
	"recovery": {"name": "恢复", "desc": "每秒回复 0.2 生命", "max": 3, "cost": 80},
	"sense": {"name": "感知", "desc": "拾取范围 +10%", "max": 3, "cost": 40},
	"growth": {"name": "成长", "desc": "获得的经验 +5%", "max": 5, "cost": 70},
	"reroll": {"name": "命运重抽", "desc": "每局可以重抽升级选项 1 次", "max": 3, "cost": 120},
	"revive": {"name": "主神的眷顾", "desc": "每局可以复活 1 次（恢复一半生命）", "max": 1, "cost": 500},
}


## 购买下一级（当前等级为 level）需要的奖励点
static func cost(id: String, level: int) -> int:
	return UPGRADES[id].cost * (level + 1)


## 每局开始时，把已购买的永久强化加到玩家身上
static func apply(player: Player) -> void:
	player.max_hp += 10.0 * Save.meta_level("vitality")
	player.hp = player.max_hp
	player.damage_mult += 0.05 * Save.meta_level("strength")
	player.move_speed *= 1.0 + 0.04 * Save.meta_level("agility")
	player.cooldown_mult *= 1.0 - 0.03 * Save.meta_level("focus")
	player.regen += 0.2 * Save.meta_level("recovery")
	player.pickup_radius *= 1.0 + 0.1 * Save.meta_level("sense")
	player.xp_mult += 0.05 * Save.meta_level("growth")
	player.rerolls = Save.meta_level("reroll")
	player.revives = Save.meta_level("revive")
