extends SceneTree

var game
var output := ""
var actors := []
var specs := []

func _initialize():
	call_deferred("run")

func capture(label):
	game.player._camera.force_update_scroll()
	for actor in actors: actor.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var result = root.get_texture().get_image().save_png(output + "/actors_" + label + ".png")
	print("CAPTURE ", label, " ", result)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty() or root.get_node("Save").path == "user://save.json": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.get_node("Save").reset()
	root.get_node("Settings").change("language", "zh")
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	current_scene = game
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	game.level_up_panel.choose(0)
	game.level_up_panel.hide()
	paused = false
	for power in game.player.gods.values(): power.free()
	game.player.gods.clear()
	game.player.faith.clear()
	game.hud.set_faith(game.player)
	game.player._camera.position_smoothing_enabled = false
	var i := 0
	for id in ["swordsman", "gunslinger", "assassin", "mage"]:
		var actor = game.player if i == 0 else load("res://scripts/entities/player.gd").new()
		if i > 0:
			actor.character_id = id
			game.add_child(actor)
			actor._camera.enabled = false
		actor.position = Vector2(-300 + i * 200, -90)
		actor._sprite.rotation = 0
		if actor._actions: actor._actions.pause(); actor._actions.frame = 0
		actors.append(actor)
		specs.append({"name": id, "position": [actor.position.x, actor.position.y]})
		i += 1
	game.player._camera.position = -game.player.position
	for item in [["draugr",false],["wolf",false],["ice_spirit",false],["frost_giant",false],["draugr",true],["wolf",true]]:
		var actor = game.spawn_enemy(item[0], Vector2(-350 + (actors.size() - 4) * 140, 120), item[1], true)
		if actor._actions: actor._actions.pause(); actor._actions.frame = 0
		actors.append(actor)
		specs.append({"name": item[0] + ("_elite" if item[1] else ""), "position": [actor.position.x, actor.position.y]})
	for actor in actors:
		actor._sprite.scale /= 1.1
		actor._sprite.set_meta("base_scale", actor._sprite.scale)
	await capture("before")
	for actor in actors:
		actor._sprite.scale *= 1.1
		actor._sprite.set_meta("base_scale", actor._sprite.scale)
	await capture("after")
	var file = FileAccess.open(output + "/captures.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"actors": specs, "viewport": [1280,720], "method": "same Game scene; before removes only the requested1.1 display multiplier; after restores it; same atlas frames and foot positions"}, "\t"))
	file.close()
	game.free()
	await process_frame
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer: child.stop(); child.stream = null
		await create_timer(0.2).timeout
		audio._streams.clear()
		audio.free()
		audio_script._instance = null
	quit()
