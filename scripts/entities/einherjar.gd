class_name Einherjar
extends Node2D
## 英灵：支线「沉睡的英灵」唤醒的战士之魂。跟在玩家身边 60 秒，追砍玩家附近的敌人
## 没有素材，先用半透明的金色剪影（圆盾 + 头盔 + 剑）

const DURATION := 60.0
const FADE := 2.0         # 最后这几秒慢慢淡出
const SPEED := 280.0
const FOLLOW := 60.0      # 没有敌人时待在玩家身边这么远
const SEEK := 280.0       # 离玩家这么远以内的敌人会被它追过去砍
const REACH := 34.0
const SWING_EVERY := 0.5
const SWING_RADIUS := 44.0
const DAMAGE := 12.0
const COLOR := Color(1.0, 0.85, 0.5)

var player: Player
var power := 1.0  # 伤害跟着敌人血量一起成长，由支线设置
var _life := DURATION
var _swing_cd := 0.0
var _swing_t := 0.0
var _swing_dir := Vector2.RIGHT
var _time := 0.0


func _ready() -> void:
	FxLayer.burst(global_position, COLOR, 30, 220.0)


func _process(delta: float) -> void:
	_time += delta
	_life -= delta
	if _life <= 0.0 or not is_instance_valid(player):
		FxLayer.burst(global_position, COLOR, 16, 120.0)
		queue_free()
		return
	var foe := _nearest_enemy()
	var goal := player.global_position + Vector2.from_angle(_time * 0.7) * FOLLOW
	if foe:
		goal = foe.global_position + foe.global_position.direction_to(global_position) * REACH * 0.6
	position = MapLayer.push_out(Game.clamp_to_map(position.move_toward(goal, SPEED * delta), 12.0), 12.0)
	_swing_cd -= delta
	_swing_t = maxf(0.0, _swing_t - delta)
	if foe and _swing_cd <= 0.0 and global_position.distance_to(foe.global_position) < REACH + foe.radius:
		_swing_cd = SWING_EVERY
		_swing_t = 0.15
		_swing_dir = global_position.direction_to(foe.global_position)
		var at := global_position + _swing_dir * 24.0
		Enemy.damage_in_radius(get_tree(), at, SWING_RADIUS, DAMAGE * power * player.damage_mult, 140.0)
		FxLayer.mark(at, _swing_dir.angle(), 56.0, COLOR)
	queue_redraw()


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.global_position.distance_to(player.global_position) > SEEK:
			continue
		var d := enemy.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _draw() -> void:
	var a := clampf(_life / FADE, 0.0, 1.0) * (0.75 + 0.1 * sin(_time * 6.0))
	var c := Color(COLOR, a)
	var hover := Vector2(0, -4.0 + 2.0 * sin(_time * 3.0))
	draw_circle(Vector2(0, 14), 10.0, Color(COLOR, 0.15 * a))
	draw_colored_polygon(PackedVector2Array([hover + Vector2(-9, 12), hover + Vector2(-7, -8), hover + Vector2(7, -8), hover + Vector2(9, 12)]), c)
	draw_circle(hover + Vector2(0, -14), 7.0, c)
	draw_line(hover + Vector2(-7, -18), hover + Vector2(-11, -26), c, 2.0)  # 头盔两侧的角
	draw_line(hover + Vector2(7, -18), hover + Vector2(11, -26), c, 2.0)
	var facing := -1.0 if _swing_dir.x < 0.0 else 1.0
	draw_circle(hover + Vector2(-9 * facing, 2), 8.0, Color(COLOR.darkened(0.3), a))  # 圆盾
	var blade := _swing_dir.rotated(-1.2 + 2.4 * (1.0 - _swing_t / 0.15)) if _swing_t > 0.0 else Vector2(facing * 0.4, -1).normalized()
	draw_line(hover + Vector2(8 * facing, 0), hover + Vector2(8 * facing, 0) + blade * 22.0, Color(1, 1, 0.9, a), 2.5)
