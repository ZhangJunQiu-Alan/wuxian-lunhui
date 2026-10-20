extends SceneTree

var _checks := 0
var _failures := 0
var _enemy_script: GDScript
var _player_script: GDScript
var _god_script: GDScript
var _game: Node
var _player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)


func _ids(nodes: Array) -> Array[int]:
	var ids: Array[int] = []
	for node in nodes:
		ids.append(node.get_instance_id())
	ids.sort()
	return ids


func _spawn(pos: Vector2, radius: float = 12.0) -> Node2D:
	var enemy = _enemy_script.new()
	enemy.setup("draugr", 1.0)
	enemy.position = pos
	enemy.radius = radius
	enemy.hp = 1000000.0
	enemy.target = _player
	_game.add_child(enemy)
	return enemy


func _clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	_game._alive_by_type.clear()


func _clear_gods() -> void:
	for power in _player.gods.values():
		power.free()
	_player.gods.clear()
	_player.faith.clear()
	_player.upgrade_levels.clear()


func _test_faith_and_levels() -> void:
	var db = load("res://scripts/data/upgrade_db.gd")
	var gods = load("res://scripts/data/gods.gd")
	_player.add_god("thor")
	for level in [5, 10, 15]:
		_player.level = level
		_game._on_player_leveled_up(level)
		_check(_game._pending_rewards[0].kind == "god", "god selection at level %d" % level)
		_game.level_up_panel.choose(0)
	_check(_player.faith.size() == 4 and _player.gods.size() == 4, "four distinct faith slots")
	var fifth: String = gods.ALL.keys().filter(func(id): return not _player.faith.has(id))[0]
	_player.add_god(fifth)
	_check(_player.faith.size() == 4 and db.god_choices(_player, 3).is_empty(), "fifth faith cannot be added or offered")
	_clear_gods()
	_player.level = 1
	for god: String in gods.ALL:
		_player.add_god(god)
		var power = _player.gods[god]
		var boons: Array = db.UPGRADES.keys().filter(func(id): return db.UPGRADES[id].kind == "boon" and db.UPGRADES[id].god == god)
		for rarity in 4:
			_player.faith[god] = 1
			_player.upgrade_levels.clear()
			power.stats.clear()
			if rarity == 3:
				var card = _game.level_up_panel._make_card(0, {"id": boons[0], "rarity": rarity}, _player)
				_check(card.find_children("*", "Label", true, false).any(func(label): return label.text.contains("1 → 2 / 12")), "legendary faith preview shows +1: " + god)
				card.free()
			db.apply({"id": boons[0], "rarity": rarity}, _player)
			_check(_player.faith[god] == 2, "all rarities grant exactly one faith: " + god)
			_check(is_equal_approx(power.stats[boons[0]], db.value(boons[0], rarity)), "rarity retains boon strength: " + god)
		_player.faith[god] = 1
		_player.upgrade_levels.clear()
		power.stats.clear()
		for i in 11:
			var available: Array = boons.filter(func(id): return db._is_available(id, _player))
			_check(not available.is_empty(), "enough boon levels to awaken: " + god)
			db.apply({"id": available[0], "rarity": i % 4}, _player)
			_check(_player.faith[god] == i + 2, "faith follows selection count: " + god)
			if i == 4 or i == 10:
				_game._check_faith()
				_check(_game._pending_rewards[0].kind == ("path" if i == 4 else "awaken"), "path / awakening threshold: " + god)
				_game._open_reward()
				_game.level_up_panel.choose(0)
				_check(_player.faith[god] == i + 2, "path and awakening do not add extra faith: " + god)
		_check(power.awakened, "eleven boons awaken: " + god)
		for id in boons:
			_check(not db._is_available(id, _player), "awakened god's boon removed: " + id)
		var before: Dictionary = power.stats.duplicate()
		var selected: Dictionary = _player.upgrade_levels.duplicate()
		db.apply({"id": boons.back(), "rarity": 3}, _player)
		_check(power.stats == before and _player.upgrade_levels == selected, "stale awakened boon cannot apply: " + god)
		for title in ["", "chest", "quest"]:
			_game.queue_reward(title)
			_check(_game.level_up_panel._offers.all(func(offer): return db.get_info(offer.id).kind != "boon"), "level / chest / quest excludes awakened boons: " + god)
			_game.level_up_panel.choose(0)
		for id: String in db.UPGRADES:
			if db.UPGRADES[id].kind in ["stat", "weapon"]:
				_player.upgrade_levels[id] = db.UPGRADES[id].max
		var fallback: Array = db.get_choices(_player, 3, 0.0)
		_check(fallback.size() == 1 and fallback[0].id == db.FALLBACK, "exhausted pool retains fallback: " + god)
		_clear_gods()
	_player.revives = 0
	_player.slow_immune = false
	var player = _player_script.new()
	var levels: Array[int] = []
	player.leveled_up.connect(func(level): levels.append(level))
	player.add_xp(2581.0)
	_check(player.level == 30 and levels.size() == 29, "level 30 is no longer capped")
	player.add_xp(2059.0)
	_check(player.level == 39 and player.xp == 232.0 and player.xp_to_next == 233, "one XP below level 40")
	_game.hud.set_xp(player.xp, player.xp_to_next, player.level)
	_check(_game.hud._xp_bar.value < _game.hud._xp_bar.max_value, "level 39 HUD is not capped")
	player.add_xp(1.0)
	player.add_xp(1000000.0)
	_check(player.level == 40 and player.xp == 0.0 and levels.size() == 39, "level 40 cap and overflow")
	_game.hud.set_xp(player.xp, player.xp_to_next, player.level)
	_check(_game.hud._xp_bar.value == _game.hud._xp_bar.max_value, "level 40 HUD is full")
	player.free()
	print("PASS fixed faith gain, four gods, awakening pool, and level 40")


