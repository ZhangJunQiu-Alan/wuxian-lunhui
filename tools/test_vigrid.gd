extends SceneTree
## 第 3 关「最后之战」专项测试（K-CODE-01～07）。只用独立存档：
##   Godot --headless --path . --script tools/test_vigrid.gd -- --save-file=user://k_vigrid_test.json --settings-file=user://k_settings_zh.cfg
## 可选 --output=<目录> 写出 results.json。逻辑测试，不代替实际画面检查和完整通关

const DT := 1.0 / 60.0

var _checks := 0
var _failures := 0
var _log: Array[Dictionary] = []
var _section := ""
var _game: Node
var _player: Node2D
var _boss_db: GDScript
var _jorm: GDScript
var _fenrir: GDScript
var _surtr: GDScript
var _output := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	_log.append({"section": _section, "check": message, "pass": ok})
	if not ok:
		_failures += 1
		push_error(message)


func _begin(section: String) -> void:
	_section = section


func _pass() -> void:
	var failed := _log.filter(func(c: Dictionary) -> bool: return c.section == _section and not c.pass).size()
	print(("PASS " if failed == 0 else "FAIL ") + _section)


func _new_game() -> void:
	paused = false
	if is_instance_valid(_game):
		await process_frame  # 先让上一局 call_deferred 加的宝石、英灵进场景树，再一起释放，不留孤儿节点
		_game.queue_free()
		await process_frame
	_game = load("res://scripts/game.gd").new()
	root.add_child(_game)
	current_scene = _game
	_game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	_game.level_up_panel.choose(0)  # 开局选神
	paused = false
	_player = _game.player
	for power in _player.gods.values():
		power.free()
	_player.gods.clear()
	_player.faith.clear()
	_player.position = Vector2.ZERO
	_game.ever_faith_loki = false  # 开局随机选的神可能是洛基，测试从干净状态开始
	_clear_enemies()


func _clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	for node in get_nodes_in_group("vigrid_hazards"):
		node.free()
	for node in get_nodes_in_group("gleipnir_fragments"):
		node.free()
	_game._alive_by_type.clear()
	_game.boss = null


func _heal() -> void:
	_player.hp = _player.max_hp
	_player.is_dead = false
	_player._invincible_time = 0.0
	_player._dash_time = 0.0
	_player.ward = 0
	_player.dodge_chance = 0.0


func _awaken(god: String) -> void:
	_player.add_god(god)
	_player.faith[god] = 12
	_player.gods[god].awakened = true


func _boss(id: String, pos: Vector2 = Vector2(400, 0), wired := false) -> Node2D:
	var boss = _boss_db.create(id, 1.0)
	boss.target = _player
	boss.spawner = _game.spawn_enemy
	boss.position = pos
	if wired:  # 和 game._update_bosses 一样接上击败信号
		boss.killed.connect(_game._on_enemy_killed)
		boss.defeated.connect(_game._on_boss_defeated)
	_game.add_child(boss)
	_game.boss = boss
	return boss


func _step(node: Node, frames: int) -> void:
	for i in frames:
		if not is_instance_valid(node) or node._dead:
			return
		node._physics_process(DT)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_output = arg.trim_prefix("--output=")
	var save = root.get_node("Save")
	if save.path == save.DEFAULT_PATH:
		push_error("Use -- --save-file=user://k_vigrid_test.json to isolate test progress")
		quit(2)
		return
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	save.selected_level = "vigrid"
	_boss_db = load("res://scripts/data/boss_db.gd")
	_jorm = load("res://scripts/bosses/jormungandr.gd")
	_fenrir = load("res://scripts/bosses/fenrir.gd")
	_surtr = load("res://scripts/bosses/surtr.gd")
	_test_level_registration()
	await _new_game()
	_test_map()
	await _test_enemies()
	await _test_schedule()
	await _test_jormungandr()
	await _test_fenrir()
	await _test_surtr()
	_test_aid()
	await _test_fates_and_loki()
	await _test_ending_cases()
	await _test_skips()
	_test_save_compat()
	await _test_cleanup()
	print("RESULT: ", _checks, " checks, ", _failures, " failures")
	if _output != "":
		DirAccess.make_dir_recursive_absolute(_output)
		var file := FileAccess.open(_output.path_join("results.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": _checks, "failures": _failures, "scope": "headless logic, controlled timing (manual physics steps / forced HP); not visual or full-play acceptance", "log": _log}, "\t"))
		file.close()
	quit(1 if _failures else 0)


# ———— K-CODE-01 选关与地图 ————

func _test_level_registration() -> void:
	_begin("K-CODE-01 level registration and unlock")
	var levels = load("res://scripts/data/level_db.gd")
	var save = root.get_node("Save")
	_check(levels.is_built("vigrid") and levels.ALL.vigrid.music == "vigrid", "vigrid registered with its own music")
	var bosses: Array = levels.ALL.vigrid.bosses
	_check(bosses.map(func(b): return [b.time, b.id]) == [[180.0, "jormungandr"], [360.0, "fenrir"], [540.0, "surtr"]], "Boss table 180/360/540")
	save.cleared_levels.assign(["midgard"])
	_check(not levels.is_unlocked("vigrid") and levels.selected() != "vigrid", "locked before Helheim clear")
	save.cleared_levels.assign(["midgard", "helheim"])
	_check(levels.is_unlocked("vigrid") and levels.selected() == "vigrid", "unlocked and selectable after Helheim clear")
	save.cleared_levels.assign(["midgard"])
	save.record_run("helheim", 0, true, 600.0, 10)
	_check(save.selected_level == "vigrid", "first Helheim clear auto-selects vigrid")
	_check(levels.next_of("vigrid") == "", "vigrid is the last level of the chapter")
	for id in ["jormungandr", "fenrir", "surtr"]:
		var boss = _boss_db.create(id, 1.0)
		_check(boss != null and boss.type_id == id, "BossDB creates " + id)
		boss.free()
	_pass()


