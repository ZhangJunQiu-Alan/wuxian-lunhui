extends SceneTree

const NAMES := ["snowcliff", "approach", "entry", "longhouse", "east-gate"]
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
	root.get_node("Settings").language = "zh"
	root.get_node("Settings")._apply_language()
	change_scene_to_file("res://scenes/fimbulwinter_courtyard.tscn")
	await process_frame
	await process_frame
	var room := current_scene
	var stage: Node3D = room.stage
	room.set_process(false)
	room.player.set_physics_process(false)
	room._objective.hide()
	paused = true
	var grid: GDScript = load("res://scripts/world/map_layer.gd")
	for i in stage.FIRES.size():
		var point: Vector2 = stage.Layout.expand(stage.FIRES[i])
		var pose := point + Vector2(150, 100)
		for offset in [Vector2(150, 100), Vector2(-150, 100), Vector2(130, -100), Vector2(-130, -100), Vector2(180, 0)]:
			var candidate: Vector2 = point + offset
			if grid.push_out(candidate, room.player.RADIUS).is_equal_approx(candidate):
				pose = candidate
				break
		room.player.position = pose
		stage._sync_hero()
		var camera: Camera3D = stage.camera
		camera.position = stage.world_at(point) + stage.CAMERA_OFFSET + camera.basis.x * .5 + camera.basis.y * .35
		camera.size = 5.6
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var filename := "brazier-%02d-%s.png" % [i + 1, NAMES[i]]
		if root.get_texture().get_image().save_png(directory.path_join(filename)) != OK:
			quit(1)
			return
		print("BRAZIER ", filename, " pose ", pose)
	quit()