func _oracle_circle(center: Vector2, reach: float) -> Array:
	var result := []
	for enemy in get_nodes_in_group("enemies"):
		if not enemy._dead and enemy.global_position.distance_to(center) <= reach + enemy.radius:
			result.append(enemy)
	return result


func _oracle_line(a: Vector2, b: Vector2, width: float) -> Array:
	var result := []
	for enemy in get_nodes_in_group("enemies"):
		var p := Geometry2D.get_closest_point_to_segment(enemy.global_position, a, b)
		if not enemy._dead and p.distance_squared_to(enemy.global_position) <= pow(width * 0.5 + enemy.radius, 2):
			result.append(enemy)
	return result


func _test_queries() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261018
	for i in 350:
		_spawn(Vector2(rng.randf_range(-2000, 2000), rng.randf_range(-2000, 2000)), rng.randf_range(8, 72))
	for i in 120:
		var a := Vector2(rng.randf_range(-2200, 2200), rng.randf_range(-2200, 2200))
		var b := Vector2(rng.randf_range(-2200, 2200), rng.randf_range(-2200, 2200))
		var reach := rng.randf_range(0, 500)
		var width := rng.randf_range(0, 150)
		_check(_ids(_enemy_script.query_radius(a, reach)) == _ids(_oracle_circle(a, reach)), "circle oracle %d" % i)
		_check(_ids(_enemy_script.query_line(a, b, width)) == _ids(_oracle_line(a, b, width)), "line oracle %d" % i)
	var moved = _spawn(Vector2(-1800, -1800), 70.0)
	moved.position = Vector2(5000, -5000)
	_check(_enemy_script.query_radius(Vector2(5070, -5000), 0.0).has(moved), "same-frame move and large-radius edge")
	_check(not _enemy_script.query_radius(Vector2(-1800, -1800), 1.0).has(moved), "old cell removed")
	moved.global_position = Vector2(-5000, 5000)
	_check(_enemy_script.query_radius(moved.global_position, 0.0).has(moved), "same-frame global-position update")
	moved._die()
	_check(not _enemy_script.query_radius(Vector2(-5000, 5000), 100.0).has(moved), "death removed immediately")
	var removed = _spawn(Vector2(5000, 5000))
	_game.despawn_enemy(removed)
	_check(not _enemy_script.query_radius(Vector2(5000, 5000), 100.0).has(removed), "despawn removed immediately")
	var boss = load("res://scripts/bosses/boss.gd").new()
	boss.setup_boss("probe", "probe", "probe", 100, 1.0, 60, 0, 1)
	boss.target = _player
	boss.position = Vector2(5000, 0)
	_game.add_child(boss)
	_check(_enemy_script.query_radius(boss.position, 0.0).has(boss), "Boss registered")
	boss.set_untouchable(true)
	_check(not _enemy_script.query_radius(boss.position, 100.0).has(boss), "burrowing Boss excluded")
	boss.position.x += 500
	boss.set_untouchable(false)
	_check(_enemy_script.query_radius(boss.position, 0.0).has(boss), "surfacing Boss registered at new position")
	boss.free()
	var started := Time.get_ticks_usec()
	for i in 2000:
		_enemy_script.query_radius(Vector2((i % 40) * 100 - 2000, (i % 37) * 100 - 1800), 60.0)
	var indexed_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for i in 2000:
		_oracle_circle(Vector2((i % 40) * 100 - 2000, (i % 37) * 100 - 1800), 60.0)
	print("BENCH 350 enemies / 2000 radius queries: grid=", indexed_us, "us, scan=", Time.get_ticks_usec() - started, "us")
	_clear_enemies()
	_enemy_script.rebuild_grid(self)
	_check(_enemy_script.query_radius(Vector2.ZERO, 100000.0).is_empty(), "empty grid after cleanup")
	print("PASS spatial query equivalence and lifecycle")


