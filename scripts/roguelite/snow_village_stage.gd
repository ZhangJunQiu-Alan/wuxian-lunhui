extends Node3D

const WORLD_SCALE := 0.01
const SNOW := Color("#879fa8")
const FROST := Color("#b9cbd0")
const ICE := Color("#477d92")
const STONE := Color("#465963")
const WOOD := Color("#544840")
const ROOF := Color("#344450")
const GOLD := Color("#ffd089")
const WARNING := Color("#f45949")
const WARM := Color("#e3a05c")

var player: Player
var _camera: Camera3D
var _swordsman: Node3D
var _sword_arm: Node3D
var _player_legs: Array[Node3D] = []
var _marker: Node3D
var _barrier: MeshInstance3D
var _warning: MeshInstance3D
var _actors: Dictionary[Enemy, Node3D] = {}
var _shots: Dictionary[EnemyProjectile, Node3D] = {}
var _lightning := {}
var _ice_arrows: Array[Node3D] = []
var _materials := {}
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func _ready() -> void:
	_rng.seed = 70524
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#263b45")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#d4e2f2")
	environment.environment.ambient_light_energy = 0.45
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -34, 0)
	light.light_color = Color("#fff0d7")
	light.light_energy = 0.64
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 26.0
	add_child(light)

	_terrain()
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 8.7
	_camera.current = true
	add_child(_camera)
	_swordsman = _make_swordsman()
	_marker = Node3D.new()
	add_child(_marker)
	_ring(_marker, 0.37, GOLD, 0.025)
	_ring(_marker, 0.53, Color(GOLD, 0.55), 0.012)
	_box(_marker, Vector3(0, 0.23, 0), Vector3(0.13, 0.13, 0.13), GOLD, true).rotation_degrees = Vector3(25, 45, 25)
	_barrier = _box(self, Vector3.ZERO, Vector3(0.055, 0.022, 10.5), Color(GOLD, 0.56), true)
	_barrier.hide()
	_warning = _box(self, Vector3.ZERO, Vector3.ONE, Color(WARNING, 0.62), true)
	_warning.hide()
	_update_camera(1.0)
	_update_player(0.0)


