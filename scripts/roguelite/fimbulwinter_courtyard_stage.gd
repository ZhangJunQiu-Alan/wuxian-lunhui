extends Node3D

const PaintedCourtyard := preload("res://scripts/roguelite/fimbulwinter_courtyard_painted.gd")
const Layout := preload("res://scripts/roguelite/fimbulwinter_courtyard_layout.gd")
const FimbulwinterPlayer := preload("res://scripts/roguelite/fimbulwinter_courtyard_player.gd")
const SCALE := 0.01
const CAMERA_OFFSET := Vector3(-8.0, 14.4, 9.8)
const FIRES := [Vector2(-2387, 192), Vector2(-1373, -251), Vector2(-855, -218),
	Vector2(-349, -500), Vector2(735, -69)]
const AMBER := Color("#ffd290")
const ICE := Color("#9ddff7")
const HEADLAND := preload("res://assets/models/midgard/courtyard/v4/headland.glb")
const SHADOW_SHADER := preload("res://scripts/roguelite/courtyard_contact_shadow.gdshader")
const PORTAL_SHADER := preload("res://scripts/roguelite/courtyard_portal.gdshader")
const OUTLINE_SHADER := preload("res://scripts/roguelite/courtyard_actor_outline.gdshader")

var player: Player
var camera: Camera3D
var shutter: Node3D
var entrance_shutter: Node3D
var entrance_sealed := false
var portal_ready := false
var _approach_seal: Node3D
var _dormant_gate: Node3D
var _awakened_gate: Node3D
var _portal_material: ShaderMaterial
var _painted: PaintedCourtyard
var _snow: GPUParticles3D
var _portal_dust: CPUParticles3D
var _center := Vector3.ZERO
var _hero: Sprite3D
var _hero_shadow: MeshInstance3D
var _contact: ShaderMaterial
var _hero_frames: SpriteFrames
var _actors: Dictionary[Enemy, Node3D] = {}
var _shots: Dictionary[EnemyProjectile, MeshInstance3D] = {}
var _clock := 0.0
var _impact := 0.0
var _impact_direction := Vector3.RIGHT
var exit_threshold: PackedVector2Array


func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#17263a")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#97aac8")
	world.environment.ambient_light_energy = 0.57
	world.environment.glow_enabled = true
	world.environment.glow_intensity = 0.21
	world.environment.glow_strength = 0.82
	world.environment.glow_hdr_threshold = 1.18
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-27, -36, 0)
	sun.light_color = Color("#fff0dc")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-37, 144, 0)
	fill.light_color = Color("#95b4ec")
	fill.light_energy = 0.29
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.4
	camera.position = CAMERA_OFFSET
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	_follow_camera(1.0)
	var ruins := HEADLAND.instantiate()
	add_child(ruins)
	var perimeter := Layout.boundary_anchors(ruins)
	(player as FimbulwinterPlayer).perimeter = perimeter
	for anchor in perimeter:
		MapLayer.add_obstacle(Vector2(anchor.x, anchor.y + MapLayer.FOOT), anchor.z)
	for cover in Layout.COVERS:
		MapLayer.add_obstacle(cover.foot + Vector2(0, MapLayer.FOOT), cover.radius)
	shutter = ruins.find_child("GateShutter*", true, false) as Node3D
	entrance_shutter = ruins.find_child("EntranceShutter*", true, false) as Node3D
	_dormant_gate = ruins.find_child("DormantGate*", true, false) as Node3D
	_awakened_gate = ruins.find_child("AwakenedGate*", true, false) as Node3D
	_painted = PaintedCourtyard.new()
	_painted.name = "PaintedCourtyard"
	add_child(_painted)
	_painted.install(ruins, camera, _dormant_gate, _awakened_gate, entrance_shutter, CAMERA_OFFSET)
	entrance_shutter.position.y = 2.83
	entrance_shutter.hide()
	_setup_portal()
	_contact = ShaderMaterial.new()
	_contact.shader = SHADOW_SHADER

	for point: Vector2 in FIRES:
		var at := world_at(Layout.expand(point))
		_painted.add_brazier(at)
		_motes(at + Vector3.UP * .76, Color("#ffc189"), 14, 1.08,
			Vector3(.10, .025, .10), Vector3(.14, 1.0, 0))
	_snow = _snowfall()

	var body := SpriteVisual.create_actions("res://assets/sprites/characters/swordsman", 64.0,
		{"idle": true, "move": true, "attack": false, "hurt": false, "death": false})
	_hero_frames = body.sprite_frames
	body.free()
	_hero_shadow = _contact_shadow(self)
	_hero = _billboard(self, 0.0215)
	_ring(self, 0.235, Color("#b3e0e8b8"), 0.015).name = "PlayerRing"
	_approach_seal = Node3D.new()
	_approach_seal.position = world_at(Vector2(get_parent().APPROACH_LIMIT, 0))
	add_child(_approach_seal)
	for i in range(-8, 9):
		var z := i * 0.48
		var warmth := Color(0.94, 0.79, 0.51, 0.32 + 0.25 * (1.0 - absf(z) / 4.0))
		_beam(_approach_seal, Vector3(0.035 * sin(i), 0.030, z), Vector3(0.036, 0.008, 0.29), warmth)
	_approach_seal.hide()
	player._actions.frame_changed.connect(_sync_hero)
	player._actions.animation_changed.connect(_sync_hero)
	_sync_hero()


