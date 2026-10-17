class_name EinherjarQuest
extends SideQuest
## 隐藏支线「沉睡的英灵」（墓丘）：墓丘群里有一座始终没有裂开，里面睡着一位英灵
## 依次在 3 块墓碑前各停留 2 秒唤醒他（中途离开，这一块要重来），期间亡者从墓里爬出来
## 奖励：奖励点 +50，英灵醒来跟着你作战 60 秒

const DORMANT := preload("res://assets/sprites/quests/tombstone_dormant.png")
const AWAKENED := preload("res://assets/sprites/quests/tombstone_awakened.png")
const STAND_DISTANCE := 50.0
const STAND_TIME := 2.0
const WAVE_EVERY := 6.0
const WAVE_SIZE := 5

var _stones: Array[Vector2] = []
var _lit := 0      # 已经唤醒的墓碑数
var _stand := 0.0  # 当前这块墓碑停留了多久
var _wave_timer := 2.0


func _init() -> void:
	title = tr("沉睡的英灵")
	offer_text = tr("【主神】发现隐藏支线：沉睡的英灵。依次唤醒三块墓碑")
	hint_text = tr("【主神】墓丘之中，有一座始终没有裂开")
	time_limit = 45.0
	color = Color(1.0, 0.82, 0.5)
	is_hidden = true


func _hidden_spot() -> Vector2:
	var c: Vector2 = landmark.pos
	_stones = [c + Vector2(0, -230), c + Vector2(-250, -90), c + Vector2(250, -90)]
	return _stones[0]


func _on_update(delta: float) -> void:
	var stone := _stones[_lit]
	if player.global_position.distance_to(stone) < STAND_DISTANCE:
		_stand += delta
	else:
		_stand = 0.0
	if _stand >= STAND_TIME:
		FxLayer.burst(stone, color, 18, 160.0)
		_lit += 1
		_stand = 0.0
		if _lit == _stones.size():
			complete(true)
			return
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_EVERY
		for i in WAVE_SIZE:
			game.spawn_enemy("draugr", Game.clamp_to_map(stone + Vector2.from_angle(TAU * i / WAVE_SIZE + _time) * 260.0, 40.0))
	objective = tr("唤醒墓碑  %d / %d") % [_lit, _stones.size()]


func _reward() -> String:
	game.add_reward_points(50)
	var ally := Einherjar.new()
	ally.player = player
	ally.power = 1.0 + game.elapsed / game.level_data.hp_growth
	ally.position = _stones[0]
	game.add_child(ally)
	return tr("奖励点 +50，英灵与你并肩作战 60 秒")


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if _lit < _stones.size():
		targets.append(_stones[_lit])
	return targets


func _draw_quest() -> void:
	for i in (_stones.size() if state == "active" else 1):  # 接受之前只露出第一块
		var p := _stones[i]
		var lit := i < _lit
		var current := state == "active" and i == _lit
		# 墓碑：圆顶的灰色石板，唤醒后发出金光
		if lit or current:
			draw_circle(p + Vector2(0, -12), 22.0, Color(color, 0.25 if lit else 0.1))
		draw_texture(AWAKENED if lit else DORMANT, p - Vector2(16, 46))
		if current:
			draw_arc(p, STAND_DISTANCE, 0.0, TAU, 32, Color(color, 0.5), 2.0)
			draw_arc(p, STAND_DISTANCE + 6.0, -PI / 2, -PI / 2 + TAU * _stand / STAND_TIME, 32, color, 4.0)
