extends "res://tools/test_vigrid.gd"

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output=arg.trim_prefix("--output=")
	var save=root.get_node("Save")
	if save.path==save.DEFAULT_PATH or _output.is_empty() or DisplayServer.get_name()=="headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	save.reset()
	save.cleared_levels.assign(["midgard","helheim"])
	save.selected_level="vigrid"
	save.selected_character="gunslinger"
	AudioServer.set_bus_mute(0,true)
	_boss_db=load("res://scripts/data/boss_db.gd")
	root.get_node("Settings").language="zh"
	root.get_node("Settings")._apply_language()
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/taskM_vigrid_art_polish_2026-10-20/integration_2026-10-20/results/controlled_render_capture/playthrough.json"))
	var records=[]
	for size in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,900)]:
		DisplayServer.window_set_size(size)
		root.size=size
		root.content_scale_size=Vector2i(1280,720)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		await process_frame
		await _new_game()
		for god in ["thor","freyja","loki","baldr"]: _player.add_god(god)
		_game.hud.show_result("victory",tr("最后之战"),"",source.result,_player)
		for i in 120: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(_output.path_join("result_%d.png"%size.x))
		var controls=[]
		_collect(_game.hud,controls)
		records.append({"window":[size.x,size.y],"controls":controls})
		for node in _game.hud.find_children("*","Button",true,false):
			if not node.is_visible_in_tree():continue
			var rect: Rect2=node.get_global_rect()
			_check(Rect2(0,0,1280,720).grow(1).encloses(rect),"result button inside canvas %s/%s rect=%s"%[size,node.text,rect])
	await _test_cleanup()
	var file=FileAccess.open(_output.path_join("layout.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":_checks,"failures":_failures,"log":_log,"records":records},"\t"))
	file.close()
	print("RESULT_LAYOUT ",_checks," checks ",_failures," failures")
	quit(1 if _failures else 0)

func _collect(node: Node, rows: Array) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2=node.get_global_rect()
		rows.append({"type":node.get_class(),"text":node.text if node is Label or node is Button else "","rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	for child in node.get_children(): _collect(child,rows)