func _test_map() -> void:
	_begin("K-CODE-01 map, bounds, masks, horizon")
	var game_script = load("res://scripts/game.gd")
	_check(game_script.view_bounds == Rect2(-2560, -2560, 5120, 5120), "view rect 5120 centered")
	_check(game_script.bounds == Rect2(-2304, -2304, 4608, 4608), "walk rect matches K0")
	var map = _game._map_layer
	_check(map != null and map.get_script().resource_path.ends_with("vigrid_map.gd"), "VigridMap loaded")
	var edges := 0
	for part in map.EDGE_PARTS:
		if map._sources.has("burnt_grass_02_edge_" + part) and map._sources.has("path_edge_" + part):
			edges += 1
	_check(edges == 12, "12 midgard masks explicitly loaded and burnt_grass edges derived")
	_check(not FileAccess.file_exists("res://assets/sprites/ground/vigrid/path_edge_n.png"), "masks not copied into vigrid dir")
	var layer = load("res://scripts/world/map_layer.gd")
	var nearest_block := INF
	for cell in layer.obstacles:
		for o: Vector3 in layer.obstacles[cell]:
			nearest_block = minf(nearest_block, Vector2(o.x, o.y).length() - o.z)
	_check(nearest_block > 1280.0 - 20.0, "no fixed obstacle within central 1280 (nearest %.0f)" % nearest_block)
	var props_near := 0
	for sprite in map._props.get_children():
		if sprite.position.length() < 384.0:
			props_near += 1
	_check(props_near == 0, "spawn R384 clear of props")
	var horizon: Rect2 = _game.level_data.map.horizon
	_check(not horizon.intersects(game_script.bounds) and game_script.view_bounds.encloses(horizon), "horizon outside walk rect, inside view")
	_check(map._distant != null and map._distant.get_width() == 2048 and map._distant.get_height() == 128, "distant battle strip 512x128x4")
	_check(get_nodes_in_group("enemies").all(func(e): return not horizon.has_point(e.global_position)), "horizon has no enemy entries")
	for corner in [Vector2(-9999, -9999), Vector2(9999, -9999), Vector2(9999, 9999), Vector2(-9999, 9999)]:
		var p: Vector2 = game_script.clamp_to_map(corner, 14.0)
		_check(game_script.bounds.grow(-13.9).has_point(p), "player clamp inside corner %s" % corner)
	_player.position = Vector2(2290, 2290)
	_player.facing = Vector2(1, 1).normalized()
	_player._dash_cooldown = 0.0
	_player.try_dash()
	_check(game_script.bounds.has_point(_player._dash_to), "dash target stays in walk rect at corner")
	_player._dash_t = -1.0
	_player._dash_time = 0.0
	_player.position = Vector2.ZERO
	var hue = map.fire_hue()
	_check(hue.shader.code.contains("hue = 0.04"), "decorative fire uses instance hue 0.04 material")
	var cam: Camera2D = _player._camera
	_check(cam.limit_left == -2560 and cam.limit_bottom == 2560, "camera limited to view rect")
	_pass()


# ———— K-CODE-02 普通敌人 ————

func _test_enemies() -> void:
	_begin("K-CODE-02 regular enemies")
	_clear_enemies()
	var ids := ["fire_giant", "frost_veteran", "wolf_berserker", "dead"]
	for id in ids:
		var enemy = _game.spawn_enemy(id, Vector2(300, 0))
		_check(enemy != null and enemy._sprite != null, "spawn with sprite " + id)
		if id != "dead":
			_check(enemy.get_script().resource_path.ends_with("vigrid_enemy.gd"), "special script " + id)
			var foot: Vector2 = load("res://scripts/data/enemy_db.gd").ALL[id].foot
			var frame_h: float = enemy._actions.sprite_frames.get_frame_texture(enemy._actions.animation, 0).get_height()
			var foot_y: float = enemy._sprite.position.y - (frame_h - foot.y) * enemy._sprite.scale.y
			_check(is_equal_approx(foot_y, 20.0), "foot anchor on root+(0,20) " + id)
	_check(_game._alive_by_type.get("dead", 0) == 1, "dead reused")
	var vet = get_nodes_in_group("enemies").filter(func(e): return e.type_id == "frost_veteran")[0]
	_check(vet._actions.sprite_frames.has_animation(&"charge") and vet._actions.sprite_frames.has_animation(&"shield"), "veteran charge/shield mapped")
	_check(not vet._actions.sprite_frames.get_animation_loop(&"shield") and vet._actions.sprite_frames.get_animation_loop(&"charge"), "shield holds, charge loops")
	var wolf = get_nodes_in_group("enemies").filter(func(e): return e.type_id == "wolf_berserker")[0]
	_check(wolf._actions.sprite_frames.has_animation(&"rage") and wolf._actions.sprite_frames.get_animation_speed(&"attack") == 16.0, "berserker rage mapped, attack 16fps")
	_clear_enemies()

	# 火焰巨人：死亡时只爆炸一次，判定圆就是预警圆
	var giant = _game.spawn_enemy("fire_giant", Vector2(40, 0))
	_heal()
	giant.take_damage(9999.0)
	giant.take_damage(9999.0)
	await process_frame
	var hazards := get_nodes_in_group("vigrid_hazards")
	_check(hazards.size() == 1, "fire giant death creates exactly one blast")
	if hazards.size() == 1:
		var blast = hazards[0]
		_check(blast.in_blast(Vector2(40 + 56 + 13, 0)) and not blast.in_blast(Vector2(40 + 56 + 15, 0)), "blast edge = radius + player radius")
		_player.position = Vector2(40, 0)
		for i in 23:
			blast._physics_process(DT)
		_check(_player.hp == _player.max_hp, "no damage during warning")
		blast._physics_process(DT)
		blast._physics_process(DT)
		_check(_player.hp < _player.max_hp, "blast damages inside radius once warning ends")
		var after: float = _player.hp
		_player._invincible_time = 0.0
		blast._physics_process(DT)
		_check(_player.hp < after and after - _player.hp < 1.0, "residual fire burns as DoT, not repeated blast")
		_player.position = Vector2(200, 0)
		after = _player.hp
		blast._physics_process(DT)
		_check(_player.hp == after, "outside fire no damage")
		blast.free()
	_check(_game._alive_by_type.get("fire_giant", 0) == 0 and _game.kills >= 1, "giant counted as kill once")
	_player.position = Vector2.ZERO
	_heal()

	# 霜巨人精锐：冲锋、正面举盾减伤，背面不挡
	vet = _game.spawn_enemy("frost_veteran", Vector2(150, 0))
	vet._charge_cd = 0.0
	vet._shield_cd = 99.0
	vet._physics_process(DT)
	_check(vet.is_charging() and vet._actions.animation == &"charge", "charge starts with charge pose")
	var start: Vector2 = vet.position
	for i in 34:
		vet._physics_process(DT)
	_check(vet.position.distance_to(start) < 1.0, "no movement during charge windup")
	for i in 40:
		vet._physics_process(DT)
	_check(vet.position.x < start.x - 120.0, "charge dashes toward locked direction")
	_check(_player.hp < _player.max_hp, "charge contact hits player")
	_heal()
	for i in 30:
		vet._physics_process(DT)
	_check(not vet.is_charging(), "charge ends")
	vet.position = Vector2(200, 0)
	vet._shield_cd = 0.0
	vet._charge_cd = 99.0
	vet._physics_process(DT)
	_check(vet.is_shielding() and vet._actions.animation == &"shield", "shield raised with shield pose")
	vet.hp = 1000.0
	vet.take_damage(100.0)
	_check(is_equal_approx(vet.hp, 1000.0 - 20.0), "front hit reduced by 80%")
	vet._facing = Vector2.RIGHT  # 背对玩家（玩家在左边）
	vet.hp = 1000.0
	vet.take_damage(100.0)
	_check(is_equal_approx(vet.hp, 900.0), "back hit not blocked")
	vet.free()

	# 狂狼战士：低血量狂暴一次
	wolf = _game.spawn_enemy("wolf_berserker", Vector2(300, 0))
	var base_speed: float = wolf.speed
	wolf.hp = wolf.max_hp * 0.5
	wolf._physics_process(DT)
	_check(not wolf.raged, "no rage above 40%")
	wolf.hp = wolf.max_hp * 0.3
	wolf._physics_process(DT)
	_check(wolf.raged and is_equal_approx(wolf.speed, base_speed * 1.6) and wolf._actions.animation == &"rage", "rage once below 40% with pose and speed")
	wolf._physics_process(DT)
	wolf.hp = wolf.max_hp * 0.2
	wolf._physics_process(DT)
	_check(is_equal_approx(wolf.speed, base_speed * 1.6), "rage not applied twice")
	_clear_enemies()

	# 普通怪上限 350
	for i in 350:
		_game.spawn_enemy("dead", Vector2(i % 30, i / 30) * 4.0)
	_check(get_node_count_in_group("enemies") == 350 and _game.spawn_enemy("fire_giant", Vector2.ZERO) == null, "regular cap 350 holds for new ids")
	_clear_enemies()
	_pass()