func world_at(point: Vector2) -> Vector3:
	return Vector3(point.x, 0, point.y) * SCALE


func exit_gate_position() -> Vector3:
	return _dormant_gate.global_position


func ground_at(screen_point: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	var point := origin - direction * (origin.y / direction.y)
	return Vector2(point.x, point.z) / SCALE


func track(enemy: Enemy) -> void:
	var actor := Node3D.new()
	actor.position = world_at(enemy.global_position)
	add_child(actor)
	_contact_shadow(actor).position.y = 0.018
	_billboard(actor, 0.0187).name = "Body"
	_ring(actor, 0.22, Color("#a64f477c"), 0.013)
	var hp := _beam(actor, Vector3(0, 0.83, -0.30), Vector3(0.33, 0.027, 0.035), Color("#ff8270"))
	hp.name = "Health"
	hp.hide()
	if enemy.type_id == "ice_spirit":
		var cast := _ring(actor, 0.37, ICE, 0.025)
		cast.name = "Cast"
		cast.hide()
	actor.set_meta("hp", enemy.hp)
	_actors[enemy] = actor
	enemy.killed.connect(_foe_fell)
	enemy.tree_exiting.connect(_forget.bind(enemy, actor))
	_sync_enemy(enemy, actor)


func _forget(enemy: Enemy, actor: Node3D) -> void:
	_actors.erase(enemy)
	if is_instance_valid(actor):
		actor.queue_free()


func _foe_fell(enemy: Enemy) -> void:
	if _actors.has(enemy):
		_actors[enemy].set_meta("hp", enemy.hp)
		_hit(enemy.global_position, true)


func set_approach_seal(visible_seal: bool) -> void:
	_approach_seal.visible = visible_seal


func seal_entrance() -> void:
	entrance_sealed = true
	entrance_shutter.show()
	var drop := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(entrance_shutter, "position:y", 0.0, 0.42)
	drop.tween_callback(_shutter_impact)


func _shutter_impact() -> void:
	Audio.sfx("surtr_gate", -7.0)
	_impact = .15
	_impact_direction = Vector3(.4, .37, .58)
	var dust := _motes(entrance_shutter.global_position + Vector3.UP * .1, Color("#b6c9dd9c"),
		32, .58, Vector3(.6,.04,.39), Vector3(.08, 1, .11))
	dust.one_shot = true
	get_tree().create_timer(.85).timeout.connect(dust.queue_free)


func _setup_portal() -> void:
	_awakened_gate.hide()
	var aperture := _painted.portal_aperture(_awakened_gate)
	var veil := _mesh(_awakened_gate, aperture, Vector3.ZERO, Color.WHITE)
	_portal_material = ShaderMaterial.new()
	_portal_material.shader = PORTAL_SHADER
	_portal_material.render_priority = 3
	veil.material_override = _portal_material

	_portal_dust = _motes(_awakened_gate.global_position + Vector3.UP * .16,
		Color("#88d9fccc"), 26, 1.8, Vector3(.46,.04,.63), Vector3(.05,1,.03))
	(_portal_dust.mesh as QuadMesh).size *= .65
	_portal_dust.emitting = false

	_dormant_gate.get_parent_node_3d().global_position.x += Layout.EAST_SHIFT * SCALE
	var arrays := aperture.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	# Match the painted sill by projecting the light curtain's lower edge onto walkable ground.
	for uv in [Vector2.DOWN, Vector2.ONE]:
		var corner := veil.to_global(vertices[uvs.find(uv)])
		exit_threshold.append(ground_at(camera.unproject_position(corner)))


func awaken_exit() -> void:
	var reveal := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(shutter, "position:y", 2.72, 0.25)
	reveal.tween_callback(_reveal_restored_arch)
	reveal.tween_method(_set_portal_light, 0.0, 1.0, 0.47)
	reveal.tween_callback(func() -> void: portal_ready = true)


func _reveal_restored_arch() -> void:
	shutter.hide()
	_dormant_gate.hide()
	_awakened_gate.show()
	_portal_dust.emitting = true
	Audio.sfx("milestone", -6.0)

func _set_portal_light(amount: float) -> void:
	_portal_material.set_shader_parameter("reveal", amount)
	_painted.set_portal_reveal(amount)


func _process(delta: float) -> void:
	_clock += delta
	_painted.pulse(_clock)
	_impact = maxf(0.0, _impact - delta)
	_follow_camera(1.0 - exp(-7.0 * delta))
	_snow.position = _center + Vector3(0,3.1,0)
	_sync_hero()
	for enemy: Enemy in _actors:
		_sync_enemy(enemy, _actors[enemy])
	for shot: EnemyProjectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if not _shots.has(shot):
			var projectile := _beam(self, Vector3.ZERO, Vector3(0.09, 0.09, 0.29), ICE)
			_shots[shot] = projectile
			shot.tree_exiting.connect(_forget_shot.bind(shot, projectile))
		var visual := _shots[shot]
		visual.position = world_at(shot.global_position) + Vector3.UP * 0.26
		visual.rotation.y = atan2(shot.direction.x, shot.direction.y)


func _follow_camera(weight: float) -> void:
	var at := world_at(player.global_position)
	var court_weight := smoothstep(-6.72, -4.5, at.x)
	var target := Vector3(clampf(at.x + lerpf(1.34, 1.12, court_weight), -25.4, 19.6), 0.0,
		lerpf(clampf(at.z * .68 - .83, -4.8, 4.05), clampf(at.z * .77 - .78, -7.0, 6.0), court_weight))
	_center = _center.lerp(target, weight)
	var approach_size := 9.0 + 1.88 * (1.0 - smoothstep(4.5, 8.3, absf(at.x)))
	var court_size := 9.0 + .62 * smoothstep(-6.0, -.8, at.x) * (1.0 - smoothstep(10.4, 14.0, at.x))
	camera.size = lerpf(camera.size, lerpf(approach_size, court_size, court_weight), weight)
	var shake := _impact_direction * sin(_impact * 155.0) * _impact * .59 * Settings.screen_shake
	camera.position = _center + CAMERA_OFFSET + shake


func _contact_shadow(parent: Node3D) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.01, 0.81)
	var shadow := _mesh(parent, plane, Vector3.ZERO, Color.WHITE)
	shadow.material_override = _contact
	return shadow


