class_name ColdWaveQuest
extends SideQuest
## 支线「芬布尔寒潮」（出现在玩家附近）：接受后寒潮来袭 60 秒。离开火盆就会失去体温，体温降到 0 支线失败（不扣血）
## 火盆一个接一个点燃，每个只燃 12 秒；快熄灭前 3 秒，下一个在别处亮起，要赶过去。体温低于 30 时移速 -30%
## 奖励：奖励点 +100，额外一次升级

const BRAZIER := preload("res://assets/sprites/quests/iron_brazier.png")  # 4 帧火焰循环
const WARM_RADIUS := 90.0
const BURN_TIME := 12.0
const NEXT_EARLY := 3.0
const NEXT_DISTANCE := Vector2(450.0, 650.0)  # 下一个火盆离上一个多远
const COOL_RATE := 9.0   # 不在火盆旁，体温每秒下降
const WARM_RATE := 20.0  # 在火盆旁，体温每秒回升
const CHILLED := 30.0
const SNOW := 70

var _heat := 100.0
var _fires: Array[Dictionary] = []  # {"pos", "t" 已经燃了多久}


func _init() -> void:
	title = tr("芬布尔寒潮")
	offer_text = tr("【主神】支线剧情：芬布尔之冬的寒潮要来了。守着火盆撑过 60 秒")
	time_limit = 60.0
	color = Color(1.0, 0.65, 0.3)


func _on_accept() -> void:
	_fires.append({"pos": marker_pos, "t": 0.0})


func _on_update(delta: float) -> void:
	if time_left <= 0.0:
		complete(true)
		return
	for fire in _fires:
		fire.t += delta
	var newest: Dictionary = _fires[-1]
	if newest.t >= BURN_TIME - NEXT_EARLY:
		var pos := Vector2.INF
		for attempt in 12:  # 找一个地图里、不在障碍物上的位置
			var p: Vector2 = newest.pos + Vector2.from_angle(randf() * TAU) * randf_range(NEXT_DISTANCE.x, NEXT_DISTANCE.y)
			if Game.bounds.grow(-80.0).has_point(p) and MapLayer.push_out(p, 30.0) == p:
				pos = p
				break
		if not pos.is_finite():
			pos = MapLayer.push_out(Game.clamp_to_map(newest.pos + Vector2.from_angle(randf() * TAU) * NEXT_DISTANCE.x, 80.0), 30.0)
		_fires.append({"pos": pos, "t": 0.0})
	_fires = _fires.filter(func(fire: Dictionary) -> bool: return fire.t < BURN_TIME)
	var warm := _fires.any(func(fire: Dictionary) -> bool: return player.global_position.distance_to(fire.pos) < WARM_RADIUS)
	_heat = clampf(_heat + (WARM_RATE if warm else -COOL_RATE) * delta, 0.0, 100.0)
	player.speed_mult = 0.7 if _heat < CHILLED else 1.0
	objective = tr("撑过寒潮  体温 %d") % ceili(_heat)
	if _heat <= 0.0:
		FxLayer.floating_text(player.global_position + Vector2(0, -50), tr("冻僵了"), Color(0.7, 0.85, 1.0))
		complete(false)


func _on_end() -> void:
	player.speed_mult = 1.0


func _reward() -> String:
	game.add_reward_points(100)
	game.queue_reward(tr("熬过了寒潮！选择一项奖励"))
	return tr("奖励点 +100，额外一次升级")


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if state == "active" and player.global_position.distance_to(_fires[-1].pos) > WARM_RADIUS:
		targets.append(_fires[-1].pos)
	return targets


func _draw_quest() -> void:
	for fire in _fires:
		var p: Vector2 = fire.pos
		var left: float = 1.0 - fire.t / BURN_TIME  # 1 → 0，火越来越小
		var inside := player.global_position.distance_to(p) < WARM_RADIUS
		draw_circle(p, WARM_RADIUS, Color(color, (0.12 if inside else 0.06) * (0.4 + 0.6 * left)))
		draw_arc(p, WARM_RADIUS, -PI / 2, -PI / 2 + TAU * left, 48, Color(color, 0.7), 3.0)
		SpriteVisual.draw_frame(self, BRAZIER, 4, int(_time * 8.0 + p.x), p + Vector2(0, 16), Vector2(24, 46))


## 风雪和体温条画在角色上面
func _draw_overlay() -> void:
	if state != "active":
		return
	var center := player.global_position
	var cold := 1.0 - _heat / 100.0
	for i in SNOW:
		var seed_x := fmod(i * 97.3, 1300.0)
		var seed_y := fmod(i * 61.7, 800.0)
		var p := center + Vector2(fposmod(seed_x - _time * 260.0, 1300.0) - 650.0, fposmod(seed_y + _time * 180.0, 800.0) - 400.0)
		overlay.draw_line(p, p + Vector2(-9, 6), Color(1, 1, 1, 0.25 + 0.35 * cold), 1.5)
	var bar := Rect2(center + Vector2(-20, -44), Vector2(40, 5))
	overlay.draw_rect(bar, Color(0, 0, 0, 0.6))
	overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _heat / 100.0, bar.size.y)), color if _heat >= CHILLED else Color(0.6, 0.8, 1.0))
