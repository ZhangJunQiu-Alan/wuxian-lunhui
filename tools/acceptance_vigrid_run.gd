extends SceneTree
## 第 3 关正常伤害机器人流程：真实 Game 场景、正常刷怪和 Boss 调度，从开局一路打到篇章结局和结算
##   Godot [--headless] --path . --fixed-fps 60 --script tools/playthrough_vigrid.gd -- --save-file=user://k_play.json --settings-file=user://k_settings_zh.cfg --output=<目录>
## 测试机器人只操作移动、冲刺、大招和选卡。不写入生命、属性、伤害、时间或 Boss 状态。
## 每秒记一次：关卡时间、敌人数、节点数、内存、帧时间；Boss 登场 / 击败、命运、结局、结算都记时间点

const PREFER := ["baldr", "freyja", "thor", "odin"]
const LIMIT := 1200.0  # 关卡时间超过这么多秒还没结局就判失败

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
var _drive_next := 0.0
var _dir := Vector2.ZERO
var _captured := {}
var _damage_events := 0
var _last_hp := 0.0
var _meta_profile := false
var _invincible := false
var _character := "gunslinger"
var _level := "vigrid"
var _seed := 20261020


func _initialize() -> void:
	call_deferred("_run")


func _log(kind: String, data: Dictionary = {}) -> void:
	var entry := {"t": snappedf(_game.elapsed, 0.01) if is_instance_valid(_game) else 0.0, "wall": (Time.get_ticks_msec() - _wall_start) / 1000.0, "event": kind}
	entry.merge(data)
	_events.append(entry)
	print("EVENT ", JSON.stringify(entry))


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--character="): _character = arg.trim_prefix("--character=")
		if arg.begins_with("--level="): _level = arg.trim_prefix("--level=")
		if arg.begins_with("--seed="): _seed = int(arg.trim_prefix("--seed="))
		if arg == "--meta-max": _meta_profile = true
		if arg == "--invincible": _invincible = true
		if arg.begins_with("--output="):
			_out = arg.trim_prefix("--output=")
	var save = root.get_node("Save")
	if save.path == save.DEFAULT_PATH or _out == "":
		push_error("Use an isolated --save-file and --output=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0, true)
	root.get_node("Settings").language="zh"
	root.get_node("Settings")._apply_language()
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	if not load("res://scripts/data/character_db.gd").ALL.has(_character) or not load("res://scripts/data/level_db.gd").ALL.has(_level):
		push_error("Unknown character or level")
		quit(2)
		return
	save.selected_level = _level
	save.stats.clears = 2
	save.selected_character = _character
	if _meta_profile:
		for id in load("res://scripts/data/meta_db.gd").UPGRADES:
			save.meta[id] = load("res://scripts/data/meta_db.gd").UPGRADES[id].max
	seed(_seed)
	_wall_start = Time.get_ticks_msec()
	_game = load("res://scripts/game.gd").new()
	root.add_child(_game)
	current_scene = _game
	await process_frame
	_player = _game.player
	if _invincible: _player.immune_time = 1.0e9
	_last_hp = _player.hp
	_log("start", {"level": _game.level_id, "character": _player.character_id, "headless": DisplayServer.get_name() == "headless"})
	_last_tick = Time.get_ticks_usec()
	while true:
		await physics_frame
		var now := Time.get_ticks_usec()
		_frame_ms.append((now - _last_tick) / 1000.0)
		_last_tick = now
		_pick_rewards()
		if _game.pause_menu._root.visible:
			_game.pause_menu.close()
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
		"level_id": _level, "cleared_this_run": save.stats.clears > 2,
		"cleared_vigrid": save.cleared_levels.has("vigrid"), "fates_saved": save.fates.get("vigrid", {})})
	_release_input()
	await _capture("final_result")
	_write(result)
	_game.queue_free()
	await process_frame
	var audio_script=load("res://scripts/core/audio.gd")
	var audio=audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for voice in audio.get_children():
			if voice is AudioStreamPlayer:
				voice.stop()
				voice.stream=null
		audio._streams.clear()
		audio.free()
		audio_script._instance=null
	load("res://scripts/world/vigrid_map.gd").fire_material=null
	await process_frame
	OS.delay_msec(200)
	quit(0 if not result.is_empty() and save.stats.clears > 2 else 1)


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
		var score: int = 12 - PREFER.find(god) if PREFER.has(god) else 0
		if info.kind == "weapon": score = 15
		if panel._offers[i].id in ["regen", "vigor"] and _player.hp < _player.max_hp * 0.7: score = 18
		if info.kind in ["path", "awaken"]: score = 25
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
	if _player.ult_energy >= _player.ult_cost and (is_instance_valid(_game.boss) or get_node_count_in_group("enemies") > 12):
		_player.try_ultimate()
	if _game.elapsed >= _drive_next:
		_drive_next = _game.elapsed + 0.15
		var me: Vector2 = _player.position
		var goal := Vector2.ZERO
		var boss = _game.boss
		if is_instance_valid(boss):
			var to: Vector2 = boss.position - me
			goal = boss.position - to.normalized() * 260.0 + to.orthogonal().normalized() * 90.0
			if boss.type_id == "surtr" and boss.phase == 3 and not boss.final_safe.is_empty():
				var best := INF
				for cell: Vector2i in boss.final_safe:
					var at := Vector2(cell) * 64.0 + Vector2(32, 12)
					if at.distance_squared_to(me) < best:
						best = at.distance_squared_to(me)
						goal = at
		else:
			var best := INF
			for node in _game.get_children():
				if node.get_script() and node.get_script().resource_path.ends_with("xp_gem.gd") and node.position.distance_squared_to(me) < best:
					best = node.position.distance_squared_to(me)
					goal = node.position
			if best == INF: goal = Vector2.from_angle(_game.elapsed * 0.1) * 500.0
		var enemies = get_nodes_in_group("enemies").filter(func(e): return e.position.distance_squared_to(me) < 400.0 * 400.0)
		var best_score := INF
		for i in 17:
			var dir := Vector2.from_angle(TAU * i / 16.0) if i < 16 else Vector2.ZERO
			var at: Vector2 = me + dir * _player.move_speed * 0.32
			var score := at.distance_to(goal) * 0.12
			if not _game.bounds.grow(-30).has_point(at): score += 10000
			if not load("res://scripts/world/map_layer.gd").push_out(at, 16.0).is_equal_approx(at): score += 1000
			for e in enemies:
				var distance: float = at.distance_to(e.position) - e.radius - 14.0
				score += 1800.0 / maxf(5.0, distance)
				if distance < 8.0: score += 1000
			for hazard in get_nodes_in_group("vigrid_hazards"):
				if at.distance_to(hazard.position) < maxf(hazard.radius, hazard.blast_radius) + 25.0: score += 1600
			if is_instance_valid(boss):
				if boss.type_id == "surtr":
					if boss.in_firewall(at): score += 1200
					if boss.phase == 3 and boss.final_stage == "warn" and boss.final_t > 1.0 and boss.final_unsafe.has(boss.cell_of(at + Vector2(0,20))): score += 500
				elif boss.type_id == "fenrir" and boss.state in ["maw", "maw_windup"]:
					if Geometry2D.is_point_in_polygon(at, boss.fatal_polygon(boss.maw_hinge, boss.maw_axis, boss.maw_gap)): score += 1500
				elif boss.type_id == "jormungandr":
					if boss.body_distance(at)[0] < 60.0: score += 700
					if boss.state in ["breath_windup", "breath"] and Geometry2D.is_point_in_polygon(at, boss._breath_polygon): score += 1400
					for spit in boss.spits:
						if at.distance_to(spit.to) < 100.0: score += 1000
					for mist in boss.mists:
						if Geometry2D.is_point_in_polygon(at, mist.polygon): score += 1000
			if score < best_score:
				best_score = score
				_dir = dir
		if best_score > 700 and _dir != Vector2.ZERO:
			_player.facing = _dir
			_player.try_dash()
	_press("ui_left", _dir.x < -0.3)
	_press("ui_right", _dir.x > 0.3)
	_press("ui_up", _dir.y < -0.3)
	_press("ui_down", _dir.y > 0.3)


