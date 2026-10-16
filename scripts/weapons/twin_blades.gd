class_name TwinBlades
extends Node2D
## 刺客的双刃：射程极短、出手极快的近身连刺，左右手交替
## 被动「破阵」：身边每有 1 个敌人，伤害 +6%（最多 +60%）

const SLASH_DURATION := 0.1
const HALF_ARC := 0.7         # 扇形半角（弧度），约 40°，比太刀窄
const KNOCKBACK := 120.0
const SIEGE_RADIUS := 150.0   # 破阵：统计这个范围内的敌人
const SIEGE_PER_ENEMY := 0.06
const SIEGE_MAX := 0.6

var damage := 8.0
var cooldown := 0.32
var reach := 75.0
var flurry := false  # 三连刺：每次出手对目标额外追加一击
var player: Player
var _timer := 0.0
var _slash_time := 0.0
var _aim := Vector2.RIGHT
var _left_hand := false


func _ready() -> void:
	player = get_parent() as Player


func _process(delta: float) -> void:
	if _slash_time > 0.0:
		_slash_time -= delta
		queue_redraw()
	_timer -= delta
	if _timer > 0.0:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	var target: Enemy = null
	var best := INF
	var nearby := 0
	for node in enemies:
		var enemy := node as Enemy
		var d := enemy.global_position.distance_to(global_position)
		if d < SIEGE_RADIUS:
			nearby += 1
		if d - enemy.radius <= reach and d < best:
			best = d
			target = enemy
	if target == null:
		return  # 攻击范围内没有敌人就不出手
	_timer = cooldown * player.cooldown_mult
	_left_hand = not _left_hand
	_slash_time = SLASH_DURATION
	_aim = global_position.direction_to(target.global_position)
	if _aim == Vector2.ZERO:
		_aim = player.facing
	player.play_attack(_aim, 5.0, _timer)
	Audio.sfx("blades_slash")

	var siege := 1.0 + minf(SIEGE_MAX, nearby * SIEGE_PER_ENEMY)  # 破阵加成
	var dmg := damage * player.damage_mult * siege
	for node in enemies:
		var enemy := node as Enemy
		var offset := enemy.global_position - global_position
		if offset.length() <= reach + enemy.radius and absf(_aim.angle_to(offset)) <= HALF_ARC:
			enemy.take_damage(dmg, offset.normalized() * KNOCKBACK)
	if flurry and is_instance_valid(target):
		target.take_damage(dmg * 0.5)


func _draw() -> void:
	if _slash_time <= 0.0:
		return
	var alpha := _slash_time / SLASH_DURATION
	# 左右手交替：刀光稍微偏向一侧
	var a := _aim.angle() + (0.25 if _left_hand else -0.25)
	draw_arc(Vector2.ZERO, reach * 0.9, a - HALF_ARC, a + HALF_ARC, 16, Color(1.0, 0.45, 0.45, alpha), 3.0)
	draw_line(Vector2.ZERO, Vector2.from_angle(a) * reach, Color(1, 1, 1, alpha), 2.0)