func _forget_shot(shot: EnemyProjectile, visual: MeshInstance3D) -> void:
	_shots.erase(shot)
	if is_instance_valid(visual):
		visual.queue_free()


func _billboard(parent: Node3D, pixel_size: float) -> Sprite3D:
	var body := Sprite3D.new()
	body.rotation = camera.rotation
	body.pixel_size = pixel_size
	body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	body.alpha_scissor_threshold = 0.36
	body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(body)
	var outline_mesh := QuadMesh.new()
	var outline := _mesh(body, outline_mesh, Vector3.ZERO, Color.WHITE)
	outline.name = "OccludedOutline"
	var hint := ShaderMaterial.new()
	hint.shader = OUTLINE_SHADER
	hint.render_priority = 12
	outline.material_override = hint
	return body


func _frame(body: Sprite3D, texture: Texture2D, flipped: bool, at: Vector3) -> void:
	var outline := body.get_node("OccludedOutline") as MeshInstance3D
	var hint := outline.material_override as ShaderMaterial
	if body.texture != texture:
		body.texture = texture
		var quad := outline.mesh as QuadMesh
		quad.size = texture.get_size() * body.pixel_size
		var frame := texture as AtlasTexture
		if frame:
			var atlas := frame.atlas
			var size := atlas.get_size()
			var region := frame.region
			hint.set_shader_parameter("body_texture", atlas)
			hint.set_shader_parameter("frame_region", Vector4(
				region.position.x / size.x, region.position.y / size.y,
				region.size.x / size.x, region.size.y / size.y))
		else:
			hint.set_shader_parameter("body_texture", texture)
			hint.set_shader_parameter("frame_region", Vector4(0.0,0.0,1.0,1.0))
	body.flip_h = flipped
	hint.set_shader_parameter("flipped", flipped)
	body.position = at + camera.basis.y * (texture.get_height() * body.pixel_size * 0.5 - 0.087)


