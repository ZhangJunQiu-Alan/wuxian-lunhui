extends SceneTree
## 第 3 关神明周期援助的现状截图（真实窗口），给美术任务 M-ART-03 做对比：
## 每位神：玩家身边 10 个亡者，直接请这位神出手一次，截出手后第 2 帧和第 12 帧
##   Godot --path . --script tools/review_vigrid_aid.gd -- --save-file=user://k_aid.json --settings-file=user://k_settings_zh.cfg --output=<目录>
## 受控：玩家无敌、不刷怪、不出 Boss；不检查援助条件（附近交战、间隔），只看画面

const GODS := ["thor", "freyja", "baldr", "ran", "skadi"]

var _out := ""
var _game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_out = arg.trim_prefix("--output=")
	var save = root.get_node("Save")
	if save.path == save.DEFAULT_PATH or _out == "":
		push_error("Use an isolated --save-file and --output=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	save.selected_level = "vigrid"
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	for god in GODS:
		await _new_game()
		var player: Node2D = _game.player
		player.add_god(god)
		for i in 10:
			var enemy = _game.spawn_enemy("dead", player.position + Vector2.from_angle(TAU * i / 10.0) * randf_range(60.0, 120.0))
			enemy.speed = 0.0
			enemy.max_hp = 1.0e6  # 打不死：不掉经验、不弹升级面板，画面里一直有目标
			enemy.hp = enemy.max_hp
		await _wait(4)
		_game.battle.request_aid(god)
		await _wait(2)
		await _shot("aid_%s_f02" % god)
		await _wait(10)
		await _shot("aid_%s_f12" % god)
	_game.queue_free()
	await process_frame
	print("AID_DONE")
	quit()


func _new_game() -> void:
	paused = false
	if is_instance_valid(_game):
		await process_frame
		_game.queue_free()
		await process_frame
	_game = load("res://scripts/game.gd").new()
	root.add_child(_game)
	current_scene = _game
	await process_frame
	_game.level_up_panel.choose(0)
	paused = false
	var player: Node2D = _game.player
	for power in player.gods.values():  # 去掉开局随机的神，只留要截的那一位
		power.free()
	player.gods.clear()
	player.faith.clear()
	player.immune_time = 1.0e9
	for weapon: Node in [player.katana, player.revolver, player.blades, player.nova]:  # 关掉角色武器，画面里只剩援助
		if weapon:
			weapon.process_mode = Node.PROCESS_MODE_DISABLED
	_game._spawn_timer = 1.0e9
	_game._next_event = _game.level_data.events.size()
	_game._next_elite_time = 1.0e9
	_game._next_boss = 3
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _wait(5)


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
