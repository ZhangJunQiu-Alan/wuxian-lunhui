class_name AnchorChainsQuest
extends SideQuest
## 支线「斩断锚链」：纳吉尔法尔被 4 条锚链拴在港口。限时内全部打断，延缓起航
## 奖励：海拉推迟 45 秒登场，初始血量 -20%

const CHAINS := 4
const BOSS_DELAY := 45.0
const BOSS_HP := 0.8

var _chains: Array[Enemy] = []


func _init() -> void:
	title = "斩断锚链"
	offer_text = "【主神】支线剧情：纳吉尔法尔被锚链拴在港口。在它起航前，斩断锚链"
	time_limit = 75.0
	color = Color(0.7, 0.68, 0.62)


func _on_accept() -> void:
	for i in CHAINS:
		var pos := Game.clamp_to_map(marker_pos + Vector2(-270 + 180 * i, -60 + (i % 2) * 90), 60.0)
		var chain := game.spawn_enemy("anchor_chain", MapLayer.push_out(pos, 20.0))
		_chains.append(chain)
		chain.killed.connect(func(_e: Enemy) -> void: _chains.erase(chain))


func _on_update(_delta: float) -> void:
	objective = "打断锚链  %d / %d" % [CHAINS - _chains.size(), CHAINS]
	if _chains.is_empty():
		complete(true)


func _on_end() -> void:
	for chain in _chains:
		if is_instance_valid(chain):
			game.despawn_enemy(chain)


func _reward() -> String:
	game.boss_delay["hel"] = BOSS_DELAY
	game.boss_hp_mult["hel"] = BOSS_HP
	return "纳吉尔法尔推迟起航：海拉晚 45 秒登场，血量 -20%"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for chain in _chains:
		if is_instance_valid(chain):
			targets.append(chain.global_position)
	return targets


func _draw_quest() -> void:
	for chain in _chains:  # 锚链从岸边一直拉向北边的船
		if is_instance_valid(chain):
			var p := chain.global_position
			draw_line(p, Vector2(p.x * 0.6 + marker_pos.x * 0.4, Game.bounds.position.y - 40.0), Color(0.15, 0.14, 0.13), 7.0)
			draw_line(p, Vector2(p.x * 0.6 + marker_pos.x * 0.4, Game.bounds.position.y - 40.0), Color(0.45, 0.42, 0.4), 3.0)
