extends SceneTree
var stage: Node3D
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1400,1200)
	stage = Node3D.new()
	root.add_child(stage)
	var model = load("res://assets/models/midgard/quality/rune_gate.glb").instantiate()
	stage.add_child(model)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.035,.045,.06)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.65,.74,.85)
	env.environment.ambient_light_energy = .5
	stage.add_child(env)
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(30,30)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(.045,.052,.062)
	mat.roughness = .95
	floor_mesh.material_override = mat
	floor_mesh.position.y = -.08
	stage.add_child(floor_mesh)
	for config in [[Vector3(-3,7,4),Color(.7,.8,1),2.0],[Vector3(4,4,-2),Color(1,.7,.45),1.2]]:
		var light = DirectionalLight3D.new()
		stage.add_child(light)
		light.position=config[0]
		light.look_at(Vector3(0,2,0))
		light.light_color=config[1]
		light.light_energy=config[2]
		light.shadow_enabled=true
	var camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(5,5.5,9)
	camera.look_at(Vector3(0,2.1,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=5.5
	camera.current=true
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets/source/task3d_gate_quality_2026-11-15/previews/godot_gate.png")
	print("QUALITY_GATE_RENDER_SAVED")
	stage.queue_free()
	await process_frame
	quit()
