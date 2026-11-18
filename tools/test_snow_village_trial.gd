extends SceneTree

const SCENE := "res://scenes/snow_village_trial.tscn"

var _game: Node
var _failures := 0
var _checks := 0
var _capture_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _frames(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _key(code: Key, pressed: bool) -> void:
	var input := InputEventKey.new()
	input.keycode = code
	input.physical_keycode = code
	input.pressed = pressed
	Input.parse_input_event(input)


func _swing(towards: Vector2) -> void:
	var input := InputEventMouseButton.new()
	input.button_index = MOUSE_BUTTON_LEFT
	input.pressed = true
	input.position = _game.stage._camera.unproject_position(Vector3(towards.x, 0.0, towards.y) * 0.01)
	root.push_input(input, true)
	input = input.duplicate()
	input.pressed = false
	root.push_input(input, true)


func _capture(label: String) -> void:
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(_capture_dir.path_join(label + ".png")) == OK, "capture " + label)


func _load_trial() -> void:
	paused = false
	change_scene_to_file(SCENE)
	await process_frame
	await process_frame
	_game = current_scene


func _fight(limit: int) -> void:
	var initial_step: int = _game.step
	for i in limit:
		var enemies := get_nodes_in_group("enemies")
		if enemies.is_empty() or paused or _game.player.is_dead or _game.step != initial_step:
			break
		var nearest: Node2D = enemies[0]
		for enemy: Node2D in enemies:
			if enemy.position.distance_squared_to(_game.player.position) < nearest.position.distance_squared_to(_game.player.position):
				nearest = enemy
		var offset: Vector2 = nearest.position - _game.player.position
		var horizontal := KEY_A if offset.x < 0.0 else KEY_D
		var vertical := KEY_W if offset.y < 0.0 else KEY_S
		if offset.length() > 76.0:
			if absf(offset.x) > 14.0:
				_key(horizontal, true)
			if absf(offset.y) > 14.0:
				_key(vertical, true)
		_swing(nearest.position + offset.normalized() * 22.0)
		await _frames(0.14)
		_key(horizontal, false)
		_key(vertical, false)


