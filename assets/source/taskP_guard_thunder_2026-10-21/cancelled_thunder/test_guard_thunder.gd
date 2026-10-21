extends SceneTree

var game
var player
var drops
var game_script
var supply_script
var pulse_script
var rules
var enemy_script
var boss_db
var checks := 0
var failures := []
var samples := []
var output := ""

func _initialize():
	call_deferred("run")

func check(ok, label):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func clear_field():
	for child in drops.get_children(): child.free()
	for child in game.get_children():
		if child.get_script() == pulse_script or child.is_in_group("enemies") or child.is_in_group("xp_gems") or child.is_in_group("vigrid_hazards"):
			child.free()

func supply(kind):
	var node = drops._spawn(kind, player.position + Vector2(100, 0))
	await process_frame
	return node

func enemy(at, elite = false, id = "draugr"):
	var node = game.spawn_enemy(id, at, elite, true)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	return node

func pulse(at):
	var node = pulse_script.new()
	node.game = game
	node.position = at
	var prepared = node.prepare(at)
	game.add_child(node)
	return [node, prepared]

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty() or root.get_node("Save").path == "user://save.json":
		quit(2)
		return
	game_script = load("res://scripts/game.gd")
	supply_script = load("res://scripts/entities/run_supply.gd")
	pulse_script = load("res://scripts/effects/supply_thunder.gd")
	rules = load("res://scripts/data/supply_db.gd")
	enemy_script = load("res://scripts/entities/enemy.gd")
	boss_db = load("res://scripts/data/boss_db.gd")
	var map_script = load("res://scripts/world/map_layer.gd")
	var save = root.get_node("Save")
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	for level in ["midgard", "helheim", "vigrid"]:
		if not load("res://scripts/data/level_db.gd").is_built(level):
			print("SKIP unbuilt level ", level)
			continue
		save.selected_level = level
		game = game_script.new()
		root.add_child(game)
		current_scene = game
		game.process_mode = Node.PROCESS_MODE_DISABLED
		await process_frame
		game.level_up_panel.choose(0)
		game.level_up_panel.hide()
		paused = false
		check(game.level_id == level, "correct level " + level)
		player = game.player
		player.died.disconnect(game._on_player_died)
		for power in player.gods.values(): power.free()
		player.gods.clear()
		player.faith.clear()
		player.position = map_script.push_out(Vector2.ZERO, 22)
		for child in game.get_children():
			if child.get_script() == load("res://scripts/world/supply_drops.gd"): drops = child
		var origin = player.position
		var guard = await supply("guard_rune")
		player.pickup_radius = 10000
		guard._process(0.01)
		check(player.supply_guard_time == 0 and not guard._consumed, "guard not remotely picked up")
		check(guard.collect() and player.supply_guard_time == 8.0, "guard grants eight seconds")
		check(not guard.collect(), "guard one activation")
		await process_frame
		guard = await supply("guard_rune")
		player.supply_guard_time = 3
		check(not guard.collect() and player.supply_guard_time == 3, "active guard does not stack or refresh")
		player.supply_guard_time = 0
		player.immune_time = 1
		check(not guard.collect(), "divine immunity preserves pickup")
		player.immune_time = 0
		player.shield_time = 1
		check(not guard.collect(), "ultimate immunity preserves pickup")
		player.shield_time = 0
		check(guard.collect(), "guard available after immunity ends")
		await process_frame
		player.hp = 50
		player.dodge_chance = 0
		player.ward = 2
		player._invincible_time = 0
		player.take_damage(20)
		check(player.hp == 50 and player.supply_guard_time == 0, "one direct hit absorbed")
		check(player.ward == 2, "divine ward layers preserved")
		player._invincible_time = 0
		player.take_damage(20)
		check(player.ward == 1, "next direct hit consumes original divine ward")
		player.ward = 0
		player._invincible_time = 0
		player.take_damage(20)
		check(player.hp == 30, "guard does not persist after consumption")
		player.hp = 5
		player.supply_guard_time = 8
		player._invincible_time = 0
		player.take_damage(10)
		check(player.hp == 5 and not player.is_dead, "ordinary lethal hit still blocked")
		player.supply_guard_time = 8
		player._invincible_time = 0
		player.dodge_chance = 1
		player.take_damage(10)
		check(player.supply_guard_time == 8, "dodge does not waste guard")
		player.dodge_chance = 0
		player.supply_guard_time = 8
		player._invincible_time = 0
		player._dash_time = 1
		player.take_damage(10)
		check(player.supply_guard_time == 8, "dash immunity does not waste guard")
		player._dash_time = 0
		player.hp = 50
		player.take_dot(5)
		check(player.hp == 45 and player.supply_guard_time == 8, "DOT penetrates guard without consuming it")
		check(not player.is_invulnerable(), "guard is not general invulnerability")
		player._tick_timers(7.99)
		check(player.supply_guard_time > 0, "guard lasts before eight-second boundary")
		player._tick_timers(0.02)
		check(player.supply_guard_time == 0, "guard expires")
		player.supply_guard_time = 8
		player.hp = player.max_hp
		player._invincible_time = 0
		player.take_damage(player.max_hp * 3)
		check(player.is_dead and player.supply_guard_time == 0, "fatal max-HP attack bypasses guard and clears it")
		player.is_dead = false
		player.hp = 1
		player.supply_guard_time = 8
		player.take_dot(2)
		check(player.is_dead and player.supply_guard_time == 0, "DOT death clears guard")
		player.is_dead = false
		player.hp = player.max_hp
		player._invincible_time = 0
		clear_field()
		# Empty, elite-only and protected-object-only scenes.
		var thunder = await supply("thunder_rune")
		check(not thunder.collect(), "empty thunder preserved")
		var elite = enemy(origin + Vector2(90, 0), true)
		elite.hp = 1
		var structure = enemy(origin + Vector2(-90, 0))
		structure.behavior = "still"
		var zero_xp = enemy(origin + Vector2(0, 90))
		zero_xp.xp_value = 0
		var far = enemy(origin + Vector2(800, 800))
		var excluded_hp = [structure.hp, zero_xp.hp, far.hp]
		check(thunder.collect(), "elite-only field can be slowed")
		check(not thunder.collect(), "thunder cannot activate twice")
		await process_frame
		var p
		for child in game.get_children():
			if child.get_script() == pulse_script: p = child
		p._process(0.01)
		check(elite.hp == 1 and not elite._dead, "elite never loses HP even at one HP")
		check(elite._hit_slow == 0.3 and elite._hit_slow_time == 2.0, "elite 30 percent slow for two seconds")
		check(structure.hp == excluded_hp[0] and zero_xp.hp == excluded_hp[1] and far.hp == excluded_hp[2], "structures summons and out-of-range targets excluded")
		clear_field()
		for id in ["skoll", "nidhogg"] + (["jormungandr", "fenrir", "surtr"] if level == "vigrid" else []):
			var boss = boss_db.create(id, 1.0)
			boss.target = player
			boss.position = origin + Vector2(100, 0)
			game.add_child(boss)
			boss.process_mode = Node.PROCESS_MODE_DISABLED
			var hp_before = boss.hp
			var state_before = boss.state
			var pair = pulse(origin)
			check(not pair[1] and pair[0].targets.is_empty(), "boss excluded from target snapshot " + id)
			pair[0]._process(0.3)
			check(boss.hp == hp_before and boss.state == state_before, "boss HP and phase unchanged " + id)
			pair[0].free()
			boss.free()
		clear_field()
		var ordinary = enemy(origin + Vector2(50, 0))
		ordinary.dodge = 1
		ordinary.add_status("gold_net", 5)
		var kills_before = game.kills
		var pair = pulse(origin)
		pair[0]._process(0.01)
		check(ordinary._dead and game.kills == kills_before + 1, "ordinary executed once through normal death signal")
		pair[0]._process(0.01)
		check(game.kills == kills_before + 1, "pulse does not re-kill")
		await process_frame
		check(not get_nodes_in_group("xp_gems").is_empty(), "ordinary death retains XP")
		clear_field()
		# Dense snapshot is capped and each callback has a fixed work budget.
		var dense := []
		for i in 200:
			dense.append(enemy(origin + Vector2.from_angle(TAU * i / 200) * 120))
		pair = pulse(origin)
		check(pair[0].targets.size() == 128, "dense target snapshot cap")
		var future = enemy(origin + Vector2(20, 0))
		kills_before = game.kills
		pair[0]._process(0.01)
		check(game.kills - kills_before == 16, "at most sixteen deaths in one callback")
		for i in 7: pair[0]._process(0.01)
		check(game.kills - kills_before == 128, "all capped targets processed over eight callbacks")
		check(not future._dead, "post-activation spawns excluded")
		pair[0]._process(0.3)
		check(pair[0].is_queued_for_deletion(), "pulse cleans up after effect")
		await process_frame
		clear_field()
		ordinary = enemy(origin + Vector2(50, 0))
		pair = pulse(origin)
		ordinary.free()
		pair[0]._process(0.3)
		check(pair[0].is_queued_for_deletion(), "target freed before batch is safe")
		await process_frame
		clear_field()
		ordinary = enemy(origin + Vector2(50, 0))
		pair = pulse(origin)
		game._run_state = game_script.RunState.ENDING
		pair[0]._process(0.01)
		check(not ordinary._dead and pair[0].is_queued_for_deletion(), "ending cancels pending pulse")
		game._run_state = game_script.RunState.PLAYING
		await process_frame
		clear_field()
		if level == "vigrid":
			var giant = enemy(origin + Vector2(180, 0), false, "fire_giant")
			pair = pulse(origin)
			pair[0]._process(0.01)
			await process_frame
			check(get_nodes_in_group("vigrid_hazards").size() == 1, "fire giant death warning retained")
			var hazard = get_nodes_in_group("vigrid_hazards")[0]
			check(not hazard._blasted and hazard.warn > 0, "fire giant explosion still has escape time")
			clear_field()
		# New drops inherit cooldown, pity and deferred cap reservations.
		for kind in ["guard_rune", "thunder_rune"]:
			var rule = rules.RULES[kind]
			var fake = enemy(origin + Vector2(100, 0))
			drops._last[kind] = 0
			drops._kills[kind] = 10000
			game.elapsed = rule.first - 0.01
			drops._on_enemy_killed(fake)
			check(drops._active[kind].is_empty(), "first grace " + kind)
			game.elapsed = rule.first
			drops._on_enemy_killed(fake)
			check(drops._active[kind].size() == 1, "kill pity " + kind)
			check(drops._spawn(kind, origin) == null, "pending cap " + kind)
			await process_frame
			clear_field()
			fake = enemy(origin + Vector2(100, 0))
			drops._kills[kind] = 10000
			game.elapsed = rule.first + rule.cooldown - 0.01
			drops._on_enemy_killed(fake)
			check(drops._active[kind].is_empty(), "cooldown wins over pity " + kind)
			game.elapsed += 0.01
			drops._on_enemy_killed(fake)
			check(drops._active[kind].size() == 1, "cooldown boundary " + kind)
			await process_frame
			clear_field()
		game.free()
		await process_frame
		check(get_nodes_in_group("enemies").is_empty(), "scene exit clears targets " + level)
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
	await process_frame
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	file.close()
	print("RESULT GUARD THUNDER: ", checks, " checks, ", failures.size(), " failures")
	quit(1 if not failures.is_empty() else 0)