func _sync_hero() -> void:
	var anim := player._actions
	var action := anim.animation if _hero_frames.has_animation(anim.animation) else &"move"
	var frame := mini(anim.frame, _hero_frames.get_frame_count(action) - 1)
	var at := world_at(player.global_position)
	_frame(_hero, _hero_frames.get_frame_texture(action, frame), anim.flip_h, at)
	_hero_shadow.position = at + Vector3.UP * 0.018
	_hero.modulate = Color("#e3edff") if not player.is_hurt() else Color("#ff9f97")
	get_node("PlayerRing").position = at + Vector3.UP * 0.027


func _sync_enemy(enemy: Enemy, actor: Node3D) -> void:
	actor.position = world_at(enemy.global_position)
	var anim := enemy._actions
	var body := actor.get_node("Body") as Sprite3D
	var texture := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame) if anim else (enemy._sprite as Sprite2D).texture
	var floating := 0.12 + sin(_clock * 5.0) * 0.05 if enemy.type_id == "ice_spirit" else 0.0
	_frame(body, texture, bool(enemy._sprite.get("flip_h")), Vector3.UP * floating)
	body.modulate = Color("#fff7d4") if enemy._flash_time > 0.0 else Color("#e2e8f4")
	var hp := actor.get_node("Health") as MeshInstance3D
	hp.visible = enemy.hp < enemy.max_hp and enemy.hp > 0.0
	hp.scale.x = maxf(0.01, enemy.hp / enemy.max_hp)
	if enemy.hp < float(actor.get_meta("hp")):
		_hit(enemy.global_position, false)
	actor.set_meta("hp", enemy.hp)
	if actor.has_node("Cast"):
		actor.get_node("Cast").visible = enemy._casting


