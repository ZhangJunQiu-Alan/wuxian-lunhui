extends "res://tools/review_vigrid.gd"

func _run() -> void:
	root.get_node("Settings").language="zh"
	root.get_node("Settings")._apply_language()
	AudioServer.set_bus_mute(0,true)
	await super._run()

func _new_game() -> void:
	root.get_node("Settings").language="zh"
	root.get_node("Settings")._apply_language()
	await super._new_game()
	for weapon in [_player.katana,_player.revolver,_player.blades,_player.nova]:
		if weapon: weapon.process_mode=Node.PROCESS_MODE_DISABLED
	for power in _player.gods.values():
		power.process_mode=Node.PROCESS_MODE_DISABLED
		power.visible=false
	_game._spawn_timer=1.0e9
	_game.set_process_unhandled_input(false)
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").screen_shake=0.0
	root.get_node("Settings").language="zh"
	root.get_node("Settings")._apply_language()

func _process(_delta: float) -> bool:
	if is_instance_valid(_game) and _game.pause_menu._root.visible:
		_game.pause_menu.close()
	return false

func _wait(frames: int) -> void:
	for i in frames:
		if is_instance_valid(_game) and _game.pause_menu._root.visible:
			_game.pause_menu.close()
		if is_instance_valid(_player):
			for power in _player.gods.values():
				power.process_mode=Node.PROCESS_MODE_DISABLED
				power.visible=false
		await physics_frame

func _shot(name: String, note: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	var status := root.get_texture().get_image().save_png(_out.path_join(name+".png"))
	_shots.append({"file":name+".png","ok":status==OK,"window":[_size.x,_size.y],"note":note,"forced_render":true})
	print("SHOT ",name," ",status)
	if not is_instance_valid(_game): return
	var viewport: Viewport = _game.get_viewport()
	var world: Rect2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	var bounds: Rect2 = load("res://scripts/game.gd").view_bounds
	var item: Dictionary = _shots.back()
	item.camera_world_rect=[world.position.x,world.position.y,world.size.x,world.size.y]
	item.camera_inside_map=bounds.grow(2.0).encloses(world)
	item.master_muted=AudioServer.is_bus_mute(0)
	if not item.camera_inside_map:
		push_error("Camera sees outside map: "+name+" "+str(world))
