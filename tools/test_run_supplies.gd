extends SceneTree

var game
var player
var drops
var checks := 0
var failures: Array[String] = []
var output := ""
var samples := []
var game_script
var xp_script
var player_script
var enemy_script
var boss_script
var heal_script
var chest_script
var drop_script
var map_script
var rules_script

func _initialize():
	call_deferred("run")

func check(ok, label):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func clear_pickups():
	for child in drops.get_children():
		child.free()
	for child in game.get_children():
		if child.get_script() in [xp_script, heal_script, chest_script]:
			child.free()

func spawn_supply(kind, pos):
	var supply = drops._spawn(kind, pos)
	await process_frame
	return supply

func gem(at, amount, target):
	var node = xp_script.new()
	node.player = target
	node.position = at
	node.value = amount
	game.add_child(node)
	return node

func clean_audio():
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
		await create_timer(0.2).timeout
		audio._streams.clear()
		audio.free()
		audio_script._instance = null

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty() or root.get_node("Save").path == "user://save.json":
		quit(2)
		return
	game_script = load("res://scripts/game.gd")
	xp_script = load("res://scripts/entities/xp_gem.gd")
	player_script = load("res://scripts/entities/player.gd")
	enemy_script = load("res://scripts/entities/enemy.gd")
	boss_script = load("res://scripts/bosses/boss.gd")
	heal_script = load("res://scripts/gods/heal_pickup.gd")
	chest_script = load("res://scripts/entities/chest.gd")
	drop_script = load("res://scripts/world/supply_drops.gd")
	map_script = load("res://scripts/world/map_layer.gd")
	rules_script = load("res://scripts/data/supply_db.gd")
	var save = root.get_node("Save")
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	root.get_node("Settings").change("language", "zh")
	for level in ["midgard", "helheim", "vigrid"]:
		if not load("res://scripts/data/level_db.gd").is_built(level):
			print("SKIP unbuilt level ", level)
			continue
		save.selected_level = level
		game = game_script.new()
		root.add_child(game)
		current_scene = game
		if game.level_id != level:
			push_error("Wrong level " + game.level_id + " expected " + level)
			quit(3)
			return
		game.process_mode = Node.PROCESS_MODE_DISABLED
		await process_frame
		game.level_up_panel.choose(0)
		paused = false
		game.level_up_panel.hide()
		player = game.player
		for power in player.gods.values(): power.free()
		player.gods.clear()
		player.faith.clear()
		player.position = map_script.push_out(Vector2.ZERO, 22.0)
		for child in game.get_children():
			if child.get_script() == drop_script: drops = child
		check(drops != null, level + " automatically installs drop director")
		var at = player.position + Vector2(180, 0)
		var mead = await spawn_supply("healing_mead", at)
		check(mead != null, "spawn clear location")
		player.hp = player.max_hp
		check(not mead.collect() and not mead._consumed, "full HP does not waste mead")
		player.hp = player.max_hp - 20.0
		var before = player.hp
		check(mead.collect(), "injured player collects")
		check(is_equal_approx(player.hp - before, 8.0), "fixed small healing")
		check(not mead.collect() and is_equal_approx(player.hp - before, 8.0), "cannot collect twice before deferred free")
		await process_frame
		check(drops._active.healing_mead.is_empty(), "free releases reserved slot")
		mead = await spawn_supply("healing_mead", at)
		player.hp = player.max_hp - 1
		check(mead.collect() and player.hp == player.max_hp, "healing clamps to max HP")
		await process_frame
		mead = await spawn_supply("healing_mead", at)
		player.hp -= 20
		player.pickup_radius = 10000
		mead._process(0.1)
		check(not mead._consumed, "large pickup passive cannot remotely consume mead")
		player.position = mead.position + Vector2(25, 0)
		mead._process(0.1)
		check(mead._consumed, "proximity consumes mead")
		await process_frame
		clear_pickups()
		player.position = map_script.push_out(Vector2.ZERO, 22)
		player.pickup_radius = 1
		var magnet = await spawn_supply("soul_magnet", at)
		check(not magnet.collect(), "empty-field magnet remains available")
		var g1 = gem(player.position + Vector2(400, 0), 2, player)
		var g2 = gem(player.position + Vector2(900, 0), 3, player)
		var g3 = gem(player.position + Vector2(900, 0), 4, player)
		await process_frame
		check(g2.value + (g3.value if is_instance_valid(g3) else 0) == 7, "overlapping XP retains value")
		var other = player_script.new()
		game.add_child(other)
		other.process_mode = Node.PROCESS_MODE_DISABLED
		var other_gem = gem(Vector2(0, 600), 9, other)
		var heal = heal_script.new()
		heal.player = player
		heal.position = at + Vector2(0, 80)
		game.add_child(heal)
		var chest = chest_script.new()
		chest.player = player
		chest.position = at + Vector2(0, 160)
		game.add_child(chest)
		var hp_before = player.hp
		check(magnet.collect(), "magnet activates with XP")
		check(g1._attracted and g2._attracted, "all existing distant XP attracted")
		check(not other_gem._attracted, "other owner XP excluded")
		check(not heal._attracted and chest._open_left < 0 and player.hp == hp_before, "magnet excludes healing and chest")
		check(not magnet.collect(), "magnet activation one-shot")
		var future = gem(Vector2(0, 1000), 5, player)
		check(not future._attracted, "future drops are not globally attracted")
		player.xp_to_next = 100000
		player.xp = 0
		g1.position = player.position
		g2.position = player.position
		g1._process(0.01)
		g2._process(0.01)
		if is_instance_valid(g3):
			g3.position = player.position
			g3._process(0.01)
		check(player.xp == 9 * player.xp_mult, "merged XP delivered exactly once")
		await process_frame
		other.free()
		clear_pickups()
		var g4 = gem(Vector2(600, 600), 1, player)
		magnet = await spawn_supply("soul_magnet", at)
		player.level = player_script.MAX_LEVEL
		check(not magnet.collect() and not g4._attracted, "max-level magnet does not waste")
		player.level = 1
		game._run_state = game_script.RunState.ENDING
		check(not magnet.collect(), "no collection during ending")
		game._run_state = game_script.RunState.PLAYING
		player.is_dead = true
		check(not magnet.collect(), "dead player cannot collect")
		player.is_dead = false
		clear_pickups()
		mead = await spawn_supply("healing_mead", at)
		mead.life = 0.1
		mead._process(0.2)
		check(mead.is_queued_for_deletion(), "finite lifetime")
		await process_frame
		check(drops._active.healing_mead.is_empty(), "expiration frees cap")
		var a = drops._spawn("healing_mead", at)
		var b = drops._spawn("healing_mead", at)
		var c = drops._spawn("healing_mead", at)
		check(a != null and b != null and c == null, "cap includes deferred pending drops")
		await process_frame
		clear_pickups()
		var fake = enemy_script.new()
		fake.position = at
		fake.xp_value = 1
		fake.behavior = "chase"
		game.add_child(fake)
		fake.process_mode = Node.PROCESS_MODE_DISABLED
		for kind in rules_script.RULES:
			drops._last[kind] = 0.0
			drops._kills[kind] = 10000
		game.elapsed = 19.9
		drops._on_enemy_killed(fake)
		check(drops._active.healing_mead.is_empty() and drops._active.soul_magnet.is_empty(), "first-drop grace enforced")
		game.elapsed = 20.0
		drops._on_enemy_killed(fake)
		check(drops._active.healing_mead.size() == 1, "kill pity after grace")
		drops._kills.healing_mead = 10000
		game.elapsed = 54.99
		drops._on_enemy_killed(fake)
		check(drops._active.healing_mead.size() == 1, "cooldown cannot be bypassed by kills")
		game.elapsed = 55.0
		drops._on_enemy_killed(fake)
		check(drops._active.healing_mead.size() == 2, "cooldown boundary eligible")
		await process_frame
		clear_pickups()
		game.elapsed = 200.0
		drops._last.healing_mead = 100.0
		drops._last.soul_magnet = 1.0
		drops._kills.healing_mead = 0
		drops._kills.soul_magnet = 0
		drops._on_enemy_killed(fake)
		check(drops._active.healing_mead.size() == 1 and drops._active.soul_magnet.size() == 1, "time pity needs eligible kill then produces both")
		await process_frame
		clear_pickups()
		fake.behavior = "still"
		drops._on_enemy_killed(fake)
		check(drops._active.healing_mead.is_empty(), "quest structure excluded")
		fake.behavior = "chase"
		fake.xp_value = 0
		drops._on_enemy_killed(fake)
		check(drops._active.healing_mead.is_empty(), "zero XP summon excluded")
		var boss = boss_script.new()
		drops._on_enemy_killed(boss)
		check(drops._active.healing_mead.is_empty(), "boss kill excluded")
		boss.free()
		fake.free()
		fake = game.spawn_enemy("draugr", at, false, true)
		fake.process_mode = Node.PROCESS_MODE_DISABLED
		for kind in rules_script.RULES:
			drops._last[kind] = 0.0
			drops._kills[kind] = 10000
		var kill_before = game.kills
		fake.take_damage(1000000)
		await process_frame
		check(game.kills == kill_before + 1 and drops._active.healing_mead.size() == 1, "real enemy death signal produces supply")
		clear_pickups()
		var edge = await spawn_supply("healing_mead", game_script.bounds.position - Vector2(1000, 1000))
		if edge != null:
			check(game_script.bounds.has_point(edge.position), "drop clamped inside map")
			check(map_script.push_out(edge.position, 22).distance_to(edge.position) < 0.1, "drop does not overlap obstacle")
		else:
			check(true, "blocked edge rejects drop rather than trapping it")
		clear_pickups()
		# Exercise 600 seconds of eligible kills without relying on lucky rolls for the bounds.
		for seed_index in 10:
			drops.rng.seed = seed_index
			for kind in rules_script.RULES:
				drops._last[kind] = 0.0
				drops._kills[kind] = 0
			var counts = {}
			for kind in rules_script.RULES: counts[kind] = 0
			fake = enemy_script.new()
			fake.position = at
			game.add_child(fake)
			fake.process_mode = Node.PROCESS_MODE_DISABLED
			for second in 601:
				game.elapsed = float(second)
				for kill in 4:
					drops._on_enemy_killed(fake)
					var produced := false
					for kind in rules_script.RULES:
						if not drops._active[kind].is_empty():
							counts[kind] += 1
							produced = true
					if produced:
						await process_frame
						for pickup in drops.get_children(): pickup.free()
			check(counts.healing_mead >= 8 and counts.healing_mead <= 17, "healing throughput bounded seed%d" % seed_index)
			check(counts.soul_magnet >= 3 and counts.soul_magnet <= 7, "magnet throughput bounded seed%d" % seed_index)
			samples.append({"level": level, "seed": seed_index, "kills_per_second": 4, "seconds": 600, "drops": counts})
			fake.free()
		game.free()
		drops = null
		await process_frame
		check(get_nodes_in_group("xp_gems").is_empty(), "scene exit clears gem group")
	await clean_audio()
	await process_frame
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "drop_samples": samples}, "\t"))
	file.close()
	print("RESULT SUPPLIES: ", checks, " checks, ", failures.size(), " failures")
	quit(1 if not failures.is_empty() else 0)
