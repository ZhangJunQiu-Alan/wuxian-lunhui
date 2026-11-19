extends SceneTree

var directory := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			directory = arg.trim_prefix("--capture-dir=")
	if directory.is_empty() or DisplayServer.get_name() == "headless" or root.get_node("Save").path == "user://save.json" or root.get_node("Settings").path == "user://settings.cfg":
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/fimbulwinter_courtyard.tscn")
	await process_frame
	await process_frame
	var room := current_scene
	var stage: Node3D = room.stage
	room.set_process(false)
	room.player.set_physics_process(false)
	room._objective.hide()
	paused = true
	var point: Vector2 = stage.Layout.expand(stage.FIRES[1])
	stage.camera.position = stage.world_at(point) + stage.CAMERA_OFFSET + stage.camera.basis.y * .3
	stage.camera.size = 3.6
	var grid: GDScript = load("res://scripts/world/map_layer.gd")
	for item in [["south", Vector2(-35, 55)], ["north", Vector2(65, -100)]]:
		var pose: Vector2 = point + item[1]
		if not grid.push_out(pose, room.player.RADIUS).is_equal_approx(pose):
			push_error("Blocked pose: " + str(item[0]))
			quit(1)
			return
		print("DEPTH_POSE ", item[0], " ", pose, " collision ", grid.push_out(pose, room.player.RADIUS))
		room.player.position = pose
		stage._sync_hero()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(directory.path_join("brazier-depth-" + item[0] + ".png")) != OK:
			quit(1)
			return
	quit()
