extends SceneTree

var checks: Array = []
var captures: Array = []
var game
var player
var panel
var panel_script
var upgrades
var god_power
var render := false
var output := "res://validation/"
var ids_path := "res://validation/card_ids.json"

func _initialize():
	call_deferred("run")

func check(ok, label, actual = null):
	checks.append({"pass": bool(ok), "label": label, "actual": actual})
	if not ok:
		push_error(label + " " + str(actual))

func textures(node):
	var found: Array = []
	if node is TextureRect and node.texture is CompressedTexture2D:
		found.append(node)
	for child in node.get_children():
		found.append_array(textures(child))
	return found

func labels(node):
	var found: Array = []
	if node is Label:
		found.append(node)
	for child in node.get_children():
		found.append_array(labels(child))
	return found

func settle():
	await process_frame
	await process_frame
	await process_frame

func capture(name, ids):
	if not render:
		return
	await RenderingServer.frame_post_draw
	var path = output + name + ".png"
	var status = root.get_texture().get_image().save_png(path)
	check(status == OK, "viewport capture " + name)
	captures.append({"path": path, "ids": ids, "window": [root.size.x, root.size.y]})

func run():
	for arg in OS.get_cmdline_user_args():
		if arg == "--render": render = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--ids-file="): ids_path = arg.trim_prefix("--ids-file=")
	DirAccess.make_dir_recursive_absolute(output)
	if root.get_node("Save").path == "user://save.json":
		push_error("Use an isolated --save-file path")
		quit(2)
		return
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280, 720)
	root.get_node("Settings")._apply_language()
	root.get_node("Save").selected_level = "midgard"
	root.get_node("Save").selected_character = "swordsman"
	upgrades = load("res://scripts/data/upgrade_db.gd")
	panel_script = load("res://scripts/ui/level_up_panel.gd")
	god_power = load("res://scripts/gods/god_power.gd")
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	current_scene = game
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await settle()
	panel = game.level_up_panel
	player = game.player
	panel.choose(0)
	game._pending_rewards.clear()
	check(player.faith.size() == 1, "initial actual Game god choice applied")
	check(panel.process_mode == Node.PROCESS_MODE_ALWAYS, "cards receive input while game paused")
	var ids = JSON.parse_string(FileAccess.get_file_as_string(ids_path))
	check(ids.size() == 60, "60 independent card IDs")
	for id in ids:
		var path = panel_script.ART_DIR + id + ".png"
		var texture = load(path)
		check(texture is CompressedTexture2D, "imported texture " + id)
		if not texture is Texture2D: continue
		check(texture.get_size() == Vector2(720, 1200), "dimensions " + id)
		check(texture.get_image().has_mipmaps(), "real imported mipmaps " + id)
		check(texture.get_image().get_mipmap_count() == 10, "ten imported mip levels " + id)
		var info = upgrades.get_info(id)
		check(info.kind in ["path", "awaken", "fusion"], "actual gameplay entry " + id)
	var widths = [1280] if "--baseline" in OS.get_cmdline_user_args() else [1280, 960, 1600]
	for width in widths:
		root.size = Vector2i(width, width * 9 / 16)
		await settle()
		var max_cards = 3 if "--baseline" in OS.get_cmdline_user_args() else ids.size()
		for start in range(0, max_cards, 3):
			var offers: Array[Dictionary] = []
			var shown: Array = []
			for i in range(start, mini(start + 3, ids.size())):
				offers.append({"id": ids[i], "rarity": -1})
				shown.append(ids[i])
			var info = upgrades.get_info(shown[0])
			panel.open(offers, player, {"kind": info.kind, "god": info.god})
			paused = true
			await settle()
			var cards = panel._cards.get_children()
			check(cards.size() == shown.size(), "card count " + str(width) + "/" + str(start))
			for i in cards.size():
				var card = cards[i]
				var art = textures(card)
				check(art.size() == 1 and art[0].texture.resource_path == panel_script.ART_DIR + shown[i] + ".png", "exact ID instead of generic/split " + shown[i] + "/" + str(width))
				if art.size() == 1:
					check(art[0].texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "linear mip filter " + shown[i])
				check(card.size.is_equal_approx(panel_script.CARD_SIZE), "card dimensions " + shown[i] + "/" + str(width), [card.size.x, card.size.y])
				var bounds = card.get_global_rect().grow(0.5)
				for label in labels(card):
					check(bounds.encloses(label.get_global_rect()), "text stays inside card " + shown[i] + ":" + label.text, [label.position.x,label.position.y,label.size.x,label.size.y])
			await capture("cards_" + str(width) + "_" + str(start / 3).pad_zeros(2), shown)
	if not "--baseline" in OS.get_cmdline_user_args():
		await regular_cards()
		await selection_flow()
		await fallbacks()
	var failed = checks.filter(func(c): return not c["pass"]).size()
	var report = {"checks": checks, "passed": checks.size() - failed, "failed": failed, "captures": captures, "engine": Engine.get_version_info().string, "scope": "actual Game reward panel, imported textures, controlled selection and fallback checks; not a complete playthrough"}
	var file = FileAccess.open(output + "results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CARD_ART_RESULT checks=", checks.size(), " failed=", failed, " captures=", captures.size())
	paused = false
	game.free()
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
	await create_timer(0.15).timeout
	OS.delay_msec(200)
	quit(1 if failed else 0)

