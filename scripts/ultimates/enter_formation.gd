class_name EnterFormation
extends Node2D
## 刺客的大招「入阵曲」
## 1. 化为鬼影，无敌，每隔一小段时间瞬移到一个敌人身后斩一刀（最多 15 刀，优先最近的）
## 2. 斩完后，五百骑幻影从屏幕左侧冲锋到右侧，横扫路上所有敌人

const STRIKES := 15
const STRIKE_INTERVAL := 0.22
const STRIKE_DAMAGE := 90.0
const SEARCH_RANGE := 650.0
const CAVALRY_TIME := 1.1
const CAVALRY_DAMAGE := 60.0
const CAVALRY_WIDTH := 90.0
const COLOR := Color(0.9, 0.25, 0.3)

var player: Player
var _phase := "strikes"
var _timer := 0.0
var _strikes_left := STRIKES
var _struck := {}             # 已经斩过的敌人 id，不重复斩
var _trails: Array = []       # 瞬移残影：from、to、life
var _cavalry_t := 0.0
var _cavalry_hit := {}
var _half := Vector2.ZERO
var _center := Vector2.ZERO   # 骑兵冲锋时的屏幕中心（世界坐标）


static func cast(caster: Player) -> void:
	var fx := EnterFormation.new()
	fx.player = caster
	caster.get_parent().add_child(fx)


func _ready() -> void:
	z_index = 15
	_half = get_viewport_rect().size / 2.0
	player.shield_time = STRIKES * STRIKE_INTERVAL + CAVALRY_TIME + 0.5  # 整个大招期间无敌


func _process(delta: float) -> void:
	for trail in _trails:
		trail.life -= delta
	_trails = _trails.filter(func(t: Dictionary) -> bool: return t.life > 0.0)
	queue_redraw()

	match _phase:
		"strikes":
			_timer -= delta
			if _timer > 0.0:
				return
			_timer = STRIKE_INTERVAL
			var target := _next_target()
			if target == null or _strikes_left <= 0:
				_start_cavalry()
				return
			_strike(target)
		"cavalry":
			_cavalry_t += delta
			var x := _cavalry_x()
			for node in get_tree().get_nodes_in_group("enemies"):
				var enemy := node as Enemy
				var id := enemy.get_instance_id()
				var p := enemy.global_position
				if not _cavalry_hit.has(id) and absf(p.x - x) < CAVALRY_WIDTH and absf(p.y - _center.y) < _half.y:
					_cavalry_hit[id] = true
					enemy.take_damage(CAVALRY_DAMAGE * player.damage_mult, Vector2.RIGHT * 500.0)
			if _cavalry_t >= CAVALRY_TIME:
				queue_free()


func _next_target() -> Enemy:
	var best: Enemy = null
	var best_d := SEARCH_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var d := enemy.global_position.distance_to(player.global_position)
		if d < best_d and not _struck.has(enemy.get_instance_id()):
			best_d = d
			best = enemy
	return best


func _strike(enemy: Enemy) -> void:
	_strikes_left -= 1
	_struck[enemy.get_instance_id()] = true
	var from := player.global_position
	var through := (enemy.global_position - from).normalized()
	if through == Vector2.ZERO:
		through = Vector2.RIGHT
	# 穿过敌人，落在它身后
	player.global_position = enemy.global_position + through * (enemy.radius + 20.0)
	_trails.append({"from": from, "to": player.global_position, "life": 0.35})
	enemy.take_damage(STRIKE_DAMAGE * player.damage_mult, through * 200.0, true)
	FxLayer.burst(enemy.global_position, COLOR, 10, 200.0)
	player.shake(3.0, 0.08)


func _start_cavalry() -> void:
	_phase = "cavalry"
	_center = player.global_position
	player.shake(10.0, CAVALRY_TIME)


func _cavalry_x() -> float:
	return _center.x - _half.x - 100.0 + (_half.x * 2.0 + 200.0) * (_cavalry_t / CAVALRY_TIME)


func _draw() -> void:
	for trail in _trails:  # 瞬移的残影：一道红黑色的刀痕
		var a: float = trail.life / 0.35
		draw_line(trail.from, trail.to, Color(0.1, 0.0, 0.0, 0.7 * a), 8.0)
		draw_line(trail.from, trail.to, Color(COLOR, a), 2.0)
	if _phase != "cavalry":
		return
	# 五百骑幻影：一列列向右冲锋的鬼影骑兵
	var x := _cavalry_x()
	var rows := 14
	for i in rows:
		var y := _center.y - _half.y + (_half.y * 2.0) * (i + 0.5) / rows
		var jitter := sin(i * 12.9) * 30.0
		for k in 3:
			var p := Vector2(x + jitter - k * 70.0, y)
			var alpha := 0.55 - k * 0.15
			# 骑兵剪影：马身 + 骑手 + 前伸的长枪
			draw_colored_polygon(PackedVector2Array([p + Vector2(-22, 6), p + Vector2(18, 6), p + Vector2(24, -2), p + Vector2(-16, -4)]), Color(0.25, 0.02, 0.04, alpha))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -4), p + Vector2(4, -4), p + Vector2(2, -18), p + Vector2(-4, -16)]), Color(0.3, 0.02, 0.05, alpha))
			draw_line(p + Vector2(0, -12), p + Vector2(40, -16), Color(COLOR, alpha), 2.0)
	draw_rect(Rect2(x - CAVALRY_WIDTH, _center.y - _half.y, CAVALRY_WIDTH * 2.0, _half.y * 2.0), Color(COLOR, 0.08))
