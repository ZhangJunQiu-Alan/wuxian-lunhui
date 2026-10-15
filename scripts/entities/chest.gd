class_name Chest
extends Node2D
## 宝箱：Boss 掉落，玩家碰到后打开，获得一次额外的升级选择

signal opened

const PICKUP_DISTANCE := 30.0

var player: Player
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if is_instance_valid(player) and global_position.distance_to(player.global_position) < PICKUP_DISTANCE:
		FxLayer.burst(global_position, Color(1.0, 0.85, 0.4), 24, 200.0)
		opened.emit()
		queue_free()


func _draw() -> void:
	var bob := sin(_time * 4.0) * 3.0  # 上下浮动
	var glow := 0.5 + 0.5 * sin(_time * 6.0)
	draw_circle(Vector2(0, bob), 26.0, Color(1.0, 0.85, 0.4, 0.15 + 0.15 * glow))
	draw_rect(Rect2(-14, -10 + bob, 28, 20), Color(0.55, 0.32, 0.12))
	draw_rect(Rect2(-14, -10 + bob, 28, 6), Color(0.75, 0.48, 0.18))
	draw_rect(Rect2(-14, -10 + bob, 28, 20), Color(1.0, 0.82, 0.35), false, 2.0)
	draw_rect(Rect2(-3, -6 + bob, 6, 7), Color(1.0, 0.85, 0.4))
