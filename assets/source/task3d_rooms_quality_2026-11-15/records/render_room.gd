extends SceneTree
var stage: Node3D
func _initialize() -> void:
	run.call_deferred()
func spawn(id: String, position: Vector3, pose := 0.0) -> Node3D:
	var model = load("res://assets/models/midgard/quality/"+id+".glb").instantiate()
	stage.add_child(model)
	model.position = position
	if pose > 0:
		var player: AnimationPlayer = model.find_children("*","AnimationPlayer",true,false)[0]
		player.play("spike")
		player.seek(pose,true)
		player.pause()
	return model
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1800,1400)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage=Node3D.new(); viewport.add_child(stage)
	var world = WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color(.025,.035,.05)
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color(.56,.65,.78)
	world.environment.ambient_light_energy=.18
	world.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	stage.add_child(world)
	for x in [-3.2,0.0,3.2]:
		for z in [-3.2,0.0,3.2]:
			if not (x==0 and z==0): spawn("snow_floor",Vector3(x,0,z))
	spawn("void_causeway",Vector3(0,.09,0))
	spawn("spike_trap",Vector3(-3.25,.08,1.7),1.1)
	spawn("pressure_plate",Vector3(0,.07,3.3))
	spawn("lever",Vector3(3.2,.08,1.85))
	spawn("rune_trap",Vector3(3.1,.07,-2.7))
	spawn("rune_gate",Vector3(0,.04,-4.78))
	for x in [-2.2,2.2]:
		spawn("brazier",Vector3(x,.08,-3.68))
		var fire=OmniLight3D.new(); stage.add_child(fire)
		fire.position=Vector3(x,1.4,-3.68); fire.light_color=Color(1,.3,.075); fire.light_energy=.18; fire.omni_range=3.5
	var floor=MeshInstance3D.new(); floor.mesh=PlaneMesh.new(); floor.mesh.size=Vector2(80,80)
	var mat=StandardMaterial3D.new(); mat.albedo_color=Color(.018,.023,.031); mat.roughness=1
	floor.material_override=mat; floor.position.y=-1.4; stage.add_child(floor)
	for config in [[Vector3(-5,10,7),Color(.68,.8,1),.45],[Vector3(7,7,0),Color(1,.65,.4),.18],[Vector3(0,8,-8),Color(.45,.65,1),.25]]:
		var light=DirectionalLight3D.new(); stage.add_child(light)
		light.position=config[0]; light.look_at(Vector3(0,0,0)); light.light_color=config[1]; light.light_energy=config[2]; light.shadow_enabled=true
	var camera=Camera3D.new(); stage.add_child(camera)
	camera.position=Vector3(10,14,15); camera.look_at(Vector3(0,.9,-.25))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=12.5; camera.current=true
	for i in range(16): await process_frame
	await RenderingServer.frame_post_draw
	var result=viewport.get_texture().get_image().save_png("res://assets/source/task3d_rooms_quality_2026-11-15/previews/godot_assets.png")
	print("QUALITY_ROOM_RENDER result=",result)
	viewport.queue_free(); await process_frame
	quit(result)
