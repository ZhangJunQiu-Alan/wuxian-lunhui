class_name Projectile
extends Area2D
## 通用飞行子弹：直线飞行，碰到敌人造成伤害，穿透次数用完或超时后消失

var direction := Vector2.RIGHT
var speed := 500.0
var damage := 10.0
var pierce := 1
var lifetime := 2.0
var crit := false          # 暴击：伤害数字显示为金色
var split_on_hit := false  # 命中后分裂成两发（枪手的纸牌神射）
var color := Color(0.55, 0.9, 1.0)
var size := 1.0
var texture: Texture2D  # 有素材时画素材帧条（朝右），没有就画菱形
var frames := 1
var anchor := Vector2.ZERO
var _time := 0.0


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
	if texture and frames > 1:
		_time += delta
		queue_redraw()
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var enemy := area as Enemy
	if enemy == null or pierce <= 0:
		return
	enemy.take_damage(damage, direction * 120.0, crit)
	if split_on_hit:
		split_on_hit = false
		for angle in [-0.45, 0.45]:  # 向两侧各分出一发，继续飞行
			var shard := Projectile.new()
			shard.global_position = global_position
			shard.direction = direction.rotated(angle)
			shard.speed = speed
			shard.damage = damage * 0.5
			shard.pierce = 1
			shard.lifetime = 0.6
			shard.color = color
			shard.size = 0.7
			get_parent().add_child.call_deferred(shard)
	pierce -= 1
	if pierce <= 0:
		queue_free()


func _draw() -> void:
	if texture:
		SpriteVisual.draw_frame(self, texture, frames, int(_time * 12.0), Vector2.ZERO, anchor, 0.0, Vector2.ONE * size)
		return
	var pts := PackedVector2Array([Vector2(10, 0), Vector2(0, 4), Vector2(-8, 0), Vector2(0, -4)])
	for i in pts.size():
		pts[i] *= size
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.3) if crit else color)