# ———— Boss 调度：180/360/540，前一个没死就等，暂停不计时 ————

func _test_schedule() -> void:
	_begin("K-CODE-03..05 Boss schedule, waiting, pause")
	_clear_enemies()
	_game.elapsed = 179.9
	_game._update_bosses()
	_check(not is_instance_valid(_game.boss), "no Boss before 03:00")
	_game.elapsed = 180.0
	_game._update_bosses()
	_check(is_instance_valid(_game.boss) and _game.boss.type_id == "jormungandr", "Jormungandr at 03:00")
	var first = _game.boss
	_check(_game.boss.position.distance_to(_player.position) < 2048.0, "spawned near player, player not teleported")
	_game.elapsed = 400.0
	_game._update_bosses()
	_check(_game.boss == first, "Fenrir waits while Jormungandr lives")
	first.take_damage(first.max_hp * 2.0)
	await process_frame
	_check(_game._defeated_bosses == ["jormungandr"], "defeat recorded")
	_game._update_bosses()
	_check(is_instance_valid(_game.boss) and _game.boss.type_id == "fenrir", "Fenrir right after Jormungandr if 06:00 passed")
	_game.boss.take_damage(_game.boss.max_hp * 2.0)
	await process_frame
	_game.elapsed = 539.0
	_game._update_bosses()
	_check(not is_instance_valid(_game.boss), "Surtr waits for 09:00")
	_game.elapsed = 540.0
	_game._update_bosses()
	_check(is_instance_valid(_game.boss) and _game.boss.type_id == "surtr", "Surtr at 09:00")
	# 暂停冻结关卡时间和遭遇时钟
	_game.process_mode = Node.PROCESS_MODE_INHERIT
	paused = true
	var before: float = _game.elapsed
	await process_frame
	await process_frame
	_check(_game.elapsed == before, "paused tree freezes level time")
	paused = false
	_game.process_mode = Node.PROCESS_MODE_DISABLED
	_game.elapsed = 660.0
	_game._process(DT)
	_check(_game.is_running(), "past 10 minutes does not fail the run")
	_game._defeated_bosses.clear()
	_clear_enemies()
	_game.elapsed = 0.0
	_game._next_boss = 0
	_pass()


# ———— K-CODE-03 耶梦加得 ————

