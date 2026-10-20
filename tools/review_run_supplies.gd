extends SceneTree

var game
var player
var drops
var output := ""
var shots := []
var xp_script

func _initialize():
	call_deferred("run")

func capture(name):
	for child in game.get_children():
		if child is CanvasItem: child.queue_redraw()
	player._camera.force_update_scroll()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var err = root.get_texture().get_image().save_png(output + "/" + name + ".png")
	shots.append({"name": name, "error": err, "size": root.size})

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
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
	xp_script = load("res://scripts/entities/xp_gem.gd")
	for level in ["midgard", "helheim", "vigrid"]:
		save.selected_level = level
		game = load("res://scripts/game.gd").new()
		root.add_child(game)
		current_scene = game
		if game.level_id != level:
			push_error("Wrong level " + game.level_id + " expected " + level)
			quit(3)
			return
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
		player.position = load("res://scripts/world/map_layer.gd").push_out(Vector2.ZERO, 22)
		player._camera.position_smoothing_enabled = false
		player._camera.offset = Vector2.ZERO
		for child in game.get_children():
			if child.get_script() == load("res://scripts/world/supply_drops.gd"): drops = child
		var mead = drops._spawn("healing_mead", player.position + Vector2(100, 40))
		var magnet = drops._spawn("soul_magnet", player.position + Vector2(-100, 40))
		await process_frame
		for i in 32:
			var gem = xp_script.new()
			gem.player = player
			gem.position = player.position + Vector2.from_angle(TAU * i / 32) * (250 + (i % 3) * 55)
			game.add_child(gem)
		var chest = load("res://scripts/entities/chest.gd").new()
		chest.player = player
		chest.position = player.position + Vector2(160, 100)
		game.add_child(chest)
		var heal = load("res://scripts/gods/heal_pickup.gd").new()
		heal.player = player
		heal.kind = "apple"
		heal.position = player.position + Vector2(-160, 100)
		game.add_child(heal)
		await capture(level + "_supplies")
		player.hp -= 20
		player.position = mead.global_position
		mead._process(0.1)
		await capture(level + "_mead_collected")
		player.position = magnet.global_position
		magnet._process(0.1)
		for frame in 8:
			for gem in get_nodes_in_group("xp_gems"):
				gem._process(0.05)
			for pickup in drops.get_children(): pickup.queue_redraw()
			await capture(level + "_magnet_%02d" % frame)
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
	await process_frame
	var file = FileAccess.open(output + "/captures.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(shots, "\t"))
	file.close()
	print("CAPTURES ", shots.size())
	quit()