func _test_zone() -> void:
	_enemy_script.crit_chance = 0.0
	var script := GDScript.new()
	script.source_code = 'extends "res://scripts/gods/god_zone.gd"\nvar queries := 0\nfunc enemies_inside() -> Array[Enemy]:\n\tqueries += 1\n\treturn super.enemies_inside()\n'
	_check(script.reload() == OK, "zone probe compiles")
	var zone = script.new()
	zone.radius = 120.0
	zone.pull = 20.0
	zone.on_tick = func(enemy): enemy.take_damage(1.0)
	_game.add_child(zone)
	var target = _spawn(Vector2(100, 0))
	zone._process(0.1)
	_check(zone.queries == 1, "zone shares damage and pull query")
	_check(target.hp == 999999.0 and target.position == Vector2(98, 0), "zone damage and pull remain active")
	_check(_enemy_script.query_radius(Vector2(98, 0), 0.0).has(target), "zone pull keeps index synchronized")
	zone.free()
	_clear_enemies()


func _xp_total() -> int:
	var script = load("res://scripts/entities/xp_gem.gd")
	var total := 0
	for child in _game.get_children():
		if child.get_script() == script:
			total += child.value
	return total


func _test_skills() -> void:
	_spawn(Vector2(300, 100))
	_player.add_god("skadi")
	var skadi = _player.gods.skadi
	skadi.path = "skadi_snowshoes"
	for mult in [1.0, 0.5]:
		_player.position = Vector2.ZERO
		_player.god_cooldown_mult = mult
		skadi._walked = 0.0
		skadi._last_pos = Vector2.ZERO
		skadi._arrows.clear()
		for x in [150, 300, 450, 600]:
			_player.position.x = x
			skadi._tick_snowshoes(0.0)
		_check(skadi._arrows.size() == (4 if mult == 1.0 else 8), "snowshoes cooldown benefit")
	_player.hp = 100.0
	_player.immune_time = 3.0
	_player.take_dot(5.0)
	_check(_player.hp == 100.0, "full immunity blocks DOT")
	_player.immune_time = 0.0
	_player._invincible_time = 1.0
	_player.take_dot(5.0)
	_check(_player.hp == 95.0, "DOT still bypasses ordinary hit immunity")
	_player.shield_time = 1.0
	_player.take_dot(5.0)
	_check(_player.hp == 95.0, "assassin shield blocks DOT")
	_player.shield_time = 0.0
	_clear_enemies()
	_player.add_god("freyr")
	var freyr = _player.gods.freyr
	freyr.stats.freyr_bounty = 50.0
	await process_frame
	var before := _xp_total()
	var victim = _spawn(Vector2(1500, 1500))
	victim.hp = 1.0
	victim.xp_value = 10
	freyr.strike(victim, 1.0, Vector2.RIGHT)
	freyr.strike(victim, 1.0, Vector2.RIGHT)
	await process_frame
	var xp_script = load("res://scripts/entities/xp_gem.gd")
	_check(_xp_total() - before == 20, "one lethal Freyr hit grants one harvest; corpse hit grants none")
	for child in _game.get_children():
		if child.get_script() == xp_script:
			child.queue_free()
	print("PASS cooldown, immunity, and unique harvest")


