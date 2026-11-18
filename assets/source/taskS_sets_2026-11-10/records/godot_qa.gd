extends SceneTree

const GROUND := ["雪地", "冥界", "焦土"]
var batch := ""
var output := ""
var preview: Reels


class Reels extends Node2D:
	var data: Dictionary
	var root_path: String
	var font: Font
	var tiles: Array[Texture2D] = []
	var body: Texture2D
	var guardians := {}
	var effects: Array[Dictionary] = []
	var playback := 0.0
	var frame_override := -1
	var wanted_ground := -1

	func _ready() -> void:
		texture_filter = TEXTURE_FILTER_NEAREST
		font = ThemeDB.fallback_font
		for label in GROUND:
			tiles.append(load_image(data.grounds[label]))
		body = load_image(data.player)
		for action: String in data.guardian:
			guardians[action] = load_image(data.guardian[action].file)
		for item: Dictionary in data.files:
			if item.kind == "effects":
				effects.append({"meta": item, "image": load_image(item.file)})

	func load_image(path: String) -> ImageTexture:
		var image := Image.load_from_file(root_path.path_join(path).simplify_path())
		if image == null:
			push_error("missing " + path)
			return null
		return ImageTexture.create_from_image(image)

	func _process(delta: float) -> void:
		playback += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1152, 900), Color("#141b23"))
		for i in effects.size():
			var meta: Dictionary = effects[i].meta
			var texture: Texture2D = effects[i].image
			var ground := wanted_ground if wanted_ground >= 0 else i % 3
			var tile := tiles[ground]
			var panel := Vector2(8 + (i % 4) * 286, 10 + floori(i / 4.0) * 296)
			var target := Rect2(panel + Vector2(12, 25), Vector2(266, 260))
			draw_texture_rect(tile, target, true)
			draw_string(font, panel + Vector2(12, 18), meta.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e2d6b7"))
			var center := target.get_center()
			var size := Vector2(meta.frame_size[0], meta.frame_size[1])
			var anchor := Vector2(meta.anchor[0], meta.anchor[1])
			var n := (floori(playback * float(meta.fps)) if frame_override < 0 else frame_override) % int(meta.frames)
			var dest := Rect2(center - anchor, size)
			var source := Rect2(Vector2(size.x * n, 0), size)
			var layer: String = meta.layer
			var draw_body: bool = meta.id in ["thornoath_burst", "dragonslayer_scale", "dragonslayer_shatter", "lotus_proc", "xingtian_mengzhi"]
			var behind: bool = layer.contains("后方") or layer.contains("之间")
			var body_dest := Rect2(center - Vector2(32, 32), Vector2(64, 64))
			if draw_body and not behind:
				draw_texture_rect_region(body, body_dest, Rect2(0, 0, 64, 64))
			draw_texture_rect_region(texture, dest, source)
			if draw_body and behind:
				draw_texture_rect_region(body, body_dest, Rect2(0, 0, 64, 64))
			if meta.id == "valhalla_ring":
				var action := "attack" if frame_override >= 4 else "idle"
				var actor: Dictionary = data.guardian[action]
				var actor_frame := (maxi(frame_override, 0) if action == "idle" else frame_override - 4) % int(actor.frames)
				draw_texture_rect_region(guardians[action], Rect2(center - Vector2(32, 55), Vector2(64, 64)),
					Rect2(actor_frame * 64, 0, 64, 64))


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--batch="):
			batch = option.trim_prefix("--batch=")
		elif option.begins_with("--output="):
			output = option.trim_prefix("--output=")
	call_deferred("run")


func run() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(batch.path_join("manifest.json")))
	if not manifest is Dictionary or output.is_empty():
		push_error("Pass --batch and --output with absolute paths")
		quit(2)
		return
	preview = Reels.new()
	preview.data = manifest
	preview.root_path = batch
	root.add_child(preview)
	if preview.effects.size() != 10 or preview.tiles.has(null) or preview.body == null or preview.guardians.size() != 2:
		push_error("S-SET preview is incomplete")
		quit(1)
		return
	var checks := 0
	for ground in range(GROUND.size()):
		preview.wanted_ground = ground
		for frame in range(10):
			preview.frame_override = frame
			preview.queue_redraw()
			await process_frame
			RenderingServer.force_draw(false)
			var texture := root.get_texture().get_image()
			if not texture or texture.is_empty():
				push_error("Godot capture failed")
				quit(1)
				return
			if frame in [1, 3, 6]:
				var path := output.path_join("godot-r2-%d-frame-%d.png" % [ground+1, frame+1])
				if texture.save_png(path) != OK:
					push_error("Could not save " + path)
					quit(1)
					return
			checks += 1
	preview.queue_free()
	await process_frame
	print("S-SET GODOT: ", checks, " rendered sheets · 10 effects · 2 guardian actions · 3 ground tiles · 1x")
	quit()
