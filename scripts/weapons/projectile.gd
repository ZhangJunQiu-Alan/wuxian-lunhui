class_name Projectile
extends Area2D
## 通用飞行子弹：直线飞行，碰到敌人造成伤害，穿透次数用完或超时后消失

var direction := Vector2.RIGHT
var speed := 500.0
var damage := 10.0
var pierce := 1
var lifetime := 2.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # 只检测敌人层
	rotation = direction.angle()

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var enemy := area as Enemy
	if enemy == null or pierce <= 0:
		return
	enemy.take_damage(damage, direction * 120.0)
	pierce -= 1
	if pierce <= 0:
		queue_free()


func _draw() -> void:
	var pts := PackedVector2Array([Vector2(10, 0), Vector2(0, 4), Vector2(-8, 0), Vector2(0, -4)])
	draw_colored_polygon(pts, Color(0.55, 0.9, 1.0))
