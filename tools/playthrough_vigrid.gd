extends SceneTree
## 第 3 关受控完整流程：真实 Game 场景、正常刷怪和 Boss 调度，从开局一路打到篇章结局和结算
##   Godot [--headless] --path . --fixed-fps 60 --script tools/playthrough_vigrid.gd -- --save-file=user://k_play.json --settings-file=user://k_settings_zh.cfg --output=<目录>
## 受控条件（不是自然通关）：玩家无敌；机器人自动走位（靠近当前 Boss，没有 Boss 时捡经验）、自动选卡（偏好托尔 / 奥丁 / 弗蕾亚 / 洛基）
## 每秒记一次：关卡时间、敌人数、节点数、内存、帧时间；Boss 登场 / 击败、命运、结局、结算都记时间点

const PREFER := ["thor", "odin", "freyja", "loki"]
const LIMIT := 1500.0  # 关卡时间超过这么多秒还没结局就判失败

var _out := ""
var _game: Node
var _player: Node2D
var _samples: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _frame_ms: Array[float] = []
var _last_tick := 0
var _sample_at := 0.0
var _seen_boss := ""
var _wall_start := 0


func _initialize() -> void:
	call_deferred("_run")


func _log(kind: String, data: Dictionary = {}) -> void:
	var entry := {"t": snappedf(_game.elapsed, 0.01) if is_instance_valid(_game) else 0.0, "wall": (Time.get_ticks_msec() - _wall_start) / 1000.0, "event": kind}
	entry.merge(data)
	_events.append(entry)
	print("EVENT ", JSON.stringify(entry))


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
	_wall_start = Time.get_ticks_msec()
	_game = load("res://scripts/game.gd").new()
	root.add_child(_game)
	current_scene = _game
	await process_frame
	_player = _game.player
	_player.immune_time = 1.0e9
	_log("start", {"level": _game.level_id, "character": _player.character_id, "headless": DisplayServer.get_name() == "headless"})
	_last_tick = Time.get_ticks_usec()
	while true:
		await physics_frame
		var now := Time.get_ticks_usec()
		_frame_ms.append((now - _last_tick) / 1000.0)
		_last_tick = now
		_pick_rewards()
		_drive()
		_watch()
		if _game.hud.ending_index() >= 0 or _game._run_state == 2 or _game.elapsed > LIMIT:
			break
	if _game.hud.ending_index() >= 0:
		_log("ending_shown", {"beat": _game.hud.ending_index()})
		for i in 5:
			await create_timer(0.5).timeout
			_game.hud.advance_ending()
		await create_timer(0.5).timeout
	var result: Dictionary = _game._run_result
	_log("result", {"run": result.duplicate(), "save_runs": save.stats.runs, "save_clears": save.stats.clears,
		"cleared_vigrid": save.cleared_levels.has("vigrid"), "fates_saved": save.fates.get("vigrid", {})})
	_release_input()
	_write(result)
	_game.queue_free()
	await process_frame
	quit(0 if not result.is_empty() and save.cleared_levels.has("vigrid") else 1)


## 升级 / 选神 / 宝箱面板：优先选偏好的神和它们的强化，其余选第一个
func _pick_rewards() -> void:
	var panel = _game.level_up_panel
	if not panel.visible or panel._offers.is_empty():
		return
	var upgrades = load("res://scripts/data/upgrade_db.gd")
	var best := 0
	var best_score := -1
	for i in panel._offers.size():
		var info: Dictionary = upgrades.get_info(panel._offers[i].id)
		var god: String = info.get("god", "")
		var score: int = 4 - PREFER.find(god) if PREFER.has(god) else 0
		if score > best_score:
			best_score = score
			best = i
	var offer: Dictionary = panel._offers[best]
	panel.choose(best)
	if offer.id.ends_with("_skill"):
		_log("faith", {"god": offer.id.trim_suffix("_skill")})
	elif upgrades.get_info(offer.id).kind == "awaken":
		_log("awaken", {"id": offer.id})


