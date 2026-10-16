class_name Chest
extends Node2D
## 宝箱：Boss 掉落，玩家碰到后打开（打开的样子留一会儿再消失），获得一次额外的升级选择

signal opened

const CLOSED := preload("res://assets/sprites/pickups/chest_closed.png")
const OPEN := preload("res://assets/sprites/pickups/chest_open.png")
const PICKUP_DISTANCE := 30.0
const OPEN_TIME := 0.6

var player: Player
var _time := 0.0
var _open_left := -1.0  # 打开后还要留多久，-1 表示还没打开


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _open_left >= 0.0:
		_open_left -= delta
		if _open_left < 0.0:
			queue_free()
	elif is_instance_valid(player) and global_position.distance_to(player.global_position) < PICKUP_DISTANCE:
		_open_left = OPEN_TIME
		Audio.sfx("chest_open")
		FxLayer.burst(global_position, Color(1.0, 0.85, 0.4), 24, 200.0)
		opened.emit()


func _draw() -> void:
	if _open_left >= 0.0:
		draw_texture(OPEN, Vector2(-16, -16), Color(1, 1, 1, minf(1.0, _open_left / OPEN_TIME * 2.0)))
		return
	var bob := roundf(sin(_time * 4.0) * 3.0)  # 上下浮动
	var glow := 0.5 + 0.5 * sin(_time * 6.0)
	draw_circle(Vector2(0, bob), 26.0, Color(1.0, 0.85, 0.4, 0.15 + 0.15 * glow))
	draw_texture(CLOSED, Vector2(-16, -16 + bob))