func _run() -> void:
	if root.get_node("Save").path == "user://save.json" or root.get_node("Settings").path == "user://settings.cfg":
		push_error("Use isolated save and settings arguments")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.trim_prefix("--capture-dir=")
	seed(271)
	await _load_trial()
	_check(_game.player.swordsman_weapon.manual_attack, "trial uses active sword")
	await _capture("snow-village-start")
	_key(KEY_D, true)
	await _frames(1.69)
	_key(KEY_D, false)
	_check(_game.step == _game.Step.VILLAGE_FIGHT, "WASD crosses the village encounter trigger (position %s)" % _game.player.position)
	_check(get_node_count_in_group("enemies") == 4, "village has exactly four enemies")
	_check(_game.bounds.end.x < _game.SHRINE.x, "village encounter gates the next area")
	if get_node_count_in_group("enemies") == 0:
		_finish()
		return
	await _capture("snow-village-encounter")

	var target := get_nodes_in_group("enemies")[0] as Node2D
	var start_hp: float = target.hp
	target.set_physics_process(false)
	target.position = _game.player.position + Vector2(60, 0)
	await _frames(0.50)
	_check(target.hp == start_hp, "standing near an enemy does not auto-attack")
	_swing(_game.player.position + Vector2.LEFT * 90.0)
	await _frames(0.44)
	_check(target.hp == start_hp, "aiming away misses an enemy in range")
	_swing(target.position)
	await _frames(0.18)
	_check(not is_instance_valid(target) or target.hp < start_hp, "left click aims at and damages a nearby enemy")
	await _capture("snow-village-strike")
	if is_instance_valid(target):
		target.set_physics_process(true)

	_key(KEY_SPACE, true)
	await _frames(0.035)
	_check(_game.player.is_dashing(), "space triggers dodge")
	var hp: float = _game.player.hp
	_game.player.take_damage(8.0)
	_check(_game.player.hp == hp, "dodge rejects damage during its invulnerability window")
	_key(KEY_SPACE, false)
	await _frames(0.18)
	await _fight(180)
	_check(_game.step == _game.Step.SHRINE, "clear village through movement and sword input")
	if _game.step != _game.Step.SHRINE:
		_finish()
		return

	_game.player.position = _game.SHRINE - Vector2(70, 0)
	await _frames(0.05)
	_check(paused and _game.level_up_panel.visible, "shrine opens a paused reward choice")
	_check(_game.level_up_panel._offers.size() == 2, "shrine offers two different powers")
	await _capture("snow-village-blessings")
	_key(KEY_1, true)
	_key(KEY_1, false)
	await _frames(0.10)
	_check(not paused and _game.player.faith.has("thor"), "number key selects Thor and resumes play")
	_check(_game.step == _game.Step.LAKE_GATE, "reward unlocks the lake")

	_game.player.heal(_game.player.max_hp)
	_game.player.position = _game.LAKE - Vector2(14, 0)
	_key(KEY_D, true)
	await _frames(0.10)
	_key(KEY_D, false)
	_check(get_node_count_in_group("enemies") == 5, "lake has exactly five enemies")
	await _fight(200)
	await _frames(0.08)
	_check(_game.step == _game.Step.BOSS, "clearing the lake starts Skoll (HP %s, foes %d, player %s)" % [_game.player.hp, get_node_count_in_group("enemies"), _game.player.position])
	if _game.step != _game.Step.BOSS:
		_finish()
		return
	_game.player.heal(_game.player.max_hp)
	var saw_windup := false
	for i in 42:
		await _frames(0.1)
		if is_instance_valid(_game.boss) and _game.boss.state == "windup":
			saw_windup = true
			break
	await process_frame
	_check(saw_windup and _game.stage._warning.visible, "Skoll projects the charge warning on the 3D ground (state %s)" % _game.boss.state)
	await _capture("snow-village-skoll")
	for i in 18:
		if not is_instance_valid(_game.boss) or _game.player.is_dead:
			break
		var wolf: Node2D = _game.boss
		var approach: Vector2 = wolf.position.direction_to(_game.player.position)
		_game.player.position = wolf.position + approach * 92.0
		if wolf.state == "windup":
			_game.player.facing = approach.orthogonal()
			_key(KEY_SPACE, true)
			await _frames(0.025)
			_key(KEY_SPACE, false)
			await _frames(0.20)
		if is_instance_valid(wolf):
			_swing(wolf.position)
		await _frames(0.44)
	await _frames(0.75)
	_check(_game.step == _game.Step.COMPLETE and paused and _game._run_state == _game.RunState.ENDED, "Skoll defeat opens victory (player HP %.0f, step %d)" % [_game.player.hp, _game.step])
	_check(_game.kills >= 10, "summary includes enemies from both encounters and the boss")

	await _load_trial()
	_game.player.position = Vector2(-770, -90)
	_game.player.facing = Vector2.UP
	_key(KEY_SPACE, true)
	await _frames(0.04)
	_key(KEY_SPACE, false)
	await _frames(0.18)
	_check(_game.player.position.y > -225.0 and _game.player.position.y < -170.0,
		"dodge reaches the longhouse edge without crossing it")
	_game.player.position = _game.SHRINE - Vector2(70, 0)
	_game.step = _game.Step.SHRINE
	_game._limit_route(355.0)
	await _frames(0.08)
	_key(KEY_2, true)
	_key(KEY_2, false)
	await _frames(0.08)
	_check(_game.player.faith.has("skadi"), "second blessing path selects Skadi")
	_game.player.position = _game.LAKE + Vector2(15, 0)
	await _frames(0.60)
	_check(not _game.stage._ice_arrows.is_empty(), "Skadi fires a visible 3D projectile")
	_game.player._invincible_time = 0.0
	_game.player.take_damage(1000.0)
	await _frames(_game.player.death_duration() + 0.55)
	_check(_game.player.is_dead and paused and _game._run_state == _game.RunState.ENDED, "death opens defeat result")
	_game.hud._on_restart_pressed()
	await _frames(0.12)
	_game = current_scene
	_check(_game.scene_file_path == SCENE and _game.kills == 0 and not paused, "restart loads a clean trial")
	_finish()


func _finish() -> void:
	paused = false
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
	print("Snow village trial: %d checks, %d failures" % [_checks, _failures])
	await create_timer(0.25).timeout
	OS.delay_msec(150)
	quit(int(_failures > 0))