func _watch() -> void:
	if _player.hp < _last_hp:
		_damage_events += 1
		_log("damage", {"hp": _player.hp, "lost": _last_hp - _player.hp, "position": _player.position,
			"boss": _game.boss.type_id if is_instance_valid(_game.boss) else "", "boss_state": _game.boss.state if is_instance_valid(_game.boss) else ""})
	_last_hp = _player.hp
	var milestone := "minute_%02d" % int(_game.elapsed / 60)
	if is_instance_valid(_game.boss):
		milestone = _game.boss.type_id + "_" + _game.boss.state
	if not _captured.has(milestone):
		_captured[milestone] = true
		_capture.call_deferred(milestone)
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
	var summary := {"cleared_this_run": root.get_node("Save").stats.clears > 2,
		"headless": DisplayServer.get_name() == "headless", "wall_seconds": (Time.get_ticks_msec() - _wall_start) / 1000.0,
		"level_seconds": _game.elapsed, "max_enemies": max_enemies, "max_nodes": max_nodes,
		"frame_ms_p50": _percentile(_frame_ms, 0.5), "frame_ms_p95": _percentile(_frame_ms, 0.95), "frame_ms_p99": _percentile(_frame_ms, 0.99),
		"frame_ms_max": _frame_ms.max() if not _frame_ms.is_empty() else 0.0,
		"result": result, "damage_events": _damage_events, "seed": _seed, "character": _character, "level_id": _level, "driver": get_script().resource_path, "meta_profile": save_profile(), "invincible": _invincible, "muted": AudioServer.is_bus_mute(0), "events": _events, "samples": _samples}
	summary.scope = ("invincible bot; " if _invincible else "normal damage bot; ") + "isolated profile, optional legitimate meta upgrades, fixed initial seed (render timing and random feedback can change the run), legal movement/dash/ultimate/card input only; no clock/enemy/damage overrides; character and level recorded separately; focus pause auto-resumed"
	summary["god_build"] = {}
	for id in _player.gods:
		var power = _player.gods[id]
		summary.god_build[id] = {"path": power.path, "awakened": power.awakened, "faith": _player.faith[id], "stats": power.stats.duplicate()}
	summary["final_hp"] = _player.hp
	summary["max_hp"] = _player.max_hp
	var file := FileAccess.open(_out.path_join("playthrough.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	print("PLAYTHROUGH_DONE level=%.1f wall=%.1f enemies_max=%d p95=%.2fms won_this_run=%s" % [_game.elapsed, summary.wall_seconds, max_enemies, summary.frame_ms_p95, str(summary.cleared_this_run)])


func _capture(tag: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if tag == "final_result":
		await create_timer(0.8, true, false, true).timeout
		await process_frame
		await process_frame
	RenderingServer.force_draw()
	var path := _out.path_join(tag + ".png")
	root.get_texture().get_image().save_png(path)


func save_profile() -> Dictionary:
	return root.get_node("Save").meta.duplicate()
