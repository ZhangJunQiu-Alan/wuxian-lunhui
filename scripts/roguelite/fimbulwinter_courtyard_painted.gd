extends Node3D

const Layout := preload("res://scripts/roguelite/fimbulwinter_courtyard_layout.gd")
const ROUND := "res://assets/models/midgard/courtyard/v5_painted/round08/"
const CANVAS_CENTER := Vector3(2.25, 0, .25)
const CANVAS_SIZE := Vector2(36, 24)
const INNER_GUIDE_SIZE := Vector2(24, 16)
const ROOM_SIZE := Vector2(64, 34.25)
const APPROACH_SIZE := Vector2(48, 32)
const APPROACH_DEPTH_SHIFT := 4.0
const GROUND := preload("res://assets/models/midgard/courtyard/v5_painted/room-ground.png")
const APPROACH_FOREGROUND := preload("res://assets/models/midgard/courtyard/v5_painted/approach-foreground.png")
const APPROACH_DEPTH := preload("res://assets/models/midgard/courtyard/v5_painted/depth-approach-foreground.png")
const LONGHOUSE := preload("res://assets/models/midgard/courtyard/v5_painted/round08/longhouse.png")
const PARAPETS := preload("res://assets/models/midgard/courtyard/v5_painted/round08/parapets.png")
const DORMANT := preload("res://assets/models/midgard/courtyard/v5_painted/gate-dormant.png")
const RESTORED := preload("res://assets/models/midgard/courtyard/v5_painted/gate-restored.png")
const DORMANT_THRESHOLD := preload("res://assets/models/midgard/courtyard/v5_painted/threshold-dormant.png")
const RESTORED_THRESHOLD := preload("res://assets/models/midgard/courtyard/v5_painted/threshold-restored.png")
const RUNES := preload("res://assets/models/midgard/courtyard/v5_painted/gate-runes.png")
const ENTRANCE_SHUTTER := preload("res://assets/models/midgard/courtyard/v5_painted/entrance-shutter.png")
const BRAZIER := preload("res://assets/models/midgard/courtyard/v5_painted/brazier.png")
const CONTACT := preload("res://assets/models/midgard/courtyard/v5_painted/brazier-contact.png")
const ICE_HALO := preload("res://assets/models/midgard/courtyard/v5_painted/ice-halo.png")
const WARM_HALO := preload("res://assets/models/midgard/courtyard/v5_painted/warm-halo.png")
const GROUND_DEPTH := preload("res://assets/models/midgard/courtyard/v5_painted/depth-ground.png")
const PROPS_DEPTH := preload("res://assets/models/midgard/courtyard/v5_painted/depth-architecture.png")
const DORMANT_DEPTH := preload("res://assets/models/midgard/courtyard/v5_painted/depth-dormant.png")
const RESTORED_DEPTH := preload("res://assets/models/midgard/courtyard/v5_painted/depth-restored.png")
const SEALED_DEPTH := preload("res://assets/models/midgard/courtyard/v5_painted/depth-sealed.png")
const LAYER := preload("res://scripts/roguelite/courtyard_painted_layer.gdshader")
const EDGE_LAYER := preload("res://scripts/roguelite/courtyard_painted_parapets.gdshader")
const BLEND := preload("res://scripts/roguelite/courtyard_painted_ground.gdshader")
const FIRE := preload("res://scripts/roguelite/courtyard_painted_fire.gdshader")

var _basis: Basis
var _eye_distance: float
var _runes: ShaderMaterial
var _portal_halo: StandardMaterial3D
var _warm_halos: Array[StandardMaterial3D] = []
var _portal_reveal := 0.0


