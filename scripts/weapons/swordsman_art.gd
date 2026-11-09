class_name SwordsmanArt
extends Node2D

const WEAPON_DIR := "res://assets/sprites/weapons/"
const CHAR_DIR := "res://assets/sprites/characters/"
const ICON_DIR := "res://assets/sprites/ui/weapons/swordsman/"
const FX_MANIFEST := "res://assets/sprites/effects/weapons/swordsman/manifest.json"
const ACTIONS := {
	"idle": true, "move": true, "attack": false, "hurt": false, "death": false,
	"spin": true, "heavy": false, "sheathe": false, "iai_stance": true,
	"iai_dash": false, "throw": false, "thrust": false, "drink": false, "off_attack": false,
}
const FPS := {"attack": 16.0, "hurt": 12.0, "spin": 12.0, "heavy": 16.0,
	"sheathe": 16.0, "iai_dash": 16.0, "throw": 16.0, "thrust": 16.0, "drink": 12.0, "off_attack": 16.0}
const FLIGHT := [0.0, 0.52, 1.0, 0.77, 0.36, 0.0]

static var _weapons := {}
static var _effects := {}
static var _sockets := {}
static var _textures := {}
static var _body_frames := {}

var body: AnimatedSprite2D
var weapon: Dictionary
var _parts: Array[Sprite2D] = []
var _used := 0


static func _index(path: String) -> Dictionary:
	var result := {}
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if rows is Array:
		for row: Dictionary in rows:
			result[row.id] = row
	return result


static func weapons() -> Dictionary:
	if _weapons.is_empty():
		_weapons = _index(WEAPON_DIR + "manifest.json")
	return _weapons


static func effects() -> Dictionary:
	if _effects.is_empty():
		_effects = _index(FX_MANIFEST)
	return _effects


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


static func vec(values: Array) -> Vector2:
	return Vector2(values[0], values[1])


static func create_body(weapon_id: String, height: float) -> AnimatedSprite2D:
	if not weapons().has(weapon_id) or effects().is_empty():
		return null
	if _sockets.is_empty():
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHAR_DIR + "swordsman_sockets.json"))
		if source is not Dictionary:
			return null
		_sockets = source
	var sprite := SpriteVisual.create_actions(CHAR_DIR + "swordsman_bare", height, ACTIONS)
	if not sprite:
		return null
	var waist: bool = weapons()[weapon_id].has("sheath_file")
	var layout := "waist" if waist else ("stationary" if weapon_id == "zhuxian" else "bare")
	if not _body_frames.has(layout):
		var frames := sprite.sprite_frames.duplicate() as SpriteFrames
		if waist:
			for action: String in _sockets.waist_bodies:
				frames.clear(action)
				var file: String = _sockets.waist_bodies[action]
				SpriteVisual._add_strip(frames, action, texture(CHAR_DIR + file.get_file()), false)
		if layout == "stationary":
			var count := frames.get_frame_count(&"attack")
			frames.clear(&"attack")
			for i in count:
				frames.add_frame(&"attack", frames.get_frame_texture(&"idle", 0))
		for action: String in FPS:
			frames.set_animation_speed(action, FPS[action])
		_body_frames[layout] = frames
	sprite.sprite_frames = _body_frames[layout]
	sprite.play(&"idle")
	return sprite


func _put(ref: Dictionary, socket: Dictionary, layer: int) -> void:
	if _used == _parts.size():
		var part := Sprite2D.new()
		part.centered = false
		add_child(part)
		_parts.append(part)
	var sprite := _parts[_used]
	_used += 1
	var image := texture(WEAPON_DIR + str(ref.file))
	var grip := vec(ref.grip)
	sprite.texture = image
	sprite.position = Vector2(socket.x, socket.y) + Vector2(0.5, 0.5)
	sprite.rotation = deg_to_rad(float(socket.get("deg", 0)) - float(ref.get("base_deg", 0)))
	sprite.offset = -grip - Vector2(0.5, 0.5)
	sprite.region_enabled = ref.has("clip")
	if sprite.region_enabled:
		sprite.region_rect = Rect2(0, 0, float(ref.clip), image.get_height())
	sprite.z_index = layer
	sprite.show()


static func _shift(point: Dictionary, adjust: Dictionary) -> Dictionary:
	var result := point.duplicate()
	result.merge(adjust, true)
	result.x = float(result.x) + float(adjust.get("dx", 0))
	result.y = float(result.y) + float(adjust.get("dy", 0))
	return result


func _waist_frame(action: StringName, n: int) -> Dictionary:
	var frames: Array = _sockets.waist_frames.get(action, [])
	return frames[n] if weapon.has("sheath_file") and n < frames.size() else {}


