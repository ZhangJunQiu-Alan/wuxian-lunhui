extends SceneTree

const WAIST := ["katana", "muramasa", "duanshui", "higekiri", "excalibur"]

var checks := 0
var failures := 0
var capture_dir := ""
var game: Node
var player
var weapon
var levels: Array
var kits: Dictionary


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func run() -> void:
	var save = root.get_node("Save")
	if save.path == save.DEFAULT_PATH or root.get_node("Settings").path == "user://settings.cfg":
		push_error("Pass isolated --save-file and --settings-file arguments")
		quit(2)
		return
	save.reset()
	var legacy := FileAccess.open(save.path, FileAccess.WRITE)
	legacy.store_string('{"selected_character":"swordsman"}')
	legacy.close()
	save.load_game()
	check(save.swordsman_weapon == "katana", "legacy saves default to katana")
	levels = load("res://scripts/data/level_db.gd").ORDER
	kits = load("res://scripts/weapons/swordsman_loadout.gd").KITS
	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	await process_frame
	var choice := hub.find_child("SwordsmanLoadout", true, false) as OptionButton
	check(choice != null and choice.visible and choice.item_count == 11, "eleven options in actual hub")
	if not choice:
		quit(1)
		return
	for i in choice.item_count:
		check(choice.get_item_icon(i) != null, "hub icon: " + str(choice.get_item_metadata(i)))
	choice.select(3)
	choice.item_selected.emit(3)
	var selected: String = choice.get_item_metadata(3)
	save.load_game()
	check(save.swordsman_weapon == selected, "hub selection persists through reload")
	await settle()
	check(root.get_visible_rect().encloses(hub._start.get_global_rect()), "battle button fits the hub viewport")
	await capture("hub")
	hub.free()
	save.cleared_levels.assign(levels)
	for level: String in levels:
		save.selected_level = level
		for kit: String in kits:
			save.swordsman_weapon = kit
			await enter_level()
			check(game.level_id == level, "loaded the requested map: " + level)
			check(weapon != null and weapon.kit_id == kit, level + " equipped " + kit)
			if not weapon:
				quit(1)
				return
			await settle()
			for side in [-1.0, 1.0]:
				player.facing = Vector2(side, 0)
				var body: AnimatedSprite2D = weapon.art.body
				body.flip_h = side < 0.0
				weapon.sync_art()
				check(is_equal_approx(weapon.art.scale.x, side), level + " mirrored " + kit)
				if kit in WAIST:
					var mouth: Vector2 = weapon.art.socket_world("mouth_of_sheath")
					var image: Sprite2D = weapon.art._parts[0]
					check(image.texture.resource_path.ends_with("_stow.png"), kit + " stowed texture")
					check(is_equal_approx(image.global_position.x, mouth.x), kit + " sheath and mount share anchor")
					player.play_attack(Vector2(side, 0))
					for i in 6:
						body.frame = i
						weapon.sync_art()
						check(image.texture.resource_path.ends_with("_sheath.png" if i in [1, 2, 3, 4] else "_stow.png"), kit + " sheath frame " + str(i))
						if i in [1, 2, 3, 4]:
							check(weapon.art._used >= 2, kit + " drawn blade beside empty sheath")
					if side > 0 and not capture_dir.is_empty():
						body.pause()
						body.frame = 2
						weapon.sync_art()
						await capture(level + "_" + kit + "_drawn")
						body.play()
					player._attack_time = 0.0
					body.play(&"idle")
			if not capture_dir.is_empty():
				await capture(level + "_" + kit + "_idle")
			if level == levels[0]:
				await exercise(kit)
			await leave_level()
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values():
			tween.kill()
		for node in audio.get_children():
			if node is AudioStreamPlayer:
				node.stop()
				node.stream = null
		audio._streams.clear()
		audio.free()
		audio_script._instance = null
	print("S-SW RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)


func enter_level() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	game.level_up_panel.choose(0)
	game.pause_menu.free()
	player = game.player
	weapon = player.swordsman_weapon
	for power in player.gods.values():
		power.free()
	player.gods.clear()
	player.facing = Vector2.RIGHT


func settle() -> void:
	await process_frame
	await process_frame


func leave_level() -> void:
	game.queue_free()
	await settle()


func target(offset: Vector2, hp := 10000.0) -> Node2D:
	var enemy = game.spawn_enemy("draugr", player.position + offset)
	enemy.global_position = player.global_position + offset
	enemy.max_hp = hp
	enemy.hp = hp
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_K
	event.pressed = pressed
	Input.parse_input_event(event)


func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.position = root.get_visible_rect().get_center()
	event.global_position = event.position
	event.pressed = pressed
	Input.parse_input_event(event)


func tap(right_click := false) -> void:
	if right_click:
		mouse(true)
		await process_frame
		mouse(false)
	else:
		key(true)
		await process_frame
		key(false)


func wait(seconds: float) -> void:
	await create_timer(seconds, false).timeout


func exercise(kit: String) -> void:
	var enemy := target(Vector2(90, 0))
	match kit:
		"katana":
			await wait(0.49)
			check(enemy.hp < 10000.0, "katana damages an enemy in the actual scene")
			weapon._slash_count = 3
			weapon._timer = 0.0
			var back := target(Vector2(-91, 0))
			await wait(0.42)
			check(back.hp < 10000.0, "fourth attack also hits behind")
			player.try_dash()
			await wait(0.08)
			var found := false
			for node in game.get_children():
				if node is AnimatedSprite2D and node != weapon.art.body and node.z_index == -1:
					found = node.get_child_count() > 0 and node.get_child(0).get_child_count() > 0
			check(found, "dash ghosts include the mounted weapon")
		"muramasa":
			enemy.hp = 1.0
			await wait(0.49)
			check(weapon._chain == 1, "Muramasa kill builds chain")
			await wait(2.85)
			check(weapon._thirst > 0.0, "broken chain triggers thirst")
		"monohoshizao":
			var tip := target(Vector2(150, 0))
			await wait(0.48)
			check(tip.hp < enemy.hp and enemy.hp < 10000.0, "tip hits harder than the inner band")
		"duanshui":
			await wait(0.49)
			var crossing := target(Vector2(110, 20))
			weapon._timer = 99.0
			await wait(0.55)
			check(not weapon._areas.is_empty() and crossing.hp < 10000.0, "scar damages an enemy entering after the attack")
		"higekiri":
			await wait(0.49)
			check(weapon._oni > 0.0, "Higekiri gains Oni gauge on hit")
			weapon._oni = 1.0
			await tap()
			await wait(0.13)
			check(weapon._oni_time > 0.0, "K activates Oni")
			await tap()
			await wait(0.13)
			check(weapon._oni_time <= 0.0 and weapon._exhaust > 0.0, "K exits into exhaustion")
		"ganjiang_moye":
			weapon._timer = 99.0
			await tap(true)
			await wait(0.2)
			check(weapon._moye_state == "out" and weapon.art._used == 1, "throw detaches off-hand blade")
			await wait(0.4)
			check(weapon._moye_state == "planted" and enemy.hp < 10000.0, "planted link damages target")
			await capture("moye_planted")
			await tap(true)
			await wait(0.42)
			check(weapon._moye_state == "" and weapon.art._used == 2, "right mouse recalls Moye to off hand")
			weapon._timer = 0.0
			await wait(0.5)
			check(weapon._off_turn, "first attack uses Ganjiang")
			weapon._timer = 0.0
			await wait(0.2)
			check(weapon.art.body.animation == &"off_attack", "second attack uses Moye pose")
		"zhuxian":
			for variant: String in ["zhu", "lu", "xian", "jue"]:
				weapon._timer = 0.0
				await wait(0.19)
				check(weapon._variant == variant and weapon.art._used == 4, "Zhuxian launch and three reserve blades: " + variant)
				if variant == "zhu":
					check(weapon.art.body.sprite_frames.get_frame_texture(&"attack", 2) ==
						weapon.art.body.sprite_frames.get_frame_texture(&"idle", 0), "Zhuxian launches without a body swing")
				if variant == "lu":
					check(not weapon._bleeds.is_empty(), "Lu applies bleed")
				if variant == "xian":
					check(enemy._frozen_time > 0.0, "Xian roots the target")
				if variant == "jue":
					check(not is_instance_valid(enemy) or enemy.hp <= 0.0, "Jue executes a low-health non-boss")
				await wait(0.23)
				if variant == "xian":
					enemy.hp = 60.0
		"qinglong":
			weapon._timer = 99.0
			key(true)
			await wait(2.12)
			check(weapon._spinning and player._actions.animation == &"spin" and enemy.hp < 10000.0, "held K spins and hits")
			check(weapon._spin_audio.playing, "spin loops while held")
			key(false)
			await wait(0.23)
			check(weapon._avatar > 0.0 and player._actions.animation == &"heavy", "release heavy attack leads to dragon avatar")
			check(not weapon._spin_audio.playing, "spin loop stops on release")
		"excalibur":
			await wait(0.35)
			check(is_equal_approx(enemy.hp, 10000.0), "Excalibur awaits manual input")
			await tap()
			await wait(0.78)
			check(weapon._iai >= 0.0 and enemy.hp < 10000.0, "manual cut returns to sheath and charges (charge %s, action %s, target hp %s)" %
				[weapon._iai, player._actions.animation, enemy.hp])
			await wait(4.0)
			check(is_equal_approx(weapon._iai, 4.0), "charge reaches four seconds")
			await capture("excalibur_charged")
			var from: Vector2 = player.global_position
			var line_target := target(Vector2(180, 0))
			await tap(true)
			await wait(0.41)
			check(from.distance_to(player.global_position) > 200.0 and line_target.hp < 10000.0, "iai crosses a real level and damages along the path")
		"riyue":
			weapon._timer = 99.0
			await tap()
			await wait(0.3)
			check(weapon._variant == "moon" and player.global_position.x > 80.0, "first swap enters Moon lunge")
			await wait(1.1)
			await tap(true)
			await wait(0.16)
			check(weapon._variant == "sun" and player._actions.animation == &"spin", "second swap enters Sun Wheel")
		"chunyang":
			weapon._timer = 99.0
			for i in range(1, 4):
				await tap()
				await wait(0.58)
				check(weapon._drinks == i, "drink advances stage " + str(i))
			var hp: float = player.hp
			player.take_damage(5.0)
			check(is_equal_approx(player.hp, hp) and weapon._dodge_cd > 0.0, "third drink dodges a hit")
			weapon._timer = 0.0
			await wait(0.18)
			check(not weapon._waves.is_empty(), "drunken slash launches sword qi")


func capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	check(image != null and image.save_png(capture_dir.path_join(label + ".png")) == OK, "capture " + label)
	await process_frame