func _test_jormungandr() -> void:
	_begin("K-CODE-03 Jormungandr")
	_clear_enemies()
	_heal()
	_player.position = Vector2.ZERO
	var snake = _boss("jormungandr", Vector2(520, 0))
	var game_script = load("res://scripts/game.gd")
	var inner: Rect2 = game_script.bounds.grow(-96.0)
	_check(inner.encloses(snake.rect) and snake.rect.size == Vector2(2048, 2048), "path = player 2048 square ∩ bounds inset 96")
	_check(_jorm.corner(snake.rect) >= 128.0, "corner radius >= 128")
	var corner_rect: Rect2 = _jorm.path_rect(Vector2(-2290, -2290), game_script.bounds)
	_check(inner.encloses(corner_rect) and _jorm.corner(corner_rect) >= 128.0, "corner spawn path stays inset with radius >= 128")
	_check(snake.position.distance_to(_jorm.path_at(snake.rect, snake._u * _jorm.perimeter(snake.rect))[0]) < 1.0, "head snapped onto path")
	_step(snake, 2)
	_check(snake.is_in_group("enemies") and snake.collision_layer == 2, "head is the only enemy entry")
	_check(get_nodes_in_group("enemies").size() == 1, "body/tail not in enemy group")
	var mid: Vector2 = snake.body_points[snake.body_points.size() / 2]
	var near: Array = load("res://scripts/entities/enemy.gd").query_radius(mid, 40.0)
	_check(near.is_empty(), "spatial index has no body segment")
	var length := 0.0
	var max_gap := 0.0
	for i in range(1, snake.body_points.size()):
		length += snake.body_points[i - 1].distance_to(snake.body_points[i])
		max_gap = maxf(max_gap, snake.body_points[i - 1].distance_to(snake.body_points[i]))
	_check(length > 2000.0, "body length along path %.0f" % length)
	_check(max_gap <= 20.0, "continuous body sampling, no gap (max %.1f)" % max_gap)
	var k: int = snake.body_points.size() / 2
	var normal: Vector2 = (snake.body_points[k + 1] - snake.body_points[k - 1]).orthogonal().normalized()
	# 蛇身接触：同一条中线，有冷却，会撞飞
	_heal()
	_player.position = mid + normal * 10.0
	snake._body_cd = 0.0
	snake._body_contact(DT)
	_check(_player.hp < _player.max_hp and _player._shove.length() > 100.0, "body contact damages and shoves")
	var hp_after: float = _player.hp
	_player._invincible_time = 0.0
	snake._body_contact(DT)
	_check(_player.hp == hp_after, "body hit cooldown")
	_player._shove = Vector2.ZERO
	_heal()
	_player.position = mid + normal * (28 + 14 + 3)
	snake._body_cd = 0.0
	var dist: float = snake.body_distance(_player.position)[0]
	snake._body_contact(DT)
	_check(dist >= 42.0 and _player.hp == _player.max_hp, "outside body half-width no contact")
	_heal()
	_player.position = Vector2.ZERO
	# 收紧：每边最多 128
	var before: Rect2 = snake.rect
	snake._contract_timer = 99.0
	snake._update_contraction(DT)
	for i in 200:
		snake._update_contraction(DT)
	_check(is_equal_approx(before.size.x - snake.rect.size.x, 256.0) and before.get_center().is_equal_approx(snake.rect.get_center()), "contraction inset 128 per side")
	# 毒息：蓄力预警多边形 = 伤害多边形 = 毒雾
	snake.change_state("breath_windup")
	_player.position = snake.global_position + Vector2.from_angle(snake._head_angle) * 200.0
	for i in 61:
		snake._physics_process(DT)
	_check(snake.state == "breath" and snake._breath_polygon.size() > 3, "breath windup holds a polygon then releases")
	var hp_before: float = _player.hp
	for i in 4:
		snake._physics_process(DT)
	_check(snake._released and snake.mists.size() == 1, "release at attack frame 1 creates one mist")
	var poly: PackedVector2Array = snake.mists[0].polygon
	_check(game_script.bounds.grow(1.0).has_point(poly[0]), "mist clipped to bounds")
	_check(Geometry2D.is_point_in_polygon(_player.position, poly) == (_player.hp < hp_before), "breath hit iff player in polygon")
	_heal()
	if Geometry2D.is_point_in_polygon(_player.position, poly):
		var h: float = _player.hp
		snake._tick_mists(DT)
		_check(_player.hp < h, "mist DoT inside polygon")
	_player.position = Vector2(-2000, 2000)
	var h2: float = _player.hp
	snake._tick_mists(DT)
	_check(_player.hp == h2, "mist outside no damage")
	_player.position = Vector2.ZERO
	# 出招选择：近 → 毒息，远 → 猛噬，同一招最多连出 2 次
	snake.mists.clear()
	snake._last_attack = ""
	snake._streak = 0
	_player.position = snake.global_position + Vector2(0, 200)
	var picks := []
	for i in 3:
		picks.append(snake.next_attack())
	_check(picks == ["breath_windup", "breath_windup", "lunge_windup"], "near picks breath, no third repeat %s" % [picks])
	_player.position = snake.global_position + (Vector2.ZERO - snake.global_position).normalized() * 700.0
	_check(snake.next_attack() == "lunge_windup", "far player picks lunge")
	# 猛噬：预警长条 = 冲刺路线；落点不出地图内缩 64
	_check(is_equal_approx(_jorm.lunge_reach(Vector2(2000, 0), Vector2.RIGHT, 900.0, game_script.bounds), game_script.bounds.end.x - 64.0 - 2000.0), "lunge reach clipped to bounds inset 64")
	_heal()
	snake.change_state("lunge_windup")
	var path_point: Vector2 = snake.global_position
	for i in int(VigridTuning.LUNGE_WINDUP / DT) - 2:
		snake._physics_process(DT)
	var locked_dir: Vector2 = snake.lunge_dir
	var locked_len: float = snake.lunge_length
	_check(snake.state == "lunge_windup" and locked_dir.dot(path_point.direction_to(_player.position)) > 0.95, "lunge aims at player")
	_check(snake.global_position.distance_to(path_point) < 1.0, "head stays on path while winding up")
	_player.position += locked_dir.orthogonal() * 300.0  # 锁定之后横向走开
	for i in 4:
		snake._physics_process(DT)
	_check(snake.lunge_dir == locked_dir and snake.state == "lunge", "direction locked in last %.1fs" % VigridTuning.LUNGE_LOCK)
	var hp_side: float = _player.hp
	for i in 60:
		if snake.state != "lunge":
			break
		snake._physics_process(DT)
	_check(snake.state == "bite" and snake.global_position.distance_to(snake.lunge_from + locked_dir * locked_len) < 1.0, "lunge travels the telegraphed lane and bites")
	_check(_player.hp == hp_side, "sidestepped lunge: no damage")
	# 路线里的玩家被撞开
	_heal()
	snake._lunge_hit = false
	snake.lunge_from = snake.global_position - locked_dir * 200.0
	_player.position = snake.global_position - locked_dir * 100.0 + locked_dir.orthogonal() * (VigridTuning.LUNGE_HALF + 10.0)
	snake._lunge_contact()
	_check(_player.hp < _player.max_hp and _player._shove.length() > 300.0, "player inside lane is hit and shoved")
	_player._shove = Vector2.ZERO
	_heal()
	snake._lunge_hit = false
	_player.position = snake.global_position - locked_dir * 100.0 + locked_dir.orthogonal() * (VigridTuning.LUNGE_HALF + 14.0 + 2.0)
	snake._lunge_contact()
	_check(_player.hp == _player.max_hp, "outside lane half-width no hit")
	# 咬进地里：受到的伤害 ×LUNGE_WEAK_MULT，之后缩回路径
	var hp_snake: float = snake.hp
	snake.take_damage(100.0)
	_check(is_equal_approx(hp_snake - snake.hp, 100.0 * VigridTuning.LUNGE_WEAK_MULT), "bite takes x%.1f damage" % VigridTuning.LUNGE_WEAK_MULT)
	for i in int((VigridTuning.LUNGE_STUCK + VigridTuning.LUNGE_RETRACT) / DT) + 4:
		snake._physics_process(DT)
	var on_path: Vector2 = _jorm.path_at(snake.rect, snake._u * _jorm.perimeter(snake.rect))[0]
	_check(snake.state == "coil" and snake.global_position.distance_to(on_path) < 2.0, "retracts back onto path then coils")
	hp_snake = snake.hp
	snake.take_damage(100.0)
	_check(is_equal_approx(hp_snake - snake.hp, 100.0), "normal damage outside bite")
	# 毒液弹：游动途中吐一次；落点预警半径 = 伤害半径 = 小毒雾
	_heal()
	snake.mists.clear()
	snake.spits.clear()
	_player.position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	for i in int(VigridTuning.SERPENT_COIL_TIME * 0.5 / DT) + 2:
		snake._physics_process(DT)
	_check(snake.state == "coil" and snake.spits.size() == VigridTuning.SPIT_COUNT, "spits %d globs mid-coil without stopping" % VigridTuning.SPIT_COUNT)
	_check(snake.spits[0].to.is_equal_approx(Vector2.ZERO), "first glob on predicted player position")
	var first: Dictionary = snake.spits[0]
	first.t = VigridTuning.SPIT_FLIGHT - DT * 0.5
	_player.position = first.to + Vector2(VigridTuning.SPIT_RADIUS + 14.0 - 2.0, 0)
	var hp_spit: float = _player.hp
	snake._tick_spits(DT)
	_check(_player.hp < hp_spit and snake.mists.size() == 1, "glob hits within radius and leaves mist")
	_check(is_equal_approx(snake.mists[0].life, VigridTuning.SPIT_MIST_LIFE), "glob mist life")
	_heal()
	var second: Dictionary = snake.spits[0]
	second.t = VigridTuning.SPIT_FLIGHT
	_player.position = second.to + Vector2(VigridTuning.SPIT_RADIUS + 14.0 + 2.0, 0)
	snake._tick_spits(DT)
	_check(_player.hp == _player.max_hp, "glob outside radius no damage")
	# 狂怒：半血一次，毒液弹变多
	snake.spits.clear()
	snake.hp = snake.max_hp * VigridTuning.SERPENT_RAGE_AT - 1.0
	snake._physics_process(DT)
	_check(snake.raged, "rage below half")
	snake._spit()
	_check(snake.spits.size() == VigridTuning.SPIT_COUNT_RAGE, "raged spit count")
	snake.spits.clear()
	snake.mists.clear()
	_player.position = Vector2.ZERO
	# 托尔：90.0 通过，90.001 不通过；只算未暂停时间
	_check(_jorm.thor_condition(true, 90.0), "thor_at90")
	_check(not _jorm.thor_condition(true, 90.001), "thor_after90")
	_check(not _jorm.thor_condition(false, 40.0), "no_thor_faith")
	_check(_jorm.thor_condition(true, 89.0), "paused60seconds: unpaused age 89 passes")
	var age: float = snake.encounter_age
	_game.process_mode = Node.PROCESS_MODE_INHERIT
	paused = true
	for i in 3:
		await physics_frame
	_check(snake.encounter_age == age, "encounter age frozen while tree paused")
	_game.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	snake.free()
	_clear_enemies()
	_pass()


# ———— K-CODE-04 芬里尔 ————