func ground_at(screen_point: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(screen_point)
	var direction := _camera.project_ray_normal(screen_point)
	var world := origin + direction * (-origin.y / direction.y)
	return Vector2(world.x, world.z) / WORLD_SCALE


func mark_objective(point: Vector2) -> void:
	_marker.position = _world(point)
	_marker.show()


func hide_objective() -> void:
	_marker.hide()


func mark_route_limit(edge: float, visible: bool) -> void:
	_barrier.position = Vector3(edge * WORLD_SCALE, 0.021, 0.0)
	_barrier.visible = visible


func show_death() -> void:
	_update_player(0.0)


func track(enemy: Enemy) -> void:
	var actor: Node3D
	match enemy.type_id:
		"wolf", "skoll":
			actor = _make_wolf(enemy is Boss)
		"ice_spirit":
			actor = _make_spirit()
		_:
			actor = _make_draugr()
	_actors[enemy] = actor
	actor.position = _world(enemy.global_position)
	enemy.tree_exiting.connect(_remove_actor.bind(enemy, actor))
	if not enemy is Boss:
		_box(actor, Vector3(0, 0.88, 0), Vector3(0.38, 0.035, 0.035), Color("#222c35"), true)
		var hp_bar := _box(actor, Vector3(0, 0.89, 0), Vector3(0.36, 0.037, 0.037), WARNING, true)
		actor.set_meta("hp_bar", hp_bar)


func _remove_actor(enemy: Enemy, actor: Node3D) -> void:
	_actors.erase(enemy)
	if is_instance_valid(actor):
		actor.queue_free()


func _process(delta: float) -> void:
	_time += delta
	_update_camera(1.0 - exp(-9.0 * delta))
	_update_player(delta)
	_update_enemies()
	_update_effects()
	_marker.rotation.y = _time * 0.9


func _update_camera(weight: float) -> void:
	var target := _world(player.global_position)
	var center := Vector3(clampf(target.x + 0.75, -5.0, 5.0), 0.0, clampf(target.z, -1.55, 1.55))
	var offset := Vector3(0, 10.0, 8.0)
	_camera.position = _camera.position.lerp(center + offset, weight)
	_camera.look_at(_camera.position - offset, Vector3.UP)


func _update_player(delta: float) -> void:
	_swordsman.position = _world(player.global_position)
	var aim := player.weapon_aim() if player.weapon_pose_active() else player.facing
	_swordsman.rotation.y = lerp_angle(_swordsman.rotation.y, atan2(aim.x, aim.y), minf(1.0, delta * 28.0))
	_swordsman.rotation.x = -1.15 if player.is_dead else (-0.36 if player.is_dashing() else 0.0)
	var stride := sin(_time * 18.0) * minf(1.0, player.velocity.length() / 180.0)
	_player_legs[0].rotation.x = stride * 0.48
	_player_legs[1].rotation.x = -stride * 0.48
	var arm := -0.22 + 0.14 * stride
	if player.weapon_pose_active():
		arm = lerpf(1.45, -1.65, clampf(1.0 - player._attack_time / 0.40, 0.0, 1.0))
	_sword_arm.rotation.y = arm
	_swordsman.scale = Vector3(1.05, 0.82, 1.18) if player.is_dashing() else Vector3.ONE


func _update_enemies() -> void:
	_warning.hide()
	for enemy: Enemy in _actors:
		var actor := _actors[enemy]
		actor.position = _world(enemy.global_position)
		var aim := enemy.global_position.direction_to(player.global_position)
		if enemy is Skoll and enemy.state in ["windup", "dash"]:
			aim = enemy._dash_dir
		actor.rotation.y = atan2(aim.x, aim.y)
		actor.scale.y = 1.0 + sin(_time * 12.0 + enemy.get_instance_id()) * 0.035
		if enemy.type_id == "ice_spirit":
			actor.position.y = 0.12 + sin(_time * 5.0) * 0.08 + (0.16 if enemy._casting else 0.0)
		if actor.has_meta("hp_bar"):
			var hp_bar: MeshInstance3D = actor.get_meta("hp_bar")
			hp_bar.scale.x = maxf(0.01, enemy.hp / enemy.max_hp)
			hp_bar.visible = enemy.hp < enemy.max_hp
		if enemy is Skoll and enemy.state == "windup":
			_show_charge(enemy)
		elif enemy.type_id == "ice_spirit" and enemy._casting:
			actor.get_node("Cast").show()
		elif actor.has_node("Cast"):
			actor.get_node("Cast").hide()


func _show_charge(wolf: Skoll) -> void:
	var aim := wolf._dash_dir
	var length := Skoll.DASH_SPEED * Skoll.DASH_TIME * WORLD_SCALE
	var width := (wolf.radius + Player.RADIUS) * WORLD_SCALE * 2.0
	var forward := Vector3(aim.x, 0.0, aim.y)
	_warning.position = _world(wolf.global_position) + forward * length * 0.5 + Vector3.UP * 0.025
	_warning.rotation.y = atan2(aim.x, aim.y)
	_warning.scale = Vector3(width, 0.024, length + width)
	_warning.show()


func _update_effects() -> void:
	for shot: EnemyProjectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if not _shots.has(shot):
			var mesh := _box(self, Vector3.ZERO, Vector3(0.13, 0.13, 0.34), Color("#9ffaff"), true)
			_shots[shot] = mesh
			shot.tree_exiting.connect(_remove_shot.bind(shot, mesh))
		var visual := _shots[shot]
		visual.position = _world(shot.global_position) + Vector3.UP * 0.25
		visual.rotation.y = atan2(shot.direction.x, shot.direction.y)
	for child in get_parent().get_children():
		if child is LightningFx and not _lightning.has(child):
			child.hide()
			var strike := Node3D.new()
			strike.position = _world(child.to)
			add_child(strike)
			_ring(strike, child.blast_radius * WORLD_SCALE, GOLD, 0.027)
			_box(strike, Vector3(0, 1.8, 0), Vector3(0.085, 3.6, 0.085), GOLD, true).rotation_degrees.z = -8
			_lightning[child] = strike
			child.tree_exiting.connect(_remove_lightning.bind(child, strike))
	var skadi = player.gods.get("skadi")
	if skadi:
		for i in skadi._arrows.size():
			if i >= _ice_arrows.size():
				_ice_arrows.append(_box(self, Vector3.ZERO, Vector3(0.07, 0.09, 0.52), Color("#88eaff"), true))
			var arrow: Dictionary = skadi._arrows[i]
			var visual := _ice_arrows[i]
			visual.position = _world(arrow.pos) + Vector3.UP * 0.32
			visual.rotation.y = atan2(arrow.dir.x, arrow.dir.y)
			visual.show()
	for i in range(skadi._arrows.size() if skadi else 0, _ice_arrows.size()):
		_ice_arrows[i].hide()


func _remove_shot(shot: EnemyProjectile, visual: Node3D) -> void:
	_shots.erase(shot)
	if is_instance_valid(visual):
		visual.queue_free()


func _remove_lightning(source: LightningFx, visual: Node3D) -> void:
	_lightning.erase(source)
	if is_instance_valid(visual):
		visual.queue_free()


func show_slash(at: Vector2, direction: Vector2, radius: float, half_angle: float, critical: bool) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sweep := direction.angle()
	for i in 22:
		var a := sweep + lerpf(-half_angle, half_angle, float(i) / 22.0)
		var b := sweep + lerpf(-half_angle, half_angle, float(i + 1) / 22.0)
		var outer := radius * WORLD_SCALE
		var inner := outer * (0.88 - 0.16 * sin(PI * (float(i) + 0.5) / 22.0))
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(b), 0, sin(b))
		for vertex: Vector3 in [p * inner, p * outer, q * outer, p * inner, q * outer, q * inner]:
			surface.add_vertex(vertex)
	var slash := MeshInstance3D.new()
	slash.mesh = surface.commit()
	slash.position = _world(at) + Vector3.UP * 0.16
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := _material(GOLD if critical else Color("#e0f8ff"), true).duplicate() as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash.material_override = material
	add_child(slash)
	var tween := slash.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.19)
	tween.tween_callback(slash.queue_free)


