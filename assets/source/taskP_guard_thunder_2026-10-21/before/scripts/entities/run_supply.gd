class_name RunSupply
extends Node2D

const TEXTURES := {
	"healing_mead": preload("res://assets/sprites/pickups/healing_mead.png"),
	"soul_magnet": preload("res://assets/sprites/pickups/soul_magnet.png"),
}

var kind := "healing_mead"
var player: Player
var game: Game
var life := SupplyDB.LIFETIME
var _time := 0.0
var _consumed := false


func _process(delta: float) -> void:
	if not is_instance_valid(game) or not game.is_running() or not is_instance_valid(player) or player.is_dead:
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_time += delta
	if global_position.distance_squared_to(player.global_position) <= SupplyDB.PICKUP_DISTANCE * SupplyDB.PICKUP_DISTANCE:
		collect()
	queue_redraw()


func collect() -> bool:
	if _consumed or is_queued_for_deletion() or not is_instance_valid(game) or not game.is_running() or not is_instance_valid(player) or player.is_dead:
		return false
	if kind == "healing_mead":
		if player.hp >= player.max_hp:
			return false
		_consumed = true
		var restored := minf(SupplyDB.HEAL, player.max_hp - player.hp)
		player.heal(restored)
		Audio.sfx_or("heal_pickup", "pickup_xp", -4.0)
		FxLayer.floating_text(player.global_position + Vector2(0, -35), tr("蜜酒 +%d") % ceili(restored), Color(0.65, 1.0, 0.55))
	elif kind == "soul_magnet":
		if player.level >= Player.MAX_LEVEL:
			return false
		if XpGem.attract_all(player) == 0:
			return false
		_consumed = true
		Audio.sfx("pickup_xp", -2.0)
		FxLayer.floating_text(player.global_position + Vector2(0, -35), tr("聚魂"), Color(0.5, 0.9, 1.0))
	else:
		return false
	queue_free()
	return true


func _draw() -> void:
	var bob := Vector2(0, roundf(sin(_time * 3.0) * 2.0))
	var color := Color(1.0, 0.7, 0.25) if kind == "healing_mead" else Color(0.3, 0.8, 1.0)
	var alpha := 1.0 if life > 10.0 else (0.45 if int(_time * 4.0) % 2 else 1.0)
	draw_circle(Vector2(0, 10), 15.0, Color(color, 0.14 * alpha))
	draw_texture(TEXTURES[kind], bob - Vector2(16, 16), Color(1, 1, 1, alpha))
