class_name CharacterDB
## 角色数据。角色系统在阶段 7 完善，目前只有宫本武藏可玩
##   cutin_moment  大招特写上显示的「最璀璨的时刻」
##   cutin_line    大招台词（用 \n 换行）
##   特写立绘放在 assets/sprites/characters/<角色id>_cutin.png，没有就用占位图形

const CUTIN_DIR := "res://assets/sprites/characters/"

const ALL := {
	"musashi": {
		"name": "宫本武藏",
		"title": "剑圣",
		"ult_name": "次元斩",
		"cutin_moment": "庆长十七年 · 巌流岛",
		"cutin_line": "千日为锻，万日为炼。\n这一刀，连天地也斩得开。",
		"cutin_color": Color(0.55, 0.65, 1.0),
	},
}