func _test_fenrir() -> void:
	_begin("K-CODE-04 Fenrir")
	_clear_enemies()
	_heal()
	_player.position = Vector2.ZERO
	var wolf = _boss("fenrir", Vector2(300, 0))
	_check(wolf._actions.sprite_frames.has_animation(&"swallow") and wolf._actions.sprite_frames.get_animation_speed(&"swallow") == 16.0 and wolf._actions.sprite_frames.get_animation_speed(&"attack") == 16.0, "swallow mapped, attack/swallow 16fps")
	var frame_h: float = wolf._actions.sprite_frames.get_frame_texture(&"idle", 0).get_height()
	_check(frame_h == 192.0 and is_equal_approx(wolf._sprite.position.y - (192.0 - 190.0), 20.0), "192 body, foot anchor at root+20")
	await process_frame
	_check(get_nodes_in_group("gleipnir_fragments").size() == 2, "two fragments at encounter start")
	_check(wolf._upper.get_width() == 1024 and wolf._upper.get_height() == 128, "upper jaw 256x128x4 read as explicit regions")
	# 巨口：吸引阶段的通道 >= 64，预警和判定是同一个多边形
	wolf.change_state("maw_windup")
	var min_gap := INF
	for i in 50:
		wolf._physics_process(DT)
		_player.position = Vector2(900, 900)
		min_gap = minf(min_gap, wolf.maw_gap)
	_check(wolf.state == "maw" and min_gap >= 64.0, "active maw gap >= 64 (min %.0f)" % min_gap)
	var fatal: PackedVector2Array = _fenrir.fatal_polygon(wolf.maw_hinge, wolf.maw_axis, wolf.maw_gap)
	var basis: Transform2D = _fenrir.maw_basis(wolf.maw_hinge, wolf.maw_axis)
	var channel_ok := true
	for x in [64.0, 120.0, 176.0]:
		for y in [-31.0, 0.0, 31.0]:
			if not Geometry2D.is_point_in_polygon(basis * Vector2(x, y), fatal):
				channel_ok = false
	_check(channel_ok, "protected channel inside fatal shape (drawn and judged together)")
	# 逃脱：提交时不在致死区里就没事
	_heal()
	_player.position = Vector2(-1500, 0)
	wolf.state_time = 2.59
	wolf._physics_process(DT)
	wolf._physics_process(DT)
	_check(wolf.state == "swallow" and _player.hp == _player.max_hp, "escaped player unhurt at commit")
	# 吸引：在吸引区里被拉向口内中心，速度比玩家慢
	wolf.change_state("maw_windup")
	_player.position = Vector2(-1500, 0)
	for i in 43:
		wolf._physics_process(DT)
		_player.position = Vector2(-1500, 0)
	var ap: Vector2 = _fenrir.aperture(wolf.maw_hinge, wolf.maw_axis)
	_player.position = wolf.maw_hinge + wolf.maw_axis * 300.0
	var d0: float = _player.position.distance_to(ap)
	wolf._physics_process(DT)
	var pulled: float = d0 - _player.position.distance_to(ap)
	_check(pulled > 0.0 and pulled <= VigridTuning.MAW_PULL * DT + 0.01 and VigridTuning.MAW_PULL < _player.move_speed, "attraction pull slower than player speed")
	# 致死区里：走正常受伤流程（闪现无敌时吞不掉）
	_player.position = basis * Vector2(120, 0)
	_player.position = _fenrir.maw_basis(wolf.maw_hinge, wolf.maw_axis) * Vector2(120, 0)
	_player._dash_time = 0.2
	wolf.state_time = 2.59
	wolf._physics_process(DT)
	wolf._physics_process(DT)
	_check(wolf.state == "swallow" and not _player.is_dead and _player.hp == _player.max_hp, "dash invincibility survives swallow")
	_heal()
	wolf.change_state("maw_windup")
	for i in 43:
		wolf._physics_process(DT)
	var revives_before: int = _player.revives
	_player.revives = 1
	_player.position = _fenrir.maw_basis(wolf.maw_hinge, wolf.maw_axis) * Vector2(120, 0)
	wolf.state_time = 2.59
	wolf._physics_process(DT)
	wolf._physics_process(DT)
	_check(_player.revives == 0 and not _player.is_dead and _player.hp > 0.0, "swallow kills through normal damage and uses revive")
	_player.revives = revives_before
	_heal()
	# 碎片：捡一次就束缚，吸引中被束缚则吞噬取消
	wolf.change_state("maw_windup")
	for i in 43:
		wolf._physics_process(DT)
	var fragment = get_nodes_in_group("gleipnir_fragments")[0]
	_player.position = fragment.global_position
	fragment._physics_process(DT)
	_check(fragment.taken and wolf.is_bound() and wolf.state == "bound" and not wolf.maw_open, "fragment binds once, cancels maw")
	fragment._physics_process(DT)
	_check(is_equal_approx(wolf.bound_time, 6.0), "fragment not consumed twice")
	wolf.hp = 1000.0
	wolf.take_damage(100.0)
	_check(is_equal_approx(wolf.hp, 850.0), "bound Fenrir takes +50% damage")
	var pos_bound: Vector2 = wolf.position
	_player.position = Vector2(-600, 0)
	for i in 60:
		wolf._physics_process(DT)
	_check(wolf.position == pos_bound, "bound Fenrir cannot move")
	for i in 320:
		wolf._physics_process(DT)
	_check(not wolf.is_bound() and wolf.state != "bound", "binding ends after BIND_TIME")
	# 束缚带不进躯干保护区
	var protect: Rect2 = wolf.BIND_PROTECT
	var ellipse_ok := true
	for i in 72:
		var a := TAU * i / 72.0
		var p: Vector2 = Vector2(cos(a) * 82.0, sin(a) * 84.0)
		if protect.grow(4.0).has_point(p):
			ellipse_ok = false
	_check(ellipse_ok, "bind ribbon (width 8) stays outside protected torso rect")
	# 狂奔：路线预警和移动是同一条，都在地图里
	_heal()
	_player.position = Vector2.ZERO
	wolf.position = Vector2(350, 0)
	wolf.change_state("run_prep")
	wolf._physics_process(DT)
	var route: PackedVector2Array = wolf.route
	var inside := true
	for p in route:
		if not load("res://scripts/game.gd").bounds.has_point(p):
			inside = false
	_check(route.size() == 49 and inside, "run route planned inside bounds")
	for i in 60:
		wolf._physics_process(DT)
	_check(wolf.state == "run", "run starts after windup")
	var on_route := true
	for i in 30:
		wolf._physics_process(DT)
		var nearest := INF
		for p in route:
			nearest = minf(nearest, p.distance_to(wolf.position))
		if nearest > 60.0:
			on_route = false
	_check(on_route, "run follows the warned route")
	# 维达：没觉醒不出现；奥丁觉醒时出现一次，演出期间不伤玩家
	_heal()
	_game.fates.vidar_intervened = false
	_player.add_god("odin")
	wolf.change_state("maw_windup")
	for i in 43:
		wolf._physics_process(DT)
	_check(not wolf._vidar_ready, "odin faith without awakening: no Vidar")
	_player.gods.odin.awakened = true
	wolf.change_state("maw_windup")
	for i in 43:
		wolf._physics_process(DT)
	_check(wolf._vidar_ready, "odin awakened: Vidar ready")
	_player.position = _fenrir.maw_basis(wolf.maw_hinge, wolf.maw_axis) * Vector2(120, 0)
	var hp_wolf: float = wolf.hp
	for i in 60:
		wolf._physics_process(DT)
	_check(wolf.state == "vidar" and _game.fates.vidar_intervened, "Vidar actually intervenes and flag set")
	var hand_ok := true
	var start_hp: float = _player.hp
	for i in 200:
		wolf._physics_process(DT)
		if wolf.state == "vidar":
			var c: PackedVector2Array = wolf.vidar_contacts()
			if c[0].y > -30.0 or c[1].y < 30.0:
				hand_ok = false
	_check(hand_ok, "jaws bound to Vidar hand/boot contacts")
	_check(_player.hp == start_hp, "Vidar tableau never damages player")
	_check(wolf.hp < hp_wolf - wolf.max_hp * 0.14, "Vidar pry damages Fenrir")
	_check(wolf.state == "stagger", "Fenrir staggers after pry")
	wolf.change_state("maw_windup")
	for i in 43:
		wolf._physics_process(DT)
	_check(not wolf._vidar_ready, "Vidar only once per encounter")
	wolf.take_damage(wolf.max_hp * 5.0)
	_check(get_nodes_in_group("gleipnir_fragments").all(func(f): return f.is_queued_for_deletion()), "fragments cleared on defeat")
	_clear_gods()
	_clear_enemies()
	_pass()


