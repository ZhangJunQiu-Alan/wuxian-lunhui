extends SceneTree

const COURTYARD := "res://scenes/fimbulwinter_courtyard.tscn"
const STELE_POSE := Vector2(-1405, -103)
const POSES := [
	[Vector2(-1450, -386), "PaintedApproachForeground", "approach-stele-occlusion"],
	[Vector2(145, -638), "PaintedLonghouse", "longhouse-occlusion"],
	[Vector2(-1950, 348), "PaintedApproachForeground", "approach-fir-occlusion"],
	[Vector2(-2614, 236), "PaintedApproachForeground", "spawn-fir-occlusion"],
]

var _directory := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_directory = argument.trim_prefix("--capture-dir=")
	if _directory.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Set --capture-dir for the rendered evidence run")
		quit(2)
		return
	if root.get_node("Save").path == "user://save.json" or root.get_node("Settings").path == "user://settings.cfg":
		push_error("Use isolated --save-file and --settings-file")
		quit(2)
		return

	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.unresizable = true
	root.get_node("Settings").language = "zh"
	root.get_node("Settings")._apply_language()
	change_scene_to_file(COURTYARD)
	await process_frame
	await process_frame

	var room := current_scene
	var stage: Node3D = room.stage
	var grid: GDScript = load("res://scripts/world/map_layer.gd")
	room.set_process(false)
	room.player.set_physics_process(false)
	room._objective.hide()
	paused = true
	if grid.push_out(STELE_POSE, room.player.RADIUS).distance_to(STELE_POSE) > 0.1:
		push_error("The close-up pose intersects the stele collision")
		quit(1)
		return
	if not await _capture_stele(room, stage):
		quit(1)
		return
	for entry: Array in POSES:
		var pose: Vector2 = entry[0]
		var layer: MeshInstance3D = stage.get_node("PaintedCourtyard/" + entry[1])
		var output: String = entry[2]
		if grid.push_out(pose, room.player.RADIUS).distance_to(pose) > 0.1:
			push_error("The capture pose intersects collision for " + output)
			quit(1)
			return
		if not await _capture(room, stage, pose, layer, output):
			quit(1)
			return
	quit()


func _capture_stele(room: Node, stage: Node3D) -> bool:
	room.player.position = STELE_POSE
	stage._sync_hero()
	var camera: Camera3D = stage.camera
	var framing := -camera.basis.x * 1.72 + camera.basis.y * 1.84
	camera.position = stage.world_at(STELE_POSE) + stage.CAMERA_OFFSET + framing
	camera.size = 4.8
	var closeup := await _frame()
	var result := closeup.save_png(_directory.path_join("stele-closeup.png"))
	print("COURTYARD_STELE_CLOSEUP ", error_string(result))
	return result == OK


func _capture(room: Node, stage: Node3D, pose: Vector2, layer: MeshInstance3D, output: String) -> bool:
	room.player.position = pose
	stage._sync_hero()
	var feet: Vector3 = stage.world_at(pose)
	stage.camera.position = feet + Vector3(.75, .65, .45) + stage.CAMERA_OFFSET
	stage.camera.size = 5.8
	var covered := await _frame()
	layer.hide()
	var uncovered := await _frame()
	layer.show()

	var at: Vector2 = stage.camera.unproject_position(feet)
	var tracked := Rect2i(Vector2i(at) - Vector2i(34, 123), Vector2i(68, 131))
	var outline_pixels := 0
	for y in range(tracked.position.y, tracked.end.y):
		for x in range(tracked.position.x, tracked.end.x):
			var ink := covered.get_pixel(x, y)
			var control := uncovered.get_pixel(x, y)
			if ink.b > .68 and ink.g > .54 and ink.b - ink.r > .18 and ink.b - control.b > .20:
				outline_pixels += 1
	print("COURTYARD_OCCLUSION_RESULT ", output, ": collision clear, ", outline_pixels, " outline pixels")
	return outline_pixels >= 25 and covered.save_png(_directory.path_join(output + ".png")) == OK


func _frame() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
