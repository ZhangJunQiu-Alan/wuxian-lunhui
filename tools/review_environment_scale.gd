extends SceneTree

var game
var player
var output := ""
var label := "after"
var shots := []

func _initialize():
	call_deferred("run")

func capture(name, center):
	player.position = center
	player._camera.force_update_scroll()
	for child in game.get_children():
		if child is CanvasItem: child.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var file = name + "_" + label + ".png"
	var err = root.get_texture().get_image().save_png(output + "/" + file)
	shots.append({"file": file, "error": err, "level": game.level_id, "center": [center.x, center.y]})

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	if output.is_empty() or root.get_node("Save").path == "user://save.json":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var save = root.get_node("Save")
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	root.get_node("Settings").change("language", "zh")
	for level in ["midgard", "helheim", "vigrid"]:
		if not load("res://scripts/data/level_db.gd").is_built(level): continue
		save.selected_level = level
		game = load("res://scripts/game.gd").new()
		root.add_child(game)
		current_scene = game
		game.process_mode = Node.PROCESS_MODE_DISABLED
		await process_frame
		game.level_up_panel.choose(0)
		game.level_up_panel.hide()
		game.pause_menu.hide()
		paused = false
		player = game.player
		for power in player.gods.values(): power.free()
		player.gods.clear()
		player.faith.clear()
		game.hud.set_faith(player)
		player._camera.position_smoothing_enabled = false
		player._camera.offset = Vector2.ZERO
		if game.level_id != level: push_error("wrong level"); quit(3); return
		await capture(level + "_spawn", Vector2.ZERO)
		for lm in game.level_data.map.landmarks:
			await capture(level + "_" + lm.id, lm.pos + Vector2(0, 80))
		if label == "after":
			player.position = Vector2.ZERO
			var drops
			for child in game.get_children():
				if child.get_script() == load("res://scripts/world/supply_drops.gd"): drops = child
			var guard = drops._spawn("guard_rune", Vector2(100, 40))
			await process_frame
			await capture(level + "_guard_pickup", Vector2.ZERO)
			guard.collect()
			await capture(level + "_guard_active", Vector2.ZERO)
			player.dodge_chance = 0
			player._invincible_time = 0
			player.take_damage(10)
			await capture(level + "_guard_blocked", Vector2.ZERO)
		game.free()
		await process_frame
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
		await create_timer(0.2).timeout
		audio._streams.clear()
		audio.free()
		audio_script._instance = null
	var file = FileAccess.open(output + "/captures_" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(shots, "\t"))
	file.close()
	print("CAPTURES ", label, " ", shots.size())
	quit()