func _terrain() -> void:
	_box(self, Vector3(0, -0.21, 0), Vector3(28, 0.40, 16), SNOW)
	var lake := _cylinder(self, Vector3(7.35, -0.01, 0), 1.0, 0.045, ICE, 12)
	lake.scale = Vector3(4.05, 1, 3.35)
	_path()
	for i in 100:
		var x := _rng.randf_range(-11.4, 11.4)
		var z := _rng.randf_range(-6.0, 6.0)
		if absf(z) < 1.2 and x < 5.0:
			continue
		var on_ice := Vector2((x - 7.35) / 4.05, z / 3.35).length() < 0.89
		var size := Vector3(_rng.randf_range(0.26, 1.25), 0.022, _rng.randf_range(0.15, 0.8))
		var color := ICE.lightened(_rng.randf_range(0.04, 0.12)) if on_ice else SNOW.lerp(FROST, _rng.randf())
		var patch := _cylinder(self, Vector3(x, (0.021 if on_ice else -0.002) + i * 0.00013, z), 0.7, 0.016, color, 7)
		patch.scale = Vector3(size.x, 1.0, size.z)
		patch.rotation.y = _rng.randf() * PI
	for point: Vector2 in [Vector2(-770, -285), Vector2(-470, -280), Vector2(-175, 285)]:
		_hall(point)
	for point: Vector2 in [Vector2(-910, -105), Vector2(-555, 148), Vector2(-315, -207),
			Vector2(-96, -108), Vector2(100, 105), Vector2(390, -115), Vector2(650, 284)]:
		_torch(point)
	for i in 9:
		var angle := TAU * float(i) / 9.0
		if i in [0, 4, 5]:
			continue
		var p := Vector2(10, 0) + Vector2.from_angle(angle) * 130.0
		var base := _world(p)
		_rock(base, Vector3(0.40, 1.34, 0.34), STONE)
		_box(self, base + Vector3(0, 0.82, 0.18), Vector3(0.056, 0.24, 0.024), GOLD, true).rotation.z = 0.30
		_block(p, 22.0)
	_cylinder(self, Vector3(0.10, 0.06, 0), 0.63, 0.16, STONE, 8)
	_ring(self, 0.44, GOLD, 0.023).position = Vector3(0.10, 0.16, 0)
	for i in 46:
		var x := _rng.randf_range(-11.5, 11.5)
		var z := _rng.randf_range(3.9, 6.0) * (1.0 if i % 2 == 0 else -1.0)
		if i % 4 == 0:
			_rock(Vector3(x, 0, z), Vector3(0.8, 0.7, 0.65) * _rng.randf_range(0.5, 1.5), STONE)
		else:
			_tree(Vector3(x, 0, z), _rng.randf_range(0.8, 1.5))
	for point: Vector2 in [Vector2(-650, 200), Vector2(-350, 180), Vector2(265, -215), Vector2(435, 216)]:
		_rock(_world(point), Vector3(0.76, 0.52, 0.63), STONE)
		_block(point, 34.0)
	for i in 8:
		var x := 4.0 + i * 0.93
		var z := -3.05 if i % 2 == 0 else 3.02
		_rock(Vector3(x, 0, z), Vector3(0.65, 0.42, 0.56), ICE.darkened(0.23))
		_block(Vector2(x, z) / WORLD_SCALE, 26.0)


