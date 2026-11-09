extends SceneTree

const OUTPUT := "res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/"
var game
var player
var boss_node
var fx
var fx_script
var screenshots: Array = []
var origin := Vector2.ZERO
var render_errors: Array = []

func _initialize():
	call_deferred("run")

func clear_effects():
	fx._boss_effects.clear()
	fx._particles.clear()
	fx._numbers.clear()
	fx._marks.clear()
	fx._rings.clear()
	fx.queue_redraw()

func pose(state, time = 0.0):
	boss_node.change_state(state)
	boss_node.state_time = time
	boss_node._update_action()
	if boss_node._actions:
		boss_node._actions.stop()
		boss_node._actions.frame = mini(2, boss_node._actions.sprite_frames.get_frame_count(boss_node._actions.animation) - 1)
	boss_node.queue_redraw()

func capture(name, age = 0.12):
	fx._process(age)
	boss_node.queue_redraw()
	for child in boss_node.get_children():
		if child.name in ["ShieldFx", "GnawFx"]:
			child.queue_redraw()
	if boss_node.get("_field") != null:
		boss_node._field.queue_redraw()
	player._camera.reset_smoothing()
	player._camera.force_update_scroll()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(OUTPUT + name + ".png")
	var effects: Array = []
	for entry in fx._boss_effects:
		if entry.id not in effects:
			effects.append(entry.id)
	screenshots.append({"file": name + ".png", "boss": boss_node.type_id, "state": boss_node.state, "state_time": boss_node.state_time, "batch_effects": effects, "write_error": error})
	if error != OK:
		render_errors.append(name)
	print("CAPTURE ", name, " effects=", effects)
	boss_node._flash_time = 0
	clear_effects()

func new_game(level_id):
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
		await process_frame
	paused = false
	root.get_node("Save").cleared_levels.assign(["midgard"])
	root.get_node("Save").selected_level = level_id
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	current_scene = game
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	game.level_up_panel.choose(0)
	paused = false
	player = game.player
	for power in player.gods.values():
		power.free()
	player.gods.clear()
	fx = load("res://scripts/effects/fx_layer.gd").instance
	fx_script = load("res://scripts/effects/boss_fx.gd")
	origin = load("res://scripts/world/map_layer.gd").push_out(Vector2.ZERO, 20)
	player.position = origin
	if game.level_id != level_id:
		render_errors.append("wrong level " + level_id + " actual " + game.level_id)
	player.hp = player.max_hp
	player._invincible_time = 0

func new_boss(id):
	await new_game("midgard" if id in ["skoll", "hati", "hrym"] else "helheim")
	boss_node = load("res://scripts/data/boss_db.gd").create(id, 1.0)
	boss_node.position = origin + Vector2(170, 0)
	boss_node.target = player
	boss_node.spawner = game.spawn_enemy
	game.add_child(boss_node)
	game.boss = boss_node
	game.hud.show_boss(boss_node.display_name, boss_node.title, boss_node.max_hp)
	await process_frame
	clear_effects()

