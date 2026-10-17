class_name GodSphere
## 主神：悬在空中的光球，一圈圈光晕缓慢脉动，两道倾斜的光环带着光点转动
## 标题画面和主神空间共用。grow 从 0 到 1 是光球展开的过程，size 是光环半径


static func draw(canvas: CanvasItem, center: Vector2, time: float, grow: float = 1.0, size: float = 230.0) -> void:
	if grow <= 0.0:
		return
	var pulse := 0.5 + 0.5 * sin(time * 1.4)
	var k := size / 230.0
	for i in 7:
		canvas.draw_circle(center, (40.0 + i * 30.0 + pulse * 8.0) * k * grow, Color(1.0, 0.92, 0.75, (0.045 - i * 0.005) * grow))
	for tilt: float in [-0.35, 0.3]:
		canvas.draw_set_transform(center, tilt, Vector2(1.0, 0.28))
		canvas.draw_arc(Vector2.ZERO, size * grow, 0.0, TAU, 96, Color(1.0, 0.88, 0.6, 0.18 * grow), 2.0)
		for n in 6:
			var a := time * (0.35 if tilt > 0 else -0.28) + n * TAU / 6.0
			canvas.draw_circle(Vector2.from_angle(a) * size * grow, 6.0 * k, Color(1.0, 0.9, 0.65, 0.5 * grow))
	canvas.draw_set_transform(Vector2.ZERO)