func selection_flow():
	for power in player.gods.values(): power.free()
	player.gods.clear()
	player.faith.clear()
	player.add_god("thor")
	player.add_god("odin")
	player.faith["thor"] = upgrades.FAITH_PATH
	game._pending_rewards.clear()
	game._queue_reward({"kind": "path", "god": "thor"})
	await settle()
	check(panel._offers.size() == 3, "actual queued path reward has three roads")
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	Input.parse_input_event(key)
	await settle()
	check(player.gods["thor"].path == "thor_cloud", "keyboard2 applies displayed road through Game")
	player.faith["thor"] = upgrades.FAITH_AWAKEN
	game._queue_reward({"kind": "awaken", "god": "thor"})
	await settle()
	check(panel._offers[0].id == "thor_cloud_awaken", "actual queued awakening uses selected road ID")
	panel._cards.get_child(0).pressed.emit()
	await settle()
	check(player.gods["thor"].awakened, "card button applies awakening through Game")
	game._pending_rewards.clear()
	player.gods["odin"].set_path("odin_ravens")
	player.gods["odin"].awaken()
	game._queue_reward({"kind": "fusion", "fusion": "father_son"})
	await settle()
	check(panel._offers[0].id == "fusion_father_son", "actual queued fusion ID")
	panel._cards.get_child(0).pressed.emit()
	await settle()
	check(god_power.has_fusion("father_son"), "card button applies fusion through Game")
	check(not paused and not panel.visible, "Game resumes when reward queue finishes")

func regular_cards():
	root.size = Vector2i(1280, 720)
	var offers: Array[Dictionary] = []
	for id in ["katana_damage", "might", "thor_skill", "thor_cloud"]:
		offers.append({"id": id, "rarity": 3 if id in ["katana_damage", "might"] else -1})
	panel.open(offers, player, {"kind": "level"})
	await settle()
	var cards = panel._cards.get_children()
	check(cards.size() == 4, "four-choice layout retained")
	for card in cards:
		var bounds = card.get_global_rect().grow(0.5)
		check(Rect2(Vector2.ZERO, root.content_scale_size).encloses(bounds.grow(-1)), "four-choice card inside viewport")
		for label in labels(card):
			check(bounds.encloses(label.get_global_rect()), "regular card text stays inside: " + label.text)
	var picture = cards[3].get_child(0).get_child(0)
	cards[3].mouse_entered.emit()
	check(picture.modulate == Color.WHITE, "hover restores full illustration brightness")
	cards[3].mouse_exited.emit()
	check(picture.modulate.is_equal_approx(Color(0.8,0.8,0.8)), "mouse exit restores illustration tint")
	await capture("regular_four_choices", ["katana_damage", "might", "thor_skill", "thor_cloud"])

func fallbacks():
	var info = upgrades.get_info("thor_skill")
	var card = panel._make_card(0, {"id": "thor_skill", "rarity": -1}, player)
	var art = textures(card)
	check(art.size() == 1 and art[0].texture.resource_path.ends_with("/thor.png"), "base god portrait unchanged")
	card.free()
	var split = panel._split_art(panel._card_art(panel_script.ART_DIR + "thor.png", info, Color.BLUE), panel._card_art(panel_script.ART_DIR + "odin.png", info, Color.PURPLE))
	check(textures(split).size() == 2, "two-portrait fusion fallback still available")
	split.free()
	var missing = panel._card_art("res://assets/sprites/cards/missing_test_card.png", info, Color.BLUE)
	check(missing != null and textures(missing).is_empty(), "missing image retains geometric fallback")
	missing.free()