func _closest(cells: Array, to: Vector2) -> Vector2i:
	var best: Vector2i = cells[0]
	for cell: Vector2i in cells:
		if (Vector2(cell) * 64.0 + Vector2(32, 32)).distance_to(to) < (Vector2(best) * 64.0 + Vector2(32, 32)).distance_to(to):
			best = cell
	return best


func _clear_gods() -> void:
	for power in _player.gods.values():
		power.free()
	_player.gods.clear()
	_player.faith.clear()


# ———— K-CODE-05 苏尔特 ————

func _test_surtr() -> void:
	_begin("K-CODE-05 Surtr")
	_clear_enemies()
	_heal()
	_player.position = Vector2.ZERO
	_check(_surtr.cell_of(Vector2(-1, 5)) == Vector2i(-1, 0), "cell -1 -> -1")
	_check(_surtr.cell_of(Vector2(-64, 0)) == Vector2i(-1, 0), "cell -64 -> -1")
	_check(_surtr.cell_of(Vector2(-65, 0)) == Vector2i(-2, 0), "cell -65 -> -2")
	_check(_surtr.cell_of(Vector2(63.9, 64)) == Vector2i(0, 1), "cell 63.9 -> 0, 64 -> 1")
	var fire = _boss("surtr", Vector2(300, 0))
	for action in ["idle", "move", "windup", "attack", "plant", "summon"]:
		var frames: SpriteFrames = fire._actions.sprite_frames
		_check(frames.has_animation(action) and frames.get_frame_texture(action, 0).get_width() == 320, "320 action " + action)
	for action in ["attack", "plant", "summon"]:
		_check(fire._actions.sprite_frames.get_animation_speed(action) == 16.0, "16fps " + action)
	_check(fire._actions.sprite_frames.get_animation_speed(&"windup") == 8.0 and not fire._actions.sprite_frames.get_animation_loop(&"plant"), "windup 8fps, plant holds last frame")
	_check(is_equal_approx(fire._sprite.position.y - (320.0 - 318.0), 20.0), "foot (160,318) at root+20")
	# 横扫：预警扇形 = 伤害扇形
	fire.change_state("sweep_windup")
	_player.position = Vector2(300 - 200, 0)
	for i in 55:
		fire._physics_process(DT)
	_check(fire.state == "sweep", "sweep after windup")
	var hp0: float = _player.hp
	for i in 5:
		fire._physics_process(DT)
	_check(fire._released and _player.hp < hp0, "sweep hits inside sector at frame 1")
	await process_frame
	_check(get_nodes_in_group("vigrid_hazards").size() == 3, "sweep leaves 3 residual fires")
	for h in get_nodes_in_group("vigrid_hazards"):
		h.free()
	_heal()
	fire.change_state("sweep_windup")
	for i in 55:
		fire._physics_process(DT)
	_player.position = Vector2(300 + 400, 0)
	for i in 5:
		fire._physics_process(DT)
	_check(_player.hp == _player.max_hp, "sweep misses outside sector")
	await process_frame
	for h in get_nodes_in_group("vigrid_hazards"):
		h.free()
	# 火门：开门一次，放出火焰巨人（受敌人上限约束）
	_player.position = Vector2.ZERO
	fire.change_state("summon")
	for i in 12:
		fire._physics_process(DT)
	_check(fire.gates.size() == 2, "two gates opened once at palm frame")
	for i in 200:
		fire._physics_process(DT)
	_check(fire.gates.is_empty() and _game._alive_by_type.get("fire_giant", 0) == VigridTuning.GATE_COUNT * VigridTuning.GATE_GIANTS, "gates release their fire giants then close")
	for enemy in get_nodes_in_group("enemies"):
		if enemy != fire:
			enemy.free()
	for h in get_nodes_in_group("vigrid_hazards"):
		h.free()
	_game._alive_by_type.clear()
	# 60%：九界燃烧一次
	fire.change_state("chase")
	fire.hp = fire.max_hp * 0.59
	fire._physics_process(DT)
	_check(fire.phase == 2 and fire.firewall_age >= 0.0, "60% triggers firewall")
	var center: Vector2 = fire.firewall_center
	fire.firewall_age = 1.0
	fire.hp = fire.max_hp * 0.55
	fire._physics_process(DT)
	_check(fire.firewall_center == center and fire.firewall_age > 1.0, "firewall not restarted by later damage")
	_check(is_equal_approx(_surtr.firewall_radius_at(0.0), 1000.0) and is_equal_approx(_surtr.firewall_radius_at(999.0), 440.0), "firewall shrinks 1000 -> 440")
	_heal()
	_player.position = center + Vector2(fire.firewall_radius - 5.0, 0)
	var h1: float = _player.hp
	fire._tick_firewall(DT)
	_check(_player.hp == h1, "inside firewall circle no damage")
	_player.position = center + Vector2(fire.firewall_radius + 5.0, 0)
	fire._tick_firewall(DT)
	_check(_player.hp < h1, "outside firewall circle burns")
	_player.position = center
	# 25%：插剑 + 终焉之火一次
	_heal()
	fire.hp = fire.max_hp * 0.24
	fire._physics_process(DT)
	_check(fire.phase == 3 and fire.state == "plant", "25% triggers plant once")
	for i in 50:
		fire._physics_process(DT)
	_check(fire.state == "final" and fire.final_stage == "warn", "final fire begins with warning")
	fire.position = fire.firewall_center + Vector2(fire.firewall_radius * 0.8, 0)  # 让开中间，免得身体碰撞干扰格子判定
	var planted_at: Vector2 = fire.position
	var area: Array = fire.final_area
	var union := {}
	for c in fire.final_safe:
		union[c] = true
	var overlap := false
	for c in fire.final_unsafe:
		if fire.final_safe.has(c):
			overlap = true
		union[c] = true
	_check(not overlap and union.size() == area.size(), "safe ∪ unsafe = area, disjoint")
	var covered := 0.0
	for run: Rect2 in fire.final_rows:
		covered += run.get_area()
	var runs_ok := is_equal_approx(covered, fire.final_unsafe.size() * 4096.0)
	for cell: Vector2i in fire.final_safe:
		for run: Rect2 in fire.final_rows:
			if run.has_point(Vector2(cell) * 64.0 + Vector2(32, 32)):
				runs_ok = false
	_check(runs_ok, "drawn fire rows cover exactly the unsafe cell set, never a safe cell")
	var pc: Vector2i = fire.foot_cell()
	var reach_ok := false
	for c: Vector2i in fire.final_safe:
		if maxi(absi(c.x - pc.x), absi(c.y - pc.y)) <= 4:
			reach_ok = true
	_check(reach_ok, "a safe cell reachable near player")
	var safe_cell: Vector2i = _closest(fire.final_safe.keys(), fire.firewall_center)
	_player.position = Vector2(safe_cell) * 64.0 + Vector2(32, 32) - Vector2(0, 20)
	_check(fire.foot_cell() == safe_cell, "player foot cell lookup")
	fire.hp = fire.max_hp * 0.2
	fire.phase = 3
	for i in 125:
		fire._physics_process(DT)
	_check(fire.final_stage == "burn" and _player.hp == _player.max_hp, "safe cell protected at burn")
	for i in 130:
		fire._physics_process(DT)
	_check(fire.final_stage == "warn" and fire.final_cycles == 1, "new cycle replans")
	var unsafe_cell: Vector2i = _closest(fire.final_unsafe.keys(), fire.firewall_center)
	_player.position = Vector2(unsafe_cell) * 64.0 + Vector2(32, 32) - Vector2(0, 20)
	for i in 125:
		fire._physics_process(DT)
	_check(_player.hp < _player.max_hp, "unsafe cell takes damage at burn")
	var h3: float = _player.hp
	_player._invincible_time = 0.0
	for i in 20:
		fire._physics_process(DT)
	_check(_player.hp == h3, "burn damage resolved once per cycle")
	fire.hp = fire.max_hp * 0.1
	fire._check_phases()
	_check(fire.phase == 3 and fire.state == "final", "phases never retrigger")
	_check(fire.position == planted_at, "planted Surtr stays put")
	fire.free()
	_clear_enemies()
	_pass()


