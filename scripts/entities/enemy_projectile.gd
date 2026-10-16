class_name EnemyProjectile
extends Node2D
## 敌人发射的子弹（默认冰锥，可以换素材）：直线飞行，碰到玩家造成伤害

const SHARD := preload("res://assets/sprites/effects/ice_shard.png")
const SPEED := 230.0
const LIFETIME := 4.0
const HIT_RADIUS := 6.0

var direction := Vector2.RIGHT
var damage := 5.0
var speed := SPEED
var texture: Texture2D = SHARD  # 为 null 时画一支占位的箭
var tint := Color.WHITE
var _life := LIFETIME
var _player: Player


static func spawn(parent: Node, pos: Vector2, dir: Vector2, dmg: float) -> EnemyProjectile:
	var p := EnemyProjectile.new()
	p.position = pos
	p.direction = dir
	p.damage = dmg
	parent.add_child(p)
	return p


func _ready() -> void:
	add_to_group("enemy_projectiles")
	rotation = direction.angle()
	_player = get_tree().get_first_node_in_group("player") as Player


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life -= delta
	if _life <= 0.0 or not is_instance_valid(_player):
		queue_free()
		return
	if global_position.distance_to(_player.global_position) < Player.RADIUS + HIT_RADIUS:
		_player.take_damage(damage)
		queue_free()


func _draw() -> void:
	if texture:
		draw_texture(texture, -texture.get_size() / 2.0)
	else:
		draw_line(Vector2(-12, 0), Vector2(10, 0), tint, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(14, 0), Vector2(8, -4), Vector2(8, 4)]), tint)
