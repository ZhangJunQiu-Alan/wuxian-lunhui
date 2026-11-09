class_name CharacterDB
## 角色数据：基础属性、武器、被动、大招、解锁条件、大招特写
##   hp / speed     基础生命和移速
##   ult_cost       大招需要的击杀数
##   unlock         解锁方式：none = 初始可用；clears = 通关次数
##   cutin_moment   大招特写上显示的「最璀璨的时刻」
##   cutin_line     大招台词（用 \n 换行）
##   素材：assets/sprites/characters/<id>_idle/_move/_hurt/_death.png 动作帧条（没有就用 <id>.png），特写立绘 <id>_cutin.png

const CUTIN_DIR := "res://assets/sprites/characters/"
const DEFAULT_ID := "swordsman"

const ALL := {
	"swordsman": {
		"name": "剑士", "title": "东方剑客",
		"hp": 110.0, "speed": 220.0, "color": Color(0.95, 0.85, 0.55),
		"weapon": "太刀", "weapon_desc": "扇形斩击，自动砍向攻击范围内最近的敌人",
		"passive": "二刀流", "passive_desc": "每第 4 刀变为前后双刀斩，伤害翻倍",
		"ult_name": "次元斩", "ult_desc": "定住屏幕内所有敌人，空间裂痕同时爆开，重创全屏",
		"ult_cost": 50.0,
		"unlock": {"type": "none"},
		"cutin_moment": "孤岛 · 黎明的决斗",
		"cutin_line": "千日为锻，万日为炼。\n这一刀，连天地也斩得开。",
		"cutin_color": Color(0.55, 0.65, 1.0),
	},
	"gunslinger": {
		"name": "枪手", "title": "西部神枪手",
		"hp": 90.0, "speed": 230.0, "color": Color(0.95, 0.6, 0.35),
		"weapon": "左轮手枪", "weapon_desc": "快速射击射程内最近的敌人，每打 6 发换一次弹",
		"passive": "纸牌神射", "passive_desc": "每个弹匣的最后一发必定暴击，命中后分裂成两发",
		"ult_name": "狂野西部秀", "ult_desc": "8 秒狂热：射速 ×4、不用换弹、子弹穿透、移速 +30%、击杀回血",
		"ult_cost": 60.0,
		"unlock": {"type": "clears", "value": 1, "text": "通关篇章一第 1 关"},
		"cutin_moment": "巡演舞台 · 第一声枪响",
		"cutin_line": "女士们，先生们——\n表演开始了。",
		"cutin_color": Color(1.0, 0.65, 0.3),
	},
	"assassin": {
		"name": "刺客", "title": "鬼面刺客",
		"hp": 85.0, "speed": 245.0, "color": Color(0.8, 0.3, 0.35),
		"weapon": "双刃", "weapon_desc": "射程极短、出手极快的近身连刺",
		"passive": "破阵", "passive_desc": "身边每有 1 个敌人，伤害 +6%（最多 +60%）",
		"ult_name": "入阵曲", "ult_desc": "无敌并连续瞬移到 15 个敌人身后各斩一刀，最后五百骑幻影横扫全屏",
		"ult_cost": 60.0,
		"unlock": {"type": "none"},
		"cutin_moment": "孤城之下 · 摘下鬼面",
		"cutin_line": "五百骑，随我入阵。",
		"cutin_color": Color(0.9, 0.3, 0.3),
	},
	"mage": {
		"name": "法师", "title": "大魔法师",
		"hp": 100.0, "speed": 210.0, "color": Color(0.6, 0.55, 1.0),
		"weapon": "奥术新星", "weapon_desc": "以自身为中心扩散的魔法环，伤害并击退敌人",
		"passive": "先知", "passive_desc": "每次升级从四个选项中选择一个",
		"ult_name": "巨石阵", "ult_desc": "一圈巨石从天而降砸在身边，之后 8 秒内敌人无法进入石阵",
		"ult_cost": 60.0,
		"unlock": {"type": "none"},
		"cutin_moment": "远古 · 巨石阵",
		"cutin_line": "群山也会听从言语，\n只要你知道它们的名字。",
		"cutin_color": Color(0.65, 0.55, 1.0),
	},
}


## 是否已解锁
static func is_unlocked(id: String) -> bool:
	var unlock: Dictionary = ALL[id].unlock
	match unlock.type:
		"none":
			return true
		"clears":
			return Save.stats.clears >= unlock.value
	return false


## 当前选中的角色；存档里选的角色还没解锁（例如重置了存档）时退回剑士
static func selected() -> String:
	var id: String = Save.selected_character
	return id if ALL.has(id) and is_unlocked(id) else DEFAULT_ID