func install(ruins: Node3D, camera: Camera3D, dormant: Node3D, restored: Node3D,
		shutter: Node3D, camera_offset: Vector3) -> void:
	_basis = camera.basis
	_eye_distance = camera_offset.length()
	for part: MeshInstance3D in ruins.find_children("*", "MeshInstance3D", true, false):
		part.hide()

	var room_center := CANVAS_CENTER - _basis.x * 10.0 - _basis.y * 2.875
	var ground := _layer(self, "PaintedGround", GROUND, GROUND_DEPTH, BLEND, 0.0, -90, ROOM_SIZE, room_center, true)
	ground.set_shader_parameter("backing_plate", true)
	var approach_center := CANVAS_CENTER - _basis.x * 18.0 - _basis.y * 4.0
	_layer(self, "PaintedApproachForeground", APPROACH_FOREGROUND, APPROACH_DEPTH, LAYER, APPROACH_DEPTH_SHIFT + .014, 0,
		APPROACH_SIZE, approach_center)
	var hall_back := _layer(self, "PaintedHallBacking", preload(ROUND + "hall-backing.png"), GROUND_DEPTH,
		BLEND, 0.0, -86, CANVAS_SIZE, CANVAS_CENTER, true)
	hall_back.set_shader_parameter("threshold_plate", true)
	_layer(self, "PaintedLonghouse", LONGHOUSE, PROPS_DEPTH, LAYER, 0.0, 0, CANVAS_SIZE, CANVAS_CENTER, true)
	_layer(self, "PaintedParapets", PARAPETS, PROPS_DEPTH, EDGE_LAYER, .014, -70, CANVAS_SIZE, CANVAS_CENTER, true)
	var floor_paint := _layer(self, "CarvedCourtFloor", preload(ROUND + "court-floor.png"), GROUND_DEPTH,
		BLEND, 0.0, -89, Vector2(27, 18), Vector3(3.9, 0, -.1))
	floor_paint.set_shader_parameter("threshold_plate", true)
	for cover in Layout.COVERS:
		_standing_paint(cover.id, cover.foot, cover.width, cover.height)
	_standing_paint("broken-rack", Vector2(1059, -544), 2.35, .95, .60)
	_layer(dormant, "PaintedDormantGate", DORMANT, DORMANT_DEPTH)
	var dormant_floor := _layer(dormant, "PaintedDormantThreshold", DORMANT_THRESHOLD, GROUND_DEPTH, BLEND, 0.0, -88)
	dormant_floor.set_shader_parameter("threshold_plate", true)
	_layer(restored, "PaintedRestoredGate", RESTORED, RESTORED_DEPTH)
	var restored_floor := _layer(restored, "PaintedRestoredThreshold", RESTORED_THRESHOLD, GROUND_DEPTH, BLEND, 0.0, -88)
	restored_floor.set_shader_parameter("threshold_plate", true)
	_layer(shutter, "PaintedEntranceShutter", ENTRANCE_SHUTTER, SEALED_DEPTH)
	_runes = _layer(restored, "ElderFuthark", RUNES, RESTORED_DEPTH, BLEND, .025, 5)
	_runes.set_shader_parameter("opacity", 0.0)
	_portal_halo = _halo(restored, ICE_HALO, Vector3(0, .038, .67), 4.8, 0.0)


func _standing_paint(label: String, point: Vector2, width: float, height: float, depth_bias := 0.0) -> void:
	var sprite := Sprite3D.new()
	sprite.name = label
	sprite.texture = load(ROUND + label + ".png")
	sprite.pixel_size = width / sprite.texture.get_width()
	var foot := Vector3(point.x, 0, point.y) * .01
	sprite.basis = _basis
	sprite.scale.y = height / (sprite.texture.get_height() * sprite.pixel_size)
	sprite.position = foot + _basis.y * (height * .46) + _basis.z * depth_bias
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = .42
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)