func _test_static() -> void:
	_player.add_god("thor")
	var thor = _player.gods.thor
	thor.path = "thor_static"
	_enemy_script.crit_chance = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 182026
	var targets := []
	for i in 350:
		var enemy = _spawn(Vector2(rng.randf_range(-2000, 2000), rng.randf_range(-2000, 2000)))
		enemy.add_stacks("shock", 2)
		targets.append(enemy)
	var expected := {}
	for enemy in targets:
		var links := 0
		for other in targets:
			if other != enemy and other.position.distance_squared_to(enemy.position) < pow(thor.link_range(), 2):
				links += 1
		expected[enemy] = thor.damage(20.0) * 0.12 * 2 * (1.0 + 0.5 * mini(links, 4))
	thor._tick_static(0.0)
	for enemy in targets:
		_check(is_equal_approx(1000000.0 - enemy.hp, expected[enemy]), "static-field damage matches pairwise oracle")
	var started := Time.get_ticks_usec()
	for i in 30:
		thor._static_tick = 0.0
		thor._tick_static(0.0)
	print("BENCH 350 shocked enemies / 30 static ticks: ", Time.get_ticks_usec() - started, "us")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--static-baseline="):
			var baseline = load(arg.trim_prefix("--static-baseline=")).new()
			_player.add_child(baseline)
			started = Time.get_ticks_usec()
			for i in 30:
				baseline._static_tick = 0.0
				baseline._tick_static(0.0)
			print("BENCH baseline / 30 static ticks: ", Time.get_ticks_usec() - started, "us")
			baseline.free()
	_clear_enemies()
	print("PASS static-field damage equivalence")


func _test_spawn_budget() -> void:
	for i in 349:
		_spawn(Vector2(i % 25, i / 25))
	_game.level_data = _game.level_data.duplicate(true)
	_game.level_data.events = [{"time": 0.0, "type": "ring", "enemy": "wolf", "count": 60, "text": "test"}]
	_game._update_events()
	_check(get_node_count_in_group("enemies") == 350, "ring respects remaining budget")
	_check(_game.spawn_enemy("draugr", Vector2.ZERO) == null, "regular spawn blocked at capacity")
	_game.elapsed = 40.0
	_game._update_elites({"weights": {"draugr": 1}})
	_check(get_node_count_in_group("enemies") == 350, "elite blocked without null access")
	_game.spawn_enemy.call_deferred("nail_golem_small", Vector2.ZERO)
	await process_frame
	_check(get_node_count_in_group("enemies") == 350, "deferred split blocked at capacity")
	var quest = load("res://scripts/quests/ice_warriors_quest.gd").new()
	quest.player = _player
	quest.game = _game
	_game.add_child(quest)
	quest._on_accept()
	_check(quest._blocks.size() == 5 and get_node_count_in_group("enemies") == 355, "required quest targets bypass regular budget")
	var boss = load("res://scripts/data/boss_db.gd").create("garm", 1.0)
	boss.target = _player
	boss.spawner = _game.spawn_enemy
	_game.add_child(boss)
	_check(boss._stakes.size() == 4, "Garm keeps all required stakes at capacity")
	_clear_enemies()
	quest.queue_free()
	print("PASS regular, event, elite, split, quest and Boss spawning")


