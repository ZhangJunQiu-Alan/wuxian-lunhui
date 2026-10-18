extends SceneTree

const OUTPUT := "res://assets/source/taskI1_bridge_guard_2026-10-19/runtime/"
var game
var player
var quest
var checks: Array = []
var screenshots: Array = []
var outcomes: Array = []

func _initialize():
	call_deferred("run")

func check(ok, label, actual = null):
	checks.append({"pass": bool(ok), "label": label, "actual": actual})
	print("PASS " if ok else "FAIL ", label)

func on_finished(_quest, success):
	outcomes.append(success)

func new_game(level):
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
		await process_frame
	paused = false
	root.get_node("Save").cleared_levels.assign(["midgard"])
	root.get_node("Save").selected_level = level
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
	check(game.level_id == level, "actual level " + level)
	player.hp = player.max_hp
	player.position = load("res://scripts/world/map_layer.gd").push_out(Vector2.ZERO, 20)

func create_quest(id):
	quest = load("res://scripts/quests/" + id + "_quest.gd").new()
	quest.game = game
	quest.player = player
	quest.landmark = {"pos": player.position, "radius": 100.0}
	var landmarks = {"bonfire": "village", "valkyrie": "mounds", "hoof_tracks": "hall", "river_sword": "ford"}
	if id in landmarks:
		quest.landmark = game.landmark_by_id(landmarks[id])
	quest.finished.connect(on_finished)
	game.add_child(quest)
	if id in landmarks:
		check(not quest.landmark.is_empty(), "actual quest landmark " + landmarks[id])
	if id != "valkyrie" and id != "hoof_tracks":
		quest._wave_timer = 1000.0

func capture(name, center):
	if "--headless-audit" in OS.get_cmdline_user_args():
		return
	player.position = center + Vector2(-110, 45)
	game.pause_menu.close()
	paused = false
	player._camera.reset_smoothing()
	player._camera.force_update_scroll()
	quest.queue_redraw()
	quest.overlay.queue_redraw()
	await process_frame
	await process_frame
	game.pause_menu.close()
	paused = false
	await RenderingServer.frame_post_draw
	check(not game.pause_menu._root.visible, "capture unobstructed " + name)
	var result = root.get_texture().get_image().save_png(OUTPUT + name + ".png")
	check(result == OK, "capture " + name)
	var transform = quest.get_global_transform_with_canvas()
	var marker_screen = transform * quest.marker_pos
	var player_screen = transform * player.position
	var asset_screen = transform * center
	if name.begins_with("I1"):
		asset_screen = transform * Vector2(quest._zone.end.x + 34.0, quest._zone.end.y + 30.0)
	elif name.begins_with("I3"):
		asset_screen = transform * (player.position + Vector2(0,-34))
	elif name == "I6_carry_overlay":
		asset_screen = transform * quest._altar
	screenshots.append({"file": name + ".png", "state": quest.state, "time": quest._time, "level": game.level_id, "marker_screen": [marker_screen.x,marker_screen.y], "player_screen": [player_screen.x,player_screen.y], "asset_screen": [asset_screen.x,asset_screen.y], "pause_visible": game.pause_menu._root.visible})

