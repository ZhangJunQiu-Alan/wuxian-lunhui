class_name NailsQuest
extends SideQuest
## 支线「死者的指甲」（墓丘）：亡者之船纳吉尔法尔是用死人的指甲造的，每一片没剪的指甲都会让它早一点完工
## 50 秒内收集 30 片指甲：进行中尸鬼死后会掉一片（精英掉 3 片），8 秒后碎掉；墓丘里每 4 秒爬出一批尸鬼
## 奖励：支线剧情点 +1，奖励点 +80

const NAIL := preload("res://assets/sprites/quests/dead_nail.png")
const GOAL := 30
const PICKUP := 40.0
const NAIL_LIFE := 8.0
const WAVE_EVERY := 4.0
const WAVE_SIZE := 6

var _nails: Array[Dictionary] = []  # {"pos", "life"}
var _got := 0
var _wave_timer := 0.0


func _init() -> void:
	title = "死者的指甲"
	offer_text = "【主神】支线剧情：亡者之船正在用死人的指甲建造。去墓丘收集尸鬼的指甲"
	time_limit = 50.0
	color = Color(0.8, 0.85, 0.7)


func _on_accept() -> void:
	game.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(enemy: Enemy) -> void:
	if enemy.type_id != "draugr":
		return
	for i in 3 if enemy.is_elite else 1:
		_nails.append({"pos": enemy.global_position + Vector2.from_angle(randf() * TAU) * (12.0 * i), "life": NAIL_LIFE})


func _on_update(delta: float) -> void:
	for nail in _nails:
		nail.life -= delta
		if player.global_position.distance_to(nail.pos) < PICKUP:
			nail.life = 0.0
			_got += 1
			FxLayer.burst(nail.pos, color, 6, 90.0, 2.0)
	_nails = _nails.filter(func(nail: Dictionary) -> bool: return nail.life > 0.0)
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_EVERY
		for i in WAVE_SIZE:  # 尸鬼从墓丘里爬出来
			game.spawn_enemy("draugr", Game.clamp_to_map(marker_pos + Vector2.from_angle(TAU * i / WAVE_SIZE + _time) * 280.0, 40.0))
	objective = "收集指甲  %d / %d" % [mini(_got, GOAL), GOAL]
	if _got >= GOAL:
		complete(true)


func _on_end() -> void:
	if game.enemy_killed.is_connected(_on_enemy_killed):
		game.enemy_killed.disconnect(_on_enemy_killed)


func _reward() -> String:
	game.add_reward_points(80)
	game.add_story_points(1)
	return "支线剧情点 +1，奖励点 +80。纳吉尔法尔的完工又推迟了一点"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if player.global_position.distance_to(marker_pos) > 700.0:  # 离墓丘太远时指回墓丘
		targets.append(marker_pos)
	return targets


func _draw_quest() -> void:
	for nail in _nails:
		if nail.life < 2.0 and int(nail.life * 8.0) % 2 == 0:
			continue  # 快碎了：闪烁
		var p: Vector2 = nail.pos
		draw_circle(p, 9.0, Color(color, 0.2))
		draw_texture(NAIL, (p - Vector2(8, 8)).round())
