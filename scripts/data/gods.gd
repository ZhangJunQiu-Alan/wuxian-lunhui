class_name Gods
## 神明数据。现在只有北欧世界的神，以后每个世界会指定自己能信仰哪些神
##   skill   神术（选这位神时获得）的名字和说明
##   mark    神印：这位神给敌人挂的状态
##   rival   宿敌：选神时两位不会同时出现在同一次三选一里

const ALL := {
	"thor": {"name": "托尔", "title": "雷神", "color": Color(0.55, 0.78, 1.0),
		"skill": "落雷", "skill_desc": "每 2 秒向附近的敌人劈下一道雷，被劈中的敌人感电"},
	"odin": {"name": "奥丁", "title": "众神之父", "color": Color(0.75, 0.6, 1.0),
		"skill": "符文飞弹", "skill_desc": "向最近的敌人发射符文。符文印记叠到 3 层时引爆"},
	"loki": {"name": "洛基", "title": "诡计之神", "color": Color(1.0, 0.55, 0.2), "rival": "baldr",
		"skill": "诡火", "skill_desc": "身边燃起火焰，靠近的敌人被灼烧，离开火焰后继续掉血"},
	"freyja": {"name": "弗蕾亚", "title": "爱与战争女神", "color": Color(1.0, 0.85, 0.4),
		"skill": "女武神之羽", "skill_desc": "2 片羽刃环绕身边。被拣选的敌人死亡时可能掉下回复生命的金羽"},
	"baldr": {"name": "巴德尔", "title": "光明之神", "color": Color(1.0, 0.95, 0.7), "rival": "loki",
		"skill": "圣光", "skill_desc": "每 2.5 秒朝敌人最多的方向射出一道贯穿光束。带光痕的敌人死亡时爆出一圈光"},
	"ran": {"name": "澜", "title": "海之女神", "color": Color(0.35, 0.7, 0.95),
		"skill": "澜之网", "skill_desc": "每 3.5 秒向敌人最密集的地方抛出大网，把敌人拉到一起定住。溺水的敌人受到的范围伤害 +20%"},
	"freyr": {"name": "弗雷", "title": "丰饶之神", "color": Color(0.6, 0.9, 0.4),
		"skill": "自战之剑", "skill_desc": "一把飞剑自动追砍敌人。被它杀死的敌人掉落的经验 +50%，偶尔掉下苹果"},
	"skadi": {"name": "斯卡蒂", "title": "冬与狩猎女神", "color": Color(0.75, 0.92, 1.0),
		"skill": "霜猎之箭", "skill_desc": "每 1.8 秒向最远的敌人射出穿透的冰箭。霜冻叠到 5 层时冻结"},
}

## 融合技：两位神都觉醒后出现
const FUSIONS := {
	"father_son": {"gods": ["thor", "odin"], "name": "父子雷符", "desc": "落雷劈中带符文印记的敌人时立刻引爆印记，并给周围的敌人叠 1 层印记"},
	"utgard": {"gods": ["thor", "loki"], "name": "乌特加尔德之旅", "desc": "落雷劈中灼烧的敌人时引发火雷爆炸；诡火范围内的敌人每秒被小雷击中一次"},
	"false_bride": {"gods": ["thor", "freyja"], "name": "假新娘", "desc": "闪现后隐身 2 秒，敌人跟丢你；隐身结束时在身边降下一道巨雷"},
	"shatter_thunder": {"gods": ["thor", "skadi"], "name": "碎冰之雷", "desc": "冻结的敌人被雷劈中时碎裂，冰片伤害周围的敌人并叠 2 层霜冻"},
	"blood_brothers": {"gods": ["odin", "loki"], "name": "血誓兄弟", "desc": "符文命中时点燃敌人；被迷惑的敌人每秒叠 1 层符文印记"},
	"valhalla": {"gods": ["odin", "freyja"], "name": "英灵殿与弗尔克范格", "desc": "每个精英死亡时召唤一位英灵，并肩作战 15 秒"},
	"baldr_dream": {"gods": ["odin", "baldr"], "name": "巴德尔之梦", "desc": "光束命中带符文印记的敌人时立刻引爆印记；符文命中时给敌人挂上光痕"},
	"mistletoe": {"gods": ["loki", "baldr"], "name": "槲寄生", "desc": "光束点燃敌人；带光痕又在灼烧的敌人死亡时，射出一支贯穿的槲寄生之箭"},
	"venom": {"gods": ["loki", "skadi"], "name": "毒蛇之刑", "desc": "灼烧的敌人每秒叠 1 层霜冻；冻结的敌人受到的灼烧伤害翻倍"},
	"andvari": {"gods": ["loki", "ran"], "name": "安德瓦利", "desc": "网里的敌人被点燃；网里被烧死的敌人有几率掉落奖励点"},
	"vanir_twins": {"gods": ["freyja", "freyr"], "name": "华纳双子", "desc": "每 3 秒一片羽刃离身追击敌人再飞回；飞剑命中的敌人被拣选"},
	"serpent_fishing": {"gods": ["thor", "ran"], "name": "钓巨蛇", "desc": "落雷劈中溺水的敌人时，所有溺水的敌人一起挨雷"},
}


## a、b 两位神之间的融合技 id，没有就返回空字符串
static func fusion_between(a: String, b: String) -> String:
	for id: String in FUSIONS:
		var pair: Array = FUSIONS[id].gods
		if pair.has(a) and pair.has(b):
			return id
	return ""
