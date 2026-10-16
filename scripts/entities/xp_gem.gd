class_name XpGem
extends Node2D
## 经验宝石：玩家进入拾取范围后被吸过去

const GEM := preload("res://assets/sprites/pickups/xp_gem.png")
const BIG_GEM := preload("res://assets/sprites/pickups/xp_gem_large.png")
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
	var tex := BIG_GEM if big else GEM
	draw_texture(tex, -tex.get_size() * 0.5)
