class_name Katana
extends Node2D
## 太刀：朝面向方向挥出扇形斩击，命中范围内所有敌人

const SLASH_DURATION := 0.15
const HALF_ARC := 1.05  # 扇形半角（弧度），约 60°，整个扇形 120°

var damage := 14.0
var cooldown := 1.0
var reach := 110.0
var back_slash := false  # 回身斩：同时斩向身后
var player: Player
var _timer := 0.3
var _slash_time := 0.0
var _slash_dirs: Array[Vector2] = []


func _ready() -> void:
	player = get_parent() as Player


func _process(delta: float) -> void:
	if _slash_time > 0.0:
		_slash_time -= delta
		queue_redraw()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = cooldown * player.cooldown_mult
	_slash()


func _slash() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var aim := _aim_direction(enemies)
	_slash_dirs = [aim]
	if back_slash:
		_slash_dirs.append(-aim)
	_slash_time = SLASH_DURATION

	var dmg := damage * player.damage_mult
	for node in enemies:
		var enemy := node as Enemy
		var offset := enemy.global_position - global_position
		if offset.length() > reach + enemy.radius:
			continue
		for dir in _slash_dirs:
			if absf(dir.angle_to(offset)) <= HALF_ARC:
				enemy.take_damage(dmg)
				break


## 自动瞄准：攻击范围附近有敌人就砍最近的那个，否则朝移动方向砍
func _aim_direction(enemies: Array[Node]) -> Vector2:
	var best := (reach * 1.5) ** 2
	var aim := player.facing
	for node in enemies:
		var offset := (node as Node2D).global_position - global_position
		var d := offset.length_squared()
		if d < best and d > 0.0:
			best = d
			aim = offset.normalized()
	return aim


func _draw() -> void:
	if _slash_time <= 0.0:
		return
	var alpha := _slash_time / SLASH_DURATION
	for dir in _slash_dirs:
		var a := dir.angle()
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			pts.append(Vector2.from_angle(a - HALF_ARC + HALF_ARC * 2.0 * i / 12.0) * reach)
		draw_colored_polygon(pts, Color(0.85, 0.92, 1.0, 0.3 * alpha))
		draw_arc(Vector2.ZERO, reach, a - HALF_ARC, a + HALF_ARC, 24, Color(1, 1, 1, alpha), 3.0)
