class_name PriestsQuest
extends SideQuest
## 支线「霜巨人的祭司」（码头）：三个冰霜精魂祭司在码头召唤寒潮。60 秒内击杀全部祭司
## 祭司是血量 3 倍的精英冰霜精魂：你靠近时它们往后退，离远了又回来朝你放冰锥；每个祭司身边每 6 秒冒出一圈护卫
## 奖励：奖励点 +120，最后一个祭司掉落宝箱

const VORTEX := preload("res://assets/sprites/quests/ice_vortex.png")  # 4 帧旋转
const COUNT := 3
const HP_MULT := 3.0
const SHY := 260.0       # 玩家进入这个距离，祭司就后退
const GUARD_EVERY := 6.0
const GUARDS := ["draugr", "wolf", "draugr", "wolf"]

var _priests: Array[Enemy] = []
var _killed := 0
var _guard_timer := 2.0


func _init() -> void:
	title = "霜巨人的祭司"
	offer_text = "【主神】支线剧情：霜巨人的祭司正在码头召唤寒潮。击杀全部祭司"
	time_limit = 60.0
	color = Color(0.55, 0.8, 1.0)


func _on_accept() -> void:
	for i in COUNT:
		var pos := marker_pos + Vector2.from_angle(TAU * i / COUNT + randf()) * randf_range(220.0, 320.0)
		var priest := game.spawn_enemy("ice_spirit", Game.clamp_to_map(pos, 60.0), true)
		priest.display_name = "霜巨人祭司"
		priest.max_hp *= HP_MULT
		priest.hp = priest.max_hp
		priest.killed.connect(_on_priest_killed)
		_priests.append(priest)


func _on_priest_killed(priest: Enemy) -> void:
	_killed += 1
	if _killed < COUNT:
		return
	var chest := Chest.new()
	chest.player = player
	chest.position = priest.position
	chest.opened.connect(game.queue_reward.bind("祭司的遗物！选择一项奖励"))
	game.add_child.call_deferred(chest)
	complete(true)


func _on_update(delta: float) -> void:
	_guard_timer -= delta
	var guard := _guard_timer <= 0.0
	if guard:
		_guard_timer = GUARD_EVERY
	for priest in _alive():
		var away := priest.global_position - player.global_position
		priest.flee_to = Game.clamp_to_map(priest.global_position + away.normalized() * 200.0, 60.0) if away.length() < SHY else Vector2.INF
		if guard:
			for i in GUARDS.size():
				game.spawn_enemy(GUARDS[i], Game.clamp_to_map(priest.global_position + Vector2.from_angle(TAU * i / GUARDS.size()) * 70.0, 40.0))
	objective = "击杀祭司  %d / %d" % [_killed, COUNT]


func _on_end() -> void:
	for priest in _alive():
		game.despawn_enemy(priest)


func _alive() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for priest in _priests:
		if is_instance_valid(priest) and not priest.is_queued_for_deletion():
			alive.append(priest)
	return alive


func _reward() -> String:
	game.add_reward_points(120)
	return "奖励点 +120，祭司的遗物（宝箱）"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for priest in _alive():
		targets.append(priest.global_position)
	return targets


func _draw_quest() -> void:
	if state != "active":
		return
	# 祭司们把寒气输向码头中央的冰涡，冰涡越转越大
	var grow := 1.0 - time_left / time_limit
	SpriteVisual.draw_frame(self, VORTEX, 4, int(_time * 8.0), marker_pos, Vector2(48, 48), 0.0, Vector2.ONE * (0.7 + 0.8 * grow))
	for priest in _alive():
		var k := 0.4 + 0.3 * sin(_time * 8.0 + priest.get_instance_id())
		draw_line(priest.global_position, marker_pos, Color(color, 0.25 * k + 0.1), 2.0)
