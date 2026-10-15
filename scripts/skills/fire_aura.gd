class_name FireAura
extends Node2D
## 洛基·诡火：玩家周围的火焰光环，每隔一小段时间灼烧范围内所有敌人

const TICK := 0.5

var radius := 80.0
var damage := 6.0
var player: Player
var _timer := 0.0
var _time := 0.0


func _ready() -> void:
	player = get_parent() as Player
	show_behind_parent = true  # 画在玩家身体下面


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	Enemy.damage_in_radius(get_tree(), global_position, radius, damage * player.damage_mult)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.4, 0.1, 0.10 + 0.05 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.55, 0.15, 0.5 + 0.3 * pulse), 2.0)