# ———— K-CODE-06 援助与音频 ————

func _test_aid() -> void:
	_begin("K-CODE-06 aid and audio")
	_clear_enemies()
	_heal()
	var battle = _game.battle
	_check(battle != null, "VigridBattle present on level 3")
	for god in ["thor", "odin", "loki", "freyja"]:
		_player.add_god(god)
	for i in 10:
		_game.spawn_enemy("dead", Vector2(60 + i * 5, 0))
	_check(battle.nearby_combat(), "nearby combat with enough enemies")
	var events_before: int = battle.events.size()
	for god in ["thor", "odin", "loki", "freyja"]:
		var event: Dictionary = battle.request_aid(god)
		_check(event.has_all(["god_id", "world_position", "source_encounter", "aid_kind", "event_id"]) and event.god_id == god, "aid event fields " + god)
	_check(battle.events.size() == events_before + 4, "each aid recorded once")
	_check(get_nodes_in_group("enemies").all(func(e): return e.type_id == "dead"), "aid adds no enemy entries")
	_clear_enemies()
	_check(not battle.nearby_combat(), "no aid without nearby combat")
	battle._aid_timer = 0.0
	for i in 60 * 15:
		battle._tick_aid(DT)
	_check(battle.events.size() == events_before + 4, "periodic aid waits for nearby combat")
	# 托尔：只有获救后才在苏尔特战中落雷
	var fire = _boss("surtr", Vector2(200, 0))
	_game.fates.thor_saved = false
	battle._thor_timer = 99.0
	battle._tick_thor(DT, fire)
	_check(fire.hp == fire.max_hp, "no Thor strike without thor_saved")
	_game.fates.thor_saved = true
	battle._thor_timer = 99.0
	battle._tick_thor(DT, fire)
	_check(fire.hp < fire.max_hp and battle.events.back().aid_kind == "fate_thor_strike", "saved Thor strikes Surtr")
	# 弗雷：信仰弗雷不算，必须是弗蕾亚觉醒
	_clear_gods()
	_game.fates.freyr_assisted = false
	_awaken("freyr")
	battle._tick_freyr(DT)
	_check(not battle.freyr_active and not _game.fates.freyr_assisted, "freyr_faith_not_freyja")
	_clear_gods()
	_player.add_god("freyja")
	battle._tick_freyr(DT)
	_check(not battle.freyr_active, "freyja faith without awakening: no Freyr")
	_player.gods.freyja.awakened = true
	battle._tick_freyr(DT)
	_check(battle.freyr_active and _game.fates.freyr_assisted, "freyja awakened: Freyr assists")
	_player.hp = _player.max_hp * 0.5
	var heals_before: int = battle.events.filter(func(e): return e.aid_kind == "fate_freyr_heal").size()
	for i in 250:
		battle._tick_freyr(DT)
	_check(_player.hp > _player.max_hp * 0.5 and battle.events.filter(func(e): return e.aid_kind == "fate_freyr_heal").size() == heals_before + 1, "Freyr heals on actual grant")
	_player.hp = _player.max_hp
	var count_full: int = battle.events.size()
	for i in 250:
		battle._tick_freyr(DT)
	_check(battle.events.size() == count_full, "no heal event at full HP")
	fire.free()
	_clear_gods()
	_clear_enemies()
	# 音频：4 个新音效和关卡音乐都能按名找到
	var audio = load("res://scripts/core/audio.gd")
	var shared = audio._shared()
	for sound in ["jormungandr_hiss", "fenrir_swallow", "gleipnir_tension", "surtr_gate"]:
		_check(not shared._find(sound, audio.SFX_DIR, ["wav", "ogg"]).is_empty(), "new sfx " + sound)
	_check(not shared._find("vigrid", audio.MUSIC_DIR, ["ogg"]).is_empty(), "vigrid music")
	for sound in ["boss_windup", "boss_slam", "milestone", "lightning", "boss_howl", "chest_open", "awaken", "katana_slash", "fire_burn", "boss_warning", "heal_pickup", "big_death", "boss_block"]:
		_check(not shared._find(sound, audio.SFX_DIR, ["wav", "ogg"]).is_empty(), "reused sfx " + sound)
	_check(audio.VOICES == 24 and audio.MAX_SAME == 4 and is_equal_approx(audio.MIN_GAP, 0.05), "audio limits unchanged")
	_pass()


# ———— K-CODE-07 命运、洛基、结局、存档 ————

func _test_fates_and_loki() -> void:
	_begin("K-CODE-07 fates and Loki")
	await _new_game()
	_check(_game.fates == {"thor_saved": false, "vidar_intervened": false, "freyr_assisted": false} and not _game.ever_faith_loki, "new_run_reset: all four false")
	_check(_game.confirm_fate("thor_saved") and not _game.confirm_fate("thor_saved") and _game.fate_count() == 1, "fate monotonic and once")
	_check(not _game.confirm_fate("unknown"), "unknown fate ignored")
	_player.add_god("loki")
	_check(_game.ever_faith_loki, "Loki faith granted marks ever_faith_loki")
	_clear_gods()
	_check(_game.ever_faith_loki, "loki_lost_current_faith keeps flag")
	await _new_game()
	_check(not _game.ever_faith_loki and _game.fate_count() == 0, "next run does not inherit flags")
	var panel = _game.level_up_panel
	_game.queue_reward("")
	_check(not _game.ever_faith_loki, "menu preview does not mark Loki")
	panel.visible = false
	_game._pending_rewards.clear()
	paused = false
	# 托尔实战：信仰托尔，遭遇 89 秒内击败
	_clear_enemies()
	_player.add_god("thor")
	var snake = _boss("jormungandr")
	snake.encounter_age = 89.0
	snake.take_damage(snake.max_hp * 3.0)
	_check(_game.fates.thor_saved, "Thor saved when killed at 89s with Thor faith")
	await _new_game()
	_player.add_god("thor")
	snake = _boss("jormungandr")
	snake.encounter_age = 90.001
	snake.take_damage(snake.max_hp * 3.0)
	_check(not _game.fates.thor_saved, "Thor not saved at 90.001s")
	await _new_game()
	snake = _boss("jormungandr")
	for i in 60:
		snake._physics_process(DT)
	_check(is_equal_approx(snake.encounter_age, 1.0), "encounter age counts own physics frames, not level elapsed")
	snake.take_damage(snake.max_hp * 3.0)
	_check(not _game.fates.thor_saved, "no Thor faith: not saved")
	_pass()


