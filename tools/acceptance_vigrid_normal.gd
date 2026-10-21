extends "res://tools/acceptance_vigrid_run.gd"

var _render_intervals: Array[float] = []
var _last_idle_us := 0

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if _last_idle_us > 0: _render_intervals.append((now - _last_idle_us) / 1000.0)
	_last_idle_us = now
	return false

func _write(result: Dictionary) -> void:
	super._write(result)
	var path := _out.path_join("playthrough.json")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var real := DisplayServer.get_name() != "headless"
	report["render_metrics_valid"] = real
	if real:
		report["render_intervals"] = {"frames": _render_intervals.size(), "p50_ms": _percentile(_render_intervals, 0.5), "p95_ms": _percentile(_render_intervals, 0.95), "p99_ms": _percentile(_render_intervals, 0.99), "max_ms": _render_intervals.max(), "over_33ms": _render_intervals.filter(func(v): return v > 33.3).size(), "over_100ms": _render_intervals.filter(func(v): return v > 100.0).size(), "note": "SceneTree idle-frame wall intervals; include modal pauses and screenshot/save overhead. Legacy frame_ms fields are physics-callback intervals."}
		print("RENDER_INTERVAL_RESULT ", JSON.stringify(report.render_intervals))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()

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
			var reach := 90.0 if _player.character_id in ["swordsman", "assassin"] else 260.0
			goal = boss.position - to.normalized() * reach + to.orthogonal().normalized() * reach * 0.35
			if boss.type_id == "surtr" and boss.firewall_age >= 0.0:
				var inside: Vector2 = goal - boss.firewall_center
				goal = boss.firewall_center + inside.limit_length(maxf(0.0, boss.firewall_radius - 80.0))
			if boss.type_id == "surtr" and boss.phase == 3 and not boss.final_safe.is_empty():
				var best := INF
				for cell: Vector2i in boss.final_safe:
					var at := Vector2(cell) * 64.0 + Vector2(32, 32 - load("res://scripts/world/map_layer.gd").FOOT)
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
				if at.distance_to(hazard.position) < maxf(hazard.radius, hazard.blast_radius) + 25.0: score += 3000
			if is_instance_valid(boss):
				if boss.type_id == "surtr":
					if boss.in_firewall(at): score += 10000
					elif boss.firewall_age >= 0.0:
						var edge: float = boss.firewall_radius - at.distance_to(boss.firewall_center)
						if edge < 80.0: score += (80.0 - edge) * 15.0
					if boss.state in ["sweep_windup", "sweep"]:
						if Geometry2D.is_point_in_polygon(at, boss.sweep_polygon(boss.position, boss._sweep_dir)): score += 2500
					if boss.phase == 3 and boss.final_stage in ["warn", "burn"] and boss.final_unsafe.has(boss.cell_of(at + Vector2(0,load("res://scripts/world/map_layer.gd").FOOT))): score += 5000
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
