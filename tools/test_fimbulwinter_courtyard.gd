extends SceneTree

const SCENE := "res://scenes/fimbulwinter_courtyard.tscn"

var _room: Node
var _failed := 0
var _checks := 0
var _capture_dir := ""
var _walkthrough := false
var _hero_ran := false


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
		if _room.stage.hero.anim.current_animation == "run":
			_hero_ran = true
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
	var hero: Node3D = _room.stage.hero
	_check(["idle", "run", "dash", "attack", "attack2", "hit", "death"].all(func(a: String) -> bool: return hero.anim.has_animation(a)),
		"the 3D swordsman carries all seven actions")
	_check(hero.model.find_child("weapon_r", true, false) != null and hero.model.find_child("sheath_l", true, false) != null,
		"the 3D swordsman has the hand and hip weapon sockets")
	var skeleton: Skeleton3D = hero.model.find_children("*", "Skeleton3D", true, false)[0]
	var crown: Vector3 = skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("mixamorig_HeadTop_End")).origin
	var height: float = crown.y - hero.global_position.y
	_check(absf(height - 1.46) < 0.1, "the 3D swordsman stands about 1.5 world units tall (crown at %.2f)" % height)
	await _wait(0.25)
	await _capture("courtyard")
	await _capture_exit("dormant-gate")
	var entry_camera: Vector3 = _room.stage.camera.position
	var collision_grid: GDScript = load("res://scripts/world/map_layer.gd")
	await _advance(_room.APPROACH_TRIGGER + 9.0, 300)
	_check(_hero_ran, "the 3D swordsman plays its run while moving")
	_check(_room.phase == _room.Phase.APPROACH_FIGHT and get_node_count_in_group("enemies") == 3, "three ordinary foes appear along the snowcliff approach")
	_check(_room.stage._approach_seal.visible and not _room.stage.entrance_sealed, "the approach fight precedes the main courtyard's gate")
	var foes_3d: Array[Node] = _room.stage.find_children("Foe3D*", "", false, false)
	_check(foes_3d.size() == 3 and foes_3d.all(func(f: Node) -> bool: return f.has_model()), "the approach foes are 3D models (%d)" % foes_3d.size())
	_check(not _room.stage.find_children("Body", "Sprite3D", true, false).any(func(b: Node) -> bool: return b.visible and b.texture != null),
		"no pixel billboards remain for the draugr and the ice spirit")
	for foe: Node in foes_3d:
		var wanted: Array = ["idle", "walk", "attack", "sweep", "kneel", "hit", "death"] if foe.type_id == "draugr" else ["idle", "cast", "hit", "death"]
		_check(wanted.all(func(a: String) -> bool: return foe.anim.has_animation(a)), "the 3D %s carries its actions" % foe.type_id)
	await _wait(0.6)
	_check(foes_3d.any(func(f: Node) -> bool: return f.type_id == "draugr" and f.anim.current_animation in ["walk", "attack"]), "a draugr marches toward the player")
	await _capture("approach-fight")
	var spears_before: int = _room.stage.Enemy3D.spears_dropped
	var foes_2d := get_nodes_in_group("enemies")
	for foe: Node2D in foes_2d:
		foe.set_physics_process(false)  # 一个一个单独测招式
	_room.player.max_hp = 1000.0
	_room.player.hp = 1000.0
	_room.stage._player_hp = 1000.0
	var lancer: Node2D = foes_2d.filter(func(e: Node) -> bool: return e.type_id == "draugr")[0]
	var caster: Node2D = foes_2d.filter(func(e: Node) -> bool: return e.type_id == "ice_spirit")[0]
	_check(is_equal_approx(lancer.max_hp, 80.0) and is_equal_approx(caster.max_hp, 40.0), "draugr take 4 katana cuts, ice spirits 2 (%.0f / %.0f hp)" % [lancer.max_hp, caster.max_hp])
	for foe: Node2D in foes_2d:
		foe.position = _room.player.position + Vector2(-600, 0)  # 挪开，别推挤到被测的那只
	lancer.set_physics_process(true)
	var side := Vector2.RIGHT  # 找一个垫步路线上没有石头和墙的方向
	for turn in 12:
		side = Vector2.RIGHT.rotated(TAU * turn / 12.0)
		var clear := true
		for k in 5:
			var probe: Vector2 = _room.player.position + side * (lancer.reach() * 0.95 - 15.0 * k)
			clear = clear and collision_grid.push_out(_room.clamp_to_map(probe, lancer.radius), lancer.radius) == probe
		if clear:
			break
	var origin: Vector2 = _room.player.position + side * lancer.reach() * 0.95  # 垫步一刺刚好够得着的距离
	lancer.position = origin
	lancer.action = ""  # 冻住时可能正刺到一半
	lancer._attack_cd = 0.0
	await _wait(0.05)
	_check(lancer.action == "thrust" and lancer.position.distance_to(_room.player.position) > 200.0,
		"the draugr thrusts from spear reach plus a lunge instead of closing to contact")
	_check(lancer.moves.thrust.reach > 170.0, "the reach matches the measured spear tip (%.0f px)" % lancer.moves.thrust.reach)
	var hp_before: float = _room.player.hp
	await _wait(lancer.moves.thrust.strike + 0.03)
	_check((lancer.position - origin).dot(-side) > 50.0, "the thrust lunges about 0.6 m forward (%.0f px)" % (lancer.position - origin).dot(-side))
	_check(_room.player.hp < hp_before, "the spear thrust lands at its tip (hp %.0f -> %.0f)" % [hp_before, _room.player.hp])
	_check(not _room.hud._hurt_flash.visible and _room.stage.get_children().any(func(n: Node) -> bool: return n is Node3D and n.get_child_count() > 10 and n.get_child(0) is MeshInstance3D),
		"getting hit shows 3D shards at the swordsman instead of a full-screen red flash")
	await _wait(lancer.moves.thrust.time)
	hp_before = _room.player.hp
	lancer.position = _room.player.position + Vector2(-80, 0)
	lancer._attack_cd = 0.0
	await _wait(0.05)
	_check(lancer.action == "sweep", "a draugr sweeps when the player stands inside its spear (%s)" % lancer.action)
	await _wait(lancer.moves.sweep.strike + 0.03)
	_check(_room.player.hp < hp_before, "the sweep hits a player standing close")
	await _wait(lancer.moves.sweep.time)
	lancer._attack_cd = 5.0
	lancer.take_damage(10.0)
	_check(lancer.stagger > 0.0 and not lancer.kneeling, "a cut staggers an idle draugr")
	lancer._attack_cd = 0.0
	lancer.stagger = 0.0
	lancer.position = _room.player.position + Vector2(-lancer.reach() * 0.95, 0)
	await _wait(0.05)
	lancer.take_damage(10.0)
	_check(lancer.action == "thrust" and lancer.stagger <= 0.0, "a cut does not interrupt a thrust (super armor)")
	lancer.take_damage(10.0)
	_check(lancer.kneeling and lancer.action == "", "three cuts in a row break its poise: it kneels")
	var before_kneel: float = lancer.hp
	lancer.take_damage(10.0)
	_check(is_equal_approx(before_kneel - lancer.hp, 15.0), "a kneeling draugr takes +50%% damage (%.1f)" % (before_kneel - lancer.hp))
	await _wait(1.1)
	_check(not lancer.kneeling, "it rises after a second")
	lancer.set_physics_process(false)
	lancer.position = _room.player.position + Vector2(-500, 260)
	caster.set_physics_process(true)
	caster.position = _room.player.position + Vector2(150, 0)
	caster._spell_cd = 9.0
	await _wait(0.75)
	_check(caster.position.distance_to(_room.player.position) > 300.0, "the ice spirit drifts back when the player closes in (%.0f px)" % caster.position.distance_to(_room.player.position))
	caster.position = _room.player.position + Vector2(260, 0)
	caster._spell_cd = 0.0
	caster._next_spell = "bolt"
	await _wait(0.3)
	var aim_line: Node3D = _room.stage._actors[caster].get_node("Aim")
	_check(caster.action == "bolt" and aim_line.visible, "the ice bolt shows a ground aim line while it charges")
	await _wait(caster.moves.bolt.strike - 0.3 + 0.05)
	_check(get_nodes_in_group("enemy_projectiles").size() > 0 and not aim_line.visible, "the bolt flies and the aim line goes out")
	_check(get_nodes_in_group("enemy_projectiles").all(func(b: Node) -> bool: return is_equal_approx(b.speed, 230.0 * 1.2)), "the ice bolt flies 1.2x as fast as a plain shard")
	_check(caster.DRIFT_COOLDOWN == 5.0 and caster._drift_cd > 3.0, "after drifting the spirit waits 5 s before drifting again")
	for i in 60:
		if get_nodes_in_group("enemy_projectiles").is_empty():
			break
		await _wait(0.05)
	await _wait(0.6)
	hp_before = _room.player.hp
	caster._spell_cd = 0.0
	caster._next_spell = "spike"
	await _wait(caster.moves.spike.strike + 0.1)
	_check(_room.stage.has_node("IceSpike"), "the ice spike marks the player's feet first")
	_check(_room.player.hp == hp_before, "the spike does not hurt before it erupts")
	await _wait(caster.SPIKE_DELAY)
	_check(_room.player.hp < hp_before, "standing in the mark gets the player hit by the spike")
	for foe: Node2D in foes_2d:
		foe.set_physics_process(true)
	var model: Node3D = _room.stage._actors[lancer].get_meta("model")
	var fell_at: Vector3 = _room.stage.world_at(lancer.position)
	_room.player.position = lancer.position + Vector2(-60, 0)
	lancer.take_damage(1000.0)
	await _wait(0.6)
	_check(model.dying and Vector2(model.position.x - fell_at.x, model.position.z - fell_at.z).length() > 0.9,
		"a killing cut knocks the corpse 1-1.5 m away (%.2f)" % Vector2(model.position.x - fell_at.x, model.position.z - fell_at.z).length())
	_check(collision_grid.push_out(Vector2(-1947,-336), _room.player.RADIUS).distance_to(Vector2(-1947,-336)) > 20.0,
		"the stone parapet and its collision share the same path")
	await _fight()
	_check(_room.stage.find_children("Foe3D*", "", false, false).any(func(f: Node) -> bool: return f.dying), "a slain foe stays to play its fall")
	await _wait(1.5)
	_check(_room.stage.Enemy3D.spears_dropped - spears_before == 2, "both slain draugr let go of their spears")
	await _capture("fallen")
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
		_room.player.swordsman_weapon._slash_count = 0  # 避开二刀流（每第 4 刀前后双斩），这里只测瞄准方向
		_click(_room.player.position + Vector2.LEFT * 75)
		await _wait(0.44)
		_check(is_instance_valid(target) and target.hp == hp, "aiming away does not hit")
		if is_instance_valid(target):
			_click(target.position)
			await _wait(0.13)
			_check(not is_instance_valid(target) or target.hp < hp, "an aimed strike damages the foe")
			_check(_room.stage.hero.anim.current_animation in ["attack", "attack2"], "the 3D swordsman swings on a strike")
			await _capture("strike")
		for foe: Node2D in targets:
			if is_instance_valid(foe):
				foe.set_physics_process(true)
	_key(KEY_SPACE, true)
	await _wait(0.035)
	_check(_room.player.is_dashing(), "Space dodges")
	_check(_room.stage.hero.anim.current_animation == "dash", "the 3D swordsman plays its dash")
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
	var threshold: PackedVector2Array = _room.stage.exit_threshold
	var threshold_center := threshold[0].lerp(threshold[1], 0.5)
	_room._on_foot_moved(threshold_center - Vector2.RIGHT * 20.0, threshold_center + Vector2.RIGHT * 20.0)
	_check(_room.phase == _room.Phase.REWARD, "touching the curtain before choosing a blessing does not leave")
	await _capture("reward")
	_key(KEY_1, true)
	_key(KEY_1, false)
	await _wait(0.82)
	_check(not paused and _room.phase == _room.Phase.EXIT and not _room.stage.shutter.visible, "selecting a blessing opens the archway")
	_check(_room.player.faith.has("thor"), "the choice applies Thor's existing blessing")
	_check(_room.bounds.end.x - _room.player.RADIUS > maxf(threshold[0].x, threshold[1].x),
		"the open bounds reach the full width of the threshold")
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
	for weight in [-0.1, 1.1]:
		var outside := threshold[0].lerp(threshold[1], weight)
		_room._on_foot_moved(outside - Vector2.RIGHT * 60.0, outside + Vector2.RIGHT * 60.0)
		_check(_room.phase == _room.Phase.EXIT, "crossing the line outside the aperture does not leave")
	await _walk_to(Vector2(1324, 0))
	await _advance(1435.0, 80)
	_check(_room.phase == _room.Phase.EXIT and _room.player.position.x < 1410.0,
		"the north pillar still blocks walking outside the arch (at %s)" % _room.player.position)
	await _walk_to(Vector2(1324, threshold_center.y))
	var foot: Vector2 = _room.player.position
	var threshold_x := lerpf(threshold[0].x, threshold[1].x, inverse_lerp(threshold[0].y, threshold[1].y, foot.y))
	await _advance(threshold_x - 4.0, 100)
	foot = _room.player.position
	_check(_room.phase == _room.Phase.EXIT and foot.x < threshold_x and threshold_x - foot.x <= 4.0,
		"the player can walk up to the sill without leaving early (at %s)" % foot)
	_check(_room.stage.camera.is_position_in_frustum(_room.stage.world_at(threshold_center))
		and _room.stage.camera.position.x - center_camera.x > 8.0, "the following camera keeps the sill in frame")
	await _capture("threshold-before")
	await _advance(threshold_x + 1.0, 10)
	foot = _room.player.position
	_check(_room.phase == _room.Phase.COMPLETE and paused
		and foot.distance_to(Geometry2D.get_closest_point_to_segment(foot, threshold[0], threshold[1])) < 0.01,
		"the first step onto the light curtain completes the room at the sill (at %s)" % foot)
	await _capture("threshold-after")
	if _walkthrough or (not _capture_dir.is_empty() and DisplayServer.get_name() != "headless"):
		await _wait(2.35)
	if _walkthrough:
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
