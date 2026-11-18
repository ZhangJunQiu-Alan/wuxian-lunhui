extends SceneTree

const COURTYARD := "res://scenes/fimbulwinter_courtyard.tscn"
const PAINT := preload("res://scripts/roguelite/fimbulwinter_courtyard_painted.gd")
const MANIFEST := "res://assets/source/midgard_courtyard/v5_painted/stele_variants/分配.json"
const BACKUP := "res://assets/source/midgard_courtyard/v5_painted/stele_variants/过程/原图集/"
const POSES := [Vector2(-2666, -139), Vector2(-2213, -97), Vector2(-1769, -186),
	Vector2(-1501, -149), Vector2(-1037, -109)]
const BACK_POSES := [Vector2(-1450, -386), Vector2(-1430, -400), Vector2(-1452, -379)]

var _directory := ""
var _before := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_directory = arg.trim_prefix("--capture-dir=")
		elif arg == "--before":
			_before = true
	if _directory.is_empty() or DisplayServer.get_name() == "headless" or root.get_node("Save").path == "user://save.json" or root.get_node("Settings").path == "user://settings.cfg":
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
	if _before and not _load_before_atlases(stage):
		quit(1)
		return
	room.set_process(false)
	room.player.set_physics_process(false)
	room._objective.hide()
	paused = true

	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var grid: GDScript = load("res://scripts/world/map_layer.gd")
	for index in POSES.size():
		var pose: Vector2 = POSES[index]
		if not grid.push_out(pose, room.player.RADIUS).is_equal_approx(pose):
			push_error("Blocked close-up pose at slot %d" % (index + 1))
			quit(1)
			return
		var point: Array = data.placements[index].foot_px
		var foot := Vector2(point[0], point[1])
		_set_pose(stage, room.player, pose, foot)
		var shot := await _frame()
		var filename := "stele-%s.png" % data.placements[index].variant.to_lower()
		if shot.save_png(_directory.path_join(filename)) != OK:
			quit(1)
			return
		print("STELE_CLOSEUP ", filename, " collision clear")
	if not _before and not await _silhouette(stage, room.player, grid):
		push_error("No rendered stele silhouette found")
		quit(1)
		return
	quit()


func _load_before_atlases(stage: Node3D) -> bool:
	var painting: ShaderMaterial = stage._painted.get_node("PaintedGround").material_override
	var foreground: ShaderMaterial = stage._painted.get_node("PaintedApproachForeground").material_override
	for entry: Array in [
		[painting, "painting", "room-ground.png"],
		[foreground, "painting", "approach-foreground.png"],
		[foreground, "painted_depth", "depth-approach-foreground.png"],
	]:
		var image := Image.load_from_file(BACKUP + entry[2])
		if image == null or image.is_empty():
			push_error("Could not load original atlas " + entry[2])
			return false
		entry[0].set_shader_parameter(entry[1], ImageTexture.create_from_image(image))
	return true


func _set_pose(stage: Node3D, player: Node2D, pose: Vector2, foot: Vector2) -> void:
	player.position = pose
	stage._sync_hero()
	var camera: Camera3D = stage.camera
	var guide_center := PAINT.CANVAS_CENTER - camera.basis.x * 18.0 - camera.basis.y * 4.0
	var anchor := guide_center + camera.basis.x * ((foot.x - 768.0) / 32.0) + camera.basis.y * ((512.0 - foot.y) / 32.0)
	camera.position = anchor + stage.CAMERA_OFFSET + camera.basis.x * 0.7 + camera.basis.y * 0.95
	camera.size = 5.6


func _silhouette(stage: Node3D, player: Node2D, grid: GDScript) -> bool:
	var layer: MeshInstance3D = stage._painted.get_node("PaintedApproachForeground")
	for pose: Vector2 in BACK_POSES:
		if not grid.push_out(pose, player.RADIUS).is_equal_approx(pose):
			continue
		_set_pose(stage, player, pose, Vector2(841, 571))
		var covered := await _frame()
		layer.hide()
		var uncovered := await _frame()
		layer.show()
		var at := Vector2i(stage.camera.unproject_position(stage.world_at(pose)))
		var pixels := 0
		for y in range(at.y - 132, at.y + 8):
			for x in range(at.x - 45, at.x + 45):
				var shade := covered.get_pixel(x, y)
				if shade.b > .68 and shade.g > .54 and shade.b - shade.r > .18 and shade.b - uncovered.get_pixel(x, y).b > .20:
					pixels += 1
		if pixels >= 25:
			print("STELE_SILHOUETTE ", pixels, " outline pixels at ", pose)
			return covered.save_png(_directory.path_join("stele-occlusion.png")) == OK
	return false


func _frame() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
