class_name SwordsmanLoadout

const KITS := {
	"katana": ["太刀", "自动扇斩。每第四刀触发二刀流。"],
	"muramasa": ["村正", "连杀加快出刀。连杀中断后进入渴。"],
	"monohoshizao": ["物干竿", "窄扇长斩。外侧三分之一的刀尖伤害更高。"],
	"duanshui": ["断水", "斩击留下水痕，伤害经过弧线的敌人。"],
	"higekiri": ["髭切", "命中积攒鬼气。K / 右键鬼化连斩，再次按下可结束。"],
	"ganjiang_moye": ["干将莫邪", "雌雄双剑交替。K / 右键掷出莫邪，再按召回。"],
	"zhuxian": ["诛仙四剑", "诛、戮、陷、绝依序出击，分别重斩、流血、定身和处决。"],
	"qinglong": ["青龙偃月刀", "按住 K / 右键转刀。松手重劈，蓄足后青龙附体。"],
	"excalibur": ["湖中剑", "K / 右键挥剑，随后收鞘蓄力。蓄满后再按，发动居合。"],
	"riyue": ["日月双刀", "日、月普攻交替。K / 右键换手，发动日轮或月牙。"],
	"chunyang": ["纯阳剑", "K / 右键饮酒。一醉出剑气，二醉加快出刀，三醉可醉步闪避。"],
}


static func valid(id: String) -> String:
	return id if KITS.has(id) else "katana"


static func icon(id: String) -> Texture2D:
	var kit: Dictionary = SwordsmanArt.weapons().get(id, {})
	if kit.is_empty():
		return null
	return SwordsmanArt.texture(SwordsmanArt.WEAPON_DIR + str(kit.icon))
