class_name BonfireQuest
extends SideQuest
## 支线「最后的篝火」：村庄里还有幸存者。守在篝火旁累计 45 秒，期间亡者会一波波围上来
## 奖励：奖励点 +100，生命全部恢复

const CAMPFIRE := preload("res://assets/sprites/quests/campfire.png")  # 4 帧火焰循环
const ZONE_RADIUS := 150.0
const HOLD_TIME := 45.0
const WAVE_EVERY := 6.0
const WAVE_SIZE := 8

var _held := 0.0
var _wave_timer := 2.0


func _init() -> void:
	title = tr("最后的篝火")
	offer_text = tr("【主神】支线剧情：村庄里还有幸存者。前往篝火，守护他们")
	time_limit = 90.0
	color = Color(1.0, 0.6, 0.25)


func _on_update(delta: float) -> void:
	if _player_in_zone():
		_held += delta
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_EVERY
		for i in WAVE_SIZE:  # 一圈亡者从四面八方围向篝火
			game.spawn_enemy("draugr", marker_pos + Vector2.from_angle(TAU * i / WAVE_SIZE) * 320.0)
	objective = tr("守在篝火旁  %d / %d 秒") % [int(_held), int(HOLD_TIME)]
	if _held >= HOLD_TIME:
		complete(true)


func _player_in_zone() -> bool:
	return player.global_position.distance_to(marker_pos) < ZONE_RADIUS


func _reward() -> String:
	game.add_reward_points(100)
	player.heal(player.max_hp)
	return tr("奖励点 +100，生命全部恢复")


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if not _player_in_zone():  # 离开篝火范围时，箭头指回篝火
		targets.append(marker_pos)
	return targets


func _draw_quest() -> void:
	if state == "active":
		var inside := _player_in_zone()
		draw_circle(marker_pos, ZONE_RADIUS, Color(color, 0.12 if inside else 0.05))
		draw_arc(marker_pos, ZONE_RADIUS, 0.0, TAU, 64, Color(color, 0.8 if inside else 0.4), 3.0)
		# 进度环
		draw_arc(marker_pos, ZONE_RADIUS + 8.0, -PI / 2, -PI / 2 + TAU * _held / HOLD_TIME, 64, Color(1.0, 0.9, 0.5), 4.0)
	SpriteVisual.draw_frame(self, CAMPFIRE, 4, int(_time * 8.0), marker_pos + Vector2(0, 12), Vector2(32, 62))
	# 围着篝火的幸存者
	for i in 4:
		draw_circle(marker_pos + Vector2.from_angle(TAU * i / 4 + 0.4) * 34.0, 6.0, Color(0.85, 0.75, 0.6))
