class_name SupplyThunder
extends Node2D

var game: Game
var targets: Array[Enemy] = []
var _cursor := 0
var _age := 0.0


func prepare(center: Vector2) -> bool:
	for enemy in Enemy.query_radius(center, SupplyDB.THUNDER_RADIUS):
		if not enemy is Boss and not enemy._dead and enemy.behavior != "still" and enemy.xp_value > 0:
			targets.append(enemy)
	targets.sort_custom(func(a: Enemy, b: Enemy): return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	if targets.size() > SupplyDB.THUNDER_MAX_TARGETS:
		targets.resize(SupplyDB.THUNDER_MAX_TARGETS)
	return not targets.is_empty()


func _ready() -> void:
	z_index = 8
	LightningFx.spawn(self, Vector2(0, -252), Vector2.ZERO, 0.0)
	FxLayer.ring(global_position, SupplyDB.THUNDER_RADIUS, 0.45)


func _process(delta: float) -> void:
	if not is_instance_valid(game) or not game.is_running() or game.player.is_dead:
		queue_free()
		return
	_age += delta
	var end := mini(_cursor + SupplyDB.THUNDER_BATCH, targets.size())
	while _cursor < end:
		var enemy := targets[_cursor]
		_cursor += 1
		if not is_instance_valid(enemy) or enemy._dead or enemy.is_queued_for_deletion():
			continue
		if enemy.is_elite:
			enemy.apply_slow(SupplyDB.ELITE_SLOW, SupplyDB.ELITE_SLOW_DURATION)
		else:
			enemy._die()
	if _cursor >= targets.size() and _age >= 0.25:
		queue_free()