func _press(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_input() -> void:
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(action)


## 走位：有 Boss 就贴近（近战够得着，绕着走），没有就去捡最近的经验宝石，再没有就绕场地中心转圈
func _drive() -> void:
	if not _game.is_running() or paused:
		_release_input()
		return
	var me: Vector2 = _player.global_position
	var goal := Vector2.ZERO
	var desired := 0.0
	if is_instance_valid(_game.boss):
		goal = _game.boss.global_position
		desired = 90.0
	else:
		var best := INF
		for node in _game.get_children():
			if node.get_script() and node.get_script().resource_path.ends_with("xp_gem.gd") and node.global_position.distance_to(me) < best:
				best = node.global_position.distance_to(me)
				goal = node.global_position
		if best == INF:
			goal = Vector2.from_angle(_game.elapsed * 0.3) * 500.0
	var to := goal - me
	var dir := to.normalized() if to.length() > desired else to.orthogonal().normalized()
	_press("ui_left", dir.x < -0.3)
	_press("ui_right", dir.x > 0.3)
	_press("ui_up", dir.y < -0.3)
	_press("ui_down", dir.y > 0.3)


func _watch() -> void:
	var boss_id: String = _game.boss.type_id if is_instance_valid(_game.boss) else ""
	if boss_id != _seen_boss:
		if _seen_boss != "":
			_log("boss_gone", {"id": _seen_boss, "defeated": _game._defeated_bosses.duplicate()})
		if boss_id != "":
			_log("boss_spawn", {"id": boss_id, "hp": _game.boss.max_hp})
		_seen_boss = boss_id
	if boss_id == "surtr" and _game.boss.phase != _events.filter(func(e): return e.event == "surtr_phase").size() + 1:
		_log("surtr_phase", {"phase": _game.boss.phase, "hp_ratio": snappedf(_game.boss.hp / _game.boss.max_hp, 0.001)})
	if boss_id == "fenrir" and _game.boss.state in ["bound", "vidar", "swallow"] and _game.boss.state_time < 0.008:  # 只在进入状态的那一帧记（0.02 会跨两帧，记成两条）
		_log("fenrir_" + _game.boss.state)
	if boss_id == "surtr" and _game.boss.final_stage == "burn" and _game.boss.final_t < 0.008:
		_log("final_fire_burn", {"cycle": _game.boss.final_cycles, "unsafe": _game.boss.final_unsafe.size(), "safe": _game.boss.final_safe.size()})
	for id in _game.fates:
		if _game.fates[id] and not _events.any(func(e): return e.event == "fate" and e.id == id):
			_log("fate", {"id": id})
	if _game.elapsed >= _sample_at:
		_sample_at += 1.0
		var recent := _frame_ms.slice(maxi(0, _frame_ms.size() - 60))
		_samples.append({"t": snappedf(_game.elapsed, 0.1), "enemies": get_node_count_in_group("enemies"),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
			"fps": Engine.get_frames_per_second(), "frame_ms_max": snappedf(recent.max() if not recent.is_empty() else 0.0, 0.01),
			"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
			"physics_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
			"level": _player.level, "hazards": get_node_count_in_group("vigrid_hazards")})


func _percentile(values: Array[float], p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(sorted.size() * p))]


func _write(result: Dictionary) -> void:
	var max_enemies := 0
	var max_nodes := 0
	for s in _samples:
		max_enemies = maxi(max_enemies, s.enemies)
		max_nodes = maxi(max_nodes, int(s.nodes))
	var summary := {"scope": "controlled full flow: invincible bot player, auto movement and auto upgrade picks; NOT a natural playthrough",
		"headless": DisplayServer.get_name() == "headless", "wall_seconds": (Time.get_ticks_msec() - _wall_start) / 1000.0,
		"level_seconds": _game.elapsed, "max_enemies": max_enemies, "max_nodes": max_nodes,
		"frame_ms_p50": _percentile(_frame_ms, 0.5), "frame_ms_p95": _percentile(_frame_ms, 0.95), "frame_ms_p99": _percentile(_frame_ms, 0.99),
		"frame_ms_max": _frame_ms.max() if not _frame_ms.is_empty() else 0.0,
		"result": result, "events": _events, "samples": _samples}
	var file := FileAccess.open(_out.path_join("playthrough.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	print("PLAYTHROUGH_DONE level=%.1f wall=%.1f enemies_max=%d p95=%.2fms cleared=%s" % [_game.elapsed, summary.wall_seconds, max_enemies, summary.frame_ms_p95, str(not result.is_empty())])
