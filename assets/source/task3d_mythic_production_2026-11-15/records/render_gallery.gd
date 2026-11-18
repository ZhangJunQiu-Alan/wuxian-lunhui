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
		player.play("open")
		player.seek(pose,true)
		player.pause()
	return model
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2000,1600)
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
	for x in [-6.4,-3.2,0.0,3.2,6.4]:
		for z in [-9.6,-6.4,-3.2,0.0,3.2]:spawn("snow_floor",Vector3(x,0,z))
	for placement in [["odin_portal",Vector3(0,.08,-7.6)],["yggdrasil_altar",Vector3(-4.8,.08,-3.9)],["norn_well",Vector3(4.8,.08,-4.1)],["bifrost_bridge",Vector3(0,.15,-1.6)],["bifrost_pillar",Vector3(-1.8,.08,-1.6)],["bifrost_pillar",Vector3(1.8,.08,-1.6)],["valhalla_wall",Vector3(-5.4,.08,-8.8)],["thor_shrine",Vector3(4.8,.08,.6)],["skadi_shrine",Vector3(-4.8,.08,.6)],["hel_gate",Vector3(5.3,.08,-8.8)],["offering_table",Vector3(0,.08,2.8)],["hero_swordsman",Vector3(-5,0,4.2)],["enemy_draugr",Vector3(-2.5,0,4.2)],["enemy_winter_wolf",Vector3(0,0,4.2)],["boss_skoll",Vector3(3,0,4.2)],["enemy_ice_spirit",Vector3(6,0,4.2)]]:
		spawn(placement[0],placement[1])
	var floor=MeshInstance3D.new(); floor.mesh=PlaneMesh.new(); floor.mesh.size=Vector2(80,80)
	var mat=StandardMaterial3D.new(); mat.albedo_color=Color(.018,.023,.031); mat.roughness=1
	floor.material_override=mat; floor.position.y=-.4; stage.add_child(floor)
	for config in [[Vector3(-5,10,7),Color(.68,.8,1),.45],[Vector3(7,7,0),Color(1,.65,.4),.18],[Vector3(0,8,-8),Color(.45,.65,1),.25]]:
		var light=DirectionalLight3D.new(); stage.add_child(light)
		light.position=config[0]; light.look_at(Vector3(0,0,0)); light.light_color=config[1]; light.light_energy=config[2]; light.shadow_enabled=true
	var camera=Camera3D.new(); stage.add_child(camera)
	camera.position=Vector3(18,23,24); camera.look_at(Vector3(0,1,-3.5))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=20; camera.current=true
	for i in range(16): await process_frame
	await RenderingServer.frame_post_draw
	var result=viewport.get_texture().get_image().save_png("res://assets/source/task3d_mythic_production_2026-11-15/previews/godot_assets.png")
	print("PRODUCTION_RENDER result=",result)
	viewport.queue_free(); await process_frame
	quit(result)