func _stow_point(sockets: Dictionary, action: StringName, n: int) -> Dictionary:
	var point: Dictionary = sockets[weapon.stow].duplicate()
	point.merge(_waist_frame(action, n).get("hip", {}), true)
	return _shift(point, weapon.get("stow_socket_adjust", {}))


func _anchor(point: Dictionary) -> Vector2:
	var p := Vector2(point.x, point.y) + Vector2(0.5, 0.5)
	return to_global(p)


func socket_world(id: String) -> Vector2:
	var frames: Array = _sockets.actions[body.animation]
	var n := mini(body.frame, frames.size() - 1)
	var sockets: Dictionary = frames[n]
	var point: Dictionary = _stow_point(sockets, body.animation, n) if id == "mouth_of_sheath" else sockets[id]
	return _anchor(point)


func render(variant: String, hide_off: bool, glow: bool, spin_deg: float) -> void:
	var action := body.animation
	var frames: Array = _sockets.actions[action]
	var n := mini(body.frame, frames.size() - 1)
	var flight: bool = weapon.has("flight_px") and action == &"attack"
	var sockets: Dictionary = _sockets.actions.idle[0] if flight else frames[n]
	var visible_part: bool = sockets.mode != "none"
	var holding: bool = visible_part and (weapon.idle_hold == "held" or sockets.mode == "held")
	var direction := -1.0 if body.flip_h else 1.0
	position = body.offset + Vector2(-32.0 * direction, -32.0)
	scale.x = direction
	_used = 0
	if visible_part and weapon.has("stow_file") and (not holding or weapon.has("sheath_file")):
		var point := _stow_point(sockets, action, n)
		var stow := {"file": weapon.sheath_file if holding else weapon.stow_file,
			"grip": weapon.stow_grip, "base_deg": weapon.stow_base_deg}
		_put(stow, point, 1 if point.z == "front" else -2)
		if not holding and weapon.has("stow_keeper"):
			stow.file = weapon.stow_keeper
			_put(stow, point, 1)
		if not holding and glow and weapon.has("stow_glow"):
			stow.file = weapon.stow_glow
			_put(stow, point, 2)
	if holding:
		_held(sockets, action, n, variant, hide_off, glow, spin_deg)
	if visible_part and weapon.has("props"):
		var gourd: Dictionary = weapon.props.gourd
		var point: Dictionary = sockets.off if action == &"drink" else _shift(sockets.hip, gourd.hip_adjust)
		if action != &"drink":
			point.deg = 0
		_put(gourd, point, 1)
	for i in range(_used, _parts.size()):
		_parts[i].hide()


func _held(sockets: Dictionary, action: StringName, n: int, variant: String, hide_off: bool,
		glow: bool, spin_deg: float) -> void:
	var variants: Dictionary = weapon.get("variants", {})
	var hand: Dictionary = variants.get(variant, weapon.get("main", {}))
	var main := _shift(sockets.main, weapon.get("idle_main_adjust", {}) if action == &"idle" else {})
	if weapon.has("flight_px") and action == &"attack":
		var phase: float = FLIGHT[n]
		var reach := float(weapon.flight_px) - float(hand.tip[0]) + float(hand.grip[0])
		main.x = lerpf(float(main.x), 32.0 + reach, phase)
		main.y = lerpf(float(main.y), 31.0, phase)
		main.deg = 0.0 if n < 3 else 180.0
		main.z = "front"
	if action == &"spin":
		main.deg = fposmod(spin_deg, 360.0)
		main.z = "back" if float(main.deg) > 180.0 else "front"
	var feed: Variant = _waist_frame(action, n).get("feed_px")
	if feed != null:
		main = _stow_point(sockets, action, n)
		var shift := Vector2.from_angle(deg_to_rad(float(main.deg))) * float(feed)
		main.x -= shift.x
		main.y -= shift.y
		hand = hand.duplicate()
		hand.clip = minf(float(hand.tip[0]) + 1.0, float(hand.grip[0]) + float(feed) + 1.0)
	if not hand.is_empty():
		_put(hand, main, -1 if main.z == "back" else 1)
	if weapon.id == "zhuxian":
		var index := 0
		for reserve: Dictionary in variants.values():
			if reserve.file == hand.file:
				continue
			var offset := vec(weapon.reserve_offsets[index])
			_put(reserve, _shift(sockets.back, {"dx": offset.x, "dy": offset.y, "deg": -90}), -2)
			index += 1
	var off := _shift(sockets.off, weapon.get("off_idle_adjust", {}) if action in [&"idle", &"move"] else {})
	if weapon.id == "riyue":
		_put(variants.sun if variant == "moon" else variants.moon, off, -1)
	elif weapon.has("off") and not hide_off:
		_put(weapon.off, off, 1 if action == &"off_attack" else -1)
	if glow and hand.has("glow"):
		var lit := hand.duplicate()
		lit.file = hand.glow
		_put(lit, main, 2)
