class_name UpgradeDB
## 升级卡牌数据库：所有卡牌都在这里定义和生效（信仰系统 2.0，见 docs/信仰系统设计.md）
##
## 卡牌种类 kind：
##   weapon  人物基础武器（character 是哪个角色的）
##   stat    通用属性
##   skill   神术：选神时获得（1、5、10 级各选一位神，一局最多 3 位）
##   boon    神明的强化：加信仰，每位神 4 个方向
##   path    质变：信仰到 6 时三选一（path 是质变 id）
##   awaken  觉醒：信仰到 12 时出现，path 是它对应的质变
##   fusion  融合技：两位神都觉醒后出现（数据在 Gods.FUSIONS）
## 其他字段：
##   name/desc  标题和说明。desc 里的 {v} 换成这一稀有度的数值
##   values     普通 / 稀有 / 史诗 / 传说 四档数值；没有 values 的武器卡，高稀有度附带武器伤害加成
##   descs      某些稀有度的说明和别的档不一样时，按稀有度写完整说明（空字符串 = 用 desc）
##   max        最多能选几次
##
## 抽到的卡是 {"id": 卡牌 id, "rarity": 稀有度}，稀有度 0~3，选神 / 质变 / 觉醒 / 融合是 -1

const FAITH_PATH := 6     # 信仰到 6：选质变
const FAITH_AWAKEN := 12  # 信仰到 12：觉醒
const FAITH_MAX := 12
const MAX_GODS := 3       # 一局最多信仰几位神
const GOD_LEVELS := [5, 10]  # 这些等级的升级改成选一位新的神（开局 1 级也选一次）

const RARITY_NAMES := ["普通", "稀有", "史诗", "传说"]
const RARITY_COLORS := [Color(0.82, 0.84, 0.88), Color(0.4, 0.66, 1.0), Color(0.78, 0.45, 1.0), Color(1.0, 0.74, 0.25)]
const RARITY_WEIGHTS := [60.0, 28.0, 10.0, 2.0]  # 基础几率（%）
const RARITY_PER_MINUTE := 2.0  # 每过 1 分钟，稀有以上的几率共 +2%
const WEAPON_RARITY_BONUS := [0, 10, 20, 30]  # 没有数值的武器卡：高稀有度附带武器伤害 +x%

