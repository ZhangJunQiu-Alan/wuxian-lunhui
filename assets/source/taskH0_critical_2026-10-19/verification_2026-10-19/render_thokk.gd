extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var stage = Node2D.new()
	root.add_child(stage)
	current_scene = stage
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color("121721"))
	var font = ThemeDB.fallback_font
	var enemies: Array = []
	var enemy_script = load("res://scripts/entities/enemy.gd")
	for i in 3:
		var e = enemy_script.new()
		e.setup("frost_giant" if i == 2 else "thokk", 1.0, i == 1)
		e.position = Vector2(220 + i * 400, 230)
		e.process_mode = Node.PROCESS_MODE_DISABLED
		stage.add_child(e)
		enemies.append(e)
	var drawing = Node2D.new()
	stage.add_child(drawing)
	drawing.draw.connect(func():
		drawing.draw_string(font, Vector2(40, 45), "Godot current Enemy loader / source-pixel size / no game integration changes", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
		for i in 3:
			var e = enemies[i]
			var x = e.position.x
			var title = ["thokk normal 1x", "thokk elite 1.2x", "existing frost giant"][i]
			drawing.draw_string(font, Vector2(x - 150, 110), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
			drawing.draw_line(Vector2(x - 150, 250), Vector2(x + 150, 250), Color(0.2, 0.8, 0.5), 1)
			drawing.draw_circle(e.position, e.radius, Color(0.9, 0.3, 0.3), false, 1)
			drawing.draw_string(font, Vector2(x - 150, 360), "red: origin/collision; green: y+20", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8,0.8,0.8))
			drawing.draw_string(font, Vector2(x - 150, 390), "scale=" + str(e._sprite.scale) + " centered=" + str(e._sprite.centered), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			drawing.draw_string(font, Vector2(40, 470), "Engine rendering review only; not an encounter or gameplay acceptance.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	)
	for frame in 4:
		for e in enemies:
			if e._actions:
				e._actions.stop()
				e._actions.animation = &"attack"
				e._actions.frame = frame
		drawing.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../thokk_engine_frame_" + str(frame) + ".png")
	stage.queue_free()
	await process_frame
	quit()
