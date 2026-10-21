extends SceneTree
## 第 3 关画面检查：在真实窗口里跑 Game 场景，摆出关键时刻截图（不是 source 图库）
##   Godot --path . --script tools/review_vigrid.gd -- --save-file=user://k_review.json --settings-file=user://k_settings_zh.cfg --output=<绝对目录>
## 受控条件：玩家无敌、不刷小怪、Boss 由脚本按关卡流程生成并切到指定技能。截图只证明画面，不是完整通关

var _out := ""
var _game: Node
var _player: Node2D
var _shots: Array[Dictionary] = []
var _size := Vector2i(1280, 720)


func _initialize() -> void:
	call_deferred("_run")


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
	await _resize(Vector2i(1280, 720))
	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	await _wait(20)
	await _shot("hub_levels", "Lord God Space: level 3 card unlocked after Helheim clear")
	hub.queue_free()
	await _new_game()
	await _map_views("")
	await _serpent()
	await _wolf()
	await _fire()
	await _ending("")
	for size in [Vector2i(960, 540), Vector2i(1600, 900)]:
		await _resize(size)
		await _new_game()
		var tag := "_%dx%d" % [size.x, size.y]
		await _map_views(tag)
		await _ending(tag)
	var file := FileAccess.open(_out.path_join("captures.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "real Godot window, Game scene, controlled: invincible player, no regular spawns, scripted Boss states", "captures": _shots}, "\t"))
	file.close()
	print("REVIEW_DONE ", _shots.size(), " captures")
	_game.queue_free()
	await process_frame
	quit()


func _resize(size: Vector2i) -> void:
	_size = size
	DisplayServer.window_set_size(size)
	root.size = size
	await process_frame
	await process_frame


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
	_player = _game.player
	_player.immune_time = 1.0e9  # 受控：玩家不会死
	_game._spawn_timer = 1.0e9   # 不刷小怪
	_game._next_event = _game.level_data.events.size()
	_game._next_elite_time = 1.0e9
	_game._next_boss = 3         # Boss 由脚本按顺序生成
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _wait(5)


## 按物理帧等（玩法按物理帧推进；高刷新率屏幕上渲染帧比物理帧多）
func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _teleport(pos: Vector2) -> void:
	_player.position = pos
	_player._camera.reset_smoothing()
	_player._camera.force_update_scroll()


func _shot(name: String, note: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ".png")
	var status := root.get_texture().get_image().save_png(path)
	_shots.append({"file": name + ".png", "ok": status == OK, "window": [_size.x, _size.y], "note": note})
	print("SHOT ", name, " ", status)


func _spawn_boss(index: int) -> Node2D:
	_game._next_boss = index
	_game.elapsed = _game.level_data.bosses[index].time
	_game._update_bosses()
	_game._next_boss = 3
	await _wait(2)
	return _game.boss


func _kill(boss: Node2D) -> void:
	if is_instance_valid(boss):
		boss.take_damage(boss.max_hp * 10.0)
	await _wait(3)
	for node in get_nodes_in_group("enemies"):  # 召唤出来的火焰巨人等一起清掉，下一张截图更干净
		if node != boss:
			node.queue_free()
	for chest in _game.get_children():
		if chest.get_script() and chest.get_script().resource_path.ends_with("chest.gd"):
			chest.queue_free()
	await _wait(2)


# ———— 地图 ————

func _map_views(tag: String) -> void:
	_teleport(Vector2.ZERO)
	await _wait(10)
	await _shot("map_spawn" + tag, "spawn (0,0), central plain, routes")
	for corner in [["nw", Vector2(-2290, -2290)], ["ne", Vector2(2290, -2290)], ["se", Vector2(2290, 2290)], ["sw", Vector2(-2290, 2290)]]:
		_teleport(corner[1])
		await _wait(6)
		await _shot("map_corner_%s%s" % [corner[0], tag], "walk-rect corner, border haze and fire band, camera limit")
	_teleport(Vector2(0, -2290))
	await _wait(6)
	await _shot("map_horizon" + tag, "north horizon distant battle strip, non-interactive")
	_teleport(Vector2(-1536, 1024))
	await _wait(6)
	await _shot("map_frost_remnants" + tag, "burnt grass with derived midgard-mask transitions, giant treads")
	_teleport(Vector2(1536, 1280))
	await _wait(6)
	await _shot("map_muspel" + tag, "cracked lava decoration and hue 0.04 decorative fire")
	_teleport(Vector2.ZERO)


# ———— 耶梦加得 ————

func _serpent() -> void:
	_teleport(Vector2.ZERO)
	var snake = await _spawn_boss(0)
	# 让蛇头刚过右上圆角，身体从上边绕过来
	var total: float = snake.perimeter(snake.rect)
	var c: float = snake.corner(snake.rect)
	snake._u = (snake.rect.size.x - 2.0 * c + PI * 0.5 * c * 0.9) / total
	snake.change_state("coil")
	_teleport(Vector2(snake.rect.end.x - 330.0, snake.rect.position.y + 260.0))
	await _wait(20)
	await _shot("serpent_corner_turn", "Jormungandr body ribbon turning the rounded corner; head ring = only target")
	snake._u = 0.42
	_teleport(snake.rect.get_center())
	await _wait(4)
	snake.change_state("breath_windup")
	_teleport(snake.global_position + Vector2.from_angle(snake._head_angle + 0.6) * 260.0)
	await _wait(40)
	await _shot("serpent_breath_windup", "poison breath warning sector (same polygon as damage)")
	await _wait(30)
	await _shot("serpent_mist", "after release: breath FX clipped to sector, lingering mist polygon")
	# 猛噬：蛇头在右边，玩家在内侧 480
	snake.mists.clear()
	snake._u = 0.40
	snake.change_state("coil")
	await _wait(2)
	_teleport(snake.global_position + Vector2(-480, 60))
	snake.change_state("lunge_windup")
	await _wait(24)
	await _shot("serpent_lunge_windup", "lunge: head rears on the path, faint yellow lane = still aiming, follows the player")
	await _wait(20)
	await _shot("serpent_lunge_locked", "lunge: last 0.3s the lane turns red and is locked; sidestep to dodge")
	while snake.state != "bite":
		await physics_frame
	await _wait(6)
	await _shot("serpent_lunge_bite", "bite: head stuck in the ground, neck stretched across the arena, thick gold ring = x1.5 damage window")
	while snake.state != "coil":
		await physics_frame
	# 毒液弹：游动中吐出，空中的毒液团 + 地面落点预警
	snake.raged = true
	_teleport(snake.global_position + Vector2(-420, 0))
	snake.state_time = VigridTuning.SERPENT_COIL_TIME * 0.5 - 0.02
	await _wait(32)
	await _shot("serpent_spit", "raged spit: 5 globs in flight, ground warning circles = hit radius")
	await _wait(40)
	await _shot("serpent_spit_mist", "globs landed: small mist pools")
	await _kill(snake)


# ———— 芬里尔 ————

func _wolf() -> void:
	_teleport(Vector2.ZERO)
	var wolf = await _spawn_boss(1)
	wolf.position = _player.position + Vector2(330, 60)
	wolf.change_state("maw_windup")
	await _wait(50)
	_player.position = wolf.aperture(wolf.maw_hinge, wolf.maw_axis)
	await _wait(30)
	await _shot("fenrir_maw_active", "attraction phase: split jaws, gap %.0f >= 64 with active player in channel, fatal box and countdown" % wolf.maw_gap)
	wolf.position = _player.position + Vector2(-330, 60)
	wolf.change_state("maw_windup")
	await _wait(50)
	await _shot("fenrir_maw_left", "mirrored maw facing left (upper jaw still on top)")
	await _wait(140)
	_player.add_god("odin")
	_player.gods.odin.awakened = true
	_teleport(Vector2(-900, 0))
	wolf.position = Vector2(-1250, 60)
	wolf.change_state("maw_windup")
	await _wait(50)
	_player.position = wolf.aperture(wolf.maw_hinge, wolf.maw_axis)
	await _wait(10)
	while wolf.state != "vidar":
		await _wait(1)
	await _wait(20)
	await _shot("fenrir_vidar_brace", "Vidar pry frame %d: jaws placed on hand/boot contacts, no damage window" % wolf.vidar_frame())
	while not wolf._vidar_pried:
		await _wait(1)
	await _wait(6)
	await _shot("fenrir_vidar_pried", "jaws torn open, Fenrir damaged")
	while wolf.state == "vidar":
		await _wait(1)
	_teleport(wolf.global_position + Vector2(-260, 0))
	wolf.bind()
	await _wait(20)
	await _shot("fenrir_bound", "Gleipnir braid ribbon around torso, protected rect clear, bind timer")
	await _wait(400)
	_teleport(wolf.global_position + Vector2(-330, 0))
	wolf.change_state("run_prep")
	await _wait(30)
	await _shot("fenrir_run_route", "run route warning ring (same polyline as movement)")
	await _wait(60)
	await _shot("fenrir_run", "running along route with trail")
	await _kill(wolf)


# ———— 苏尔特 ————

func _fire() -> void:
	_teleport(Vector2.ZERO)
	var fire = await _spawn_boss(2)
	fire.position = Vector2(260, 40)
	fire.change_state("sweep_windup")
	await _wait(44)
	await _shot("surtr_sweep_windup", "320 windup pose, sweep sector warning")
	while not fire._released:
		await _wait(1)
	await _wait(2)
	await _shot("surtr_sweep_release", "attack frame 1: sword arc clipped to sector, residual fire")
	await _wait(60)
	fire.change_state("summon")
	await _wait(40)
	await _shot("surtr_gates", "Muspel gates open, fire giants emerging")
	await _wait(120)
	fire.hp = fire.max_hp * 0.59
	await _wait(10)
	_teleport(fire.firewall_center + Vector2(fire.firewall_radius - 140.0, 0))
	await _wait(10)
	await _shot("surtr_firewall", "Nine Worlds burning: band on circle boundary, fire half outward, clear inside + boundary line")
	fire.hp = fire.max_hp * 0.24
	_teleport(fire.firewall_center)
	fire.position = fire.firewall_center + Vector2(250, -60)
	await _wait(5)
	while fire.state != "final":
		await _wait(1)
	var safe: Vector2i = fire.final_safe.keys()[0]
	for cell: Vector2i in fire.final_safe:
		if (Vector2(cell) * 64.0).distance_to(fire.firewall_center) < (Vector2(safe) * 64.0).distance_to(fire.firewall_center):
			safe = cell
	_teleport(Vector2(safe) * 64.0 + Vector2(32, 12))
	await _wait(60)
	await _shot("surtr_final_warn", "final fire warning on unsafe 64 cells, safe runes, player on a safe cell")
	while fire.final_stage != "burn":
		await _wait(1)
	await _wait(3)
	await _shot("surtr_final_burn", "final fire on the same unsafe cell set; safe cells unburnt")
	_player.add_god("loki")
	_game.confirm_fate("vidar_intervened")
	_game._defeated_bosses.assign(["jormungandr", "fenrir"])
	await _kill(fire)


# ———— 结局 ————

func _ending(tag: String) -> void:
	if not _game._run_recorded and _game.is_running():
		_game.confirm_fate("thor_saved")
		_player.add_god("loki")
		_game._defeated_bosses.assign(["jormungandr", "fenrir"])
		var fire = await _spawn_boss(2)
		await _kill(fire)
	while _game.hud.ending_index() != 0:
		await _wait(1)
	for i in 5:
		await _wait(20)
		await _shot("ending_beat_%d%s" % [i, tag], "ending beat %d (manual advance, skippable)" % i)
		_game.hud.advance_ending()
	await _wait(40)
	await _shot("ending_result" + tag, "result: time/kills, fates rewritten, Loki hint")