const UPGRADES := {
	# ———— 人物基础武器：太刀（剑士）————
	"katana_damage": {"kind": "weapon", "character": "swordsman", "name": "太刀·锋利", "desc": "太刀伤害 +{v}%", "values": [25, 37, 55, 75], "max": 5},
	"katana_speed": {"kind": "weapon", "character": "swordsman", "name": "太刀·居合", "desc": "太刀挥砍间隔 -{v}%", "values": [10, 14, 19, 25], "max": 4},
	"katana_range": {"kind": "weapon", "character": "swordsman", "name": "太刀·长刃", "desc": "太刀攻击范围 +{v}%", "values": [15, 20, 28, 36], "max": 3},
	"katana_back": {"kind": "weapon", "character": "swordsman", "name": "太刀·回身斩", "desc": "挥砍时同时斩向身后", "max": 1},
	"katana_knockback": {"kind": "weapon", "character": "swordsman", "name": "太刀·震退", "desc": "太刀击退距离 +{v}%", "values": [40, 60, 88, 120], "max": 3},
	"katana_hamstring": {"kind": "weapon", "character": "swordsman", "name": "太刀·断筋", "desc": "被太刀砍中的敌人移速 -{v}%，持续 2 秒", "values": [20, 25, 30, 40], "max": 2},

	# ———— 人物基础武器：左轮手枪（枪手）————
	"revolver_damage": {"kind": "weapon", "character": "gunslinger", "name": "左轮·重弹", "desc": "子弹伤害 +{v}%", "values": [25, 37, 55, 75], "max": 5},
	"revolver_rate": {"kind": "weapon", "character": "gunslinger", "name": "左轮·快拔", "desc": "射击间隔 -{v}%", "values": [10, 14, 19, 25], "max": 4},
	"revolver_mag": {"kind": "weapon", "character": "gunslinger", "name": "左轮·扩容", "desc": "弹匣 +{v} 发，换弹时间 -10%", "values": [2, 3, 4, 6], "max": 3},
	"revolver_pierce": {"kind": "weapon", "character": "gunslinger", "name": "左轮·穿甲", "desc": "子弹穿透 +{v}", "values": [1, 1, 2, 2], "max": 2},
	"revolver_twin": {"kind": "weapon", "character": "gunslinger", "name": "左轮·双枪", "desc": "双手持枪，每次同时射出两发", "max": 1},

	# ———— 人物基础武器：双刃（刺客）————
	"blades_damage": {"kind": "weapon", "character": "assassin", "name": "双刃·淬锋", "desc": "双刃伤害 +{v}%", "values": [25, 37, 55, 75], "max": 5},
	"blades_speed": {"kind": "weapon", "character": "assassin", "name": "双刃·疾袭", "desc": "出手间隔 -{v}%", "values": [10, 14, 19, 25], "max": 4},
	"blades_reach": {"kind": "weapon", "character": "assassin", "name": "双刃·突进", "desc": "攻击范围 +{v}%", "values": [15, 20, 28, 36], "max": 3},
	"blades_flurry": {"kind": "weapon", "character": "assassin", "name": "双刃·三连刺", "desc": "每次出手对目标追加一击（50% 伤害）", "max": 1},

	# ———— 人物基础武器：奥术新星（法师）————
	"nova_damage": {"kind": "weapon", "character": "mage", "name": "新星·增幅", "desc": "新星伤害 +{v}%", "values": [25, 37, 55, 75], "max": 5},
	"nova_cooldown": {"kind": "weapon", "character": "mage", "name": "新星·吟唱", "desc": "新星间隔 -{v}%", "values": [10, 14, 19, 25], "max": 4},
	"nova_radius": {"kind": "weapon", "character": "mage", "name": "新星·扩散", "desc": "新星范围 +{v}%", "values": [15, 20, 28, 36], "max": 3},
	"nova_echo": {"kind": "weapon", "character": "mage", "name": "新星·回响", "desc": "每次释放后再放一圈新星", "max": 1},

	# ———— 通用属性 ————
	"might": {"kind": "stat", "name": "力量", "desc": "所有伤害 +{v}%", "values": [10, 15, 22, 30], "max": 5},
	"crit": {"kind": "stat", "name": "暴击", "desc": "所有攻击的暴击率 +{v}%（暴击伤害 ×2）", "values": [5, 7.5, 11, 15], "max": 4},
	"cooldown": {"kind": "stat", "name": "冷却缩短", "desc": "所有神术的冷却 -{v}%", "values": [5, 7.5, 11, 15], "max": 4},
	"haste": {"kind": "stat", "name": "急速", "desc": "基础武器的冷却 -{v}%", "values": [8, 12, 18, 24], "max": 3},
	"luck": {"kind": "stat", "name": "幸运", "desc": "抽到高稀有度卡的几率 +{v}%", "values": [3, 4.5, 6.5, 9], "max": 3},
	"swift": {"kind": "stat", "name": "迅捷", "desc": "移动速度 +{v}%", "values": [8, 12, 17, 24], "max": 3},
	"vigor": {"kind": "stat", "name": "体魄", "desc": "最大生命 +{v}，并回复同样多的生命", "values": [20, 30, 44, 60], "max": 5},
	"magnet": {"kind": "stat", "name": "引力", "desc": "拾取范围 +{v}%", "values": [30, 45, 66, 90], "max": 3},
	"wisdom": {"kind": "stat", "name": "智慧", "desc": "获得的经验 +{v}%", "values": [15, 22, 33, 45], "max": 3},
	"evasion": {"kind": "stat", "name": "闪避", "desc": "受到攻击时有 {v}% 几率闪避", "values": [8, 12, 17, 24], "max": 2},
	"regen": {"kind": "stat", "name": "再生", "desc": "每秒回复 {v} 点生命", "values": [1, 1.5, 2.2, 3], "max": 3},

	# ———— 托尔 ————
	"thor_skill": {"kind": "skill", "god": "thor"},
	"thor_storm": {"kind": "boon", "god": "thor", "name": "风暴", "desc": "每次多劈 {v} 道雷", "values": [1, 1, 1, 2], "max": 3,
		"descs": ["", "", "每次多劈 1 道雷，落雷范围 +10%", ""]},
	"thor_field": {"kind": "boon", "god": "thor", "name": "雷域", "desc": "落雷范围 +{v}%", "values": [12, 18, 26, 36], "max": 4},
	"thor_paralyze": {"kind": "boon", "god": "thor", "name": "麻痹", "desc": "被雷劈中的敌人有 {v}% 几率麻痹 0.6 秒，停止移动和攻击", "values": [12, 18, 26, 36], "max": 3},
	"thor_echo": {"kind": "boon", "god": "thor", "name": "回响", "desc": "落雷有 {v}% 几率在 0.5 秒后原地再劈一次", "values": [12, 18, 26, 36], "max": 3},
	"thor_mjolnir": {"kind": "path", "god": "thor", "name": "妙尔尼尔", "desc": "改为每 3 秒向敌人掷出战锤，飞出去再飞回手里，一路落雷。风暴 = 多掷一把锤；回响 = 回手时有几率立刻再掷"},
	"thor_cloud": {"kind": "path", "god": "thor", "name": "雷暴云", "desc": "头顶跟着一团雷云，每秒向周围劈 3 道小雷。风暴 = 每秒多劈 1 道；雷域 = 雷云更大"},
	"thor_static": {"kind": "path", "god": "thor", "name": "静电场", "desc": "落雷改为给敌人叠感电；相邻的感电敌人连成电网，每秒互相电击。雷域 = 电网连得更远"},
	"thor_mjolnir_awaken": {"kind": "awaken", "god": "thor", "path": "thor_mjolnir", "name": "觉醒·妙尔尼尔归来", "desc": "多掷 2 把战锤；战锤飞回手里的瞬间在身边引发大雷爆。受到攻击时 30% 几率反劈一道雷"},
	"thor_cloud_awaken": {"kind": "awaken", "god": "thor", "path": "thor_cloud", "name": "觉醒·山羊战车", "desc": "雷云覆盖整个屏幕，落雷速度翻倍。受到攻击时 30% 几率反劈一道雷"},
	"thor_static_awaken": {"kind": "awaken", "god": "thor", "path": "thor_static", "name": "觉醒·雷神之域", "desc": "感电的敌人死亡时，引爆电网上所有相连的敌人。受到攻击时 30% 几率反劈一道雷"},

	# ———— 奥丁 ————
	"odin_skill": {"kind": "skill", "god": "odin"},
	"odin_count": {"kind": "boon", "god": "odin", "name": "符文增殖", "desc": "每次多发射 {v} 枚符文", "values": [1, 1, 1, 2], "max": 3},
	"odin_pierce": {"kind": "boon", "god": "odin", "name": "破甲符文", "desc": "符文穿透 +{v}", "values": [1, 1, 2, 2], "max": 3},
	"odin_resonance": {"kind": "boon", "god": "odin", "name": "符文共鸣", "desc": "印记引爆时波及半径 +{v} 内的敌人，并给它们叠 1 层印记", "values": [40, 55, 75, 100], "max": 3},
	"odin_return": {"kind": "boon", "god": "odin", "name": "回旋符文", "desc": "符文飞到尽头后折返；折返时分裂成 2 枚的几率 +{v}%", "values": [25, 37, 55, 75], "max": 3},
	"odin_gungnir": {"kind": "path", "god": "odin", "name": "冈格尼尔", "desc": "改为每 2.5 秒掷出长枪，贯穿一条直线上的所有敌人，命中直接引爆印记。增殖 = 多掷一支；破甲 = 长枪更宽"},
	"odin_ravens": {"kind": "path", "god": "odin", "name": "渡鸦", "desc": "福金和雾尼绕身飞行，轮流俯冲啄向印记最多的敌人，每啄一下叠 2 层。增殖 = 多一只渡鸦"},
	"odin_nights": {"kind": "path", "god": "odin", "name": "九夜符文", "desc": "符文落地变成符文阵，停留 3 秒，阵里的敌人每秒叠 1 层印记。破甲 = 符文阵更大"},
	"odin_gungnir_awaken": {"kind": "awaken", "god": "odin", "path": "odin_gungnir", "name": "觉醒·永不落空", "desc": "长枪贯穿后自动转向下一个敌人，连续贯穿 3 次。每击杀 100 个敌人召唤一位英灵 20 秒"},
	"odin_ravens_awaken": {"kind": "awaken", "god": "odin", "path": "odin_ravens", "name": "觉醒·至高王座", "desc": "渡鸦 +2；被渡鸦啄死的精英化作英灵为你战斗 15 秒。每击杀 100 个敌人召唤一位英灵 20 秒"},
	"odin_nights_awaken": {"kind": "awaken", "god": "odin", "path": "odin_nights", "name": "觉醒·世界树之秘", "desc": "符文阵变大、停留更久；一处印记引爆时，所有符文阵里的敌人叠 1 层。每击杀 100 个敌人召唤一位英灵 20 秒"},

	# ———— 洛基 ————
	"loki_skill": {"kind": "skill", "god": "loki"},
	"loki_radius": {"kind": "boon", "god": "loki", "name": "野火蔓延", "desc": "火焰范围 +{v}%", "values": [12, 18, 26, 36], "max": 4},
	"loki_ember": {"kind": "boon", "god": "loki", "name": "余烬", "desc": "灼烧持续时间 +{v} 秒", "values": [1, 1.5, 2.2, 3], "max": 3},
	"loki_silver": {"kind": "boon", "god": "loki", "name": "银舌", "desc": "灼烧的敌人每秒有 {v}% 几率被迷惑 3 秒，去咬身边的同伴", "values": [4, 6, 9, 12], "max": 3},
	"loki_spark": {"kind": "boon", "god": "loki", "name": "火种", "desc": "灼烧的敌人死亡时点燃身边 {v} 个敌人", "values": [1, 1, 2, 3], "max": 3},
	"loki_wolf": {"kind": "path", "god": "loki", "name": "狼之父", "desc": "火焰收拢成一只芬里尔幼狼，跟着你扑咬附近的敌人并点燃它们。野火 = 扑咬范围更大"},
	"loki_shifter": {"kind": "path", "god": "loki", "name": "变形者", "desc": "每 4 秒在原地留下一个火焰分身，吸引附近的敌人，带着火焰燃烧 4 秒。火种 = 分身消失时爆炸"},
	"loki_road": {"kind": "path", "god": "loki", "name": "纳吉尔法尔之路", "desc": "火焰改为你走过的地方燃起火路，持续 4 秒。野火 = 火路更宽；余烬 = 火路更久"},
	"loki_wolf_awaken": {"kind": "awaken", "god": "loki", "path": "loki_wolf", "name": "觉醒·芬里尔", "desc": "幼狼长成巨狼，每 10 秒喷出一道狼嚎火焰，迷惑一路的敌人。被迷惑的敌人死亡时爆炸"},
	"loki_shifter_awaken": {"kind": "awaken", "god": "loki", "path": "loki_shifter", "name": "觉醒·千面", "desc": "同时存在 3 个分身，分身消失时迷惑周围的敌人。被迷惑的敌人死亡时爆炸"},
	"loki_road_awaken": {"kind": "awaken", "god": "loki", "path": "loki_road", "name": "觉醒·苏尔特之火", "desc": "火路持续更久，宽度随击杀不断变大（每 50 击杀 +5%）。被迷惑的敌人死亡时爆炸"},

	# ———— 弗蕾亚 ————
	"freyja_skill": {"kind": "skill", "god": "freyja"},
	"freyja_count": {"kind": "boon", "god": "freyja", "name": "羽翼丰满", "desc": "羽刃 +{v}", "values": [1, 1, 1, 2], "max": 4},
	"freyja_wings": {"kind": "boon", "god": "freyja", "name": "展翼", "desc": "羽刃环绕半径和转速 +{v}%", "values": [12, 18, 26, 36], "max": 3},
	"freyja_gold": {"kind": "boon", "god": "freyja", "name": "金羽", "desc": "被拣选的敌人死亡时掉落金羽的几率 +{v}%，捡起回复生命", "values": [3, 4.5, 6.5, 9], "max": 3},
	"freyja_aegis": {"kind": "boon", "god": "freyja", "name": "羽盾", "desc": "羽刃碰到飞向你的子弹时，有 {v}% 几率把它挡下", "values": [25, 37, 55, 75], "max": 3},
	"freyja_hawk": {"kind": "path", "god": "freyja", "name": "鹰羽披风", "desc": "羽刃改为每 2 秒向四周射出，飞到尽头再飞回身边，往返都能切。展翼 = 射得更远"},
	"freyja_brisingamen": {"kind": "path", "god": "freyja", "name": "布里辛嘉曼", "desc": "羽刃化成一圈金色光环：环上的敌人减速 30%，你每切到一个敌人回复少量生命。丰满 = 光环更粗"},
	"freyja_cats": {"kind": "path", "god": "freyja", "name": "战猫车", "desc": "两只战猫在身边巡逻，扑向靠近的敌人并拣选它们。丰满 = 多一只战猫"},
	"freyja_hawk_awaken": {"kind": "awaken", "god": "freyja", "path": "freyja_hawk", "name": "觉醒·弗尔克范格", "desc": "射出的羽刃第一次命中时分裂成 3 片小羽刃。本局获得一次复活"},
	"freyja_brisingamen_awaken": {"kind": "awaken", "god": "freyja", "path": "freyja_brisingamen", "name": "觉醒·金泪", "desc": "受到伤害时掉下一颗金色眼泪，捡起回复 15% 生命。本局获得一次复活"},
	"freyja_cats_awaken": {"kind": "awaken", "god": "freyja", "path": "freyja_cats", "name": "觉醒·女神出征", "desc": "每 15 秒，弗蕾亚乘猫车从屏幕一侧冲到另一侧，撞飞路上的敌人。本局获得一次复活"},

	# ———— 巴德尔 ————
	"baldr_skill": {"kind": "skill", "god": "baldr"},
	"baldr_prism": {"kind": "boon", "god": "baldr", "name": "棱光", "desc": "每次多射 {v} 道光束，扇形散开", "values": [1, 1, 1, 2], "max": 3},
	"baldr_radiance": {"kind": "boon", "god": "baldr", "name": "光辉", "desc": "光束长度和宽度 +{v}%", "values": [12, 18, 26, 36], "max": 4},
	"baldr_afterglow": {"kind": "boon", "god": "baldr", "name": "余晖", "desc": "光束消失后地上留下光带 {v} 秒，走进去的敌人持续受伤", "values": [1, 1.5, 2.2, 3], "max": 3},
	"baldr_refract": {"kind": "boon", "god": "baldr", "name": "折射", "desc": "光束命中带光痕的敌人时，有 {v}% 几率折射出一道小光束", "values": [12, 18, 26, 36], "max": 3},
	"baldr_spear": {"kind": "path", "god": "baldr", "name": "光明之矛", "desc": "光束收成一支光矛，飞过整个屏幕，伤害 ×2.5，间隔 ×1.5。棱光 = 多掷一支"},
	"baldr_daylight": {"kind": "path", "god": "baldr", "name": "白昼", "desc": "光束改为绕着你旋转的光柱，扫到的敌人持续受伤。棱光 = 多一道光柱；余晖 = 扫过的地方留光带"},
	"baldr_oath": {"kind": "path", "god": "baldr", "name": "万物之誓", "desc": "光束每命中一个敌人，你得到 1 层誓言护盾（最多 3 层，每层挡一次伤害）；护盾满时光束伤害 ×2"},
	"baldr_spear_awaken": {"kind": "awaken", "god": "baldr", "path": "baldr_spear", "name": "觉醒·神之光矛", "desc": "光矛命中第一个敌人时炸开十字光。每 30 秒全屏闪光，所有敌人挂上光痕"},
	"baldr_daylight_awaken": {"kind": "awaken", "god": "baldr", "path": "baldr_daylight", "name": "觉醒·永昼", "desc": "光柱 +2。每 30 秒全屏闪光，所有敌人挂上光痕"},
	"baldr_oath_awaken": {"kind": "awaken", "god": "baldr", "path": "baldr_oath", "name": "觉醒·无伤之神", "desc": "护盾叠满时 3 秒无敌，期间光束伤害翻倍。每 30 秒全屏闪光，所有敌人挂上光痕"},

	# ———— 澜 ————
	"ran_skill": {"kind": "skill", "god": "ran"},
	"ran_size": {"kind": "boon", "god": "ran", "name": "大网", "desc": "网的半径 +{v}%", "values": [12, 18, 26, 36], "max": 4},
	"ran_double": {"kind": "boon", "god": "ran", "name": "双网", "desc": "每次多抛 {v} 张网", "values": [1, 1, 1, 2], "max": 3},
	"ran_whirl": {"kind": "boon", "god": "ran", "name": "漩涡", "desc": "收网后原地留下漩涡 {v} 秒，继续把附近的敌人吸进来", "values": [1, 1.5, 2.2, 3], "max": 3},
	"ran_drag": {"kind": "boon", "god": "ran", "name": "拖曳", "desc": "被网住的敌人多定住 {v} 秒", "values": [0.2, 0.3, 0.45, 0.6], "max": 3},
	"ran_waves": {"kind": "path", "god": "ran", "name": "九浪", "desc": "网改为向前推出一道巨浪，卷走路上的敌人冲到尽头再拍下。大网 = 浪更宽；双网 = 多推一道浪"},
	"ran_andvari": {"kind": "path", "god": "ran", "name": "安德瓦利之网", "desc": "网留在地上 3 秒，网里的敌人每秒受伤；网里被打死的敌人掉落的经验翻倍"},
	"ran_drowned": {"kind": "path", "god": "ran", "name": "溺亡者", "desc": "网里被打死的敌人变成溺亡者，为你作战 8 秒（最多 6 个）"},
	"ran_waves_awaken": {"kind": "awaken", "god": "ran", "path": "ran_waves", "name": "觉醒·九位浪女", "desc": "每 12 秒，九道浪从四面八方冲向你所在的位置。受到伤害时 20% 几率把攻击者拖进网里"},
	"ran_andvari_awaken": {"kind": "awaken", "god": "ran", "path": "ran_andvari", "name": "觉醒·安德瓦利的黄金", "desc": "网变成金网，网里的敌人受到的伤害 +50%，偶尔掉落奖励点。受到伤害时 20% 几率把攻击者拖进网里"},
	"ran_drowned_awaken": {"kind": "awaken", "god": "ran", "path": "ran_drowned", "name": "觉醒·澜的殿堂", "desc": "溺亡者最多 12 个，并且不会消失。受到伤害时 20% 几率把攻击者拖进网里"},

	# ———— 弗雷 ————
	"freyr_skill": {"kind": "skill", "god": "freyr"},
	"freyr_twin": {"kind": "boon", "god": "freyr", "name": "双生剑", "desc": "飞剑 +{v}", "values": [1, 1, 1, 2], "max": 3},
	"freyr_dance": {"kind": "boon", "god": "freyr", "name": "剑之舞", "desc": "飞剑速度 +{v}%", "values": [12, 18, 26, 36], "max": 3},
	"freyr_bounty": {"kind": "boon", "god": "freyr", "name": "丰饶", "desc": "被飞剑杀死的敌人经验再 +{v}%", "values": [15, 22, 33, 45], "max": 3},
	"freyr_apple": {"kind": "boon", "god": "freyr", "name": "苹果", "desc": "掉落苹果的几率 +{v}%，捡起回复生命", "values": [2, 3, 4.5, 6], "max": 3},
	"freyr_boar": {"kind": "path", "god": "freyr", "name": "古林博斯帝", "desc": "飞剑换成金鬃野猪，每 4 秒冲向敌人最多的方向，撞飞一路的敌人。双生 = 多一头野猪"},
	"freyr_field": {"kind": "path", "god": "freyr", "name": "丰收之地", "desc": "飞剑每砍 10 下，插进地里长出一片麦田 8 秒：站在里面回复生命，敌人减速"},
	"freyr_sun": {"kind": "path", "god": "freyr", "name": "阳光之剑", "desc": "飞剑飞过的地方留下一道灼热的光痕，碰到的敌人灼烧"},
	"freyr_boar_awaken": {"kind": "awaken", "god": "freyr", "path": "freyr_boar", "name": "觉醒·金鬃冲锋", "desc": "每 15 秒，野猪群从屏幕边缘一起冲过来。每分钟回复 15% 生命"},
	"freyr_field_awaken": {"kind": "awaken", "god": "freyr", "path": "freyr_field", "name": "觉醒·华纳海姆之春", "desc": "一片麦田跟着你移动。每分钟回复 15% 生命"},
	"freyr_sun_awaken": {"kind": "awaken", "god": "freyr", "path": "freyr_sun", "name": "觉醒·三柄阳剑", "desc": "飞剑 +2，光痕留得更久。每分钟回复 15% 生命"},

	# ———— 斯卡蒂 ————
	"skadi_skill": {"kind": "skill", "god": "skadi"},
	"skadi_volley": {"kind": "boon", "god": "skadi", "name": "连珠", "desc": "每次多射 {v} 支冰箭，扇形散开", "values": [1, 1, 1, 2], "max": 3},
	"skadi_chill": {"kind": "boon", "god": "skadi", "name": "寒意", "desc": "每支冰箭多叠 {v} 层霜冻", "values": [1, 1, 2, 2], "max": 2},
	"skadi_icefield": {"kind": "boon", "god": "skadi", "name": "冰原", "desc": "冰箭飞过的地面结冰 {v} 秒，踩上去的敌人叠霜冻", "values": [1, 1.5, 2.2, 3], "max": 3},
	"skadi_shatter": {"kind": "boon", "god": "skadi", "name": "碎冰", "desc": "冻结的敌人被打死时爆出 {v} 片冰片", "values": [2, 3, 4, 5], "max": 3},
	"skadi_hunter": {"kind": "path", "god": "skadi", "name": "狩猎本能", "desc": "标记屏幕内最强的敌人，冰箭改为蓄力狙击它：伤害 ×3，直接冻结。连珠 = 狙击后追加普通箭"},
	"skadi_snowshoes": {"kind": "path", "god": "skadi", "name": "雪鞋", "desc": "移动时每走 150 像素自动射一支箭，跑得越多射得越多，站着不动就不射"},
	"skadi_winter": {"kind": "path", "god": "skadi", "name": "永冬", "desc": "冰箭改为身边一圈暴风雪，持续给范围内的敌人叠霜冻。连珠 = 暴风雪更大"},
	"skadi_hunter_awaken": {"kind": "awaken", "god": "skadi", "path": "skadi_hunter", "name": "觉醒·群山之女", "desc": "狙击箭贯穿整个屏幕，冻结一路上的所有敌人。免疫减速"},
	"skadi_snowshoes_awaken": {"kind": "awaken", "god": "skadi", "path": "skadi_snowshoes", "name": "觉醒·滑雪猎手", "desc": "闪现后 3 秒内箭的数量翻倍。免疫减速"},
	"skadi_winter_awaken": {"kind": "awaken", "god": "skadi", "path": "skadi_winter", "name": "觉醒·芬布尔之冬", "desc": "暴风雪扩大到整个屏幕。免疫减速"},
}