func _test_ending() -> void:
	_game._defeated_bosses.assign(["skoll", "hati"])
	var boss = load("res://scripts/data/boss_db.gd").create("hrym", 1.0)
	boss.target = _player
	_game.add_child(boss)
	_game.queue_reward("")
	_check(_game.level_up_panel.visible, "reward open before final Boss")
	_game._on_boss_defeated(boss)
	_check(not _game.is_running() and paused, "final Boss immediately freezes combat")
	_check(not _game.level_up_panel.visible and _game._pending_rewards.is_empty(), "ending clears rewards")
	_game._on_upgrade_chosen({"id": "might", "rarity": 0})
	_game.pause_menu.close()
	_game.queue_reward("")
	_check(paused and _game._pending_rewards.is_empty(), "stale rewards and pause menu cannot resume ending")
	var before: float = _game.elapsed
	_game._process(10.0)
	_check(_game.elapsed == before and _game.spawn_enemy("wolf", Vector2.ZERO) == null, "ending blocks timer and deferred spawns")
	await create_timer(3.2).timeout
	var save = root.get_node("Save")
	_check(_game._run_recorded and save.stats.runs == 1 and save.stats.clears == 1, "victory records once")
	_game._on_level_cleared()
	_game._on_abandon_requested()
	_game._on_player_died()
	_game._on_upgrade_chosen({"id": "might", "rarity": 0})
	_check(paused and save.stats.runs == 1 and save.stats.clears == 1, "ended run ignores duplicate and stale callbacks")
	print("PASS final Boss, queued rewards, pause and duplicate settlement")


func _test_other_results() -> void:
	for kind in ["death", "abandon"]:
		_game.queue_free()
		await process_frame
		await process_frame
		paused = false
		_game = load("res://scripts/game.gd").new()
		root.add_child(_game)
		current_scene = _game
		_game.process_mode = Node.PROCESS_MODE_DISABLED
		await process_frame
		_game.level_up_panel.choose(0)
		var save = root.get_node("Save")
		var runs: int = save.stats.runs
		var clears: int = save.stats.clears
		_game.queue_reward("")
		if kind == "death":
			_game.player.is_dead = true
			_game.player.revives = 0
			_game._on_player_died()
			await create_timer(_game.player.death_duration() + 0.6).timeout
		else:
			_game._on_abandon_requested()
		_game._on_upgrade_chosen({"id": "might", "rarity": 0})
		_game.pause_menu.close()
		_check(paused and _game._pending_rewards.is_empty() and not _game.level_up_panel.visible, kind + " cannot resume from stale choice")
		_check(save.stats.runs == runs + 1 and save.stats.clears == clears, kind + " recorded once without victory")
	print("PASS death and abandon settlement on Helheim")


func _run() -> void:
	var save = root.get_node("Save")
	if save.path == save.DEFAULT_PATH:
		push_error("Use -- --save-file=user://combat_regression_save.json to isolate test progress")
		quit(2)
		return
	save.reset()
	_enemy_script = load("res://scripts/entities/enemy.gd")
	_player_script = load("res://scripts/entities/player.gd")
	_god_script = load("res://scripts/gods/god_power.gd")
	_game = load("res://scripts/game.gd").new()
	root.add_child(_game)
	current_scene = _game
	_game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	_game.level_up_panel.choose(0)
	_player = _game.player
	_clear_gods()
	_clear_enemies()
	_test_faith_and_levels()
	_test_queries()
	_test_zone()
	await _test_skills()
	_test_static()
	await _test_spawn_budget()
	await _test_ending()
	await _test_other_results()
	_game.queue_free()
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values():
			tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
		audio._streams.clear()
		audio.free()
		audio_script._instance = null
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	_check(_enemy_script.query_radius(Vector2.ZERO, 100000.0).is_empty(), "scene exit clears index")
	print("RESULT: ", _checks, " checks, ", _failures, " failures")
	quit(1 if _failures else 0)