func show_slash(at: Vector2, direction: Vector2, radius: float, half_angle: float, critical: bool) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer := radius * SCALE
	for i in 24:
		var u := float(i) / 24.0
		var v := float(i + 1) / 24.0
		var a := direction.rotated(lerpf(-half_angle, half_angle, u))
		var b := direction.rotated(lerpf(-half_angle, half_angle, v))
		var ai := Vector3(a.x, 0.0, a.y) * outer
		var bi := Vector3(b.x, 0.0, b.y) * outer
		var inner_a := ai * (1.0 - 0.24 * sin(PI * u))
		var inner_b := bi * (1.0 - 0.24 * sin(PI * v))
		for vertex: Vector3 in [ai, bi, inner_a, bi, inner_b, inner_a]:
			surface.add_vertex(vertex)
	var slash := _mesh(self, surface.commit(), world_at(at) + Vector3.UP * 0.27, AMBER if critical else Color("#e5faffed"))
	var trail := create_tween().set_parallel(true)
	trail.tween_property(slash.material_override, "albedo_color:a", 0.0, 0.18)
	trail.tween_property(slash, "scale", Vector3(1.10, 1.0, 1.10), 0.18)
	trail.chain().tween_callback(slash.queue_free)


func _hit(point: Vector2, defeated: bool) -> void:
	var aim := player.global_position.direction_to(point)
	_impact_direction = Vector3(aim.x, 0.0, aim.y)
	_impact = 0.09 if defeated else 0.065
	var sparks := Node3D.new()
	sparks.position = world_at(point) + Vector3.UP * 0.28
	add_child(sparks)
	var scatter := sparks.create_tween().set_parallel(true)
	for i in 8:
		var angle := aim.angle() + (float(i) - 3.5) * 0.39
		var direction := Vector3(cos(angle), 0.22 + i * 0.025, sin(angle))
		var particle := _beam(sparks, direction * 0.08, Vector3(0.022, 0.024, 0.15), AMBER if i % 3 else Color.WHITE)
		particle.rotation.y = atan2(direction.x, direction.z)
		scatter.tween_property(particle, "position", direction * (0.48 + i * 0.032), 0.19)
		scatter.tween_property(particle, "scale", Vector3.ZERO, 0.19)
	scatter.chain().tween_callback(sparks.queue_free)


func _motes(at: Vector3, color: Color, count: int, life: float, area: Vector3, drift: Vector3) -> CPUParticles3D:
	var air := CPUParticles3D.new()
	air.position = at
	air.amount = count
	air.lifetime = life
	air.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	air.emission_box_extents = area
	air.direction = drift
	air.spread = 28.0
	air.gravity = Vector3(.13, .07, .0)
	air.initial_velocity_min = .2
	air.initial_velocity_max = 1.1
	air.scale_amount_min = .24
	air.scale_amount_max = 1.20
	var mote := QuadMesh.new()
	mote.size = Vector2.ONE * .054
	var material := _material(color)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote.material = material
	air.mesh = mote
	add_child(air)
	return air


func _snowfall() -> GPUParticles3D:
	var air := GPUParticles3D.new()
	air.amount = 150
	air.lifetime = 4.3
	air.preprocess = 4.3
	air.local_coords = true
	air.visibility_aabb = AABB(Vector3(-11,-5,-10),Vector3(22,10,20))
	var wind := ParticleProcessMaterial.new()
	wind.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	wind.emission_box_extents = Vector3(10.6,1.66,8.5)
	wind.direction = Vector3(.67,-.65,.23)
	wind.spread = 28
	wind.gravity = Vector3(.04,-.17,.0)
	wind.initial_velocity_min = .39
	wind.initial_velocity_max = .91
	wind.scale_min = .53
	wind.scale_max = 1.26
	air.process_material = wind
	var flake := QuadMesh.new()
	flake.size = Vector2.ONE * .034
	var material := _material(Color("#cfe8ff6c"))
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flake.material = material
	air.draw_pass_1 = flake
	add_child(air)
	return air


func _ring(parent: Node3D, radius: float, color: Color, stroke: float) -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = radius - stroke
	ring.outer_radius = radius
	ring.rings = 32
	ring.ring_segments = 5
	return _mesh(parent, ring, Vector3.UP * 0.027, color)


func _beam(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent, box, at, color)


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.position = at
	visual.mesh = mesh
	visual.material_override = _material(color)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