## 卡池抽空时的保底卡
const FALLBACK := "mead"
const FALLBACK_INFO := {"kind": "stat", "name": "蜜酒", "desc": "回复 30 生命", "max": 0}


static func get_info(id: String) -> Dictionary:
	if id == FALLBACK:
		return FALLBACK_INFO
	if id.begins_with("fusion_"):
		var fusion: Dictionary = Gods.FUSIONS[id.trim_prefix("fusion_")]
		return {"kind": "fusion", "gods": fusion.gods, "god": fusion.gods[0], "name": fusion.name, "desc": fusion.desc, "max": 1}
	var info: Dictionary = UPGRADES[id]
	if info.kind == "skill":  # 神术卡的名字和说明写在 Gods 里
		var god: Dictionary = Gods.ALL[info.god]
		return {"kind": "skill", "god": info.god, "name": god.skill, "desc": god.skill_desc, "max": 1}
	return info


## 这张卡在这个稀有度下的说明（已翻译）
static func describe(id: String, rarity: int) -> String:
	var info := get_info(id)
	var descs: Array = info.get("descs", [])
	if rarity >= 0 and rarity < descs.size() and descs[rarity] != "":
		return tr_text(descs[rarity])
	var text := tr_text(info.desc)
	if info.has("values"):
		text = text.replace("{v}", _number(value(id, maxi(rarity, 0))))
	elif info.kind == "weapon" and rarity > 0:
		text += tr_text("，武器伤害 +%d%%") % WEAPON_RARITY_BONUS[rarity]
	return text


