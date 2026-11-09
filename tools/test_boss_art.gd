extends SceneTree

var checks: Array = []
var observations: Dictionary = {}
var game
var player
var calls: Array = []

func _initialize():
	call_deferred("run")

func check(ok, label, actual = null):
	checks.append({"pass": bool(ok), "label": label, "actual": actual})
	print("PASS " if ok else "FAIL ", label, " ", actual if actual != null else "")

func spawn_capture(id, at, elite = false, required = false):
	calls.append({"id": id, "at": [at.x, at.y]})
	var enemy = load("res://scripts/entities/enemy.gd").new()
	enemy.setup(id, 1.0, elite)
	enemy.position = at
	enemy.target = player
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	game.add_child(enemy)
	return enemy

func boss(id):
	var b = load("res://scripts/bosses/" + id + ".gd").new()
	b.init_stats(1.0)
	b.target = player
	b.spawner = spawn_capture
	b.position = Vector2.ZERO
	b.process_mode = Node.PROCESS_MODE_DISABLED
	game.add_child(b)
	return b

func reset_player(at):
	player.position = at
	player.hp = player.max_hp
	player._invincible_time = 0.0
	player._dash_time = 0.0
	player.shield_time = 0.0
	player.immune_time = 0.0
	player.ward = 0
	player.dodge_chance = 0.0
	player._fear_time = 0.0

