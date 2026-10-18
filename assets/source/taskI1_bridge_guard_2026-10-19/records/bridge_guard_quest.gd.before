class_name BridgeGuardQuest
extends SideQuest
## 支线「守桥人的盘问」：守桥的少女问：「活人为什么要过冥界的桥？」
## 在吉欧尔桥上累计守住 40 秒，亡者从桥两头一波波涌上来
## 奖励：奖励点 +100，一次升级

const HOLD_TIME := 40.0
const WAVE_EVERY := 4.0
const WAVE_SIZE := 6

var _held := 0.0
var _wave_timer := 1.0
var _zone := Rect2()


func _init() -> void:
	title = tr("守桥人的盘问")
	offer_text = tr("【主神】支线剧情：吉欧尔桥的守桥人拦住了你。在桥上证明你的决心")
	time_limit = 70.0
	color = Color(1.0, 0.82, 0.4)


func _ready() -> void:
	super._ready()
	var river: Dictionary = game.level_data.map.river
	var bridge: Vector2 = river.crossings[0]
	_zone = Rect2(bridge.x, river.y - river.half, bridge.y - bridge.x, river.half * 2.0)
	marker_pos = _zone.get_center()


func _on_update(delta: float) -> void:
	if _zone.has_point(player.global_position):
		_held += delta
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_EVERY
		for end in [-1.0, 1.0]:  # 桥的南北两头
			for i in WAVE_SIZE / 2:
				var pos := Vector2(_zone.get_center().x + randf_range(-60, 60), _zone.get_center().y + end * (_zone.size.y / 2.0 + 160.0 + i * 20.0))
				game.spawn_enemy("dead", pos)
	objective = tr("守在桥上  %d / %d 秒") % [int(_held), int(HOLD_TIME)]
	if _held >= HOLD_TIME:
		complete(true)


func _reward() -> String:
	game.add_reward_points(100)
	game.queue_reward(tr("守桥人放行了你！选择一项奖励"))
	return tr("奖励点 +100，一次升级")


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if not _zone.has_point(player.global_position):
		targets.append(_zone.get_center())
	return targets


func _draw_quest() -> void:
	if state == "active":
		var inside := _zone.has_point(player.global_position)
		draw_rect(_zone, Color(color, 0.12 if inside else 0.05))
		draw_rect(_zone, Color(color, 0.8 if inside else 0.4), false, 3.0)
		draw_rect(Rect2(_zone.position + Vector2(0, -12), Vector2(_zone.size.x * _held / HOLD_TIME, 6)), Color(1.0, 0.9, 0.5))
	# 守桥的少女：桥头的金色人影
	var guard := Vector2(_zone.end.x + 34.0, _zone.end.y + 30.0)
	draw_circle(guard + Vector2(0, -26), 6.0, Color(0.95, 0.85, 0.6))
	draw_rect(Rect2(guard + Vector2(-6, -20), Vector2(12, 22)), Color(0.85, 0.7, 0.35))
