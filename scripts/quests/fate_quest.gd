class_name FateQuest
extends SideQuest
## 支线「命运之线」（十字路口）：命运三女神诺伦在路口纺线。接受后身边垂下三条命运之线，走进其中一条就选定了它
## 灰线一定会出现（什么代价也没有），另外两条从金、银、黑、白里随机。30 秒内不选，诺伦就把线收走了
## 只有金线是试炼（撑过 60 秒），其他线选了马上生效

const BALLS := {
	"gold": preload("res://assets/sprites/quests/fate_thread_gold.png"), "silver": preload("res://assets/sprites/quests/fate_thread_silver.png"), "black": preload("res://assets/sprites/quests/fate_thread_black.png"),
	"white": preload("res://assets/sprites/quests/fate_thread_white.png"), "grey": preload("res://assets/sprites/quests/fate_thread_gray.png"),
}
const TOUCH := 30.0
const SPACING := 120.0
const THREADS := {
	"gold": {"name": "金线 · 荣耀", "desc": "60 秒内敌人翻倍\n撑过去奖励点 +200", "color": Color(1.0, 0.82, 0.3)},
	"silver": {"name": "银线 · 以血换力", "desc": "失去 40% 当前生命\n立刻获得一次升级", "color": Color(0.85, 0.88, 0.95)},
	"black": {"name": "黑线 · 向死而生", "desc": "本局最大生命 -25%\n获得一次复活", "color": Color(0.55, 0.4, 0.7)},
	"white": {"name": "白线 · 远见", "desc": "本局经验 -20%\n升级选项 +1", "color": Color(0.95, 0.97, 1.0)},
	"grey": {"name": "灰线 · 平静", "desc": "什么也不发生\n奖励点 +60", "color": Color(0.6, 0.62, 0.66)},
}
const GOLD_TIME := 60.0
const GOLD_SPAWN := 2.0

var _options: Array[String] = []
var _spots: Array[Vector2] = []
var _chosen := ""
var _font: Font


func _init() -> void:
	title = "命运之线"
	offer_text = "【主神】支线剧情：命运三女神在十字路口纺线。去选一条你的命运"
	time_limit = 30.0
	color = Color(0.85, 0.75, 1.0)
	var custom: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	_font = load(custom) if custom != "" else ThemeDB.fallback_font


func _on_accept() -> void:
	var others := ["gold", "silver", "black", "white"]
	others.shuffle()
	_options.assign(["grey", others[0], others[1]])
	_options.shuffle()
	for i in _options.size():
		_spots.append(MapLayer.push_out(marker_pos + Vector2((i - 1) * SPACING, -90.0), Player.RADIUS + 6.0))


func _on_update(_delta: float) -> void:
	if _chosen == "":
		objective = "走进一条命运之线"
		for i in _options.size():
			if player.global_position.distance_to(_spots[i]) < TOUCH:
				_choose(_options[i])
				return
		return
	# 只有金线会走到这里：荣耀试炼
	objective = "荣耀试炼：撑过去"
	if time_left <= 0.0:
		complete(true)


func _choose(id: String) -> void:
	_chosen = id
	FxLayer.burst(player.global_position, THREADS[id].color, 30, 220.0)
	match id:
		"gold":
			game.spawn_mult = GOLD_SPAWN
			time_left = GOLD_TIME
			return
		"silver":
			player.hp = maxf(1.0, player.hp * 0.6)
			player.hp_changed.emit(player.hp, player.max_hp)
		"black":
			player.max_hp *= 0.75
			player.hp = minf(player.hp, player.max_hp)
			player.hp_changed.emit(player.hp, player.max_hp)
			player.revives += 1
		"white":
			player.xp_mult *= 0.8
			player.choice_count += 1
	complete(true)


func _on_end() -> void:
	if _chosen == "gold":
		game.spawn_mult = 1.0


func _reward() -> String:
	match _chosen:
		"gold":
			game.add_reward_points(200)
			return "荣耀试炼完成，奖励点 +200"
		"silver":
			game.queue_reward("银线的力量！选择一项奖励")
			return "以血换力：额外一次升级"
		"black":
			return "向死而生：获得一次复活"
		"white":
			return "远见：本局升级选项 +1"
	game.add_reward_points(60)
	return "平静：奖励点 +60"


func _active_targets() -> Array[Vector2]:
	if _chosen == "" and player.global_position.distance_to(marker_pos) > 300.0:
		var targets: Array[Vector2] = [marker_pos]
		return targets
	return []


## 三条从天上垂下来的线，下端是一个线团
func _draw_quest() -> void:
	if state != "active" or _chosen != "":
		return
	for i in _options.size():
		var c: Color = THREADS[_options[i]].color
		var bottom := _spots[i]
		var points := PackedVector2Array()
		for k in 13:
			var y := -160.0 + k * 160.0 / 12.0
			points.append(bottom + Vector2(sin(_time * 2.0 + k * 0.6 + i) * 4.0 * (1.0 - k / 12.0), y))
		draw_polyline(points, Color(c, 0.8), 2.0)
		draw_circle(bottom, TOUCH, Color(c, 0.08))
		draw_texture(BALLS[_options[i]], bottom - Vector2(8, 8))  # 线垂下来，底端是线团


func _draw_overlay() -> void:
	if state != "active" or _chosen != "":
		return
	for i in _options.size():
		var thread: Dictionary = THREADS[_options[i]]
		var at := _spots[i] + Vector2(-SPACING / 2.0, 30.0)
		overlay.draw_string_outline(_font, at, thread.name, HORIZONTAL_ALIGNMENT_CENTER, SPACING, 14, 4, Color(0, 0, 0, 0.8))
		overlay.draw_string(_font, at, thread.name, HORIZONTAL_ALIGNMENT_CENTER, SPACING, 14, thread.color)
		var line_y := 18.0
		for line: String in thread.desc.split("\n"):
			overlay.draw_string_outline(_font, at + Vector2(0, line_y), line, HORIZONTAL_ALIGNMENT_CENTER, SPACING, 11, 3, Color(0, 0, 0, 0.8))
			overlay.draw_string(_font, at + Vector2(0, line_y), line, HORIZONTAL_ALIGNMENT_CENTER, SPACING, 11, Color(1, 1, 1, 0.85))
			line_y += 14.0
