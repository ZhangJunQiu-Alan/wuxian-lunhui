extends SceneTree

var checks := 0
var failures := []
var output := ""
var intro_script
var game_script
var book := {}
var save
var settings

func _initialize():
	call_deferred("run")

func check(ok, label):
	checks += 1
	if not ok: failures.append(label); push_error(label)

func frames(count := 3):
	for i in count: await process_frame

func clear_scene():
	paused = false
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames()

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	save = root.get_node("Save")
	settings = root.get_node("Settings")
	if output.is_empty() or save.path == "user://save.json": quit(2); return
	save.reset()
	intro_script = load("res://scripts/ui/chapter_intro.gd")
	game_script = load("res://scripts/game.gd")
	book = JSON.parse_string(FileAccess.get_file_as_string(intro_script.DATA))
	var font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	var initial_hub = load("res://scenes/hub.tscn").instantiate()
	root.add_child(initial_hub);current_scene=initial_hub
	await frames()
	var replay_buttons = initial_hub.find_children("*","Button",true,false).filter(func(button):return button.text==tr("回看本关剧情"))
	check(replay_buttons.size()==3,"three chapter replay buttons")
	for i in replay_buttons.size():
		check(replay_buttons[i].disabled==(i>0),"locked chapter story remains locked " + str(i))
	await clear_scene()
	for language in ["zh","en"]:
		settings.change("language",language)
		for id in book:
			var data = book[id]
			check(data.shots.size()==4,"four distinct story shots " + id)
			var previous_end := 0.0
			for shot in data.shots:
				check(float(shot.start)<=previous_end+0.001 and float(shot.end)>float(shot.start),"continuous timeline " + id + "/" + shot.art)
				check(float(shot.voice_start)+float(shot.voice_seconds)<float(shot.end)-0.6,"voice finishes before shot exit " + id + "/" + shot.art)
				check(float(shot.caption_start)<float(shot.voice_start) and float(shot.caption_end)>float(shot.voice_start)+float(shot.voice_seconds),"caption brackets voice " + id + "/" + shot.art)
				previous_end = float(shot.end)
				for line in tr(str(shot.caption)).split("\n"):
					check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x<1140,"subtitle fits " + language + "/" + id)
			var intro = intro_script.new()
			intro.level_id = id
			root.add_child(intro)
			current_scene = intro
			await frames()
			check(intro.duration==data.duration,"matching duration " + id)
			check(intro._textures.values().all(func(t):return t is Texture2D and t.get_width()>0),"all textures load " + id)
			check(intro.music.bus==&"Music" and intro.effects.bus==&"SFX" and intro.narration.bus==&"SFX","settings audio buses " + id)
			intro.timeline.seek(1.0,true)
			intro._toggle_pause()
			var at = intro.playhead
			await create_timer(0.08).timeout
			check(is_equal_approx(at,intro.playhead) and intro.narration.stream_paused,"manual pause freezes picture and voice " + id)
			intro._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			intro._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			check(not intro.timeline.is_playing(),"refocus preserves manual pause " + id)
			intro._toggle_pause()
			check(intro.timeline.is_playing() and not intro.narration.stream_paused,"resume picture and voice " + id)
			intro._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			check(not intro.timeline.is_playing() and intro.music.stream_paused,"focus loss suspends all stems " + id)
			intro._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			check(intro.timeline.is_playing(),"focus regain resumes " + id)
			await clear_scene()
	settings.change("language","zh")
	save.cleared_levels.assign(["midgard","helheim"])
	for id in book:
		for route in ["complete","escape","gamepad"]:
			save.selected_level = id
			var stats_before = save.stats.duplicate(true)
			var hub = load("res://scenes/hub.tscn").instantiate()
			root.add_child(hub)
			current_scene = hub
			await frames()
			hub._start_battle()
			hub._start_battle()
			await frames(5)
			var intro = current_scene
			check(intro.get_script()==intro_script and intro.level_id==id,"Hub selects matching intro " + id)
			check(get_nodes_in_group("enemies").is_empty(),"no battle simulation behind intro " + id)
			check(save.stats==stats_before,"intro awards no rewards or run stats " + id)
			if route != "complete":
				intro.timeline.seek(1.0,true)
				if route=="escape":
					var key := InputEventKey.new()
					key.keycode=KEY_ESCAPE; key.pressed=true
					intro._unhandled_input(key)
				else:
					var button := InputEventJoypadButton.new()
					button.button_index=JOY_BUTTON_A;button.pressed=true
					intro._unhandled_input(button)
				intro._finish(true)
			else:
				intro._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
				intro.timeline.seek(intro.duration-0.04,true)
				await create_timer(0.15).timeout
			await frames(7)
			check(current_scene.get_script()==game_script and current_scene.level_id==id,"completion/skip enters correct battle " + id)
			if current_scene.get_script()==game_script:
				check(current_scene.elapsed==0 and current_scene.level_up_panel.visible,"battle starts at zero with initial god choice " + id)
				if route=="complete":
					current_scene.hud._on_restart_pressed()
					await frames(5)
					check(current_scene.get_script()==intro_script and current_scene.level_id==id,"result retry enters matching intro " + id)
					current_scene._finish(true)
					await frames(5)
					check(current_scene.get_script()==game_script and current_scene.elapsed==0,"retry starts battle after intro " + id)
			await clear_scene()
		var hub = load("res://scenes/hub.tscn").instantiate()
		root.add_child(hub); current_scene=hub
		await frames()
		intro_script.open(self,id,true)
		await frames(5)
		check(current_scene.replay_only and current_scene.level_id==id,"replay selects matching sequence " + id)
		current_scene._finish(true)
		await frames(5)
		check(current_scene.get_script()==hub.get_script() if is_instance_valid(hub) else current_scene.scene_file_path=="res://scenes/hub.tscn","replay returns to Hub " + id)
		await clear_scene()
	save.selected_level="midgard"
	var game=game_script.new()
	root.add_child(game);current_scene=game
	await frames()
	save.selected_level="helheim"
	game.hud._on_restart_pressed()
	await frames(5)
	check(current_scene.get_script()==intro_script and current_scene.level_id=="helheim","post-clear next selection shows next chapter story")
	current_scene._finish(true)
	await frames(5)
	check(current_scene.get_script()==game_script and current_scene.level_id=="helheim","post-clear continuation enters next chapter battle")
	await clear_scene()
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer: child.stop();child.stream=null
		await create_timer(0.2).timeout
		audio._streams.clear();audio.free();audio_script._instance=null
	check(get_nodes_in_group("enemies").is_empty(),"all route tests release battle entities")
	var file=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("CHAPTER_INTRO_RESULT ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
