class_name SupplyDrops
extends Node2D

var game: Game
var rng := RandomNumberGenerator.new()
var _active := {}
var _last := {}
var _kills := {}


func _ready() -> void:
	game = get_parent() as Game
	rng.randomize()
	for kind: String in SupplyDB.RULES:
		_active[kind] = []
		_last[kind] = 0.0
		_kills[kind] = 0
	game.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(enemy: Enemy) -> void:
	if not game.is_running() or game.player.is_dead or enemy is Boss or enemy.behavior == "still" or enemy.xp_value <= 0:
		return
	for kind: String in SupplyDB.RULES:
		_kills[kind] += 1
		var rule: Dictionary = SupplyDB.RULES[kind]
		if game.elapsed < rule.first or (float(_last[kind]) > 0.0 and game.elapsed - float(_last[kind]) < rule.cooldown):
			continue
		if kind == "soul_magnet" and game.player.level >= Player.MAX_LEVEL:
			continue
		if _active[kind].size() >= rule.cap:
			continue
		var pity: bool = game.elapsed - float(_last[kind]) >= rule.pity_time or int(_kills[kind]) >= rule.pity_kills
		if pity or rng.randf() < rule.chance:
			_spawn(kind, enemy.global_position)


func _spawn(kind: String, at: Vector2) -> RunSupply:
	var rule: Dictionary = SupplyDB.RULES[kind]
	if _active[kind].size() >= rule.cap:
		return null
	var pos := Game.clamp_to_map(at, 22.0)
	for i in 4:
		pos = Game.clamp_to_map(MapLayer.push_out(pos, 22.0), 22.0)
	if MapLayer.push_out(pos, 22.0).distance_squared_to(pos) > 0.01:
		return null
	var pickup := RunSupply.new()
	pickup.kind = kind
	pickup.player = game.player
	pickup.game = game
	pickup.position = to_local(pos)
	_active[kind].append(pickup)
	pickup.tree_exited.connect(func(): _active[kind].erase(pickup))
	_last[kind] = game.elapsed
	_kills[kind] = 0
	add_child.call_deferred(pickup)
	return pickup
