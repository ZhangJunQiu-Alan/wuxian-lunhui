extends SceneTree

var checks := 0
var failures: Array[String] = []
var capture_dir := ""
var test_quit := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		if arg == "--test-quit":
			test_quit = true
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)


func settle() -> void:
	for i in 3:
		await process_frame


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await settle()


func capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	check(image.save_png(capture_dir.path_join(label + ".png")) == OK, "capture " + label)


func cleanup_audio() -> void:
	if not is_instance_valid(Audio._instance):
		return
	var audio := Audio._instance
	for tween in audio._tweens.values():
		tween.kill()
	audio._tweens.clear()
	for player in audio.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	audio._streams.clear()
	audio.free()
	Audio._instance = null


func layout_checks(title: Control, label: String) -> void:
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	var previous_bottom := 0.0
	for button: Button in title._buttons:
		var bounds := button.get_global_rect()
		check(viewport.encloses(bounds), label + " button inside viewport: " + button.text)
		check(bounds.position.y >= previous_bottom, label + " non-overlapping rows: " + button.text)
		previous_bottom = bounds.end.y
	var logo: TextureRect = title._content.get_child(0)
	check(viewport.encloses(logo.get_global_rect()), label + " logo inside viewport")
	check(logo.get_global_rect().end.y < title._buttons[0].get_global_rect().position.y, label + " logo above menu")


func mouse_settings(title: Control) -> void:
	var pointer := InputEventMouseMotion.new()
	pointer.position = title._buttons[2].get_global_rect().get_center()
	Input.parse_input_event(pointer)
	await settle()
	check(title._buttons[2].has_focus(), "mouse hover selects settings")
	var click := InputEventMouseButton.new()
	click.position = pointer.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await settle()
	click = InputEventMouseButton.new()
	click.position = pointer.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	Input.parse_input_event(click)
	await settle()
	check(title._settings.visible, "mouse click opens settings")
	await key(KEY_ESCAPE)
	check(not title._settings.visible, "mouse-opened settings closes")


func run() -> void:
	var save = root.get_node("Save")
	var settings = root.get_node("Settings")
	if save.path == "user://save.json" or settings.path == "user://settings.cfg":
		push_error("Use isolated --save-file and --settings-file paths")
		quit(2)
		return
	settings.change("language", "zh")
	change_scene_to_file("res://scenes/title.tscn")
	await settle()
	var title = current_scene
	await create_timer(0.9).timeout
	check(title._buttons.size() == 5, "five native menu buttons")
	check(title._buttons[0].has_focus(), "start focused on entry")
	check(title._buttons[0].text == "开始游戏", "Chinese start label")
	check(title._content.modulate.a > 0.99, "intro completes")
	var logo: TextureRect = title._content.get_child(0)
	check(logo.texture is AtlasTexture, "isolated logo texture")
	check(logo.texture.atlas.get_image().detect_alpha() != Image.ALPHA_NONE, "logo alpha retained")
	check(title.get_child(0).texture.resource_path == title.BACKGROUND, "clean temple background loaded")
	if test_quit:
		title._buttons[4].set_meta("silent", true)
		cleanup_audio()
		await create_timer(0.2).timeout
		title._buttons[4].pressed.connect(func() -> void: print("QUIT_BUTTON_ACTIVATED"))
		title._buttons[4].grab_focus()
		await key(KEY_ENTER)
		push_error("Quit button did not exit")
		quit(1)
		return
	await key(KEY_DOWN)
	check(title._buttons[1].has_focus(), "down selects codex")
	await key(KEY_UP)
	check(title._buttons[0].has_focus(), "up returns to start")
	await key(KEY_UP)
	check(title._buttons[4].has_focus(), "up wraps to quit")
	await key(KEY_DOWN)
	check(title._buttons[0].has_focus(), "down wraps to start")
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	check(is_instance_valid(title._overlay), "keyboard opens codex")
	check(title._buttons[0].disabled, "codex blocks background menu")
	await key(KEY_ENTER)
	check(current_scene == title, "Enter in codex cannot start game")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(title._overlay), "Escape closes codex")
	check(title._buttons[1].has_focus(), "codex restores selected focus")
	title._buttons[2].grab_focus()
	await key(KEY_ENTER)
	check(title._settings.visible, "keyboard opens settings")
	check(title._buttons[0].disabled, "settings blocks background menu")
	await key(KEY_ENTER)
	check(current_scene == title, "Enter in settings cannot start game")
	await key(KEY_ESCAPE)
	check(not title._settings.visible, "Escape closes settings")
	check(title._buttons[2].has_focus(), "settings restores selected focus")
	title._buttons[3].grab_focus()
	await key(KEY_ENTER)
	check(is_instance_valid(title._overlay), "keyboard opens credits")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(title._overlay), "Escape closes credits")
	check(title._buttons[3].has_focus(), "credits restores selected focus")
	if DisplayServer.get_name() != "headless":
		await mouse_settings(title)
	title._buttons[0].grab_focus()
	root.content_scale_size = Vector2i.ZERO
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 1000), Vector2i(1920, 800)]:
		root.size = dimensions
		await settle()
		var label := "zh_%dx%d" % [dimensions.x, dimensions.y]
		layout_checks(title, label)
		await capture(label)
	root.size = Vector2i(1280, 720)
	await settle()
	title._buttons[2].grab_focus()
	await key(KEY_ENTER)
	settings.change("language", "en")
	await settle()
	title = current_scene
	check(title._settings.visible, "language reload reopens settings")
	check(title._buttons[0].text == "Start Game", "English menu localization")
	check(title._buttons[0].disabled, "language reload keeps background blocked")
	await key(KEY_ESCAPE)
	check(not title._settings.visible, "English settings closes")
	layout_checks(title, "English")
	title._buttons[0].grab_focus()
	await settle()
	await capture("en_1280x720")
	await key(KEY_ENTER)
	check(current_scene.scene_file_path == "res://scenes/hub.tscn", "Enter starts hub")
	change_scene_to_file("res://scenes/title.tscn")
	await settle()
	title = current_scene
	check(title._content.modulate.a == 1.0, "return skips intro")
	check(title._buttons[0].has_focus(), "return restores start focus")
	print("TITLE_MENU_RESULT ", checks, " checks, ", failures.size(), " failures")
	for failure in failures:
		print("FAIL ", failure)
	current_scene.queue_free()
	await settle()
	cleanup_audio()
	await create_timer(0.2).timeout
	await settle()
	quit(0 if failures.is_empty() else 1)
