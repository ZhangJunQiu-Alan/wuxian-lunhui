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
var _slash_count := 0
var _niten := false  # 这一刀是否触发了二天一流
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
	# 宫本武藏的被动「二天一流」：每第 4 刀变为双刀斩，前后同时斩击，伤害翻倍
	_slash_count += 1
	_niten = _slash_count % 4 == 0
	_slash_dirs = [aim]
	if back_slash or _niten:
		_slash_dirs.append(-aim)
	_slash_time = SLASH_DURATION

	var dmg := damage * player.damage_mult * (2.0 if _niten else 1.0)
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
		var tint := Color(1.0, 0.85, 0.45) if _niten else Color(0.85, 0.92, 1.0)  # 二天一流的刀光是金色
		draw_colored_polygon(pts, Color(tint, 0.3 * alpha))
		draw_arc(Vector2.ZERO, reach, a - HALF_ARC, a + HALF_ARC, 24, Color(tint, alpha), 3.0)
