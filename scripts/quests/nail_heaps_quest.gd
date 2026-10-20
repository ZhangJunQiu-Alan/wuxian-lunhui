class_name NailHeapsQuest
extends SideQuest
## 支线「指甲堆」：指甲工坊里堆着造船用的指甲。限时内烧掉 5 堆，每堆被毁都会冒出指甲傀儡
## 奖励：奖励点 +60，海拉第二阶段的指甲弹幕减少 30%

const HEAPS := 5
const GOLEMS_PER_HEAP := 2

var _heaps: Array[Enemy] = []


func _init() -> void:
	title = tr("指甲堆")
	offer_text = tr("【主神】支线剧情：亡者在工坊里用指甲造船。烧掉那些指甲堆")
	time_limit = 90.0
	color = Color(0.85, 0.6, 0.3)


func _on_accept() -> void:
	for i in HEAPS:
		var pos := Game.clamp_to_map(marker_pos + Vector2.from_angle(TAU * i / HEAPS + 0.3) * 200.0, 60.0)
		var heap := game.spawn_enemy("nail_heap", MapLayer.push_out(pos, 26.0), false, true)
		if heap == null:
			complete(false)
			return
		_heaps.append(heap)
		heap.killed.connect(_on_heap_burned.bind(heap))


func _on_heap_burned(_e: Enemy, heap: Enemy) -> void:
	_heaps.erase(heap)
	FxLayer.burst(heap.global_position, Color(1.0, 0.55, 0.2), 24, 200.0, 4.0)
	for i in GOLEMS_PER_HEAP:
		game.spawn_enemy.call_deferred("nail_golem", heap.global_position + Vector2.from_angle(randf() * TAU) * 50.0)


func _on_update(_delta: float) -> void:
	objective = tr("烧掉指甲堆  %d / %d") % [HEAPS - _heaps.size(), HEAPS]
	if _heaps.is_empty():
		complete(true)


func _on_end() -> void:
	for heap in _heaps:
		if is_instance_valid(heap):
			game.despawn_enemy(heap)


func _reward() -> String:
	game.add_reward_points(60)
	game.boss_tweaks["hel"] = {"barrage_mult": 0.7}
	return tr("奖励点 +60，海拉的指甲弹幕减少 30%")


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for heap in _heaps:
		if is_instance_valid(heap):
			targets.append(heap.global_position)
	return targets