func _path() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 36:
		var x := -11.2 + i * 0.43
		var center := sin(x * 0.48) * 0.42
		var shade := Color("#6d797b").lerp(Color("#8c9691"), _rng.randf())
		for side in [-1.0, 1.0]:
			surface.set_color(shade)
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(x, 0.005, center + side * _rng.randf_range(0.56, 0.95)))
	var path := _mesh(self, surface.commit(), Vector3.ZERO, Color.WHITE)
	var material := path.material_override.duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	path.material_override = material


func _hall(point: Vector2) -> void:
	var p := _world(point)
	_box(self, p + Vector3(0, 0.16, 0), Vector3(2.48, 0.35, 1.51), STONE)
	_box(self, p + Vector3(0, 0.58, 0), Vector3(2.35, 0.98, 1.38), WOOD)
	for side in [-1.0, 1.0]:
		var roof := _box(self, p + Vector3(0, 1.29, side * 0.43), Vector3(2.72, 0.12, 1.10), ROOF)
		roof.rotation.x = side * 0.56
		var cap := _box(self, p + Vector3(0, 1.39, side * 0.41), Vector3(2.40, 0.045, 0.76), FROST)
		cap.rotation.x = roof.rotation.x
	for i in 5:
		var x := -1.05 + i * 0.52
		_box(self, p + Vector3(x, 0.57, 0.71), Vector3(0.075, 0.86, 0.10), WOOD.darkened(0.34))
		_block(point + Vector2(x * 100.0, -35), 42.0)
		_block(point + Vector2(x * 100.0, 35), 42.0)
	_box(self, p + Vector3(0.56, 0.61, 0.77), Vector3(0.30, 0.32, 0.025), GOLD, true)
	_box(self, p + Vector3(-0.48, 0.41, 0.77), Vector3(0.40, 0.71, 0.035), WOOD.darkened(0.43))


func _tree(p: Vector3, height: float) -> void:
	_cylinder(self, p + Vector3.UP * 0.37 * height, 0.075 * height, 0.74 * height, WOOD, 6)
	for i in 3:
		var cone := CylinderMesh.new()
		cone.radial_segments = 6
		cone.top_radius = 0.0
		cone.bottom_radius = (0.51 - i * 0.12) * height
		cone.height = 0.75 * height
		_mesh(self, cone, p + Vector3.UP * (0.67 + i * 0.32) * height, Color("#3e6664").lerp(Color("#8aa4a0"), i * 0.25))


func _torch(point: Vector2) -> void:
	var p := _world(point)
	_cylinder(self, p + Vector3.UP * 0.22, 0.08, 0.44, WOOD, 6)
	_cylinder(self, p + Vector3.UP * 0.46, 0.14, 0.11, STONE, 6)
	_rock(p + Vector3.UP * 0.49, Vector3(0.12, 0.31, 0.12), WARM, true)
	var light := OmniLight3D.new()
	light.position = p + Vector3.UP * 0.78
	light.light_color = WARM
	light.light_energy = 1.35
	light.omni_range = 2.3
	add_child(light)


func _make_swordsman() -> Node3D:
	var actor := Node3D.new()
	add_child(actor)
	var dark := Color("#263244")
	var cloak := Color("#8c342e")
	for x in [-0.12, 0.12]:
		var leg := Node3D.new()
		leg.position = Vector3(x, 0.33, 0)
		actor.add_child(leg)
		_player_legs.append(leg)
		_box(leg, Vector3(0, -0.13, 0), Vector3(0.15, 0.28, 0.16), dark)
		_box(leg, Vector3(0, -0.27, 0.044), Vector3(0.16, 0.105, 0.23), WOOD)
	_box(actor, Vector3(0, 0.52, 0), Vector3(0.43, 0.35, 0.28), Color("#d4c2a3"))
	_box(actor, Vector3(0, 0.43, -0.146), Vector3(0.37, 0.53, 0.071), cloak).rotation.x = -0.20
	_box(actor, Vector3(0, 0.63, 0.03), Vector3(0.46, 0.13, 0.31), cloak)
	_rock(Vector3(0, 0.68, 0.024), Vector3(0.27, 0.30, 0.26), dark, false, actor)
	_box(actor, Vector3(0, 0.80, 0.145), Vector3(0.18, 0.09, 0.041), Color("#deb193"))
	_box(actor, Vector3(-0.28, 0.50, 0.034), Vector3(0.13, 0.30, 0.14), dark)
	_sword_arm = Node3D.new()
	_sword_arm.position = Vector3(0.28, 0.59, 0.04)
	actor.add_child(_sword_arm)
	_box(_sword_arm, Vector3(0, -0.076, 0.10), Vector3(0.13, 0.15, 0.28), dark)
	_box(_sword_arm, Vector3(0, -0.07, 0.25), Vector3(0.18, 0.075, 0.07), GOLD)
	_box(_sword_arm, Vector3(0, -0.07, 0.54), Vector3(0.060, 0.042, 0.57), Color("#dcebf1"))
	_ring(actor, 0.28, Color("#d0f0ef"), 0.017)
	return actor


