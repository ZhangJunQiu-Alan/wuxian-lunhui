class_name EmberQuest
extends SideQuest
## 支线「太阳的余烬」（十字路口 → 符文石阵）：斯库尔追咬太阳时掉下一块余烬，把它送到符文石阵的祭坛
## 拿着余烬移速 -20%，狼群闻着光围过来（一半从前方包抄）；受伤时余烬会掉在地上，要回去捡（掉下后 1 秒内捡不起来）
## 奖励：大招能量充满，奖励点 +100

const PICKUP := 30.0
const ALTAR_RADIUS := 70.0
const CARRY_SPEED := 0.8
const DROP_COOLDOWN := 1.0
const WAVE_EVERY := 5.0
const WAVE_SIZE := 5

var _carried := true
var _ember := Vector2.ZERO
var _cooldown := 0.0
var _altar := Vector2.ZERO
var _last_hp := 0.0
var _wave_timer := 2.0


func _init() -> void:
	title = "太阳的余烬"
	offer_text = "【主神】支线剧情：斯库尔咬下了一块太阳的余烬。把它送到符文石阵的祭坛"
	time_limit = 45.0
	color = Color(1.0, 0.75, 0.35)


func _on_accept() -> void:
	_altar = game.landmark_by_id("stones").get("pos", Vector2.ZERO)
	_last_hp = player.hp
	player.hp_changed.connect(_on_hp_changed)


func _on_hp_changed(hp: float, _max_hp: float) -> void:
	if hp < _last_hp - 0.01 and _carried:
		_carried = false
		_ember = player.global_position
		_cooldown = DROP_COOLDOWN
		FxLayer.burst(_ember, color, 14, 140.0)
		FxLayer.floating_text(_ember + Vector2(0, -40), "余烬掉了", color)
	_last_hp = hp


func _on_update(delta: float) -> void:
	if _carried:
		_ember = player.global_position
		player.speed_mult = CARRY_SPEED
		if player.global_position.distance_to(_altar) < ALTAR_RADIUS:
			FxLayer.burst(_altar, color, 40, 260.0, 4.0)
			complete(true)
			return
	else:
		player.speed_mult = 1.0
		_cooldown -= delta
		if _cooldown <= 0.0 and player.global_position.distance_to(_ember) < PICKUP:
			_carried = true
	_wave_timer -= delta
	if _wave_timer <= 0.0:  # 狼群闻着光围过来：冬狼比拿着余烬的你慢，所以一半从前方包抄
		_wave_timer = WAVE_EVERY
		var ahead := _ember.direction_to(_altar).angle()
		for i in WAVE_SIZE:
			var angle := ahead + randf_range(-0.6, 0.6) if i % 2 == 0 else randf() * TAU
			game.spawn_enemy("wolf", Game.clamp_to_map(_ember + Vector2.from_angle(angle) * 420.0, 40.0))
	if _carried:
		objective = "把余烬送到符文石阵  还有 %d 米" % ceili(player.global_position.distance_to(_altar) / 20.0)
	else:
		objective = "余烬掉了！回去捡起来"


func _on_end() -> void:
	player.speed_mult = 1.0
	if player.hp_changed.is_connected(_on_hp_changed):
		player.hp_changed.disconnect(_on_hp_changed)


func _reward() -> String:
	player.add_ult_energy(player.ult_cost)
	game.add_reward_points(100)
	return "太阳的力量：大招能量充满，奖励点 +100"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = [_altar if _carried else _ember]
	return targets


func _draw_quest() -> void:
	if state != "active":
		return
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_circle(_altar, ALTAR_RADIUS, Color(color, 0.05 + 0.05 * pulse))
	draw_arc(_altar, ALTAR_RADIUS, 0.0, TAU, 48, Color(color, 0.5), 3.0)
	if not _carried:
		_draw_ember(self, _ember + Vector2(0, -6))


## 拿着时余烬浮在头顶，画在角色上面
func _draw_overlay() -> void:
	if state == "active" and _carried:
		_draw_ember(overlay, player.global_position + Vector2(0, -46 + 3.0 * sin(_time * 5.0)))


func _draw_ember(canvas: CanvasItem, p: Vector2) -> void:
	var flicker := 0.8 + 0.2 * sin(_time * 13.0)
	canvas.draw_circle(p, 20.0 * flicker, Color(color, 0.18))
	canvas.draw_circle(p, 9.0, Color(1.0, 0.6, 0.2))
	canvas.draw_circle(p, 5.0 * flicker, Color(1.0, 0.95, 0.7))
