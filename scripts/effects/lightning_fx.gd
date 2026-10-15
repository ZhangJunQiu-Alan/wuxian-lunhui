class_name LightningFx
extends Node2D
## 闪电特效：一条折线闪电 + 落点的爆炸圈，0.2 秒后消失

const DURATION := 0.2

var from := Vector2.ZERO
var to := Vector2.ZERO
var blast_radius := 0.0
var _points := PackedVector2Array()
var _time := DURATION


static func spawn(parent: Node, from_pos: Vector2, to_pos: Vector2, radius: float) -> void:
	var fx := LightningFx.new()
	fx.from = from_pos
	fx.to = to_pos
	fx.blast_radius = radius
	parent.add_child(fx)


func _ready() -> void:
	z_index = 10  # 画在敌人上面
	# 把直线切成几段，每个中间点随机偏移，形成锯齿状闪电
	var segments := 8
	var normal := (to - from).normalized().orthogonal()
	_points.append(from)
	for i in range(1, segments):
		var p := from.lerp(to, float(i) / segments)
		_points.append(p + normal * randf_range(-14.0, 14.0))
	_points.append(to)


func _process(delta: float) -> void:
	_time -= delta
	if _time <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := _time / DURATION
	draw_polyline(_points, Color(0.6, 0.85, 1.0, alpha), 5.0)
	draw_polyline(_points, Color(1, 1, 1, alpha), 2.0)
	if blast_radius > 0.0:
		draw_circle(to, blast_radius, Color(0.6, 0.85, 1.0, 0.35 * alpha))
