extends "res://tools/test_vigrid.gd"

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
	var save = root.get_node("Save")
	if save.path == save.DEFAULT_PATH or _output.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	AudioServer.set_bus_mute(0, true)
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	save.selected_level = "vigrid"
	_boss_db = load("res://scripts/data/boss_db.gd")
	await _new_game()
	_test_new_map()
	await _test_aid_art()
	await _test_arc_art()
	await _test_cleanup()
	var file = FileAccess.open(_output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":_checks,"failures":_failures,"log":_log},"\t"))
	file.close()
	print("M_ART_RESULT ", _checks, " checks ", _failures, " failures")
	quit(1 if _failures else 0)

func _test_new_map() -> void:
	_begin("M01 production map routes and sources")
	var map = _game._map_layer
	_check(map.ROUTE == "ash_road", "actual map uses new road")
	_check(map.edges.get("ash_road") == "ash_road_edge", "road topology registered")
	for part in map.EDGE_PARTS:
		_check(map._sources.has("ash_road_edge_" + part), "new road edge loaded: " + part)
	for id in ["ash_road", "burnt_grass_02", "cracked_lava_02"]:
		_check(map._sources.has(id), "new ground source loaded: " + id)
	_check(map.edge_masks.has("burnt_grass_02"), "grass mask applies to new ID")
	_check(not map.edge_masks.has("burnt_grass"), "obsolete grass ID not used by layout")
	_pass()

func _test_aid_art() -> void:
	_begin("M03 production aid dispatch, lifecycle and positions")
	var fx = load("res://scripts/effects/fx_layer.gd")
	var layer = fx.instance
	var battle = _game.battle
	_check(not fx.play_aid("unknown",Vector2.ZERO), "unknown god has no custom sprite")
	for god in ["freyja", "baldr", "ran", "skadi"]:
		_clear_enemies()
		_player.add_god(god)
		for i in 8:
			var enemy = _game.spawn_enemy("dead",Vector2(65+i*4,0))
			enemy.max_hp=1.0e6
			enemy.hp=enemy.max_hp
		layer._aid_effects.clear()
		layer._rings.clear()
		layer._particles.clear()
		var count: int = battle.events.size()
		var event: Dictionary = battle.request_aid(god)
		_check(battle.events.size()==count+1, god+" records exactly one aid")
		_check(layer._aid_effects.size()==1,god+" actual request emits sprite")
		var effect: Dictionary=layer._aid_effects.back()
		_check(effect.god_id==god and effect.pos==event.world_position,god+" visual and event center agree")
		if god=="freyja":
			_check(effect.pos==_player.global_position,"Freyja centered on player, not enemy cluster")
		else:
			_check(effect.pos.distance_to(_player.global_position)>30,god+" effect targets actual enemy cluster")
		_check(effect.texture.get_size()==Vector2(2560,320),god+" 8 native 320px frames")
		_check(layer._rings.is_empty() and layer._particles.is_empty(),god+" no generic ring/burst masks identity")
		_check(get_nodes_in_group("enemies").any(func(e):return e.hp<e.max_hp),god+" existing damage still applies")
		layer._process(7.0/12.0+.001)
		_check(layer._aid_effects.size()==1 and int(layer._aid_effects[0].age*12)==7,god+" transparent terminal frame retained")
		layer._process(1.0/12.0)
		_check(layer._aid_effects.is_empty(),god+" effect expires after one cycle")
		layer._boss_effects.clear()
		await _new_game()
		layer=fx.instance
		battle=_game.battle
	var nodes: int = get_node_count()
	for i in 100: fx.play_aid("freyja",Vector2(i,0))
	_check(layer._aid_effects.size()==32,"aid budget capped at32")
	_check(get_node_count()==nodes,"aid requests do not allocate scene nodes")
	layer._process(1.0)
	_check(layer._aid_effects.is_empty(),"all saturated aid entries expire")
	_player.add_god("thor")
	_game.spawn_enemy("dead",Vector2(50,0))
	battle.request_aid("thor")
	_check(layer._aid_effects.is_empty() and not layer._rings.is_empty(),"Thor retains prior lightning and generic feedback")
	await _new_game()
	layer=fx.instance
	fx.play_aid("ran",Vector2(20,0))
	_game.process_mode=Node.PROCESS_MODE_INHERIT
	_game._spawn_timer=1.0e9
	_game._next_boss=3
	_player.immune_time=1.0e9
	_game.pause_menu.open()
	var age: float=layer._aid_effects[0].age
	await create_timer(.15).timeout
	_check(layer._aid_effects.size()==1 and layer._aid_effects[0].age==age,"real pause freezes aid animation")
	_game.pause_menu.close()
	await create_timer(.8).timeout
	_check(layer._aid_effects.is_empty(),"resume completes and removes aid")
	_game.process_mode=Node.PROCESS_MODE_DISABLED
	await _new_game()
	_check(fx.instance._aid_effects.is_empty(),"new Game has no previous aid instances")
	_pass()

func _test_arc_art() -> void:
	_begin("M02 actual Surtr sweep dispatch")
	var fx = load("res://scripts/effects/fx_layer.gd")
	var boss_fx = load("res://scripts/effects/boss_fx.gd")
	var fire = _boss("surtr",Vector2(200,0),true)
	var layer=fx.instance
	layer._boss_effects.clear()
	fire._sweep_dir=Vector2.LEFT
	_player.immune_time=1.0e9
	fire._sweep()
	var effects=layer._boss_effects.filter(func(e):return e.id=="surtr_sword_arc_large")
	_check(effects.size()==1,"actual sweep emits one new arc")
	var arc: Dictionary=effects[0]
	_check(arc.scale==Vector2.ONE,"actual arc at native1x")
	_check(is_equal_approx(arc.rot,PI),"arc follows attack direction")
	_check(arc.radius==290 and is_equal_approx(arc.half,1.05),"arc clipping matches damage sector")
	_check(boss_fx.frame_count(arc.id)==4 and boss_fx.fps(arc.id)==16,"new arc registered 4frames16fps")
	_check(boss_fx.texture(arc.id).get_size()==Vector2(2560,640),"native640px source loaded")
	layer._process(.26)
	_check(layer._boss_effects.is_empty(),"arc removed after one shot")
	_pass()
