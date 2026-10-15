class_name IcePillar
extends StaticBody2D
## 冰柱：实心障碍物，玩家无法穿过（敌人可以），持续一段时间后碎裂

const RADIUS := 18.0
const COLOR := Color(0.6, 0.88, 1.0)

var _life := 3.0
var _grow := 0.0


## 物理帧中途不能直接添加碰撞体，所以延迟到帧末添加
static func spawn(parent: Node, pos: Vector2, duration: float) -> void:
	var pillar := IcePillar.new()
	pillar.position = pos
	pillar._life = duration
	parent.add_child.call_deferred(pillar)


func _ready() -> void:
	collision_layer = 1  # 和玩家同一层，玩家会被挡住；敌人是 Area2D，不受影响
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)


func _process(delta: float) -> void:
	_grow = minf(1.0, _grow + delta * 8.0)
	_life -= delta
	queue_redraw()
	if _life <= 0.0:
		FxLayer.burst(global_position, COLOR, 8, 120.0)
		queue_free()


func _draw() -> void:
	var r := RADIUS * _grow
	var pts := PackedVector2Array()
	for i in 6:  # 六边形冰晶
		pts.append(Vector2.from_angle(TAU * i / 6.0 + 0.5) * r)
	draw_colored_polygon(pts, COLOR)
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 1, 1, 0.8), 2.0)
