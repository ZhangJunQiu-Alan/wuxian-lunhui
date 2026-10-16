class_name HoofTracksQuest
extends SideQuest
## 隐藏支线「八足的蹄印」（海拉的大厅门前）：曾有人骑着八足神驹来冥界求海拉放回巴德尔
## 沿着蹄印往回走，限时内捡回 5 枚掉落的马蹄铁
## 奖励：本局移速 +15%，奖励点 +60

const SHOES := 5
const STEP := 260.0
const PICK_DISTANCE := 30.0

var _shoes: Array[Vector2] = []
var _found := 0


func _init() -> void:
	title = "八足的蹄印"
	offer_text = "【主神】隐藏支线：这串蹄印通往冥界之外。沿着它，找回掉落的马蹄铁"
	hint_text = "【主神】大厅门前，有一串不属于这里的马蹄印"
	is_hidden = true
	time_limit = 60.0
	color = Color(0.85, 0.85, 0.75)


func _hidden_spot() -> Vector2:
	return landmark.pos + Vector2(0, 320)


func _on_accept() -> void:
	var at := marker_pos
	var dir := marker_pos.direction_to(Vector2.ZERO)  # 往广场方向蜿蜒
	for i in SHOES:
		dir = dir.rotated(randf_range(-0.6, 0.6))
		at = MapLayer.push_out(Game.clamp_to_map(at + dir * STEP, 60.0), 12.0)
		_shoes.append(at)


func _on_update(_delta: float) -> void:
	for shoe in _shoes:
		if player.global_position.distance_to(shoe) < PICK_DISTANCE + Player.RADIUS:
			_shoes.erase(shoe)
			_found += 1
			FxLayer.burst(shoe, color, 12, 120.0, 3.0)
			Audio.sfx("pickup_xp")
			break
	objective = "找回马蹄铁  %d / %d" % [_found, SHOES]
	if _found >= SHOES:
		complete(true)


func _reward() -> String:
	player.move_speed *= 1.15
	game.add_reward_points(60)
	return "本局移速 +15%，奖励点 +60"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if not _shoes.is_empty():
		targets.append(_shoes[0])
	return targets


func _draw_quest() -> void:
	if state != "active":
		return
	var prev := marker_pos
	for shoe in _shoes:  # 一路的蹄印
		for k in range(1, 6):
			var p := prev.lerp(shoe, k / 6.0)
			draw_circle(p + Vector2(5, 0).rotated(k), 3.0, Color(0.15, 0.13, 0.12, 0.6))
		prev = shoe
		draw_arc(shoe, 9.0, PI * 0.15, PI * 1.85, 12, Color(0.75, 0.72, 0.65), 3.0)
		draw_circle(shoe, 18.0 + sin(_time * 4.0) * 3.0, Color(color, 0.12))
