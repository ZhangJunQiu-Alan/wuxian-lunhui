class_name QuestPointer
extends Control
## 屏幕边缘的箭头：目标在屏幕外时，在屏幕边缘画一个指向它的箭头

const MARGIN := 36.0

var targets: Array = []  # 每项是 [世界坐标, 颜色]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	var center := screen / 2.0
	var to_screen := get_viewport().get_canvas_transform()  # 世界坐标 → 屏幕坐标（包含镜头位置）
	for target: Array in targets:
		var p: Vector2 = to_screen * (target[0] as Vector2)
		var color: Color = target[1]
		if Rect2(Vector2.ZERO, screen).grow(-MARGIN).has_point(p):
			continue  # 目标就在屏幕里，不用画箭头
		var dir := (p - center).normalized()
		# 从屏幕中心沿方向走，直到碰到留了边距的屏幕边框
		var half := center - Vector2(MARGIN, MARGIN)
		var t := minf(absf(half.x / dir.x) if dir.x != 0.0 else INF, absf(half.y / dir.y) if dir.y != 0.0 else INF)
		var tip := center + dir * t
		var side := dir.orthogonal() * 10.0
		draw_colored_polygon(PackedVector2Array([tip + dir * 14.0, tip + side, tip - side]), color)
		draw_circle(tip, 4.0, color)