func run():
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	current_scene = game
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	game.level_up_panel.choose(0)
	paused = false
	player = game.player
	for power in player.gods.values():
		power.free()
	player.gods.clear()
	var plan = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/taskH0_critical_2026-10-19/records/plan_all_H.json"))
	for a in plan:
		if a.target.contains("thokk"):
			continue  # 女巨人的素材已经删除
		var texture = load("res://" + a.target)
		check(texture is Texture2D and texture.get_width() == a.w * a.frames and texture.get_height() == a.h, "Godot loads " + a.id)
	var skoll = boss("skoll")
	await process_frame
	skoll.hp = skoll.max_hp * 0.49
	skoll._update_state(0)
	check(skoll._enraged and skoll.state == "howl", "skoll half-health howl")
	check(skoll._actions.sprite_frames.has_animation("howl"), "new skoll howl is discovered")
	check(skoll.state_action() == &"howl", "skoll uses new howl action")
	calls.clear()
	skoll.state_time = 0.61
	skoll._update_state(0)
	check(calls.size() == 10, "skoll summons ten wolves", calls.size())
	skoll.change_state("dash")
	skoll._dash_dir = Vector2.RIGHT
	skoll._update_state(0.1)
	check(is_equal_approx(skoll.position.x, 95.0), "skoll dash speed unchanged")
	var hati = boss("hati")
	hati.hp = hati.max_hp * 0.74
	hati._update_state(0)
	check(hati._split_unlocked, "hati split unlock at 75 percent")
	hati._split()
	var phantoms: Array = []
	for c in game.get_children():
		if c.get_script() == load("res://scripts/bosses/hati_phantom.gd"):
			phantoms.append(c)
	check(phantoms.size() == 2, "hati creates two phantoms")
	for p in phantoms:
		check(p._actions.sprite_frames.get_animation_names() == hati._actions.sprite_frames.get_animation_names(), "phantom action set matches")
		check(p._actions.sprite_frames.get_frame_texture("move", 0).atlas.resource_path == hati._actions.sprite_frames.get_frame_texture("move", 0).atlas.resource_path, "phantom uses same body texture")
		p._life = 0.01
		p._physics_process(0.02)
	await process_frame
	check(not is_instance_valid(phantoms[0]) and not is_instance_valid(phantoms[1]), "phantoms expiry releases nodes")
	for distance in [279.0, 281.0]:
		reset_player(hati.position + Vector2(distance, 0))
		hati.change_state("howl_windup")
		hati.state_time = 1.11
		hati._update_state(0)
		check((player._fear_time > 0) == (distance < 280), "hati fear boundary " + str(distance))
	var hrym = boss("hrym")
	hrym.change_state("shield")
	hrym._facing = Vector2.RIGHT
	for angle in [0.0, 1.29, 1.31, PI]:
		reset_player(hrym.position + Vector2.from_angle(angle) * 150)
		var old_hp = hrym.hp
		hrym.take_damage(10)
		check(is_equal_approx(old_hp, hrym.hp) == (abs(angle) < 1.3), "hrym front shield angle " + str(angle))
	var wave = load("res://scripts/bosses/shockwave.gd").new()
	var gap_angles: Array[float] = [0.0, PI]
	wave.gaps = gap_angles
	wave.player = player
	wave.process_mode = Node.PROCESS_MODE_DISABLED
	game.add_child(wave)
	for angle in [0.0, 0.419, 0.421, PI, PI - 0.419, PI - 0.421, TAU - 0.1]:
		var expected = min(abs(angle_difference(angle, 0)), abs(angle_difference(angle, PI))) < 0.42
		check(wave._in_gap(angle) == expected, "hrym two gap angular boundary " + str(angle))
	reset_player(Vector2(300, 0))
	wave._radius = 300
	wave._process(0)
	check(player.hp == player.max_hp, "hrym gap protects player at ring radius")
	reset_player(Vector2(0, 300))
	wave._process(0)
	check(player.hp < player.max_hp, "hrym solid wave damages player")
	wave._process(3)
	await process_frame
	check(not is_instance_valid(wave), "shockwave releases after max radius")
	var pillar = load("res://scripts/bosses/ice_pillar.gd").new()
	pillar.process_mode = Node.PROCESS_MODE_DISABLED
	game.add_child(pillar)
	check(pillar.get_child(0).shape.radius == 18.0, "ice pillar collision radius retained")
	pillar._process(3.01)
	await process_frame
	check(not is_instance_valid(pillar), "ice pillar expiry cleanup")
	var garm = boss("garm")
	check(garm._stakes.size() == 4, "garm starts with four stakes")
	var original_speed = garm.speed
	var stakes = garm._stakes.duplicate()
	for i in range(4):
		garm._on_stake_broken(stakes[i])
		check(garm._free == (i == 3), "garm freed only at final stake " + str(i))
	check(is_equal_approx(garm.speed, original_speed * 1.5), "garm freed speed multiplier")
	var old_garm_hp = garm.hp
	garm.take_damage(10)
	check(is_equal_approx(old_garm_hp - garm.hp, 13), "garm freed damage multiplier")
	for distance in [259.0, 261.0]:
		reset_player(garm.position + Vector2(distance, 0))
		garm._howl()
		check((player.hp < player.max_hp) == (distance < 260), "garm howl damage boundary " + str(distance))
		reset_player(garm.position + Vector2(distance, 0))
		player.frenzy_time = 2
		player.shield_time = 2
		garm._howl()
		check((player.frenzy_time == 0 and player.shield_time == 0) == (distance < 260), "garm dispel respects howl range " + str(distance))
	var nid = boss("nidhogg")
	await process_frame
	nid.change_state("burrow")
	nid.state_time = 0.51
	nid._update_state(0)
	check(nid.untouchable and not nid.is_in_group("enemies") and not nid._sprite.visible, "nidhogg underground hidden and untargetable")
	nid.state_time = 1.31
	nid._update_state(0)
	check(not nid.untouchable and nid.is_in_group("enemies") and nid._sprite.visible, "nidhogg emerges visible and targetable")
	nid.change_state("gnaw")
	nid._gnaw_damage = 0
	nid.take_damage(nid.max_hp * 0.059)
	check(nid.state == "gnaw", "nidhogg below gnaw interrupt threshold")
	nid.take_damage(nid.max_hp * 0.0011)
	check(nid.state == "stagger", "nidhogg 6 percent damage interrupts gnaw")
	nid.state_time = 2.01
	nid._update_state(0)
	check(nid.state == "chase", "nidhogg stagger ends after two seconds")
	for angle in [0.59, 0.61]:
		reset_player(nid.position + Vector2.from_angle(angle) * 200)
		nid._breath_dir = Vector2.RIGHT
		nid._breathe()
		check((player.hp < player.max_hp) == (angle < 0.6), "nidhogg breath angular edge " + str(angle))
	for distance in [313.0, 315.0]:
		reset_player(nid.position + Vector2(distance, 0))
		nid._breath_dir = Vector2.RIGHT
		nid._breathe()
		check((player.hp < player.max_hp) == (distance < 314), "nidhogg breath radial edge includes player radius " + str(distance))
	await process_frame
	var foot = load("res://scripts/world/map_layer.gd").FOOT
	var pool = load("res://scripts/bosses/poison_pool.gd").new()
	pool.position = Vector2.ZERO
	pool.process_mode = Node.PROCESS_MODE_DISABLED
	game.add_child(pool)
	for at in [Vector2(47, -foot), Vector2(49, -foot), Vector2(0, 23 - foot), Vector2(0, 25 - foot)]:
		reset_player(at)
		check(pool._inside() == (((at + Vector2(0, foot)) * Vector2(1, 2)).length() < 48), "poison pool ellipse " + str(at))
	pool._physics_process(7.01)
	await process_frame
	check(not is_instance_valid(pool), "poison pool seven second cleanup")
	var hel = boss("hel")
	await process_frame
	for pair in [[0, 1000], [50, 690], [100, 380], [150, 380]]:
		hel._fight_time = pair[0]
		check(is_equal_approx(hel._domain_radius(), pair[1]), "hel safety radius " + str(pair[0]))
	hel._fight_time = 0
	hel.position = Vector2(-100, 0)
	var minion = spawn_capture("dead", Vector2(-150, 0))
	minion.hp = minion.max_hp * 0.5
	var before_heal = minion.hp
	hel._side_timer = 0
	hel._update_side(0)
	check(is_equal_approx(minion.hp - before_heal, minion.max_hp * 0.15), "hel life side heals 15 percent")
	hel.position = Vector2(100, 0)
	hel._side_timer = 0
	calls.clear()
	hel._update_side(0)
	check(calls.size() == 3, "hel death side summons three")
	calls.clear()
	hel._raise_army()
	check(calls.size() == 14, "hel army summons fourteen")
	reset_player(Vector2(500, 0))
	hel.change_state("cast_windup")
	hel.state_time = 0.81
	hel._update_state(0)
	var shots = get_nodes_in_group("enemy_projectiles")
	check(shots.size() == 5, "hel first phase five projectiles")
	check(shots[0].texture != null and shots[0].texture.resource_path.ends_with("hel_death_bolt.png"), "hel phase one uses new death bolt")
	for shot in shots:
		shot._physics_process(4.01)
	await process_frame
	check(get_nodes_in_group("enemy_projectiles").is_empty(), "hel projectile expiry cleanup")
	hel.hp = hel.max_hp * 0.29
	hel._update_state(0)
	check(hel._phase2 and hel.state == "ship" and is_instance_valid(hel._ship), "hel low health boards ship")
	hel._barrage()
	shots = get_nodes_in_group("enemy_projectiles")
	check(shots.size() == 9 and shots[0].texture == hel._nail, "hel phase two retains nine nail projectiles")

	var fx_script = load("res://scripts/effects/boss_fx.gd")
	var layer_script = load("res://scripts/effects/fx_layer.gd")
	var layer = layer_script.instance
	layer._boss_effects.clear()
	for a in plan:
		if a.target.begins_with("assets/sprites/effects/bosses/"):
			check(fx_script.texture(a.id) != null, "effect cache resolves " + a.id)
			check(fx_script.frame_count(a.id) == a.frames, "effect frame count " + a.id)
			if a.frames > 1:
				check(fx_script.fps(a.id) == a.fps, "effect speed " + a.id)
	var gaps: Array[float] = [TAU + 0.2, PI - 0.1]
	var arcs = fx_script.visible_arcs(gaps, 0.42)
	for i in 360:
		var angle = TAU * i / 360.0
		var visible = false
		for arc in arcs:
			visible = visible or (angle >= arc.x and angle <= arc.y) or (angle + TAU >= arc.x and angle + TAU <= arc.y)
		var safe = abs(angle_difference(angle, gaps[0])) < 0.42 or abs(angle_difference(angle, gaps[1])) < 0.42
		check(visible != safe, "rendered wave gaps match collision " + str(i))
	for i in 150:
		fx_script.play("garm_bite", Vector2(i, 0))
	check(layer._boss_effects.size() == 96, "boss effects budget caps at96 without adding nodes")
	var nodes_before = get_node_count()
	layer._process(0.6)
	check(layer._boss_effects.is_empty(), "boss effects expire completely")
	check(get_node_count() == nodes_before, "batch effects create no extra scene nodes")
	fx_script._textures["garm_bite"] = null
	check(not fx_script.play("garm_bite", Vector2.ZERO), "missing texture returns fallback signal")
	fx_script._textures.erase("garm_bite")
	check(fx_script.texture("garm_bite") != null, "texture restored after fallback test")


	layer._boss_effects.clear()
	garm.position = Vector2.ZERO
	garm._lunges_left = 3
	garm._lunge_dir = Vector2.RIGHT
	garm._bite_shown = false
	garm.change_state("lunge")
	for lunge in 3:
		reset_player(Vector2(35, 0))
		garm.state_time = 0.1
		for contact in 8:
			garm._update_state(0)
		check(layer._boss_effects.filter(func(e):return e.id == "garm_bite").size() == lunge+1, "garm each lunge emits one bite only " + str(lunge))
		garm.state_time = 0.47
		garm._update_state(0)
	check(garm.state == "recover", "garm three lunges return to recover")
	for child in game.get_children():
		if child.get_script() == load("res://scripts/bosses/shockwave.gd"):
			child.free()
	hrym.hp = hrym.max_hp * 0.49
	hrym._gaps = gap_angles
	hrym.change_state("stomp_windup")
	hrym.state_time = 1.11
	hrym._update_state(0)
	check(hrym._phase2 and hrym._second_stomp and hrym.state == "stomp_windup", "hrym phase two queues second stomp")
	hrym.state_time = 1.11
	hrym._update_state(0)
	var waves = game.get_children().filter(func(n):return n.get_script() == load("res://scripts/bosses/shockwave.gd"))
	check(waves.size() == 2 and not hrym._second_stomp, "hrym phase two emits two separate waves")
	check(waves[0].gaps != waves[1].gaps, "hrym second wave has newly warned gaps")

	var failures = checks.filter(func(c): return not c.pass)
	var out = {"engine": Engine.get_version_info(), "scope": "current integrated code: automated loading, gameplay boundary and effect lifecycle assertions", "checks": checks, "count": checks.size(), "failures": failures.size(), "observations": observations, "visual_acceptance": "separate rendered encounter review"}
	FileAccess.open("res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/runtime_checks.json", FileAccess.WRITE).store_string(JSON.stringify(out, "\t"))
	print("RESULT ", checks.size(), " checks ", failures.size(), " failures")
	game.queue_free()
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
	quit(1 if failures.size() else 0)
