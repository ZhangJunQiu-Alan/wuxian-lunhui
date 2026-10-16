class_name ArcaneNova
extends Node2D
## 法师的奥术新星：以自身为中心向外扩散的魔法环，经过的敌人受到伤害并被强力击退
## 每个敌人每一圈新星只会被打中一次

const EXPAND_TIME := 0.35
const KNOCKBACK := 420.0
const COLOR := Color(0.65, 0.55, 1.0)

var damage := 12.0
var cooldown := 1.3
var radius := 170.0
var echo := false  # 双重新星：每次释放后 0.3 秒再放一圈
var player: Player
var _timer := 0.5
var _waves := []  # 正在扩散的环：t（已扩散时间）、hit（已命中的敌人 id）


func _ready() -> void:
	player = get_parent() as Player
	show_behind_parent = true


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 and _enemy_in_range():
		_timer = cooldown * player.cooldown_mult
		_waves.append({"t": 0.0, "hit": {}})
		player.play_attack(player.facing, 0.0, _timer)
		if echo:
			_waves.append({"t": -0.3, "hit": {}})  # 负数表示延迟出发

	var dmg := damage * player.damage_mult
	for wave in _waves:
		wave.t += delta
		if wave.t <= 0.0:
			continue
		var r := radius * minf(1.0, wave.t / EXPAND_TIME)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			var id := enemy.get_instance_id()
			var offset := enemy.global_position - global_position
			if offset.length() - enemy.radius <= r and not wave.hit.has(id):
				wave.hit[id] = true
				enemy.take_damage(dmg, offset.normalized() * KNOCKBACK)
	_waves = _waves.filter(func(w: Dictionary) -> bool: return w.t < EXPAND_TIME + 0.15)
	queue_redraw()


func _enemy_in_range() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if (node as Node2D).global_position.distance_to(global_position) < radius:
			return true
	return false


func _draw() -> void:
	for wave in _waves:
		if wave.t <= 0.0:
			continue
		var k := minf(1.0, wave.t / EXPAND_TIME)
		var r := radius * k
		var alpha := 1.0 - maxf(0.0, wave.t - EXPAND_TIME) / 0.15
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(COLOR, 0.9 * alpha), 6.0 * (1.0 - k) + 2.0)
		draw_circle(Vector2.ZERO, r, Color(COLOR, 0.08 * alpha))
