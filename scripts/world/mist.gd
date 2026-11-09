class_name Mist
extends Node2D
## 冥雾（第 2 关）：站在雾里每秒掉一点生命，敌人在雾里变慢
## 关卡数据 map.mist 里写固定的雾区（zones）和飘动的雾团数量（drifting）

const DAMAGE_RATIO := 0.02   # 每秒掉最大生命的这么多
const ENEMY_SLOW := 0.6
const DRIFT_SPEED := 22.0
const DRIFT_RADIUS := Vector2(200.0, 290.0)
const PUFFS := 7             # 每个雾区由几团雾叠成
const TINT := Color(0.62, 0.72, 0.7, 0.32)

static var instance: Mist

var player: Player
var _zones := []  # 每项：pos、radius、vel（固定雾区为 0）、seed
var _texture: Texture2D
var _time := 0.0
var _warned := false


## pos 是否在雾里
static func covers(pos: Vector2) -> bool:
	if instance == null:
		return false
	for zone in instance._zones:
		if pos.distance_squared_to(zone.pos) < zone.radius * zone.radius:
			return true
	return false


func setup(config: Dictionary) -> void:
	for zone: Dictionary in config.get("zones", []):
		_zones.append({"pos": zone.pos, "radius": zone.radius, "vel": Vector2.ZERO, "seed": randf() * 100.0})
	for i in config.get("drifting", 0):
		var pos := Vector2(randf_range(Game.bounds.position.x, Game.bounds.end.x), randf_range(Game.bounds.position.y, Game.bounds.end.y))
		_zones.append({"pos": pos, "radius": randf_range(DRIFT_RADIUS.x, DRIFT_RADIUS.y),
			"vel": Vector2.from_angle(randf() * TAU) * DRIFT_SPEED, "seed": randf() * 100.0})


func _ready() -> void:
	instance = self
	z_index = 5  # 盖在角色和敌人上面，半透明
	_texture = _make_puff()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _physics_process(delta: float) -> void:
	_time += delta
	for zone in _zones:
		if zone.vel == Vector2.ZERO:
			continue
		zone.vel = zone.vel.rotated(randf_range(-0.4, 0.4) * delta)  # 慢慢拐弯
		zone.pos += zone.vel * delta
		var inner := Game.bounds.grow(-zone.radius * 0.5)
		if not inner.has_point(zone.pos):  # 碰到地图边缘就掉头
			zone.vel = (inner.get_center() - zone.pos).normalized() * DRIFT_SPEED
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		enemy.slow = ENEMY_SLOW if covers(enemy.global_position) else 1.0
	if is_instance_valid(player) and covers(player.global_position):
		player.take_dot(player.max_hp * DAMAGE_RATIO * delta)
		if not _warned:
			_warned = true
			var game := get_tree().current_scene
			if game.get("hud"):
				game.hud.announce(tr("冥雾：站在雾里会持续掉血，但敌人在雾里会变慢"))
	queue_redraw()


## 一团边缘柔和、带噪点的雾
func _make_puff() -> Texture2D:
	var size := 128
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(Vector2(size, size) / 2.0) / (size / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (0.6 + 0.4 * (noise.get_noise_2d(x, y) + 1.0) / 2.0)
			image.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	var view := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera else Vector2.ZERO
	var visible_rect := Rect2(center - view, view * 2.0)
	for zone in _zones:
		var r: float = zone.radius
		if not visible_rect.grow(r).has_point(zone.pos):
			continue
		for i in PUFFS:
			var angle: float = zone.seed + TAU * i / PUFFS + _time * 0.05
			var offset := Vector2.from_angle(angle) * r * 0.45 * (0.7 + 0.3 * sin(_time * 0.3 + i))
			var size := r * 1.3
			draw_texture_rect(_texture, Rect2(zone.pos + offset - Vector2.ONE * size / 2.0, Vector2.ONE * size), false, TINT)
		draw_texture_rect(_texture, Rect2(zone.pos - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, TINT)
