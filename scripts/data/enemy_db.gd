class_name EnemyDB
## 敌人数据表
##   hp/speed/damage/radius/xp/color  基础属性
##   behavior  chase = 贴身追击（默认）；ranged = 保持距离射击；drain = 保持距离吸血（持续掉血，自己回血）；
##             still = 不动也不攻击（支线里要打碎的目标）
##   mass      体重，越重越不容易被其他敌人挤开（默认 1）
##   远程敌人额外字段：shoot_range 射程，shoot_cooldown 射击间隔，projectile_damage 子弹伤害（吸血时是每秒伤害）
##             projectile 子弹素材（assets/sprites/effects/<名字>.png，默认冰锥），projectile_speed 子弹速度
##   max_alive 同时存在的上限，超过时改刷尸鬼（防止远程怪越积越多）
##   gait      步态（程序动画）：walk 双足（默认）、quad 四足、heavy 巨人、float 飘浮
##   attack    近身攻击的特效：claw 爪击（默认）、bite 撕咬、slam 砸地
##   pack      一次刷出几只（成群出现）
##   ghost     穿过其他敌人、冥河和物件
##   dodge     被打中时闪避的几率（闪开后 DODGE_COOLDOWN 秒内不会再闪）
##   split     死亡时分裂成哪种敌人，split_count 分裂几只
##   sprite_dir 素材不在 enemies/ 里时写素材所在的文件夹（Boss 战里要打断的锁桩）；sprite 是素材文件名和 id 不一样时的文件名
##   script    有专属行为的敌人用的脚本（继承 Enemy），没有就是普通 Enemy

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

	# ———— 篇章一 · 第 2 关「亡者之船」————
	"dead": {"name": "亡者", "hp": 7.0, "speed": 62.0, "damage": 6.0, "radius": 12.0, "xp": 1,
		"color": Color(0.62, 0.62, 0.58), "pack": 6},
	"mist_wraith": {"name": "冥雾幽魂", "hp": 9.0, "speed": 80.0, "damage": 4.0, "radius": 11.0, "xp": 2,
		"color": Color(0.55, 0.75, 0.7), "behavior": "drain", "ghost": true,
		"shoot_range": 180.0, "projectile_damage": 2.0, "max_alive": 12, "gait": "float"},
	"dark_elf": {"name": "黑暗精灵", "hp": 10.0, "speed": 95.0, "damage": 5.0, "radius": 11.0, "xp": 2,
		"color": Color(0.5, 0.42, 0.65), "behavior": "ranged", "dodge": 0.35,
		"shoot_range": 380.0, "shoot_cooldown": 2.2, "projectile_damage": 8.0, "max_alive": 30,
		"projectile": "dark_arrow", "projectile_speed": 340.0},
	"nail_golem": {"name": "指甲傀儡", "hp": 45.0, "speed": 48.0, "damage": 16.0, "radius": 22.0, "xp": 5,
		"color": Color(0.78, 0.72, 0.52), "mass": 3.5, "gait": "heavy", "attack": "slam",
		"split": "nail_golem_small", "split_count": 3},
	"nail_golem_small": {"name": "小指甲傀儡", "hp": 8.0, "speed": 90.0, "damage": 5.0, "radius": 10.0, "xp": 1,
		"color": Color(0.78, 0.72, 0.52), "mass": 0.8},
	# Boss 加姆的锁桩：不会动，打断 4 根加姆就挣脱了
	"chain_stake": {"name": "锁桩", "hp": 70.0, "speed": 0.0, "damage": 0.0, "radius": 16.0, "xp": 3,
		"color": Color(0.45, 0.4, 0.38), "behavior": "still", "mass": 1000.0, "sprite_dir": "res://assets/sprites/props/helheim/"},
	# 支线「斩断锚链」「指甲堆」要打碎的目标
	"anchor_chain": {"name": "锚链", "hp": 110.0, "speed": 0.0, "damage": 0.0, "radius": 18.0, "xp": 3,
		"color": Color(0.4, 0.38, 0.36), "behavior": "still", "mass": 1000.0, "sprite_dir": "res://assets/sprites/quests/"},
	"nail_heap": {"name": "指甲堆", "hp": 60.0, "speed": 0.0, "damage": 0.0, "radius": 24.0, "xp": 3,
		"color": Color(0.72, 0.66, 0.48), "behavior": "still", "mass": 1000.0, "sprite_dir": "res://assets/sprites/props/helheim/",
		"sprite": "nail_heap_02"},
	# 隐藏支线「不肯哭泣的女巨人」：诡计之神变的老女巨人
	"thokk": {"name": "不肯哭泣的女巨人", "hp": 90.0, "speed": 70.0, "damage": 14.0, "radius": 20.0, "xp": 10,
		"color": Color(0.55, 0.45, 0.4), "mass": 4.0, "gait": "heavy"},

	# ———— 篇章一 · 第 3 关「最后之战」（亡者复用第 2 关的 dead）————
	# 专属行为在 vigrid_enemy.gd：火焰巨人死亡爆炸留下火焰地面，霜巨人精锐冲锋 / 正面举盾，狂狼战士低血量狂暴
	# foot 是素材清单里的脚锚（帧内像素），K 素材按它把脚对齐到 MapLayer.FOOT
	"fire_giant": {"name": "火焰巨人", "hp": 40.0, "speed": 50.0, "damage": 16.0, "radius": 22.0, "xp": 5,
		"color": Color(0.95, 0.45, 0.2), "mass": 4.0, "gait": "heavy", "attack": "slam",
		"script": "res://scripts/entities/vigrid_enemy.gd", "foot": Vector2(48, 94)},
	"frost_veteran": {"name": "霜巨人精锐", "hp": 60.0, "speed": 52.0, "damage": 18.0, "radius": 22.0, "xp": 6,
		"color": Color(0.5, 0.62, 0.9), "mass": 4.5, "gait": "heavy",
		"script": "res://scripts/entities/vigrid_enemy.gd", "foot": Vector2(48, 94)},
	"wolf_berserker": {"name": "狂狼战士", "hp": 12.0, "speed": 100.0, "damage": 7.0, "radius": 12.0, "xp": 2,
		"color": Color(0.6, 0.5, 0.42),
		"script": "res://scripts/entities/vigrid_enemy.gd", "foot": Vector2(32, 62)},
}

## 精英怪的属性倍率
const ELITE_HP := 6.0
const ELITE_SIZE := 1.4    # 碰撞半径和影子
const ELITE_VISUAL := 1.2  # 画面上比普通怪大多少（像素画平时只按整数倍放大，精英怪单独再放大）
const ELITE_SPEED := 1.2
const ELITE_DAMAGE := 1.5
const ELITE_XP := 15
const DODGE_COOLDOWN := 2.0
