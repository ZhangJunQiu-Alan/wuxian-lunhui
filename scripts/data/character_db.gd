class_name CharacterDB
## 角色数据：基础属性、武器、被动、大招、解锁条件、大招特写
##   hp / speed     基础生命和移速
##   ult_cost       大招需要的击杀数
##   unlock         解锁方式：none = 初始可用；clears = 通关次数；quests = 累计完成支线数；story = 花费支线剧情点
##   cutin_moment   大招特写上显示的「最璀璨的时刻」
##   cutin_line     大招台词（用 \n 换行）
##   素材：assets/sprites/characters/<id>_idle/_move/_hurt/_death.png 动作帧条（没有就用 <id>.png），特写立绘 <id>_cutin.png

const CUTIN_DIR := "res://assets/sprites/characters/"
const DEFAULT_ID := "musashi"

const ALL := {
	"musashi": {
		"name": "宫本武藏", "title": "剑圣",
		"hp": 110.0, "speed": 220.0, "color": Color(0.95, 0.85, 0.55),
		"weapon": "太刀", "weapon_desc": "扇形斩击，自动砍向攻击范围内最近的敌人",
		"passive": "二天一流", "passive_desc": "每第 4 刀变为前后双刀斩，伤害翻倍",
		"ult_name": "次元斩", "ult_desc": "定住屏幕内所有敌人，空间裂痕同时爆开，重创全屏",
		"ult_cost": 50.0,
		"unlock": {"type": "none"},
		"cutin_moment": "庆长十七年 · 巌流岛",
		"cutin_line": "千日为锻，万日为炼。\n这一刀，连天地也斩得开。",
		"cutin_color": Color(0.55, 0.65, 1.0),
	},
	"annie": {
		"name": "安妮·奥克利", "title": "小神枪手",
		"hp": 90.0, "speed": 230.0, "color": Color(0.95, 0.6, 0.35),
		"weapon": "左轮手枪", "weapon_desc": "快速射击射程内最近的敌人，每打 6 发换一次弹",
		"passive": "纸牌神射", "passive_desc": "每个弹匣的最后一发必定暴击，命中后分裂成两发",
		"ult_name": "狂野西部秀", "ult_desc": "8 秒狂热：射速 ×4、不用换弹、子弹穿透、移速 +30%、击杀回血",
		"ult_cost": 60.0,
		"unlock": {"type": "clears", "value": 1, "text": "通关篇章一第 1 关"},
		"cutin_moment": "1885 · 水牛比尔的狂野西部秀",
		"cutin_line": "女士们，先生们——\n表演开始了。",
		"cutin_color": Color(1.0, 0.65, 0.3),
	},
	"lanling": {
		"name": "兰陵王", "title": "鬼面将军",
		"hp": 85.0, "speed": 245.0, "color": Color(0.8, 0.3, 0.35),
		"weapon": "双刃", "weapon_desc": "射程极短、出手极快的近身连刺",
		"passive": "破阵", "passive_desc": "身边每有 1 个敌人，伤害 +6%（最多 +60%）",
		"ult_name": "入阵曲", "ult_desc": "无敌并连续瞬移到 15 个敌人身后各斩一刀，最后五百骑幻影横扫全屏",
		"ult_cost": 60.0,
		"unlock": {"type": "quests", "value": 3, "text": "累计完成 3 个支线剧情"},
		"cutin_moment": "公元 564 年 · 邙山之战",
		"cutin_line": "五百骑，随我入阵。",
		"cutin_color": Color(0.9, 0.3, 0.3),
	},
	"merlin": {
		"name": "梅林", "title": "大魔法师",
		"hp": 100.0, "speed": 210.0, "color": Color(0.6, 0.55, 1.0),
		"weapon": "奥术新星", "weapon_desc": "以自身为中心扩散的魔法环，伤害并击退敌人",
		"passive": "先知", "passive_desc": "每次升级多一个选项（四选一）",
		"ult_name": "巨石阵", "ult_desc": "一圈巨石从天而降砸在身边，之后 8 秒内敌人无法进入石阵",
		"ult_cost": 60.0,
		"unlock": {"type": "story", "value": 3, "text": "花费 3 点支线剧情点"},
		"cutin_moment": "公元 5 世纪 · 巨石阵",
		"cutin_line": "群山也会听从言语，\n只要你知道它们的名字。",
		"cutin_color": Color(0.65, 0.55, 1.0),
	},
}


## 是否已解锁。story 类型需要在主神空间里花点数解锁，记录在存档里
static func is_unlocked(id: String) -> bool:
	var unlock: Dictionary = ALL[id].unlock
	match unlock.type:
		"none":
			return true
		"clears":
			return Save.stats.clears >= unlock.value
		"quests":
			return Save.stats.quests_done >= unlock.value
		"story":
			return id in Save.unlocked_characters
	return false


## 当前选中的角色；存档里选的角色还没解锁（例如重置了存档）时退回宫本武藏
static func selected() -> String:
	var id: String = Save.selected_character
	return id if ALL.has(id) and is_unlocked(id) else DEFAULT_ID