func _make_draugr() -> Node3D:
	var actor := Node3D.new()
	add_child(actor)
	var fur := Color("#68756b")
	for x in [-0.11, 0.11]:
		_box(actor, Vector3(x, 0.16, 0), Vector3(0.14, 0.31, 0.17), WOOD)
		_box(actor, Vector3(x * 2.1, 0.48, 0.11), Vector3(0.12, 0.25, 0.21), fur).rotation.x = 0.5
	_box(actor, Vector3(0, 0.43, 0), Vector3(0.35, 0.34, 0.28), fur)
	_rock(Vector3(0, 0.57, 0.10), Vector3(0.24, 0.26, 0.22), STONE, false, actor)
	_box(actor, Vector3(0, 0.69, 0.22), Vector3(0.16, 0.036, 0.026), WARM, true)
	return actor


func _make_spirit() -> Node3D:
	var actor := Node3D.new()
	add_child(actor)
	_rock(Vector3(0, 0.12, 0), Vector3(0.33, 0.55, 0.32), Color("#558b9e"), false, actor)
	_rock(Vector3(0, 0.56, 0.04), Vector3(0.25, 0.25, 0.25), FROST, false, actor)
	_box(actor, Vector3(0, 0.67, 0.145), Vector3(0.12, 0.05, 0.04), Color("#7affff"), true)
	var cast := _ring(actor, 0.36, Color("#80ecff"), 0.028)
	cast.name = "Cast"
	cast.hide()
	return actor


func _make_wolf(large: bool) -> Node3D:
	var actor := Node3D.new()
	add_child(actor)
	var fur := Color("#283945") if large else Color("#647e89")
	_rock(Vector3(0, 0.23, -0.06), Vector3(0.37, 0.29, 0.67), fur, false, actor)
	for x in [-0.14, 0.14]:
		for z in [-0.24, 0.18]:
			_box(actor, Vector3(x, 0.15, z), Vector3(0.09, 0.30, 0.11), fur)
		_box(actor, Vector3(x * 0.63, 0.48, 0.30), Vector3(0.067, 0.17, 0.088), fur).rotation.z = x
		_box(actor, Vector3(x * 0.68, 0.39, 0.45), Vector3(0.063, 0.04, 0.036), GOLD if large else FROST, true)
	_box(actor, Vector3(0, 0.42, 0.30), Vector3(0.26, 0.23, 0.29), fur)
	_box(actor, Vector3(0, 0.32, 0.47), Vector3(0.16, 0.12, 0.19), fur.darkened(0.2))
	_box(actor, Vector3(0, 0.33, -0.49), Vector3(0.10, 0.12, 0.38), fur).rotation.x = 0.31
	if large:
		var meshes := actor.get_children()
		var body := Node3D.new()
		actor.add_child(body)
		for child in meshes:
			child.reparent(body, false)
		body.scale = Vector3(2.1, 2.1, 2.1)
		_ring(actor, 0.52, Color(WARNING, 0.75), 0.025)
	return actor


func _block(point: Vector2, radius: float) -> void:
	MapLayer.add_obstacle(point + Vector2(0, MapLayer.FOOT), radius)


func _world(point: Vector2) -> Vector3:
	return Vector3(point.x, 0, point.y) * WORLD_SCALE


func _material(color: Color, unshaded: bool) -> StandardMaterial3D:
	var key := Vector2i(color.to_rgba32(), int(unshaded))
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if unshaded:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = material
	return _materials[key]


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, unshaded := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color, unshaded)
	node.position = at
	if unshaded:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, unshaded := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, color, unshaded)


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, segments: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return _mesh(parent, mesh, at, color)


func _rock(at: Vector3, size: Vector3, color: Color, unshaded := false, parent: Node3D = self) -> MeshInstance3D:
	var rock := SphereMesh.new()
	rock.radial_segments = 6
	rock.rings = 2
	var mesh := _mesh(parent, rock, at + Vector3.UP * size.y * 0.5, color, unshaded)
	mesh.scale = size
	return mesh


func _ring(parent: Node3D, radius: float, color: Color, thickness: float) -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = maxf(0.01, radius - thickness)
	ring.outer_radius = radius
	ring.rings = 32
	ring.ring_segments = 5
	return _mesh(parent, ring, Vector3.UP * 0.041, color, true)
