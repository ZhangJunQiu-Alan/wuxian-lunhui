class_name BossFx

const ROOT := "res://assets/sprites/effects/bosses/"
const FAST := ["skoll_dash_trail", "skoll_bite", "hati_lunge_trail", "hrym_block_spark", "hrym_ice_break", "garm_bite", "garm_chain_break", "nidhogg_poison_breath", "nidhogg_burrow_dust", "nidhogg_emerge_burst", "nidhogg_gnaw_stagger",
	"surtr_sword_arc", "surtr_final_fire", "fire_giant_explosion"]
const STILL := ["garm_chain_link", "hel_life_ground", "hel_death_ground", "surtr_safe_rune", "fenrir_bind_link"]
const MAX_EFFECTS := 96

static var _textures: Dictionary = {}


static func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		var path := ROOT + id + ".png"
		_textures[id] = load(path) if ResourceLoader.exists(path) else null
	return _textures[id]


static func frame_count(id: String) -> int:
	return 1 if id in STILL else 4


static func fps(id: String) -> float:
	return 16.0 if id in FAST else 8.0


static func anchor(id: String, size: Vector2) -> Vector2:
	if id in ["skoll_dash_trail", "hati_lunge_trail"]:
		return Vector2(size.x, size.y * 0.5)
	if id == "nidhogg_poison_breath":
		return Vector2(4, 32)
	if id == "surtr_gate":
		return Vector2(64, 126)
	return size * 0.5


static func play(id: String, pos: Vector2, rot: float = 0.0, scale: Vector2 = Vector2.ONE,
		tint: Color = Color.WHITE, reverse: bool = false, clip_radius: float = 0.0, clip_half: float = PI) -> bool:
	if texture(id) == null or not is_instance_valid(FxLayer.instance):
		return false
	var effects: Array = FxLayer.instance._boss_effects
	if effects.size() >= MAX_EFFECTS:
		effects.pop_front()
	effects.append({"id": id, "pos": pos, "rot": rot, "scale": scale, "tint": tint,
		"reverse": reverse, "radius": clip_radius, "half": clip_half, "age": 0.0,
		"life": frame_count(id) / fps(id)})
	return true


static func draw(canvas: CanvasItem, id: String, age: float, pos: Vector2 = Vector2.ZERO,
		rot: float = 0.0, scale: Vector2 = Vector2.ONE, tint: Color = Color.WHITE,
		reverse: bool = false, clip_radius: float = 0.0, clip_half: float = PI, loop: bool = true) -> bool:
	var strip := texture(id)
	if strip == null:
		return false
	var count := frame_count(id)
	var frame := int(age * fps(id))
	frame = posmod(frame, count) if loop else mini(count - 1, frame)
	if reverse:
		frame = count - 1 - frame
	var size := Vector2(strip.get_width() / count, strip.get_height())
	var pivot := anchor(id, size)
	if clip_radius <= 0.0:
		SpriteVisual.draw_frame(canvas, strip, count, frame, pos, pivot, rot, scale, tint)
		return true
	var quad := PackedVector2Array()
	for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		quad.append(pos + ((corner - pivot) * scale).rotated(rot))
	var mask := sector(pos, clip_radius, rot, clip_half)
	for polygon in Geometry2D.intersect_polygons(quad, mask):
		var uv := PackedVector2Array()
		for point in polygon:
			var local: Vector2 = (point - pos).rotated(-rot) / scale + pivot
			uv.append((local + Vector2(frame * size.x, 0)) / strip.get_size())
		canvas.draw_polygon(polygon, PackedColorArray([tint]), uv, strip)
	return true


static func sector(center: Vector2, radius: float, angle: float, half: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var full := half >= PI
	if not full:
		polygon.append(center)
	var steps := maxi(8, ceili(64.0 * half / PI))
	for i in range(steps + (0 if full else 1)):
		polygon.append(center + Vector2.from_angle(angle - half + 2.0 * half * i / steps) * radius)
	return polygon


static func visible_arcs(gaps: Array[float], half: float) -> Array[Vector2]:
	var arcs: Array[Vector2] = []
	if gaps.is_empty():
		arcs.append(Vector2(0, TAU))
		return arcs
	var sorted: Array[float] = []
	for gap in gaps:
		sorted.append(fposmod(gap, TAU))
	sorted.sort()
	for i in sorted.size():
		var from := sorted[i] + half
		var to := sorted[(i + 1) % sorted.size()] - half
		if i == sorted.size() - 1:
			to += TAU
		if to > from:
			arcs.append(Vector2(from, to))
	return arcs


static func draw_band(canvas: CanvasItem, id: String, age: float, center: Vector2,
		radius: float, width: float, arcs: Array[Vector2], tint: Color = Color.WHITE) -> bool:
	var strip := texture(id)
	if strip == null:
		return false
	var count := frame_count(id)
	var frame := posmod(int(age * fps(id)), count)
	var tile_width := float(strip.get_width()) / count
	var inner := maxf(0.0, radius - width * 0.5)
	var outer := radius + width * 0.5
	for arc in arcs:
		var at := arc.x
		while at < arc.y - 0.00001:
			var tile_start := at
			var tile_end := minf(arc.y, at + tile_width / maxf(1.0, radius))
			var steps := maxi(1, ceili((tile_end - at) * radius / 24.0))
			for i in steps:
				var a := lerpf(tile_start, tile_end, float(i) / steps)
				var b := lerpf(tile_start, tile_end, float(i + 1) / steps)
				var points := PackedVector2Array([center + Vector2.from_angle(a) * outer,
					center + Vector2.from_angle(b) * outer, center + Vector2.from_angle(b) * inner,
					center + Vector2.from_angle(a) * inner])
				var u0 := (frame + (a - tile_start) * radius / tile_width) / count
				var u1 := (frame + (b - tile_start) * radius / tile_width) / count
				canvas.draw_polygon(points, PackedColorArray([tint]),
					PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]), strip)
			at = tile_end
	return true


## 一次画很多个四边形（每 4 个点一个，顺序 a b c d），只提交一条绘制命令。texture 为 null 时画纯色
## 第 3 关的火墙条带、蛇身、终焉之火范围外的红色区域都有几百段，逐段 draw_polygon 在敌人多时很拖帧
static func draw_quads(canvas: CanvasItem, points: PackedVector2Array, uvs: PackedVector2Array, texture: Texture2D, tint: Color = Color.WHITE) -> void:
	if points.size() < 4:
		return
	var indices := PackedInt32Array()
	for q in points.size() / 4:
		var i := q * 4
		indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])
	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(tint)
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, points, colors, uvs if texture else PackedVector2Array(),
		PackedInt32Array(), PackedFloat32Array(), texture.get_rid() if texture else RID())


static func draw_chain(canvas: CanvasItem, points: PackedVector2Array) -> bool:
	if texture("garm_chain_link") == null:
		return false
	var next := 8.0
	var travelled := 0.0
	for i in range(1, points.size()):
		var segment := points[i] - points[i - 1]
		var length := segment.length()
		while next <= travelled + length:
			var pos := points[i - 1] + segment * ((next - travelled) / maxf(length, 0.001))
			draw(canvas, "garm_chain_link", 0, pos, segment.angle())
			next += 14.0
		travelled += length
	return true


static func draw_ground(canvas: CanvasItem, id: String, rect: Rect2) -> bool:
	var strip := texture(id)
	if strip == null:
		return false
	canvas.draw_texture_rect(strip, rect, true)
	return true