static func tr_text(text: String) -> String:
	return TranslationServer.translate(text)


static func value(id: String, rarity: int) -> float:
	return UPGRADES[id].values[rarity]


static func _number(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(v)


## 抽一个稀有度：基础几率 + 每分钟 +2%（稀有以上）+ 幸运
static func roll_rarity(player: Player, minutes: float) -> int:
	var bonus := minutes * RARITY_PER_MINUTE + player.luck
	var high := RARITY_WEIGHTS[1] + RARITY_WEIGHTS[2] + RARITY_WEIGHTS[3]
	var scale := (high + bonus) / high
	var weights: Array[float] = [0.0, RARITY_WEIGHTS[1] * scale, RARITY_WEIGHTS[2] * scale, RARITY_WEIGHTS[3] * scale]
	weights[0] = maxf(0.0, 100.0 - weights[1] - weights[2] - weights[3])
	var roll := randf() * (weights[0] + weights[1] + weights[2] + weights[3])
	for i in 4:
		roll -= weights[i]
		if roll < 0.0:
			return i
	return 0


## 普通升级：抽出 count 张卡（武器、通用属性、已信仰的神的强化），至少 1 张来自已信仰的神
static func get_choices(player: Player, count: int, minutes: float) -> Array[Dictionary]:
	var boons: Array[String] = []
	var others: Array[String] = []
	for id: String in UPGRADES:
		if not _is_available(id, player):
			continue
		if UPGRADES[id].kind == "boon":
			boons.append(id)
		else:
			others.append(id)
	boons.shuffle()
	var picked: Array[String] = []
	if not boons.is_empty():
		picked.append(boons.pop_back())
	var rest := boons + others
	rest.shuffle()
	while picked.size() < count and not rest.is_empty():
		picked.append(rest.pop_back())
	var result: Array[Dictionary] = []
	for id in picked:
		result.append({"id": id, "rarity": roll_rarity(player, minutes)})
	result.shuffle()
	if result.is_empty():
		result.append({"id": FALLBACK, "rarity": -1})
	return result


static func _is_available(id: String, player: Player) -> bool:
	var info: Dictionary = UPGRADES[id]
	match info.kind:
		"weapon":
			if info.character != player.character_id:
				return false
		"boon":
			if not player.faith.has(info.god):
				return false
		"stat":
			pass
		_:
			return false  # 神术、质变、觉醒有自己的弹窗
	return player.upgrade_levels.get(id, 0) < info.max


## 选神：从还没信仰的神里随机 count 位；宿敌不同时出现
static func god_choices(player: Player, count: int) -> Array[Dictionary]:
	var pool: Array = Gods.ALL.keys().filter(func(god: String) -> bool: return not player.faith.has(god))
	pool.shuffle()
	var picked: Array[String] = []
	for god: String in pool:
		var rival: String = Gods.ALL[god].get("rival", "")
		if picked.has(rival):
			continue
		picked.append(god)
		if picked.size() >= count:
			break
	var result: Array[Dictionary] = []
	for god in picked:
		result.append({"id": god + "_skill", "rarity": -1})
	return result


## 这位神的三个质变
static func path_choices(god: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in UPGRADES:
		if UPGRADES[id].kind == "path" and UPGRADES[id].god == god:
			result.append({"id": id, "rarity": -1})
	return result


## 选过的质变对应的觉醒
static func awaken_choice(path: String) -> Array[Dictionary]:
	return [{"id": path + "_awaken", "rarity": -1}]


## 稀有度给的信仰：普通 +1 … 传说 +4
static func faith_gain(rarity: int) -> int:
	return maxi(rarity, 0) + 1


## 让一张卡生效：记录次数、增加信仰、修改玩家或技能的数值
static func apply(offer: Dictionary, player: Player) -> void:
	var id: String = offer.id
	var rarity: int = offer.rarity
	player.upgrade_levels[id] = player.upgrade_levels.get(id, 0) + 1
	var info := get_info(id)
	var v: float = value(id, rarity) if info.has("values") and rarity >= 0 else 0.0

	match info.kind:
		"skill":
			player.add_god(info.god)
			return
		"boon":
			player.faith[info.god] = mini(player.faith.get(info.god, 0) + faith_gain(rarity), FAITH_MAX)
			player.gods[info.god].upgrade(id, v, rarity)
			return
		"path":
			player.gods[info.god].set_path(id)
			return
		"awaken":
			player.gods[info.god].awaken()
			return
		"fusion":
			GodPower.fusions[id.trim_prefix("fusion_")] = true
			return
		"weapon":
			if not info.has("values") and rarity > 0:
				player.weapon_damage_bonus(WEAPON_RARITY_BONUS[rarity] / 100.0)

	match id:
		"mead":
			player.heal(30.0)

		"katana_damage":
			player.katana.damage *= 1.0 + v / 100.0
		"katana_speed":
			player.katana.cooldown *= 1.0 - v / 100.0
		"katana_range":
			player.katana.reach *= 1.0 + v / 100.0
		"katana_back":
			player.katana.back_slash = true
		"katana_knockback":
			player.katana.knockback *= 1.0 + v / 100.0
		"katana_hamstring":
			player.katana.hamstring += v / 100.0

		"revolver_damage":
			player.revolver.damage *= 1.0 + v / 100.0
		"revolver_rate":
			player.revolver.fire_interval *= 1.0 - v / 100.0
		"revolver_mag":
			player.revolver.magazine += int(v)
			player.revolver.reload_time *= 0.9
		"revolver_pierce":
			player.revolver.pierce += int(v)
		"revolver_twin":
			player.revolver.twin = true

		"blades_damage":
			player.blades.damage *= 1.0 + v / 100.0
		"blades_speed":
			player.blades.cooldown *= 1.0 - v / 100.0
		"blades_reach":
			player.blades.reach *= 1.0 + v / 100.0
		"blades_flurry":
			player.blades.flurry = true

		"nova_damage":
			player.nova.damage *= 1.0 + v / 100.0
		"nova_cooldown":
			player.nova.cooldown *= 1.0 - v / 100.0
		"nova_radius":
			player.nova.radius *= 1.0 + v / 100.0
		"nova_echo":
			player.nova.echo = true

		"might":
			player.damage_mult += v / 100.0
		"crit":
			Enemy.crit_chance += v / 100.0
		"cooldown":
			player.god_cooldown_mult *= 1.0 - v / 100.0
		"haste":
			player.weapon_cooldown_mult *= 1.0 - v / 100.0
		"luck":
			player.luck += v
		"swift":
			player.move_speed *= 1.0 + v / 100.0
		"vigor":
			player.max_hp += v
			player.heal(v)
		"magnet":
			player.pickup_radius *= 1.0 + v / 100.0
		"wisdom":
			player.xp_mult += v / 100.0
		"evasion":
			player.dodge_chance += v / 100.0
		"regen":
			player.regen += v
