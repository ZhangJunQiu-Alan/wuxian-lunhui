class_name XpGem
extends Node2D
## 经验宝石：玩家进入拾取范围后被吸过去

const FLY_SPEED := 450.0

var value := 1
var big := false  # 精英怪掉落的大宝石
var player: Player
var _attracted := false


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var dist := global_position.distance_to(player.global_position)
	if dist < player.pickup_radius:
		_attracted = true
	if _attracted:
		global_position = global_position.move_toward(player.global_position, FLY_SPEED * delta)
		if dist < 12.0:
			player.add_xp(value)
			queue_free()


func _draw() -> void:
	var s := 2.0 if big else 1.0
	var pts := PackedVector2Array([Vector2(0, -6), Vector2(4, 0), Vector2(0, 6), Vector2(-4, 0)])
	for i in pts.size():
		pts[i] *= s
	draw_colored_polygon(pts, Color(1.0, 0.8, 0.3) if big else Color(0.4, 0.85, 1.0))
