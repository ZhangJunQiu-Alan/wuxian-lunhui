class_name FishingQuest
extends SideQuest
## 隐藏支线「遗落的鱼竿」（冰湖）：托尔曾在这里钓过尘世巨蟒，冰洞边还插着一根鱼竿
## 守在冰洞旁累计 20 秒，冰下的动静会把怪物引过来。钓完随机钓上一样东西
## 信仰托尔时，钓上巨蟒鳞片的几率翻倍

const HOLE := preload("res://assets/sprites/quests/ice_fishing_hole.png")  # 冰洞和插在旁边的鱼竿
const ZONE_RADIUS := 70.0
const HOLD_TIME := 20.0
const WAVE_EVERY := 5.0
const WAVE := ["draugr", "draugr", "ice_spirit", "draugr", "draugr", "ice_spirit"]
const CATCH_WEIGHTS := {"fish": 35, "purse": 30, "chest": 25, "scale": 10}

var _held := 0.0
var _wave_timer := 1.0


func _init() -> void:
	title = "遗落的鱼竿"
	offer_text = "【主神】发现隐藏支线：遗落的鱼竿。守在冰洞旁，看看能钓上什么"
	hint_text = "【主神】冰湖的冰面下，似乎有什么东西在动"
	time_limit = 50.0
	color = Color(0.5, 0.85, 0.95)
	is_hidden = true


func _hidden_spot() -> Vector2:
	return landmark.pos + Vector2(-120, 60)


func _on_update(delta: float) -> void:
	if _in_zone():
		_held += delta
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_EVERY
		for i in WAVE.size():
			game.spawn_enemy(WAVE[i], Game.clamp_to_map(marker_pos + Vector2.from_angle(TAU * i / WAVE.size() + _time) * 340.0, 40.0))
	objective = "守在冰洞旁  %d / %d 秒" % [int(_held), int(HOLD_TIME)]
	if _held >= HOLD_TIME:
		complete(true)


func _in_zone() -> bool:
	return player.global_position.distance_to(marker_pos) < ZONE_RADIUS


func _reward() -> String:
	var weights := CATCH_WEIGHTS.duplicate()
	if player.faith.has("thor"):
		weights.scale *= 2
	FxLayer.burst(marker_pos, color, 24, 200.0)
	match game._pick_weighted(weights):
		"fish":
			player.heal(player.max_hp)
			game.add_reward_points(50)
			return "钓上来一条冻僵的大鱼！生命全部恢复，奖励点 +50"
		"purse":
			game.add_reward_points(150)
			return "钓上来一个沉在湖底的钱袋！奖励点 +150"
		"chest":
			game.queue_reward("冰封的宝箱！选择一项奖励")
			return "钓上来一只冰封的宝箱！额外一次升级"
	game.add_story_points(1)
	game.add_reward_points(50)
	return "钓上来一片尘世巨蟒的鳞片！支线剧情点 +1，奖励点 +50"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if not _in_zone():
		targets.append(marker_pos)
	return targets


func _draw_quest() -> void:
	var p := marker_pos
	if state == "active":
		var inside := _in_zone()
		draw_circle(p, ZONE_RADIUS, Color(color, 0.1 if inside else 0.04))
		draw_arc(p, ZONE_RADIUS, 0.0, TAU, 48, Color(color, 0.8 if inside else 0.4), 3.0)
		draw_arc(p, ZONE_RADIUS + 8.0, -PI / 2, -PI / 2 + TAU * _held / HOLD_TIME, 48, Color(0.85, 0.95, 1.0), 4.0)
	draw_texture(HOLE, p - Vector2(32, 34))