func run():
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280, 720)
	for row in [["bridge_guard",64,64], ["bridge_guard_idle",256,64], ["bonfire_survivors",128,64], ["valkyrie_wings",256,32], ["iron_horseshoe",16,16], ["river_sword",128,64], ["sun_altar",96,96]]:
		var t = load("res://assets/sprites/quests/" + row[0] + ".png")
		check(t is Texture2D and t.get_width() == row[1] and t.get_height() == row[2], "texture " + row[0])
		if "--texture-audit-only" in OS.get_cmdline_user_args():
			t.get_image().save_png(OUTPUT + "texture_" + row[0] + ".png")
	if "--texture-audit-only" in OS.get_cmdline_user_args():
		quit()
		return
	await new_game("helheim")
	create_quest("bridge_guard")
	await capture("I1_offered", quest.marker_pos)
	player.position = quest.marker_pos
	quest._process(0.0)
	check(quest.state == "active" and quest.time_left == 70.0, "bridge accepts at original marker and timer")
	for i in 4:
		quest._time = i / 8.0
		await capture("I1_idle_" + str(i), quest.marker_pos)
	player.position = quest._zone.get_center()
	quest._on_update(0.5)
	check(quest._held == 0.5 and quest._active_targets().is_empty(), "bridge accumulation inside")
	player.position = quest._zone.end + Vector2(80,80)
	quest._on_update(0.5)
	check(quest._held == 0.5 and quest._active_targets().size() == 1, "bridge outside no accumulation and pointer")
	quest._held = 39.5
	player.position = quest._zone.get_center()
	quest._on_update(0.5)
	check(quest.state == "done" and outcomes.back(), "bridge original 40 second completion")
	await process_frame
	await new_game("midgard")
	create_quest("bonfire")
	await capture("I2_offered", quest.marker_pos)
	player.position = quest.marker_pos
	quest._process(0.0)
	check(quest.state == "active" and quest.time_left == 90.0, "bonfire accepts and timer")
	quest._held = 20.0
	await capture("I2_active", quest.marker_pos)
	player.position = quest.marker_pos + Vector2(151,0)
	quest._on_update(0.5)
	check(quest._held == 20.0 and quest._active_targets().size() == 1, "bonfire original 150 radius and pointer")
	player.position = quest.marker_pos
	quest._held = 44.5
	quest._on_update(0.5)
	check(quest.state == "done" and outcomes.back(), "bonfire original 45 second completion")
	await process_frame
	create_quest("valkyrie")
	player.position = quest.marker_pos
	quest._process(0.0)
	check(game.spawn_mult == 3.0 and quest.time_left == 60.0, "wings retains trial spawn rate and timer")
	check(quest.overlay.z_index == 20, "wings player foreground overlay")
	for i in 4:
		quest._time = i / 8.0
		await capture("I3_wings_" + str(i), quest.marker_pos)
	game.kills = quest._start_kills + 149
	quest._on_update(0.0)
	check(quest.state == "active", "trial 149 kills incomplete")
	game.kills += 1
	quest._on_update(0.0)
	check(quest.state == "done" and game.spawn_mult == 1.0 and outcomes.back(), "trial 150 kills and spawn cleanup")
	await process_frame
	await new_game("helheim")
	create_quest("hoof_tracks")
	player.position = quest.marker_pos
	quest._process(0.0)
	check(quest._shoes.size() == 5 and quest.time_left == 60.0, "hoof quest five collectibles and timer")
	await capture("I4_horseshoe", quest._shoes[0])
	var first = quest._shoes[0]
	player.position = first + Vector2(50,0)
	quest._on_update(0.0)
	check(quest._found == 0, "horseshoe outside pickup radius")
	player.position = first
	quest._on_update(0.0)
	check(quest._found == 1 and quest._shoes.size() == 4, "horseshoe pickup removes one")
	check(quest._active_targets()[0] == quest._shoes[0], "horseshoe pointer advances")
	for i in 4:
		player.position = quest._shoes[0]
		quest._on_update(0.0)
	check(quest.state == "done" and outcomes.back(), "horseshoe original five-item completion")
	await process_frame
	create_quest("river_sword")
	player.position = quest.marker_pos
	quest._process(0.0)
	check(quest.state == "active" and quest.time_left == 45.0, "sword accepts original timer")
	for i in 4:
		quest._time = i / 8.0
		quest._dug = 7.5
		await capture("I5_sword_" + str(i), quest.marker_pos)
	player.position = quest.marker_pos + Vector2(91,0)
	quest._on_update(0.5)
	check(quest._dug == 7.5 and quest._active_targets().size() == 1, "sword original 90 radius and pointer")
	player.position = quest.marker_pos
	quest._dug = 14.5
	quest._on_update(0.5)
	check(quest.state == "done" and outcomes.back(), "sword original 15 second completion")
	await process_frame
	await new_game("midgard")
	create_quest("ember")
	player.position = quest.marker_pos
	quest._process(0.0)
	check(quest.state == "active" and quest.time_left == 45.0, "ember accepts original timer")
	quest._on_update(0.01)
	check(player.speed_mult == 0.8, "ember carrying speed unchanged")
	await capture("I6_altar", quest._altar)
	player.position = quest._altar + Vector2(0,20)
	quest.queue_redraw()
	quest.overlay.queue_redraw()
	await capture("I6_carry_overlay", quest._altar + Vector2(110,-25))
	quest._ember = player.position
	quest._on_hp_changed(player.hp - 1.0, player.max_hp)
	check(not quest._carried and quest._cooldown == 1.0, "ember damage drop and cooldown unchanged")
	player.position = quest._ember
	quest._on_update(0.5)
	check(not quest._carried and player.speed_mult == 1.0, "ember cooldown prevents pickup restores speed")
	quest._on_update(0.6)
	check(quest._carried, "ember pickup after cooldown")
	player.position = quest._altar
	quest._on_update(0.01)
	check(quest.state == "done" and outcomes.back() and player.speed_mult == 1.0, "ember original altar radius completion and cleanup")
	check(not player.hp_changed.is_connected(quest._on_hp_changed), "ember disconnects signal")
	await process_frame
	var failures = checks.filter(func(c): return not c.pass)
	var report = {"checks": checks, "failures": failures, "screenshots": screenshots, "scope": "controlled actual Game rendering and quest interaction, not a manual playthrough"}
	FileAccess.open(OUTPUT + "runtime_checks.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("QUEST ART CHECKS ", checks.size(), " FAILURES ", failures.size())
	game.queue_free()
	await process_frame
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for t in audio._tweens.values():
			t.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
		audio._streams.clear()
		audio.free()
		audio_script._instance = null
	await process_frame
	await create_timer(0.15).timeout
	quit(1 if failures.size() else 0)
