class_name RavensQuest
extends SideQuest
## 支线「奥丁的渡鸦」：奥丁的两只渡鸦福金（思想）与雾尼（记忆）在风雪中迷路了，限时找到它们
## 渡鸦受了惊吓：要在它身边停留 3 秒安抚它（离开就前功尽弃），同时守在旁边的冬狼会围攻你
## 奖励：支线剧情点 +1，奖励点 +80；信仰奥丁时额外获得一次升级选择，否则大招能量 +50%

const CALM_DISTANCE := 60.0
const CALM_TIME := 3.0
const GUARDS := 6

var _ravens: Array[Dictionary] = []


func _init() -> void:
	title = "奥丁的渡鸦"
	offer_text = "【主神】支线剧情：奥丁的渡鸦在风雪中迷路了"
	time_limit = 45.0
	color = Color(0.75, 0.6, 1.0)


func _on_accept() -> void:
	var base := randf() * TAU
	for i in 2:
		var pos := marker_pos + Vector2.from_angle(base + PI * i + randf_range(-0.6, 0.6)) * randf_range(600.0, 850.0)
		pos = Game.clamp_to_map(pos, 120.0)
		_ravens.append({"name": ["福金（思想）", "雾尼（记忆）"][i], "pos": pos, "found": false, "calm": 0.0})
		for g in GUARDS:
			game.spawn_enemy("wolf", pos + Vector2.from_angle(TAU * g / GUARDS) * 90.0)


func _on_update(delta: float) -> void:
	var found := 0
	for raven in _ravens:
		if raven.found:
			found += 1
			continue
		if player.global_position.distance_to(raven.pos) < CALM_DISTANCE:
			raven.calm += delta
		else:
			raven.calm = 0.0  # 离开就要重新安抚
		if raven.calm >= CALM_TIME:
			raven.found = true
			FxLayer.burst(raven.pos, color, 20, 180.0)
			FxLayer.floating_text(raven.pos + Vector2(0, -30), "找到了" + raven.name, color)
			found += 1
	objective = "安抚奥丁的渡鸦  %d / 2" % found
	if found == 2:
		complete(true)


func _reward() -> String:
	game.add_reward_points(80)
	game.add_story_points(1)
	if player.faith.has("odin"):
		game.queue_reward("奥丁的赏赐！选择一项奖励")
		return "支线剧情点 +1，奖励点 +80，奥丁的赏赐（额外一次升级）"
	player.add_ult_energy(player.ult_cost * 0.5)
	return "支线剧情点 +1，奖励点 +80，大招能量 +50%"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for raven in _ravens:
		if not raven.found:
			targets.append(raven.pos)
	return targets


func _draw_quest() -> void:
	for raven in _ravens:
		if raven.found:
			continue
		var p: Vector2 = raven.pos
		var flap := sin(_time * 10.0) * 6.0
		draw_circle(p, 22.0, Color(color, 0.15))
		draw_arc(p, CALM_DISTANCE, 0.0, TAU, 32, Color(color, 0.4), 2.0)
		if raven.calm > 0.0:  # 安抚进度环
			draw_arc(p, CALM_DISTANCE + 6.0, -PI / 2, -PI / 2 + TAU * raven.calm / CALM_TIME, 32, color, 4.0)
		# 黑色渡鸦：身体 + 两只扇动的翅膀
		draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -4 - flap), p + Vector2(0, 2), p + Vector2(-4, 6)]), Color(0.08, 0.08, 0.12))
		draw_colored_polygon(PackedVector2Array([p + Vector2(16, -4 - flap), p + Vector2(0, 2), p + Vector2(4, 6)]), Color(0.08, 0.08, 0.12))
		draw_circle(p + Vector2(0, 3), 5.0, Color(0.1, 0.1, 0.14))
