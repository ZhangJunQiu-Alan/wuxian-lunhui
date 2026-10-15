class_name EnemyProjectile
extends Node2D
## 敌人发射的子弹（冰锥）：直线飞行，碰到玩家造成伤害

const SPEED := 230.0
const LIFETIME := 4.0
const HIT_RADIUS := 6.0

var direction := Vector2.RIGHT
var damage := 5.0
var _life := LIFETIME
var _player: Player


static func spawn(parent: Node, pos: Vector2, dir: Vector2, dmg: float) -> void:
	var p := EnemyProjectile.new()
	p.position = pos
	p.direction = dir
	p.damage = dmg
	parent.add_child(p)


func _ready() -> void:
	add_to_group("enemy_projectiles")
	rotation = direction.angle()
	_player = get_tree().get_first_node_in_group("player") as Player


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_life -= delta
	if _life <= 0.0 or not is_instance_valid(_player):
		queue_free()
		return
	if global_position.distance_to(_player.global_position) < Player.RADIUS + HIT_RADIUS:
		_player.take_damage(damage)
		queue_free()


func _draw() -> void:
	var pts := PackedVector2Array([Vector2(9, 0), Vector2(-3, 4), Vector2(-7, 0), Vector2(-3, -4)])
	draw_colored_polygon(pts, Color(0.7, 0.92, 1.0))