func add_brazier(at: Vector3) -> void:
	var contact := _halo(self, CONTACT, at + Vector3(-.05, .04, .06), 1.65, .74)
	contact.no_depth_test = false
	contact.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	contact.render_priority = 2
	var sprite := Sprite3D.new()
	sprite.name = "PaintedBrazier"
	sprite.texture = BRAZIER
	sprite.pixel_size = 1.20 / BRAZIER.get_height()
	sprite.position = at + _basis.y * .53 + _basis.z * .16
	sprite.basis = _basis
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flame := ShaderMaterial.new()
	flame.shader = FIRE
	flame.render_priority = 2
	flame.set_shader_parameter("painted_fire", BRAZIER)
	flame.set_shader_parameter("phase", at.x)
	sprite.material_override = flame
	add_child(sprite)
	_warm_halos.append(_halo(self, WARM_HALO, at + Vector3.UP * .05, 3.85, .58))


func portal_aperture(gate: Node3D) -> ArrayMesh:
	var corners := [Vector2(1098, 206), Vector2(1208, 251), Vector2(1197, 382), Vector2(1094, 338)]
	var uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	var face := Plane(gate.global_basis.z, gate.to_global(Vector3(0, 0, .12)))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0, 1, 2, 0, 2, 3]:
		var uv: Vector2 = corners[index] / Vector2(1536, 1024)
		var screen_point := CANVAS_CENTER + _basis.x * (uv.x - .5) * INNER_GUIDE_SIZE.x \
			+ _basis.y * (.5 - uv.y) * INNER_GUIDE_SIZE.y
		var world_point: Vector3 = face.intersects_ray(screen_point - _basis.z * 50, _basis.z)
		surface.set_uv(uvs[index])
		surface.add_vertex(gate.to_local(world_point))
	return surface.commit()


func set_portal_reveal(amount: float) -> void:
	_portal_reveal = amount
	_runes.set_shader_parameter("opacity", amount)


func pulse(time: float) -> void:
	_portal_halo.albedo_color.a = _portal_reveal * (.71 + sin(time * 2.6) * .057)
	for index in _warm_halos.size():
		_warm_halos[index].albedo_color.a = .55 + sin(time * 7.8 + index * 1.7) * .071


func _layer(parent: Node3D, label: String, image: Texture2D, depth: Texture2D,
		shader: Shader = LAYER, bias := 0.0, priority := 0, size := CANVAS_SIZE, center := CANVAS_CENTER, expand_plate := false) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = shader
	paint.render_priority = priority
	paint.set_shader_parameter("painting", image)
	paint.set_shader_parameter("painted_depth", depth)
	paint.set_shader_parameter("depth_offset", bias)
	paint.set_shader_parameter("guide_back", _basis.z)
	paint.set_shader_parameter("eye_distance", _eye_distance)
	var quad := QuadMesh.new()
	quad.size = size
	var layer := MeshInstance3D.new()
	layer.name = label
	layer.mesh = _expanded_plate(quad, center) if expand_plate else quad
	layer.material_override = paint
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(layer)
	layer.global_transform = Transform3D(_basis, center)
	return paint


func _expanded_plate(quad: QuadMesh, center: Vector3) -> ArrayMesh:
	quad.subdivide_width = ceili(quad.size.x * 3.0)
	quad.subdivide_depth = ceili(quad.size.y * 3.0)
	var arrays := quad.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var point := center + _basis * vertices[i]
		var foot := point - _basis.z * point.y / _basis.z.y
		var old := Vector2(foot.x, foot.z) * 100.0
		var shift := (Layout.expand(old) - old) * .01
		vertices[i] += _basis.inverse() * Vector3(shift.x, 0, shift.y)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _halo(parent: Node3D, texture: Texture2D, at: Vector3, width: float,
		strength: float) -> StandardMaterial3D:
	var sprite := Sprite3D.new()
	sprite.name = "GroundHalo"
	sprite.texture = texture
	sprite.pixel_size = width / texture.get_width()
	sprite.position = at
	sprite.rotation.x = -PI / 2
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	light.no_depth_test = true
	light.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	light.albedo_texture = texture
	light.albedo_color.a = strength
	light.render_priority = 1
	sprite.material_override = light
	parent.add_child(sprite)
	return light
