extends SceneTree

const STEP := 32.0
var checks := 0
var failures := []
var results := []
var output := ""
var game
var map_script

func _initialize():
	call_deferred("run")

func check(ok, label):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty() or root.get_node("Save").path == "user://save.json": quit(2); return
	var game_script = load("res://scripts/game.gd")
	map_script = load("res://scripts/world/map_layer.gd")
	var quest_script = load("res://scripts/quests/side_quest.gd")
	var save = root.get_node("Save")
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	for level in ["midgard", "helheim", "vigrid"]:
		if not load("res://scripts/data/level_db.gd").is_built(level): continue
		save.selected_level = level
		game = game_script.new()
		root.add_child(game)
		current_scene = game
		game.process_mode = Node.PROCESS_MODE_DISABLED
		await process_frame
		game.level_up_panel.choose(0)
		paused = false
		game.level_up_panel.hide()
		var map = game._map_layer
		check(game.level_id == level, "actual level " + level)
		var enlarged := 0
		var fixed := 0
		for sprite in map._props.get_children():
			var file = sprite.texture.resource_path.get_file().get_basename()
			var expected = 1.0 if file in map_script.FIXED_SIZE_PROPS else 2.0
			check(sprite.scale == Vector2.ONE * expected, "scale " + level + "/" + file)
			check(is_zero_approx(sprite.get_rect().end.y), "stable bottom anchor " + level + "/" + file)
			if expected == 2: enlarged += 1
			else: fixed += 1
		check(enlarged > 0, "environment objects actually enlarged " + level)
		# Build a 32-world-pixel player-center clearance graph (player radius14).
		var bounds = game_script.bounds.grow(-14.0)
		var grid_origin = bounds.position + Vector2.ONE * STEP * 0.5
		var size = Vector2i((bounds.size / STEP).floor())
		var open := {}
		for x in size.x:
			for y in size.y:
				var at = grid_origin + Vector2(x, y) * STEP
				if map_script.push_out(at, 14.0).distance_squared_to(at) < 0.01: open[Vector2i(x, y)] = true
		var start = Vector2i(((Vector2.ZERO - grid_origin) / STEP).round())
		check(open.has(start), "spawn clear " + level)
		var visited := {start: true}
		var queue := [start]
		var cursor := 0
		while cursor < queue.size():
			var p = queue[cursor]
			cursor += 1
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next = p + direction
				if open.has(next) and not visited.has(next):
					visited[next] = true
					queue.append(next)
		var fine_escapes := []
		for isolated in open:
			if visited.has(isolated): continue
			var center = grid_origin + Vector2(isolated) * STEP
			var fine_seen := {Vector2i.ZERO: true}
			var fine_queue := [Vector2i.ZERO]
			var fine_cursor := 0
			var escaped := false
			while fine_cursor < fine_queue.size() and not escaped:
				var fine = fine_queue[fine_cursor]
				fine_cursor += 1
				var world = center + Vector2(fine) * 8.0
				var coarse = Vector2i(((world - grid_origin) / STEP).round())
				if visited.has(coarse) and world.distance_to(grid_origin + Vector2(coarse) * STEP) <= 8.0:
					escaped = true
					break
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next = fine + direction
					if absi(next.x) > 16 or absi(next.y) > 16 or fine_seen.has(next): continue
					var at = center + Vector2(next) * 8.0
					if map_script.push_out(at, 14.0).distance_squared_to(at) < 0.01:
						fine_seen[next] = true
						fine_queue.append(next)
			if not escaped:
				for prop in map._props.get_children():
					if prop.position.distance_to(center) < 180.0: print("POCKET PROP ", prop.texture.resource_path, " ", prop.position)
				for bucket in map_script.obstacles.values():
					for circle in bucket:
						if Vector2(circle.x, circle.y).distance_to(center) < 180.0: print("POCKET CIRCLE ", circle)
			check(escaped, "fine-grid escape from coarse pocket " + level + str(center))
			fine_escapes.append({"position": [center.x, center.y], "escaped": escaped})
		var markers := []
		for landmark in game.level_data.map.landmarks:
			var reachable := false
			for cell in visited:
				if (grid_origin + Vector2(cell) * STEP).distance_to(landmark.pos) <= landmark.radius * 0.4:
					reachable = true
					break
			check(reachable, "landmark connected " + level + "/" + landmark.id)
			for seed_index in 8:
				seed(seed_index + 3100)
				var quest = quest_script.new()
				quest.game = game
				quest.player = game.player
				quest.landmark = landmark
				game.add_child(quest)
				var can_accept := false
				var approach = Vector2.ZERO
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						var cell = Vector2i(((quest.marker_pos - grid_origin) / STEP).round()) + Vector2i(dx, dy)
						if visited.has(cell) and (grid_origin + Vector2(cell) * STEP).distance_to(quest.marker_pos) < quest.ACCEPT_DISTANCE:
							can_accept = true
							approach = grid_origin + Vector2(cell) * STEP
				check(can_accept, "quest marker approach " + level + "/" + landmark.id + " seed" + str(seed_index))
				if can_accept:
					game.player.position = approach
					quest._process(0.0)
					check(quest.state == "active", "actual quest acceptance " + level + "/" + landmark.id + " seed" + str(seed_index))
				markers.append({"landmark": landmark.id, "seed": seed_index, "position": [quest.marker_pos.x, quest.marker_pos.y], "can_accept": can_accept})
				quest.free()
		# Direct fixtures prove the enlarged collision base tracks the enlarged image.
		var file = "rock_01" if level == "midgard" else ("chain_pillar" if level == "helheim" else "giant_remains")
		var at = Vector2(-9000, -9000)
		var sprite = map.prop(file, at, 12.0)
		var center = at + Vector2(0, -12)
		var circles = map_script.obstacles.get(Vector2i((center / map_script.OBSTACLE_CELL).floor()), [])
		check(circles.any(func(c): return Vector2(c.x, c.y) == center and c.z == 24.0), "scaled collision radius and offset " + level)
		sprite.free()
		results.append({"level": level, "enlarged_props": enlarged, "fixed_structural_props": fixed, "fine_escapes": fine_escapes, "free_grid_cells": open.size(), "connected_grid_cells": visited.size(), "isolated_samples": open.keys().filter(func(cell): return not visited.has(cell)).map(func(cell): return [grid_origin.x + cell.x * STEP, grid_origin.y + cell.y * STEP]), "markers": markers})
		game.free()
		await process_frame
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer: child.stop(); child.stream = null
		await create_timer(0.2).timeout
		audio._streams.clear()
		audio.free()
		audio_script._instance = null
	await process_frame
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "levels": results, "navigation_grid": 32, "player_radius": 14}, "\t"))
	file.close()
	print("RESULT ENVIRONMENT: ", checks, " checks, ", failures.size(), " failures")
	quit(1 if not failures.is_empty() else 0)