func run():
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280, 720)
	if "--wave-only" in OS.get_cmdline_user_args():
		await new_boss("hrym")
		var final_gaps: Array[float] = [0.3, PI + 0.3]
		boss_node._gaps = final_gaps
		pose("stomp_windup", 0.85)
		boss_node._stomp()
		for child in game.get_children():
			if child.get_script() == load("res://scripts/bosses/shockwave.gd"):
				child._process(0.66)
		await capture("hrym_wave_two_gaps")
		FileAccess.open(OUTPUT + "wave_review.json", FileAccess.WRITE).store_string(JSON.stringify(screenshots, "\t"))
		game.queue_free()
		await process_frame
		quit()
		return
	await new_boss("skoll")
	pose("windup", 0.65)
	await capture("skoll_windup")
	pose("dash", 0.12)
	await capture("skoll_dash")
	player.position = boss_node.position + Vector2(35, 0)
	boss_node._bite_shown = false
	boss_node._update_state(0)
	await capture("skoll_bite")
	player.position = origin
	boss_node.hp = boss_node.max_hp * 0.49
	boss_node._update_state(0)
	pose("howl", 0.25)
	await capture("skoll_howl", 0.25)
	boss_node._summon_wolves()
	pose("howl", 0.85)
	await capture("skoll_wolf_summon")

	await new_boss("hati")
	boss_node._split()
	pose("lunge", 0.12)
	for child in game.get_children():
		if child.get_script() == load("res://scripts/bosses/hati_phantom.gd"):
			child._physics_process(0)
	await capture("hati_split_and_lunge", 0.25)
	pose("howl_windup", 0.9)
	await capture("hati_howl_warning")
	boss_node.state_time = 1.11
	boss_node._update_state(0)
	await capture("hati_howl_release", 0.25)
	for child in game.get_children():
		if child.get_script() == load("res://scripts/bosses/hati_phantom.gd"):
			child._life = 0
			child._physics_process(0)
	await capture("hati_phantom_dissolve", 0.25)

	await new_boss("hrym")
	var gaps: Array[float] = [0.3, PI + 0.3]
	boss_node._gaps = gaps
	pose("stomp_windup", 0.85)
	await capture("hrym_gap_warning")
	boss_node._stomp()
	for child in game.get_children():
		if child.get_script() == load("res://scripts/bosses/shockwave.gd"):
			child._process(0.66)
	await capture("hrym_wave_two_gaps")
	for child in game.get_children():
		if child.get_script() == load("res://scripts/bosses/shockwave.gd"):
			child.free()
	pose("shield", 0.25)
	boss_node._facing = Vector2.RIGHT
	player.position = boss_node.position + Vector2(110, 0)
	boss_node.take_damage(10)
	await capture("hrym_shield_block")
	player.position = origin
	boss_node._facing = Vector2.DOWN
	await capture("hrym_shield_rotated")
	boss_node._summon_guards()
	await capture("hrym_guard_summon", 0.25)
	boss_node._cage_center = origin
	pose("cage_windup", 0.91)
	boss_node._update_state(0)
	await process_frame
	for child in game.get_children():
		if child.get_script() == load("res://scripts/bosses/ice_pillar.gd"):
			child._process(0.23)
	await capture("hrym_ice_cage")
	for child in game.get_children():
		if child.get_script() == load("res://scripts/bosses/ice_pillar.gd"):
			child._process(3)
	await capture("hrym_ice_break")

	await new_boss("garm")
	pose("bark_windup", 0.6)
	await capture("garm_chains_and_warning")
	pose("lunge", 0.1)
	player.position = boss_node.position + Vector2(35, 0)
	boss_node._bite_shown = false
	boss_node._update_state(0)
	await capture("garm_bite")
	player.position = origin
	player.frenzy_time = 2
	player.shield_time = 2
	boss_node._howl()
	pose("bark", 0.1)
	await capture("garm_red_howl_dispel", 0.25)
	player.position = origin
	var stakes = boss_node._stakes.duplicate()
	stakes[0].take_damage(100000)
	await capture("garm_chain_break")
	for i in range(1, stakes.size()):
		stakes[i].take_damage(100000)
	await capture("garm_free")

	await new_boss("nidhogg")
	boss_node._breath_dir = Vector2.RIGHT
	pose("breath_windup", 0.7)
	await capture("nidhogg_breath_warning")
	boss_node._breathe()
	pose("breath", 0.1)
	await capture("nidhogg_poison_breath")
	pose("burrow", 0.51)
	boss_node._update_state(0)
	await capture("nidhogg_burrow_hidden")
	boss_node.state_time = 0.8
	boss_node.queue_redraw()
	await capture("nidhogg_under_crack")
	boss_node.state_time = 1.31
	boss_node._update_state(0)
	await capture("nidhogg_emerge")
	boss_node.position = boss_node._root.position + Vector2(0, -50)
	pose("gnaw", 0.25)
	await capture("nidhogg_gnaw_flow")
	boss_node._gnaw_damage = 0
	boss_node.take_damage(boss_node.max_hp * 0.061)
	await capture("nidhogg_gnaw_interrupt")

	await new_boss("hel")
	boss_node._fight_time = 100
	pose("chase")
	await capture("hel_ground_and_domain")
	boss_node.position = boss_node._anchor + Vector2(-100, 0)
	var minion = game.spawn_enemy("dead", boss_node.position + Vector2(-50, 60), false, true)
	minion.hp = minion.max_hp * 0.5
	boss_node._side_timer = 0
	boss_node._update_side(0)
	await capture("hel_life_heal", 0.25)
	boss_node.position = boss_node._anchor + Vector2(100, 0)
	boss_node._side_timer = 0
	boss_node._update_side(0)
	await capture("hel_death_summon", 0.25)
	boss_node._raise_army()
	await capture("hel_army_summon", 0.25)
	boss_node._switch_timer = 0
	boss_node._update_side(0)
	await capture("hel_shift", 0.25)
	pose("cast_windup", 0.81)
	boss_node._update_state(0)
	for shot in get_nodes_in_group("enemy_projectiles"):
		shot._physics_process(0.45)
	await capture("hel_death_bolts")
	player.position = boss_node._anchor + Vector2(0, -180)
	boss_node._enter_phase2()
	await capture("hel_board_ship", 0.25)
	boss_node._barrage()
	for shot in get_nodes_in_group("enemy_projectiles"):
		shot._physics_process(0.3)
	await capture("hel_nail_barrage")

	var report = {"engine": Engine.get_version_info(), "scope": "actual integrated Game viewport with deterministic skill triggers; full playthrough and balance not tested", "screenshots": screenshots, "image_write_errors": render_errors}
	FileAccess.open(OUTPUT + "render_review.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	if not "--skip-stress" in OS.get_cmdline_user_args():
		await stress()
	game.queue_free()
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values():
			tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
		audio._streams.clear()
		audio.free()
		audio_script._instance = null
	await process_frame
	await process_frame
	print("REVIEW COMPLETE ", screenshots.size(), " captures")
	quit(1 if render_errors.size() else 0)

func stress():
	await new_boss("hel")
	boss_node._fight_time = 100
	boss_node.process_mode = Node.PROCESS_MODE_DISABLED
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.set_process(false)
	player.set_physics_process(false)
	for child in player.get_children():
		if child != player._camera:
			child.process_mode = Node.PROCESS_MODE_DISABLED
	player.immune_time = 1000
	for i in 350:
		var at = origin + Vector2.from_angle(i * 2.399963) * (100 + fmod(i * 19, 450))
		var enemy = game.spawn_enemy("draugr", at, false, true)
		enemy.hp = 1000000
	var measurements: Array = []
	for phase in ["350_enemies_baseline", "350_enemies_40_boss_effects"]:
		var times: Array = []
		var start = Time.get_ticks_usec()
		var before = start
		var next_fx = 0
		while Time.get_ticks_usec() - start < 4000000:
			if phase.ends_with("effects") and Time.get_ticks_usec() >= next_fx:
				next_fx = Time.get_ticks_usec() + 250000
				for i in 20:
					fx_script.play("hel_army_summon", origin + Vector2.from_angle(i * 2.4) * (80 + i * 15))
			await process_frame
			var now = Time.get_ticks_usec()
			times.append((now - before) / 1000.0)
			before = now
		times.sort()
		var sum = 0.0
		for value in times:
			sum += value
		measurements.append({"phase": phase, "frames": times.size(), "mean_frame_ms": sum / times.size(), "p95_frame_ms": times[int(times.size() * 0.95)], "fps_over_interval": times.size() * 1000.0 / sum, "enemies": get_node_count_in_group("enemies"), "active_boss_effects": fx._boss_effects.size(), "nodes": get_node_count()})
	fx._boss_effects.clear()
	await create_timer(0.7).timeout
	measurements.append({"phase": "after_effects_expire", "active_boss_effects": fx._boss_effects.size(), "nodes": get_node_count()})
	FileAccess.open(OUTPUT + "performance.json", FileAccess.WRITE).store_string(JSON.stringify({"engine": Engine.get_version_info(), "viewport": [1280,720], "renderer": "gl_compatibility", "measurements": measurements, "note": "M2 local rendered test, four seconds per phase; no long-session guarantee"}, "\t"))
	print("PERFORMANCE ", measurements)
