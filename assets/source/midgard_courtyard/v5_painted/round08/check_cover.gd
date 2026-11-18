extends SceneTree

const Layout := preload("res://scripts/roguelite/fimbulwinter_courtyard_layout.gd")
const SCENE := "res://scenes/fimbulwinter_courtyard.tscn"
var checks := 0
var failed := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)


func run() -> void:
	var dest := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			dest = arg.trim_prefix("--capture-dir=")
	if dest.is_empty() or DisplayServer.get_name() == "headless" or root.get_node("Save").path == "user://save.json" or root.get_node("Settings").path == "user://settings.cfg":
		quit(2)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.get_node("Settings").language = "zh"
	root.get_node("Settings")._apply_language()
	change_scene_to_file(SCENE)
	await process_frame
	await process_frame
	var room := current_scene
	var stage: Node3D = room.stage
	var player: Node2D = room.player
	var grid: GDScript = load("res://scripts/world/map_layer.gd")
	room.bounds = Rect2(room.SEALED_EDGE, -936, room.CLOSED_EDGE-room.SEALED_EDGE, 1872)
	room.set_process(false)
	room._objective.hide()
	paused = true
	for c in Layout.COVERS:
		var foot: Vector2 = c.foot
		check(grid.push_out(foot, player.RADIUS).distance_to(foot) >= c.radius + player.RADIUS, c.id + " walk collision")
		var clearance: float = c.radius + player.RADIUS + 2.0
		var lap_clear := true
		for i in 72:
			var step := foot + Vector2.from_angle(TAU * i / 72.0) * (clearance + 8.0)
			lap_clear = lap_clear and grid.push_out(step,player.RADIUS).is_equal_approx(step)
		check(lap_clear, c.id + " full walking circuit")
		player.position = foot - Vector2.RIGHT * clearance
		var landing: Vector2 = player.weapon_dash(Vector2.RIGHT,player.DASH_DISTANCE)
		check(landing.x >= foot.x + clearance - 2.0 and grid.push_out(landing,player.RADIUS).is_equal_approx(landing),
			c.id + " axial dash lands clear on the far side")
		var offset := Vector2.DOWN * sqrt(maxf(clearance * clearance - 70.0 * 70.0, 0.0))
		player.position = foot + offset - Vector2.RIGHT * 75
		var end: Vector2 = player.weapon_dash(Vector2.RIGHT,player.DASH_DISTANCE)
		check(end.is_equal_approx(foot + offset + Vector2.RIGHT*75), c.id + " dash clears both edges")
	var wall := Layout.expand(Vector2(161,693))
	player.position = wall - Vector2.DOWN*75
	check(player.weapon_dash(Vector2.DOWN,player.DASH_DISTANCE).y < wall.y, "dash stops at the southern parapet")
	check(grid.push_out(Layout.RING,player.RADIUS).is_equal_approx(Layout.RING), "rune ring is walkable")
	for c in Layout.COVERS:
		await check_silhouette(stage, player, grid, c, dest)
	print("ROUND08_COVER ", checks, " checks, ", failed, " failures")
	quit(int(failed > 0))


func check_silhouette(stage: Node3D, player: Node2D, grid: GDScript, c: Dictionary, dest: String) -> void:
	var cover: Sprite3D = stage._painted.get_node(c.id)
	var foot: Vector2 = c.foot
	var back: Vector2 = Vector2(stage.CAMERA_OFFSET.x,stage.CAMERA_OFFSET.z).normalized()
	player.position = foot - back*(c.radius + player.RADIUS + 4.0)
	check(grid.push_out(player.position,player.RADIUS).is_equal_approx(player.position), "occlusion pose is reachable")
	stage._sync_hero()
	stage.camera.position = stage.world_at(player.position) + Vector3(.55,.72,.2) + stage.CAMERA_OFFSET
	stage.camera.size = 5.6
	var covered := await frame()
	var outline: MeshInstance3D = stage._hero.get_node("OccludedOutline")
	outline.hide()
	var without_outline := await frame()
	outline.show()
	cover.hide()
	var uncovered := await frame()
	cover.show()
	var xy: Vector2i = Vector2i(stage.camera.unproject_position(stage.world_at(player.position)))
	var pixels := 0
	for y in range(xy.y-145,xy.y+8):
		for x in range(xy.x-39,xy.x+39):
			var ink := covered.get_pixel(x,y)
			if ink.b-without_outline.get_pixel(x,y).b > .13 and ink.b-uncovered.get_pixel(x,y).b > .14:
				pixels += 1
	check(pixels >= 40, "cover-specific outline in actor region")
	print("ROUND08_OUTLINE ", c.id, " ", pixels)
	if c.id == "broken-stele":
		check(covered.save_png(dest.path_join("cover-occlusion.png")) == OK, "save occlusion frame")


func frame() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
