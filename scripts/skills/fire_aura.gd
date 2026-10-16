class_name FireAura
extends Node2D
## 洛基·诡火：玩家周围的火焰光环，每隔一小段时间灼烧范围内所有敌人

const TICK := 0.5
const AURA := preload("res://assets/sprites/effects/will_o_wisp_aura.png")
const AURA_RADIUS := 60.0  # 素材里火环的半径，按光环范围缩放

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
	draw_circle(Vector2.ZERO, radius, Color(0.3, 1.0, 0.75, 0.06))
	SpriteVisual.draw_frame(self, AURA, 4, int(_time * 8.0), Vector2.ZERO, Vector2(64, 64), 0.0, Vector2.ONE * radius / AURA_RADIUS)
