class_name CombatFx

const ROOT := "res://assets/sprites/effects/"
const ART := {
	"dimension_cut": {"path": "ultimates/", "size": Vector2(128, 32)},
	"west_star": {"path": "ultimates/", "size": Vector2(32, 32)},
	"west_aura": {"path": "ultimates/", "size": Vector2(96, 96), "fps": 8.0, "loop": true},
	"formation_cavalry": {"path": "ultimates/", "size": Vector2(96, 64), "frames": 6, "fps": 8.0, "loop": true, "anchor": Vector2(48, 62)},
	"formation_slash": {"path": "ultimates/", "size": Vector2(64, 32)},
	"stonehenge_stone": {"path": "ultimates/", "size": Vector2(48, 64), "frames": 1, "anchor": Vector2(24, 62)},
	"stonehenge_lintel": {"path": "ultimates/", "size": Vector2(64, 24), "frames": 1, "anchor": Vector2(32, 15)},
	"stonehenge_circle": {"path": "ultimates/", "size": Vector2(128, 128), "frames": 1},
	"blades_slash": {"path": "", "size": Vector2(64, 64)},
	"arcane_nova": {"path": "", "size": Vector2(128, 128)},
	"hit_claw": {"path": "", "size": Vector2(32, 32)},
	"hit_bite": {"path": "", "size": Vector2(64, 64)},
	"death_shards": {"path": "", "size": Vector2(32, 32)},
	"loki_wolf_breath": {"path": "gods/", "size": Vector2(96, 64), "anchor": Vector2(4, 32)}
}

static var _textures: Dictionary = {}


static func texture(id: String) -> Texture2D:
	if not ART.has(id):
		return null
	if not _textures.has(id):
		var path: String = ROOT + ART[id].path + id + ".png"
		_textures[id] = load(path) if ResourceLoader.exists(path) else null
	return _textures[id]


static func frame_index(id: String, age: float) -> int:
	var count: int = ART[id].get("frames", 4)
	var frame := int(maxf(0.0, age) * ART[id].get("fps", 16.0))
	return posmod(frame, count) if ART[id].get("loop", false) else mini(count - 1, frame)


static func sector(center: Vector2, radius: float, angle: float, half: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var full := half >= PI
	if not full:
		points.append(center)
	var steps := maxi(8, ceili(64.0 * half / PI))
	for i in range(steps + (0 if full else 1)):
		points.append(center + Vector2.from_angle(angle - half + 2.0 * half * i / steps) * radius)
	return points


static func draw(canvas: CanvasItem, id: String, age: float, pos: Vector2 = Vector2.ZERO,
		rot: float = 0.0, scale: Vector2 = Vector2.ONE, tint: Color = Color.WHITE,
		clip_radius: float = 0.0, clip_half: float = PI, clip_angle: float = INF) -> bool:
	var strip := texture(id)
	if strip == null:
		return false
	if is_zero_approx(scale.x) or is_zero_approx(scale.y):
		return true
	var spec: Dictionary = ART[id]
	var size: Vector2 = spec.size
	var count: int = spec.get("frames", 4)
	var pivot: Vector2 = spec.get("anchor", size * 0.5)
	var frame := frame_index(id, age)
	if clip_radius <= 0.0:
		SpriteVisual.draw_frame(canvas, strip, count, frame, pos, pivot, rot, scale, tint)
		return true
	var quad := PackedVector2Array()
	for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		quad.append(pos + ((corner - pivot) * scale).rotated(rot))
	var mask := sector(pos, clip_radius, rot if is_inf(clip_angle) else clip_angle, clip_half)
	for polygon in Geometry2D.intersect_polygons(quad, mask):
		var uv := PackedVector2Array()
		for point in polygon:
			var local: Vector2 = (point - pos).rotated(-rot) / scale + pivot
			uv.append((local + Vector2(frame * size.x, 0)) / strip.get_size())
		canvas.draw_polygon(polygon, PackedColorArray([tint]), uv, strip)
	return true
