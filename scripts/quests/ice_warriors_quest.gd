class_name IceWarriorsQuest
extends SideQuest
## 支线「冰下的战士」（冰湖）：湖面下冻着 5 个霜巨人战士，冰正在融化。45 秒内打碎全部 5 块冰
## 冰块是不会动的敌人（ice_block），武器会自动打它；冰块下的光越来越亮，表示快裂开了
## 时间到了还没打碎的冰块会自己裂开，里面的战士消失在风雪中，不会出来打你
## 奖励：奖励点 +100，额外一次升级

const COUNT := 5

var _blocks: Array[Enemy] = []
var _broken := 0


func _init() -> void:
	title = "冰下的战士"
	offer_text = "【主神】支线剧情：冰湖下冻着霜巨人的战士，冰正在融化。在它们醒来之前打碎冰块"
	time_limit = 45.0
	color = Color(0.6, 0.85, 1.0)


func _on_accept() -> void:
	var base := randf() * TAU
	for i in COUNT:
		var pos := marker_pos + Vector2.from_angle(base + TAU * i / COUNT + randf_range(-0.3, 0.3)) * randf_range(160.0, 320.0)
		var block := game.spawn_enemy("ice_block", Game.clamp_to_map(pos, 60.0))
		block.killed.connect(_on_block_broken)
		_blocks.append(block)


func _on_block_broken(_block: Enemy) -> void:
	_broken += 1
	if _broken == COUNT:
		complete(true)


func _on_update(_delta: float) -> void:
	objective = "打碎冰块  %d / %d" % [_broken, COUNT]


func _on_end() -> void:
	for block in _blocks:
		if is_instance_valid(block) and not block.is_queued_for_deletion():
			FxLayer.burst(block.global_position, color, 16, 160.0)
			game.despawn_enemy(block)


func _reward() -> String:
	game.add_reward_points(100)
	game.queue_reward("冰下的宝藏！选择一项奖励")
	return "奖励点 +100，额外一次升级"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for block in _blocks:
		if is_instance_valid(block) and not block.is_queued_for_deletion():
			targets.append(block.global_position)
	return targets


func _draw_quest() -> void:
	if state != "active":
		return
	var melt := 1.0 - time_left / time_limit  # 0 → 1，越来越亮
	for block in _blocks:
		if not is_instance_valid(block) or block.is_queued_for_deletion():
			continue
		var p := block.global_position
		draw_set_transform(p + Vector2(0, 10), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 46.0, Color(0.05, 0.1, 0.2, 0.5))  # 冰下巨人的黑影
		draw_set_transform(Vector2.ZERO)
		var flicker := 0.5 + 0.5 * sin(_time * (4.0 + 10.0 * melt))
		draw_circle(p, 30.0 + 10.0 * melt, Color(color, 0.08 + 0.3 * melt * flicker))
