class_name EnemyDB
## 敌人数据表
##   hp/speed/damage/radius/xp/color  基础属性
##   behavior  chase = 贴身追击（默认）；ranged = 保持距离射击；still = 不动也不攻击（支线里要打碎的目标）
##   mass      体重，越重越不容易被其他敌人挤开（默认 1）
##   远程敌人额外字段：shoot_range 射程，shoot_cooldown 射击间隔，projectile_damage 子弹伤害
##   max_alive 同时存在的上限，超过时改刷尸鬼（防止远程怪越积越多）
##   gait      步态（程序动画）：walk 双足（默认）、quad 四足、heavy 巨人、float 飘浮
##   attack    近身攻击的特效：claw 爪击（默认）、bite 撕咬、slam 砸地

const ALL := {
	# ———— 篇章一 · 第 1 关「芬布尔之冬」————
	"draugr": {"name": "尸鬼", "hp": 10.0, "speed": 70.0, "damage": 8.0, "radius": 13.0, "xp": 1,
		"color": Color(0.45, 0.62, 0.5)},
	"wolf": {"name": "冬狼", "hp": 6.0, "speed": 140.0, "damage": 5.0, "radius": 10.0, "xp": 1,
		"color": Color(0.62, 0.62, 0.72), "mass": 0.7, "gait": "quad", "attack": "bite"},
	"ice_spirit": {"name": "冰霜精魂", "hp": 8.0, "speed": 85.0, "damage": 4.0, "radius": 11.0, "xp": 2,
		"color": Color(0.55, 0.85, 1.0), "behavior": "ranged",
		"shoot_range": 320.0, "shoot_cooldown": 2.5, "projectile_damage": 7.0, "max_alive": 30, "gait": "float"},
	"frost_giant": {"name": "霜巨人斥候", "hp": 50.0, "speed": 45.0, "damage": 18.0, "radius": 24.0, "xp": 6,
		"color": Color(0.45, 0.55, 0.85), "mass": 4.0, "gait": "heavy", "attack": "slam"},
	# 支线「冰下的战士」的冰块：不会动，打碎它
	"ice_block": {"name": "冰封的战士", "hp": 60.0, "speed": 0.0, "damage": 0.0, "radius": 18.0, "xp": 3,
		"color": Color(0.6, 0.85, 1.0, 0.9), "behavior": "still", "mass": 1000.0},
}

## 精英怪的属性倍率
const ELITE_HP := 6.0
const ELITE_SIZE := 1.4
const ELITE_DAMAGE := 1.5
const ELITE_XP := 15