## K7 的 16 种命运 / 洛基组合：命运数、洛基伏笔、结算只记一次
func _test_ending_cases() -> void:
	_begin("K-CODE-07 K7 fate/Loki combinations")
	var cases = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/data/vigrid_ending_timeline.json"))
	_check(cases is Dictionary and cases.beats.size() == 5, "ending timeline 5 beats")
	var game_script = load("res://scripts/game.gd")
	var beats: PackedStringArray = game_script.load_ending("res://scripts/data/vigrid_ending_timeline.json")
	_check(beats.size() == 5 and beats[0].begins_with("火焰熄灭了") and beats[4].contains("正在返回主神空间"), "load_ending parses and validates")
	_check(game_script.load_ending("res://missing.json").is_empty(), "missing ending falls back")
	var save = root.get_node("Save")
	for mask in 16:
		await _new_game()
		var flags := {"thor_saved": mask & 4 != 0, "vidar_intervened": mask & 2 != 0, "freyr_assisted": mask & 1 != 0}
		var loki := mask & 8 != 0
		for id in flags:
			if flags[id]:
				_game.confirm_fate(id)
		if loki:
			_player.add_god("loki")
			_clear_gods()
		var runs: int = save.stats.runs
		var points: int = save.reward_points
		var run: Dictionary = _game._finish_run(true)
		var again: Dictionary = _game._finish_run(true)
		var expected: int = int(flags.thor_saved) + int(flags.vidar_intervened) + int(flags.freyr_assisted)
		var name := "fates%d%d%d_loki%d" % [int(flags.thor_saved), int(flags.vidar_intervened), int(flags.freyr_assisted), int(loki)]
		_check(run.fate_count == expected and run.ever_faith_loki == loki, name + " count and Loki flag")
		_check(again == run and save.stats.runs == runs + 1 and save.reward_points == points + run.reward_points, name + " settled once")
		_check(save.fates.has("vigrid") and (not loki or save.fates.vigrid.ever_faith_loki), name + " fate record saved")
		_game.hud.show_result("victory", "test", "", run, _player)
		var hint = _game.hud.find_child("LokiHint", true, false)
		_check((hint != null) == loki, name + " Loki hint shown iff flag")
		var fates_row = _game.hud.find_child("Fates", true, false)
		_check(fates_row != null and fates_row.get_child(0).get_child(0).text == "%d / 3" % expected, name + " result fate tile")
	_pass()


## 五段字幕：每一段都能跳过，跳过 / 读完 / 连点 / 重复回调都只结算一次
func _test_skips() -> void:
	_begin("K-CODE-07 ending skip and settlement")
	var save = root.get_node("Save")
	for skip_at in range(-1, 5):
		await _new_game()
		_game.confirm_fate("vidar_intervened")
		_player.add_god("loki")
		var runs: int = save.stats.runs
		var clears: int = save.stats.clears
		_game._defeated_bosses.assign(["jormungandr", "fenrir"])
		var fire = _boss("surtr", Vector2(400, 0), true)
		fire.take_damage(fire.max_hp * 5.0)
		await process_frame
		_check(not _game.is_running() and paused, "final Boss freezes combat")
		await create_timer(3.2).timeout
		var hud = _game.hud
		_check(hud.ending_index() == 0 and _game._run_recorded and save.stats.runs == runs + 1, "ending shown after settlement frozen")
		var points: int = save.reward_points
		var label := "skip_at_%d" % skip_at if skip_at >= 0 else "read_all"
		if skip_at < 0:
			for i in 5:
				_check(hud.ending_index() == i, label + " beat %d" % i)
				hud.advance_ending()
		else:
			for i in skip_at:
				hud.advance_ending()
			_check(hud.ending_index() == skip_at, label + " reached beat")
			hud.skip_ending()
		hud.skip_ending()  # 连点 / 重复
		hud.advance_ending()
		_game._on_level_cleared()
		_game._on_player_died()
		_game._on_abandon_requested()
		await process_frame
		_check(hud.ending_index() == -1, label + " ending closed")
		var hint = hud.find_child("LokiHint", true, false)
		var tile = hud.find_child("Fates", true, false)
		_check(hint != null and tile != null and tile.get_child(0).get_child(0).text == "1 / 3", label + " same snapshot keeps fate and Loki hint")
		var results = hud.get_children().filter(func(c): return c is ColorRect and c.visible and c.name != "Ending")
		_check(results.size() == 1, label + " exactly one result screen")
		_check(save.stats.runs == runs + 1 and save.stats.clears == clears + 1 and save.reward_points == points, label + " no repeated reward or save")
		_check(paused, label + " world stays paused while reading")
	_pass()


func _test_save_compat() -> void:
	_begin("K-CODE-07 save compatibility")
	var save = root.get_node("Save")
	var path: String = save.path
	var old := {"version": 4, "reward_points": 12, "story_points": 3, "cleared_levels": ["midgard", "helheim"], "selected_level": "vigrid",
		"stats": {"runs": 2, "clears": 2}, "codex": {"enemies": {}, "bosses": {}, "upgrades": {}, "quests": {}}}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	save.load_game()
	_check(save.fates == {} and save.reward_points == 12 and save.selected_level == "vigrid", "v4 save loads with empty fates")
	save.record_fates("vigrid", {"thor_saved": true, "vidar_intervened": false, "freyr_assisted": false}, false)
	save.record_fates("vigrid", {"thor_saved": false, "vidar_intervened": true, "freyr_assisted": false}, true)
	_check(save.fates.vigrid == {"thor_saved": true, "vidar_intervened": true, "freyr_assisted": false, "ever_faith_loki": true}, "fate records union across runs")
	save.save_game()
	save.fates = {}
	save.load_game()
	_check(save.fates.vigrid.thor_saved and save.fates.vigrid.ever_faith_loki, "fates persisted and reloaded")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed.version == 5, "save version 5")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"fates": "broken"}))
	file.close()
	save.load_game()
	_check(save.fates == {}, "malformed fates ignored")
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	save.selected_level = "vigrid"
	_pass()


func _test_cleanup() -> void:
	_begin("cleanup")
	await _new_game()
	var snake = _boss("jormungandr")
	_step(snake, 5)
	_game.queue_free()
	await process_frame
	await process_frame
	_check(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("vigrid_hazards").is_empty() and get_nodes_in_group("gleipnir_fragments").is_empty(), "scene exit leaves no K nodes")
	_check(load("res://scripts/entities/enemy.gd").query_radius(Vector2.ZERO, 100000.0).is_empty(), "spatial index cleared")
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
	load("res://scripts/world/vigrid_map.gd").fire_material = null
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	_pass()
