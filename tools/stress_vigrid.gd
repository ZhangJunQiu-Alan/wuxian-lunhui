extends SceneTree
## 第 3 关压力检查（本机、真实窗口）：350 个普通敌人（四种混合）+ 每个 Boss 的实际技能，各跑一段，记录帧时间分位数、节点数、内存；
## 最后反复进出关卡几次，看节点和内存有没有越积越多
##   Godot --path . --script tools/stress_vigrid.gd -- --save-file=user://k_stress.json --settings-file=user://k_settings_zh.cfg --output=<目录> [--seconds=25]
## 受控：玩家无敌、不移动；苏尔特开场就压到 25% 进入终焉之火（火墙 + 64 格同时在跑）。不是完整通关

const MIX := {"dead": 110, "wolf_berserker": 100, "fire_giant": 80, "frost_veteran": 60}

var _out := ""
var _seconds := 25.0
var _game: Node
var _report := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_out = arg.trim_prefix("--output=")
		if arg.begins_with("--seconds="):
			_seconds = float(arg.trim_prefix("--seconds="))
	var save = root.get_node("Save")
	if save.path == save.DEFAULT_PATH or _out == "":
		push_error("Use an isolated --save-file and --output=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	save.selected_level = "vigrid"
	_report = {"scope": "local machine, real window renderer; invincible idle player; 350 mixed regular enemies + one Boss at a time", "window": [root.size.x, root.size.y], "bosses": {}, "reentry": []}
	await _new_game()
	_report["no_boss"] = await _stress_boss(-1)
	for index in 3:
		await _new_game()
		_report.bosses[_game.level_data.bosses[index].id] = await _stress_boss(index)
	for i in 4:
		await _new_game()
		await _wait_seconds(2.0)
		_report.reentry.append({"round": i, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT), "static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
			"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)})
	_game.queue_free()
	await process_frame
	await process_frame
	_report["after_exit"] = {"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"enemies_left": get_node_count_in_group("enemies"), "hazards_left": get_node_count_in_group("vigrid_hazards")}
	var file := FileAccess.open(_out.path_join("stress.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
	print("STRESS_DONE")
	print("REENTRY ", JSON.stringify(_report.reentry), " AFTER ", JSON.stringify(_report.after_exit))
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
	for power in _game.player.gods.values():  # 开局随机选到的神术负载差别很大（比如托尔的静电场），压力测试只留角色武器，结果可比
		power.free()
	_game.player.gods.clear()
	_game.player.faith.clear()
	_game.player.immune_time = 1.0e9
	_game._next_boss = 3
	_game._next_event = _game.level_data.events.size()


func _wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec() + seconds * 1000.0
	while Time.get_ticks_msec() < until:
		await process_frame


func _fill() -> void:
	var player: Node2D = _game.player
	for id: String in MIX:
		var want: int = MIX[id]
		var have: int = get_nodes_in_group("enemies").filter(func(e): return e.type_id == id).size()
		for i in want - have:
			if get_node_count_in_group("enemies") >= _game.level_data.max_enemies:
				return
			_game.spawn_enemy(id, _game.clamp_to_map(player.position + Vector2.from_angle(randf() * TAU) * randf_range(260.0, 900.0), 40.0))


func _stress_boss(index: int) -> Dictionary:
	var boss: Node2D = null
	if index >= 0:
		_game._next_boss = index
		_game.elapsed = _game.level_data.bosses[index].time
		_game._update_bosses()
		_game._next_boss = 3
		boss = _game.boss
	else:
		_game.elapsed = 540.0
	if boss and boss.type_id == "surtr":
		boss.hp = boss.max_hp * 0.24  # 直接进终焉之火：火墙 + 64 格一起跑
	var frames: Array[float] = []
	var samples := []
	var last := Time.get_ticks_usec()
	var start := Time.get_ticks_msec()
	var next_fill := 0.0
	var max_enemies := 0
	while Time.get_ticks_msec() - start < _seconds * 1000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		if _game.level_up_panel.visible:
			_game.level_up_panel.choose(0)
		var t := (Time.get_ticks_msec() - start) / 1000.0
		if t >= next_fill:
			next_fill += 1.0
			_fill()
			if is_instance_valid(boss):
				boss.hp = maxf(boss.hp, boss.max_hp * (0.2 if boss.type_id == "surtr" else 0.5))  # 别让 Boss 在测量途中被打死
			samples.append({"t": snappedf(t, 0.1), "enemies": get_node_count_in_group("enemies"), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1), "fps": Engine.get_frames_per_second(),
				"boss_state": boss.state if is_instance_valid(boss) else "", "hazards": get_node_count_in_group("vigrid_hazards")})
		max_enemies = maxi(max_enemies, get_node_count_in_group("enemies"))
	frames = frames.slice(30)  # 去掉刚生成时的几帧
	var sorted := frames.duplicate()
	sorted.sort()
	var pick := func(p: float) -> float: return snappedf(sorted[mini(sorted.size() - 1, int(sorted.size() * p))], 0.01) if not sorted.is_empty() else 0.0
	var result := {"frames": frames.size(), "max_enemies": max_enemies, "frame_ms_p50": pick.call(0.5), "frame_ms_p95": pick.call(0.95),
		"frame_ms_p99": pick.call(0.99), "frame_ms_max": snappedf(sorted.back(), 0.01) if not sorted.is_empty() else 0.0, "samples": samples}
	print("BOSS ", boss.type_id if is_instance_valid(boss) else "none", " p50=", result.frame_ms_p50, " p95=", result.frame_ms_p95, " p99=", result.frame_ms_p99, " max_enemies=", max_enemies)
	return result
