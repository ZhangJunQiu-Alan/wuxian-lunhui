class_name RunesQuest
extends SideQuest
## 隐藏支线「路标石的符文」（十字路口）：路标石上有三个发亮的符文，各指向一处地标
## 限时内去那三处触摸对应的符文。每碰到一处奖励点 +30，三处都碰完获得符文之力：本局伤害 +15%、冷却 -10%

const TOUCH_DISTANCE := 45.0
const SPOTS := 3
const POINTS_EACH := 30

var _spots: Array[Dictionary] = []  # {"name", "pos", "done"}


func _init() -> void:
	title = "路标石的符文"
	offer_text = "【主神】发现隐藏支线：路标石的符文。去触摸三处地标的符文"
	hint_text = "【主神】十字路口的路标石上，符文在微微发亮"
	time_limit = 150.0
	color = Color(0.55, 0.95, 0.75)
	is_hidden = true


func _hidden_spot() -> Vector2:
	return landmark.pos + Vector2(70, -26)


func _on_accept() -> void:
	var others: Array = game.level_data.map.landmarks.filter(func(l: Dictionary) -> bool: return l.id != landmark.id)
	others.shuffle()
	for l: Dictionary in others.slice(0, SPOTS):
		var pos: Vector2 = l.pos + Vector2.from_angle(randf() * TAU) * randf() * l.radius * 0.3
		_spots.append({"name": l.name, "pos": MapLayer.push_out(pos, Player.RADIUS + 10.0), "done": false})


func _on_update(_delta: float) -> void:
	var done := 0
	for spot in _spots:
		if not spot.done and player.global_position.distance_to(spot.pos) < TOUCH_DISTANCE:
			spot.done = true
			game.add_reward_points(POINTS_EACH)
			FxLayer.burst(spot.pos, color, 18, 160.0)
			FxLayer.floating_text(spot.pos + Vector2(0, -40), "%s的符文  奖励点 +%d" % [spot.name, POINTS_EACH], color)
		if spot.done:
			done += 1
	objective = "触摸符文  %d / %d" % [done, SPOTS]
	if done == SPOTS:
		complete(true)


func _reward() -> String:
	player.damage_mult += 0.15
	player.cooldown_mult *= 0.9
	return "获得符文之力：本局伤害 +15%，冷却 -10%"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for spot in _spots:
		if not spot.done:
			targets.append(spot.pos)
	return targets


func _draw_quest() -> void:
	if state != "active":
		return
	for i in _spots.size():
		var spot: Dictionary = _spots[i]
		var pulse := 0.5 + 0.5 * sin(_time * 4.0 + i)
		var c := Color(color, 0.25) if spot.done else Color(color, 0.6 + 0.4 * pulse)
		if not spot.done:
			draw_circle(spot.pos, TOUCH_DISTANCE, Color(color, 0.06 + 0.06 * pulse))
		_draw_rune(spot.pos + Vector2(0, -16), i, c)
		# 路标石上对应的符文，碰过的会暗下去
		_draw_rune(marker_pos + Vector2((i - 1) * 16, -44), i, c)


## 三个简单的符文：一根竖笔加不同的斜笔
func _draw_rune(p: Vector2, kind: int, c: Color) -> void:
	draw_line(p + Vector2(0, -10), p + Vector2(0, 10), c, 2.5)
	match kind:
		0:  # ᚠ
			draw_line(p + Vector2(0, -4), p + Vector2(7, -10), c, 2.5)
			draw_line(p + Vector2(0, 2), p + Vector2(7, -4), c, 2.5)
		1:  # ᚱ
			draw_line(p + Vector2(0, -10), p + Vector2(7, -4), c, 2.5)
			draw_line(p + Vector2(7, -4), p + Vector2(0, 1), c, 2.5)
			draw_line(p + Vector2(0, 1), p + Vector2(7, 10), c, 2.5)
		_:  # ᛏ
			draw_line(p + Vector2(0, -10), p + Vector2(-7, -3), c, 2.5)
			draw_line(p + Vector2(0, -10), p + Vector2(7, -3), c, 2.5)
