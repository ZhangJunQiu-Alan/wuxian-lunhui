extends SceneTree

const SCENE := "res://scenes/fimbulwinter_courtyard.tscn"

var _room: Node
var _failed := 0
var _checks := 0
var _capture_dir := ""
var _walkthrough := false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error(message)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = _room.stage.camera.unproject_position(_room.stage.world_at(point))
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _capture(name: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var was_paused := paused
	paused = true
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(_capture_dir.path_join(name + ".png")) == OK, "capture " + name)
	paused = was_paused


func _capture_exit(name: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var stage: Node3D = _room.stage
	var camera_at: Vector3 = stage.camera.position
	var size: float = stage.camera.size
	stage.camera.position = stage.exit_gate_position() + Vector3(-.45, .52, -.22) + stage.CAMERA_OFFSET
	stage.camera.size = 6.4
	await _capture(name)
	stage.camera.position = camera_at
	stage.camera.size = size


func _advance(right_of: float, limit: int) -> void:
	_key(KEY_D, true)
	for i in limit:
		await physics_frame
		if _room.player.position.x >= right_of or paused:
			break
	_key(KEY_D, false)


func _walk_to(point: Vector2) -> void:
	for i in 230:
		var offset: Vector2 = point - _room.player.position
		if offset.length() <= 23.0 or paused:
			break
		_key(KEY_A, offset.x < -12.0)
		_key(KEY_D, offset.x > 12.0)
		_key(KEY_W, offset.y < -12.0)
		_key(KEY_S, offset.y > 12.0)
		await _wait(0.075)
	for key in [KEY_A, KEY_D, KEY_W, KEY_S]:
		_key(key, false)


func _fight() -> void:
	for i in 175:
		var foes := get_nodes_in_group("enemies")
		if foes.is_empty() or _room.player.is_dead:
			return
		var nearest: Node2D = foes[0]
		for foe: Node2D in foes:
			if foe.position.distance_squared_to(_room.player.position) < nearest.position.distance_squared_to(_room.player.position):
				nearest = foe
		var offset: Vector2 = nearest.position - _room.player.position
		var horizontal := KEY_A if offset.x < 0.0 else KEY_D
		var vertical := KEY_W if offset.y < 0.0 else KEY_S
		if offset.length() > 59.0:
			_key(horizontal, absf(offset.x) >= 18.0)
			_key(vertical, absf(offset.y) >= 18.0)
		_click(nearest.position + offset.normalized() * 18.0)
		await _wait(0.14)
		_key(horizontal, false)
		_key(vertical, false)


func _run() -> void:
	create_timer(145.0).timeout.connect(func() -> void:
		push_error("Courtyard end-to-end test exceeded its time limit")
		quit(1)
	)
	if root.get_node("Save").path == "user://save.json" or root.get_node("Settings").path == "user://settings.cfg":
		push_error("Use isolated --save-file and --settings-file")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
		if arg == "--record-walkthrough":
			_walkthrough = true
	if DisplayServer.get_name() != "headless" and (not _capture_dir.is_empty() or _walkthrough):
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.unresizable = true
	root.get_node("Settings").language = "zh"
	root.get_node("Settings")._apply_language()
	seed(7103)
	change_scene_to_file(SCENE)
	await process_frame
	await process_frame
	_room = current_scene
	if not is_instance_valid(_room) or not is_instance_valid(_room.stage):
		push_error("Could not start the courtyard")
		quit(1)
		return
	_room.pause_menu.free()
	paused = false
	_check(_room.stage.shutter.visible, "door starts closed")
	_check(not _room.stage.entrance_shutter.visible and not _room.stage.entrance_sealed, "the battle courtyard entrance starts open")
	_check(not _room.stage._awakened_gate.visible, "the exit portal starts dormant")
	_check(_room.player.swordsman_weapon.manual_attack, "room uses manual directional strikes")
	await _wait(0.25)
	await _capture("courtyard")
	await _capture_exit("dormant-gate")
	var entry_camera: Vector3 = _room.stage.camera.position
	var collision_grid: GDScript = load("res://scripts/world/map_layer.gd")
	await _advance(_room.APPROACH_TRIGGER + 9.0, 300)
	_check(_room.phase == _room.Phase.APPROACH_FIGHT and get_node_count_in_group("enemies") == 3, "three ordinary foes appear along the snowcliff approach")
	_check(_room.stage._approach_seal.visible and not _room.stage.entrance_sealed, "the approach fight precedes the main courtyard's gate")
	await _capture("approach-fight")
	_check(collision_grid.push_out(Vector2(-1947,-336), _room.player.RADIUS).distance_to(Vector2(-1947,-336)) > 20.0,
		"the stone parapet and its collision share the same path")
	await _fight()
	_check(_room.phase == _room.Phase.COURT_ENTRY and _room.kills == 3 and not _room.stage._approach_seal.visible,
		"clearing the approach opens the path to the courtyard (at %s)" % _room.player.position)
	await _advance(-960.0, 760)
	await _walk_to(Vector2(-970, 91))
	await _capture("approach")
	await _advance(-750.0, 65)
	_check(_room.player.position.x < -835.0, "the half-fallen wall blocks the direct route")
	await _walk_to(Vector2(-940, -165))
	await _walk_to(Vector2(-752, -165))
	await _capture("entry-open")
	await _advance(_room.ENCOUNTER_X + 6.0, 330)
	_check(_room.phase == _room.Phase.BATTLE and get_node_count_in_group("enemies") == 4, "crossing entry spawns the four enemies")
	_check(_room.stage.entrance_sealed and _room.player.position.x > _room.ENTRANCE.x + 58.0, "entrance shuts only after the player clears the opening")
	_check(_room.stage.camera.position.x - entry_camera.x > 7.5, "camera travels with the player from approach into the court")
	_check(_room.stage.camera.is_position_behind(_room.stage.exit_gate_position()) or not _room.stage.camera.is_position_in_frustum(_room.stage.exit_gate_position()), "the exit is off-camera from the inner approach")
	_check(_room.bounds.end.x == _room.CLOSED_EDGE, "exit remains locked in battle")
	_key(KEY_A, true)
	await _wait(0.49)
	_key(KEY_A, false)
	_check(_room.player.position.x >= _room.SEALED_EDGE and is_zero_approx(_room.stage.entrance_shutter.position.y), "the lowered entrance gate blocks retreat")
	await _capture("entry-sealed")
	await _capture("encounter")
	_check(collision_grid.push_out(_room.Layout.expand(Vector2(161,693)), _room.player.RADIUS).distance_to(_room.Layout.expand(Vector2(161,693))) > 20.0,
		"the southern court boundary blocks crossing its visible parapet")
	var targets := get_nodes_in_group("enemies")
	if targets.is_empty() or _room.player.is_dead:
		await _finish()
		return
	if not _walkthrough:
		await _advance(-425.0, 80)
		targets = get_nodes_in_group("enemies")
		if targets.is_empty() or _room.player.is_dead:
			await _finish()
			return
		for foe: Node2D in targets:
			foe.set_physics_process(false)
		await _wait(.50)
		await _capture("broad-court")
		var target: Node2D = targets[0]
		var hp: float = target.hp
		target.position = _room.player.position + Vector2(61, 0)
		_click(_room.player.position + Vector2.LEFT * 75)
		await _wait(0.44)
		_check(is_instance_valid(target) and target.hp == hp, "aiming away does not hit")
		if is_instance_valid(target):
			_click(target.position)
			await _wait(0.13)
			_check(not is_instance_valid(target) or target.hp < hp, "an aimed strike damages the foe")
			await _capture("strike")
		for foe: Node2D in targets:
			if is_instance_valid(foe):
				foe.set_physics_process(true)
	_key(KEY_SPACE, true)
	await _wait(0.035)
	_check(_room.player.is_dashing(), "Space dodges")
	_key(KEY_SPACE, false)
	await _wait(0.28)
	await _fight()
	await _wait(1.00)
	_check(paused and _room.level_up_panel.visible and _room.kills == 7, "clearing both encounters opens the existing blessing panel")
	if not is_instance_valid(_room) or not _room.level_up_panel.visible:
		await _finish()
		return
	_check(_room.stage.portal_ready and _room.stage._awakened_gate.visible and not _room.stage._dormant_gate.visible, "clearing the foes replaces the ruin with the lit portal")
	_check(_room.bounds.end.x == _room.CLOSED_EDGE, "the doorway stays gated until reward selection")
	await _capture("reward")
	_key(KEY_1, true)
	_key(KEY_1, false)
	await _wait(0.82)
	_check(not paused and _room.phase == _room.Phase.EXIT and not _room.stage.shutter.visible, "selecting a blessing opens the archway")
	_check(_room.player.faith.has("thor"), "the choice applies Thor's existing blessing")
	if _room.bounds.end.x <= _room.CLOSED_EDGE:
		await _finish()
		return
	await _capture_exit("restored-gate")
	await _walk_to(Vector2(109, -116))
	await _walk_to(Vector2(132, -748))
	_check(_room.player.position.y < -710.0, "the player can reach the expanded side of the central court")
	await _capture("north-terrace")
	await _walk_to(_room.Layout.RING)
	var center_camera: Vector3 = _room.stage.camera.position
	await _capture("court-pan-center")
	await _walk_to(Vector2(109, -30))
	await _walk_to(Vector2(1122, -30))
	_check(_room.stage.camera.position.x - center_camera.x > 5.0, "camera follows through the arena to the east wall")
	await _capture("court-pan-east")
	await _walk_to(Vector2(1205, _room.EXIT.y))
	await _walk_to(Vector2(1715, _room.EXIT.y))
	_check(_room.player.position.x > 1690.0 and _room.stage.camera.position.x - entry_camera.x > 30.0,
		"the player walks through the east causeway with a following camera (at %s)" % _room.player.position)
	await _capture("open-gate")
	await _walk_to(_room.EXIT)
	_check(_room.phase == _room.Phase.COMPLETE and paused, "walking through the open door completes the room (at %s)" % _room.player.position)
	await _capture("complete")
	if _walkthrough:
		await _wait(2.35)
		await _finish()
		return
	_room.hud._on_restart_pressed()
	await scene_changed
	await process_frame
	_room = current_scene
	_check(_room.phase == _room.Phase.ENTRY and _room.kills == 0 and _room.stage.shutter.visible and not paused,
		"restart resets the encounter (phase %s, kills %s, shutter %s, paused %s)" %
		[_room.phase, _room.kills, _room.stage.shutter.visible, paused])
	_check(not _room.stage.entrance_sealed and not _room.stage.portal_ready, "restart resets both gate states")
	_room.player.take_damage(1000.0)
	await _wait(_room.player.death_duration() + 0.55)
	_check(paused and _room.player.is_dead and _room._run_state == _room.RunState.ENDED, "defeat leaves the room restartable")
	await _finish()


func _finish() -> void:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
		await process_frame
	if is_instance_valid(Audio._instance):
		var audio := Audio._instance
		for tween in audio._tweens.values():
			tween.kill()
		for stream: AudioStreamPlayer in audio.get_children():
			stream.stop()
			stream.stream = null
		audio._streams.clear()
		audio.free()
		Audio._instance = null
	await _wait(0.20)
	print("FIMBULWINTER_COURTYARD_RESULT ", _checks, " checks, ", _failed, " failures")
	quit(int(_failed > 0))
