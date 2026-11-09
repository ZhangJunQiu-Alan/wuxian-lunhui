class_name SwordsmanEffects
extends Node2D

var _events: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func play(id: String, at: Vector2, direction := Vector2.RIGHT, ratio := 1.0, duration := 0.0,
		length := 0.0, follow: Node2D = null, delay := 0.0, mirror := false, opacity := 1.0) -> void:
	var effect: Dictionary = SwordsmanArt.effects()[id]
	var lifetime := duration if duration > 0.0 else float(effect.frames) / float(effect.fps)
	_events.append({"id": id, "at": at - follow.global_position if follow else at, "follow": follow,
		"age": -delay, "duration": lifetime, "angle": direction.angle(), "ratio": ratio,
		"length": length, "mirror": mirror, "opacity": opacity})
	queue_redraw()


func _process(delta: float) -> void:
	for i in range(_events.size() - 1, -1, -1):
		var entry := _events[i]
		entry.age += delta
		if entry.age >= entry.duration:
			_events.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for entry in _events:
		if entry.age < 0.0 or not is_instance_valid(entry.follow) and entry.follow != null:
			continue
		var at: Vector2 = entry.at
		if is_instance_valid(entry.follow):
			at += entry.follow.global_position
		frame_on(self, entry.id, at, entry.age, entry.angle, entry.ratio, entry.length, entry.mirror, entry.opacity)


func frame_on(canvas: Node2D, id: String, at: Vector2, age: float, angle := 0.0, ratio := 1.0, length := 0.0,
		mirror := false, opacity := 1.0) -> void:
	var effect: Dictionary = SwordsmanArt.effects()[id]
	var n := floori(age * float(effect.fps))
	var count := int(effect.frames)
	match effect.play:
		"loop":
			n %= count
		"phased":
			n = 6 + mini(1, floori((age - 3.4) * 16.0)) if age > 3.4 else (2 + (n - 2) % 4 if n >= 2 else n)
		_:
			if n >= count:
				return
	var size := SwordsmanArt.vec(effect.size)
	var anchor := SwordsmanArt.vec(effect.anchor)
	var image := SwordsmanArt.texture("res://assets/" + str(effect.file))
	canvas.draw_set_transform(canvas.to_local(at), angle, Vector2(ratio, -ratio if mirror else ratio))
	var source := Rect2(Vector2(size.x * n, 0), size)
	var color := Color(1, 1, 1, opacity)
	if length > 0.0:
		var step := int(size.x) - 1
		for x in range(0, ceili(length), step):
			var region := source
			region.size.x = minf(size.x, length - x)
			canvas.draw_texture_rect_region(image, Rect2(Vector2(x, 0) - anchor, region.size), region, color)
	else:
		canvas.draw_texture_rect_region(image, Rect2(-anchor, size), source, color)
	canvas.draw_set_transform(Vector2.ZERO)
