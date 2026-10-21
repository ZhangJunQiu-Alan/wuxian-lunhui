extends "res://tools/test_vigrid.gd"

var _case_results := {}
var _point_samples: Array[Dictionary] = []

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
	var save = root.get_node("Save")
	if save.path == save.DEFAULT_PATH or _output.is_empty():
		push_error("Isolated --save-file and --output required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	AudioServer.set_bus_mute(0,true)
	save.reset()
	save.cleared_levels.assign(["midgard", "helheim"])
	save.selected_level = "vigrid"
	_boss_db = load("res://scripts/data/boss_db.gd")
	_jorm = load("res://scripts/bosses/jormungandr.gd")
	_fenrir = load("res://scripts/bosses/fenrir.gd")
	_surtr = load("res://scripts/bosses/surtr.gd")
	await _new_game()
	await _test_duplicate_boss()
	await _test_movement_and_spawns()
	await _test_walk_edges()
	if not OS.get_cmdline_user_args().has("--probe"):
		await _new_game()
		await _test_damage_points()
		await _test_grid_firewall_overlap()
		await _test_fragment_replenishment()
		await _test_pickup_merge()
		await _test_all_aid()
		await _test_pause_resume_all()
		if not OS.get_cmdline_user_args().has("--grid-probe"):
			await _test_real_pause()
		await _test_ending_workflow()
		await _test_return_retry()
		await _test_cleanup()
	var spec = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/taskK7_fate_ending_2026-10-20/acceptance_cases.json"))
	var cases := []
	for c in spec.cases:
		cases.append({"id": c.id, "execution": _case_results.get(c.id, "not_run")})
	var report := {"scope": "independent controlled runtime acceptance; manual steps and forced states/HP; not a natural clear", "checks": _checks, "failures": _failures, "log": _log, "cases": cases, "damage_points": _point_samples}
	var file := FileAccess.open(_output.path_join("acceptance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("INDEPENDENT_RESULT ", _checks, " checks ", _failures, " failures cases=", _case_results.size(), "/28")
	quit(1 if _failures else 0)

func _test_duplicate_boss() -> void:
	_begin("duplicate Boss defeat callbacks")
	var snake = _boss("jormungandr", Vector2(500,0), true)
	var points: int = _game.reward_points
	_game._on_boss_defeated(snake)
	_game._on_boss_defeated(snake)
	_check(_game._defeated_bosses == ["jormungandr"], "duplicate defeated callback does not advance encounter twice")
	_check(_game.reward_points == points + snake.reward_points, "duplicate defeated callback awards Boss points once")
	_check(_game.is_running(), "duplicate first Boss callback cannot finish level")
	_pass()
	await _new_game()

func _test_movement_and_spawns() -> void:
	_begin("map movement obstacles roads and enemy spawn")
	var game_script = load("res://scripts/game.gd")
	var map_script = load("res://scripts/world/map_layer.gd")
	var bounds: Rect2 = game_script.bounds
	var block_list := []
	for list in map_script.obstacles.values():
		block_list.append_array(list)
	var spawn_overlap := 0
	var spawn_outside := 0
	for o: Vector3 in block_list:
		var e = _game.spawn_enemy("dead", Vector2(o.x, o.y) - Vector2(0,20))
		var corrected: Vector2 = map_script.push_out(e.position, e.radius)
		if e.position.distance_to(corrected) > 0.01: spawn_overlap += 1
		e.free()
	for pos in [Vector2(-9999,-9999),Vector2(9999,-9999),Vector2(9999,9999),Vector2(-9999,9999)]:
		var e = _game.spawn_enemy("fire_giant",pos)
		if not bounds.grow(-e.radius+0.1).has_point(e.position): spawn_outside += 1
		e.free()
	_check(spawn_overlap == 0, "enemy spawn resolves fixed obstacles before first frame: overlaps=%d" % spawn_overlap)
	_check(spawn_outside == 0, "enemy spawn clamped before first frame: outside=%d" % spawn_outside)
	for start in [Vector2(-2290,0),Vector2(2290,0),Vector2(0,-2290),Vector2(0,2290),Vector2(-2290,-2290),Vector2(2290,-2290),Vector2(2290,2290),Vector2(-2290,2290)]:
		_player.position = start
		_player.facing = start.normalized()
		_player._dash_t = -1.0
		_player._dash_cooldown = 0.0
		_player.try_dash()
		for i in 12:
			_player._update_dash(DT)
			_check(bounds.grow(-13.9).has_point(_player.position), "dash path stays inside %s step %d" % [start,i])
		_player._dash_t = -1.0
	for o: Vector3 in block_list:
		for i in 8:
			var normal := Vector2.from_angle(TAU*i/8.0)
			var at := Vector2(o.x,o.y) + normal*(o.z+4.0) - Vector2(0,20)
			var resolved: Vector2 = map_script.push_out(at,14.0)
			_check((resolved+Vector2(0,20)).distance_to(Vector2(o.x,o.y)) >= o.z+13.95, "obstacle push resolves overlap %s/%d" % [o,i])
			var retreat: Vector2 = map_script.push_out(resolved+normal*20.0,14.0)
			_check(retreat.distance_to(resolved)>19.9, "can retreat after obstacle contact %s/%d" % [o,i])
	for corner in [Vector2(-2290,-2290),Vector2(2290,-2290),Vector2(2290,2290),Vector2(-2290,2290)]:
		_player.position=corner
		var closest:=INF
		for i in 500:
			closest=minf(closest,_game._random_spawn_position().distance_to(corner))
		_check(closest>=_game.SPAWN_DISTANCE-80.0,"corner spawns preserve approach distance %s min=%.2f"%[corner,closest])
	var routes: Array = _game.level_data.map.routes
	var blocked := 0
	for route in routes:
		for i in 101:
			var at: Vector2 = route[0].lerp(route[1],i/100.0)
			if map_script.push_out(at-Vector2(0,20),14.0).distance_to(at-Vector2(0,20)) > 0.1: blocked+=1
	_check(blocked == 0, "all route centerlines traversable at 101 points each: blocked=%d" % blocked)
	# Flood fill on a 32-pixel grid, including all five landmarks.
	var seen := {Vector2i(0,0):true}
	var queue: Array[Vector2i] = [Vector2i(0,0)]
	var index := 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index+=1
		for dir in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+dir
			var pos := Vector2(next)*32.0
			if seen.has(next) or not bounds.grow(-14).has_point(pos): continue
			if map_script.push_out(pos-Vector2(0,20),18.0).distance_to(pos-Vector2(0,20))>0.1: continue
			seen[next]=true
			queue.append(next)
	for lm: Dictionary in _game.level_data.map.landmarks:
		_check(seen.has(Vector2i((lm.pos/32.0).round())), "landmark reachable by continuous grid route: "+lm.id)
	_player.position=Vector2.ZERO
	_pass()

func _sample(kind: String, pos: Vector2, expected: bool, hit: bool) -> void:
	_point_samples.append({"kind":kind,"position":[pos.x,pos.y],"expected_hit":expected,"actual_hit":hit})
	_check(hit==expected,"%s at %s expected=%s hit=%s" % [kind,pos,expected,hit])

func _test_damage_points() -> void:
	_begin("actual damage sampling: mouth / bind / firewall / 64-grid")
	_heal()
	_player.set_block_signals(true)
	var wolf = _boss("fenrir",Vector2(1000,1000))
	for angle in [0.0,PI/4,PI/2,PI*0.75,PI,PI*1.25,PI*1.5,PI*1.75]:
		wolf.maw_hinge = Vector2(300,-300)
		wolf.maw_axis = Vector2.from_angle(angle)
		wolf.maw_gap = VigridTuning.MAW_GAP
		var basis: Transform2D = wolf.maw_basis(wolf.maw_hinge,wolf.maw_axis)
		for x in [39.5,40.5,120.0,199.5,200.5]:
			for y in [-56.5,-55.5,0.0,55.5,56.5]:
				_heal()
				_player.position = basis * Vector2(x,y)
				wolf._committed = false
				wolf._commit_swallow()
				_sample("maw",_player.position,x>40 and x<200 and absf(y)<56,_player.hp < _player.max_hp)
	# Test the actual ribbon quads against the protected rectangle, including the 8-pixel width.
	var protected_poly := PackedVector2Array([wolf.BIND_PROTECT.position,Vector2(wolf.BIND_PROTECT.end.x,wolf.BIND_PROTECT.position.y),wolf.BIND_PROTECT.end,Vector2(wolf.BIND_PROTECT.position.x,wolf.BIND_PROTECT.end.y)])
	for i in 72:
		var a0 := TAU*i/72.0
		var a1 := TAU*(i+1)/72.0
		var p0: Vector2 = Vector2(cos(a0),sin(a0))*wolf.BIND_RADII
		var p1: Vector2 = Vector2(cos(a1),sin(a1))*wolf.BIND_RADII
		var n0: Vector2 = Vector2(cos(a0),sin(a0))*wolf.BIND_WIDTH*0.5
		var n1: Vector2 = Vector2(cos(a1),sin(a1))*wolf.BIND_WIDTH*0.5
		_check(Geometry2D.intersect_polygons(protected_poly,PackedVector2Array([p0-n0,p1-n1,p1+n1,p0+n0])).is_empty(),"actual bind quad clear of protected region %d" % i)
	wolf.free()
	_clear_enemies()
	_heal()
	var fire = _boss("surtr",Vector2(1400,1400))
	fire.firewall_center = Vector2(-128,64)
	fire.firewall_age = 100.0
	fire.firewall_radius = VigridTuning.FIREWALL_MIN
	for i in 72:
		for offset in [-1.0,-0.01,0.0,0.01,1.0]:
			_heal()
			_player.position=fire.firewall_center+Vector2.from_angle(TAU*i/72.0)*(440.0+offset)
			fire._tick_firewall(DT)
			_sample("firewall",_player.position,offset>0,_player.hp<_player.max_hp)
	_player.position=fire.firewall_center
	fire._plan_final()
	for cell: Vector2i in fire.final_area:
		for offset in [Vector2(0,0),Vector2(0.01,0.01),Vector2(32,32),Vector2(63.99,63.99)]:
			_heal()
			_player.position=Vector2(cell)*64.0+offset-Vector2(0,20)
			fire.final_stage="warn"
			fire.final_t=VigridTuning.FINAL_WARN-DT*0.5
			fire._tick_final(DT)
			_sample("final_cell",_player.position,fire.final_unsafe.has(cell),_player.hp<_player.max_hp)
			var hp: float = _player.hp
			_player._invincible_time=0
			fire._tick_final(DT)
			_check(_player.hp==hp,"final-cell damage once per cycle %s/%s" % [cell,offset])
	fire.free()
	_player.set_block_signals(false)
	_heal()
	_player.position=Vector2.ZERO
	_pass()

func _case(id: String, ok: bool) -> void:
	_case_results[id]="passed" if ok else "failed"
	_check(ok,"K7 "+id)

func _test_real_pause() -> void:
	_begin("real sixty-second pause / fate deadlines")
	await _new_game()
	_player.add_god("thor")
	var snake = _boss("jormungandr")
	snake.encounter_age=89.0
	_game.elapsed=269.0
	_game.process_mode=Node.PROCESS_MODE_INHERIT
	paused=true
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 60000:
		await create_timer(0.25,true,false,true).timeout
	var wall := (Time.get_ticks_msec()-start)/1000.0
	var frozen: bool = snake.encounter_age==89.0 and _game.elapsed==269.0 and wall>=59.9
	print("PAUSE_MEASURE wall=",wall," encounter=",snake.encounter_age," level=",_game.elapsed)
	_game.process_mode=Node.PROCESS_MODE_DISABLED
	paused=false
	snake.take_damage(snake.max_hp*3)
	_case("paused60seconds",frozen and _game.fates.thor_saved)
	for entry in [["thor_at90",true,90.0,true],["thor_after90",true,90.001,false],["no_thor_faith",false,40.0,false]]:
		await _new_game()
		if entry[1]: _player.add_god("thor")
		snake=_boss("jormungandr")
		snake.encounter_age=entry[2]
		snake.take_damage(snake.max_hp*3)
		_case(entry[0],_game.fates.thor_saved==entry[3])
	await _new_game()
	_awaken("freyr")
	var fire=_boss("surtr")
	_game.battle._tick_freyr(DT)
	_case("freyr_faith_not_freyja",not _game.fates.freyr_assisted and not _game.battle.freyr_active)
	fire.free()
	_pass()

func _test_ending_workflow() -> void:
	_begin("K7 28-case actual ending workflow")
	var spec = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/taskK7_fate_ending_2026-10-20/acceptance_cases.json"))
	var save = root.get_node("Save")
	for c in spec.cases:
		if not c.has("input"): continue
		await _new_game()
		for id in ["thor_saved","vidar_intervened","freyr_assisted"]:
			if c.input[id]: _game.confirm_fate(id)
		if c.input.ever_faith_loki:
			_player.add_god("loki")
			_clear_gods()
		var runs: int = save.stats.runs
		_game._on_level_cleared()
		var snapshot: Dictionary = _game._run_result.duplicate(true)
		var points: int = save.reward_points
		var good: bool = snapshot.fate_count==c.expected_fate_count and snapshot.ever_faith_loki==c.expected_loki_hint and paused
		for i in 5:
			good = good and _game.hud.ending_index()==i
			_game.hud.advance_ending()
		for i in 20:
			_game.hud.advance_ending()
			_game.hud.skip_ending()
			_game._on_level_cleared()
			_game._on_player_died()
			_game._on_abandon_requested()
		var hint = _game.hud.find_child("LokiHint",true,false)
		good = good and (hint!=null)==c.expected_loki_hint and _game._run_result==snapshot and save.stats.runs==runs+1 and save.reward_points==points
		save.load_game()
		good = good and save.stats.runs==runs+1 and save.reward_points==points and save.cleared_levels.has("vigrid")
		_case(c.id,good)
	await _new_game()
	_player.add_god("loki")
	_clear_gods()
	_game._on_level_cleared()
	_game.hud.skip_ending()
	_case("loki_lost_current_faith",_game._run_result.ever_faith_loki and _game.hud.find_child("LokiHint",true,false)!=null)
	await _new_game()
	_case("new_run_reset",_game.fate_count()==0 and not _game.ever_faith_loki)
	for beat in 5:
		await _new_game()
		_player.add_god("loki")
		_game.confirm_fate("thor_saved")
		var runs: int = save.stats.runs
		_game._on_level_cleared()
		var frozen: Dictionary = _game._run_result.duplicate(true)
		var points: int = save.reward_points
		for i in beat: _game.hud.advance_ending()
		var reached: bool = _game.hud.ending_index()==beat
		for i in 50:
			_game.hud.skip_ending()
			_game.hud.advance_ending()
			_game._on_level_cleared()
		_case("skip_at_%d"%beat,reached and _game._run_result==frozen and save.stats.runs==runs+1 and save.reward_points==points and _game.hud.ending_index()==-1)
	_pass()

func _test_return_retry() -> void:
	_begin("result return and restart")
	await _new_game()
	_game.process_mode=Node.PROCESS_MODE_INHERIT
	_game._on_level_cleared()
	_game.hud.skip_ending()
	var save = root.get_node("Save")
	var runs: int = save.stats.runs
	_game.hud._on_hub_pressed()
	await process_frame
	await process_frame
	_check(current_scene.scene_file_path=="res://scenes/hub.tscn" and not paused,"return button loads real hub scene and resumes tree")
	_check(get_nodes_in_group("enemies").is_empty(),"hub return clears enemy nodes")
	current_scene.queue_free()
	await process_frame
	_game=load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	current_scene=_game
	await process_frame
	_game.confirm_fate("thor_saved")
	_game.ever_faith_loki=true
	_game._on_level_cleared()
	_game.hud.skip_ending()
	_game.hud._on_restart_pressed()
	await process_frame
	await process_frame
	_game=current_scene
	_player=_game.player
	_check(current_scene.scene_file_path=="res://scenes/main.tscn" and _game.is_running(),"restart button reloads real game scene")
	_check(_game.fate_count()==0 and not _game.ever_faith_loki,"restart resets fate and Loki flags")
	_check(save.stats.runs==runs+1,"return/restart do not settle old result again")
	_pass()


func _test_grid_firewall_overlap() -> void:
	_begin("safe-grid plus shrinking firewall combined damage")
	await _new_game()
	_heal()
	_player.set_block_signals(true)
	var fire = _boss("surtr",Vector2(400,0))
	fire.firewall_center=Vector2(-128,64)
	for cycle in 24:
		fire.final_cycles=cycle
		fire.firewall_age=float(cycle)*1.5
		fire.firewall_radius=fire.firewall_radius_at(fire.firewall_age)
		_player.position=fire.firewall_center+Vector2(fire.firewall_radius-80,0)
		fire._plan_final()
		var initial_age: float = fire.firewall_age
		for cell: Vector2i in fire.final_safe:
			for offset in [Vector2(0.01,0.01),Vector2(63.99,0.01),Vector2(63.99,63.99),Vector2(0.01,63.99)]:
				_heal()
				_player.position=Vector2(cell)*64.0+offset-Vector2(0,20)
				fire.firewall_age=initial_age+VigridTuning.FINAL_WARN+VigridTuning.FINAL_BURN
				fire._tick_firewall(DT)
				_sample("safe_grid_combined",_player.position,false,_player.hp<_player.max_hp)
	fire.free()
	_player.set_block_signals(false)
	_heal()
	_pass()


func _test_fragment_replenishment() -> void:
	_begin("consumed fragment replenishment after deferred free")
	await _new_game()
	var wolf=_boss("fenrir",Vector2(400,0))
	await process_frame
	for cycle in 3:
		var fragment=get_nodes_in_group("gleipnir_fragments")[0]
		_player.position=fragment.position
		fragment._physics_process(DT)
		await process_frame
		_check(not is_instance_valid(fragment),"consumed fragment freed before replenishment %d"%cycle)
		wolf._fragment_timer=VigridTuning.FRAGMENT_EVERY
		wolf._update_state(DT)
		await process_frame
		_check(wolf.fragments.all(func(f):return is_instance_valid(f)) and wolf.fragments.size()==2,"replenishment safely prunes freed references and restores cap %d"%cycle)
	wolf.free()
	_clear_enemies()
	_pass()


func _test_pickup_merge() -> void:
	_begin("XP merge conservation and cleanup")
	await _new_game()
	var gem_script=load("res://scripts/entities/xp_gem.gd")
	var before: float=_player.xp
	var total:=0
	for i in 1000:
		var gem=gem_script.new()
		gem.position=Vector2(512+ i%16,512+i%16)
		gem.player=_player
		gem.value=1+i%5
		gem.big=i==999
		total+=gem.value
		_game.add_child(gem)
	await process_frame
	var gems=_game.get_children().filter(func(n):return n.get_script()==gem_script)
	_check(gems.size()==1 and gems[0].value==total and gems[0].big,"1000 nearby drops merge without losing XP or elite indicator")
	_check(_player.xp==before,"merging does not grant XP remotely")
	var original=gems[0]
	_player.position=original.position
	original._attracted=true
	original._unindex()
	var next=gem_script.new()
	next.player=_player
	next.position=original.position
	_game.add_child(next)
	_check(not next._merged and original.value==total,"flying gem does not absorb another drop")
	await _new_game()
	_check(gem_script._loose.is_empty(),"scene exit clears loose XP index")
	_pass()


func _test_all_aid() -> void:
	_begin("all eight actual periodic aid implementations")
	for god in ["thor","odin","loki","freyja","baldr","ran","freyr","skadi"]:
		await _new_game()
		_player.add_god(god)
		for i in 10:
			var enemy=_game.spawn_enemy("dead",Vector2(100+i*5,0))
			enemy.hp=10000
			enemy.max_hp=10000
		var battle=_game.battle
		_check(battle.nearby_combat(),god+" nearby combat condition")
		battle._aid_timer=VigridTuning.AID_EVERY-DT*0.5
		battle._tick_aid(DT)
		await process_frame
		for node in _game.get_children():
			if node.get_script() and node.get_script().resource_path.ends_with("god_zone.gd"): node._process(DT)
		_check(battle.events.size()==1 and battle.events[0].god_id==god,god+" periodic aid actually recorded once")
		_check(battle.request_aid("missing").is_empty(),god+" absent faith cannot request aid")
		battle._tick_aid(DT)
		_check(battle.events.size()==1,god+" cooldown prevents duplicate aid")
		if god=="odin":
			_check(_game.get_children().any(func(n):return n.get_script() and n.get_script().resource_path.ends_with("einherjar.gd")),"Odin aid actually summons ally")
		else:
			_check(get_nodes_in_group("enemies").any(func(e):return e.hp<e.max_hp),god+" aid actually deals damage")
	_pass()


func _test_walk_edges() -> void:
	_begin("actual player walking against edges and retreat")
	_player.process_mode=Node.PROCESS_MODE_ALWAYS
	await physics_frame
	for start in [Vector2(-2290,0),Vector2(2290,0),Vector2(0,-2290),Vector2(0,2290),Vector2(-2290,-2290),Vector2(2290,-2290),Vector2(2290,2290),Vector2(-2290,2290)]:
		_player.position=start
		_player._dash_t=-1.0
		_player._shove=Vector2.ZERO
		for phase in [1,-1]:
			for pair in [["ui_left",start.x*phase<0],["ui_right",start.x*phase>0],["ui_up",start.y*phase<0],["ui_down",start.y*phase>0]]:
				if pair[1]: Input.action_press(pair[0])
				else: Input.action_release(pair[0])
			var before: Vector2=_player.position
			for i in 60 if phase==1 else 10:
				await physics_frame
				_check(_game.bounds.grow(-13.9).has_point(_player.position),"walking never crosses boundary %s/%d/%d"%[start,phase,i])
			if phase==-1: _check(_player.position.distance_to(before)>20,"can walk back from boundary %s"%start)
	for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)
	_player.position=Vector2.ZERO
	_player.process_mode=Node.PROCESS_MODE_INHERIT
	_pass()

func _test_pause_resume_all() -> void:
	_begin("real pause menu freezes all three Bosses and resumes")
	for id in ["jormungandr","fenrir","surtr"]:
		await _new_game()
		_player.immune_time=1.0e9
		_game._next_boss=3
		_game._spawn_timer=1.0e9
		var actor=_boss(id)
		_game.process_mode=Node.PROCESS_MODE_INHERIT
		await create_timer(0.2).timeout
		_game.pause_menu.open()
		var snapshot: Array=[_game.elapsed,actor.state_time,actor.position]
		if id=="surtr": snapshot.append(actor.firewall_age)
		await create_timer(0.35).timeout
		_check(paused and _game.elapsed==snapshot[0] and actor.state_time==snapshot[1] and actor.position==snapshot[2],id+" actual pause freezes level/state/motion")
		if id=="surtr": _check(actor.firewall_age==snapshot[3],"pause freezes firewall shrink")
		_game.pause_menu.close()
		await create_timer(0.2).timeout
		_check(not paused and _game.elapsed>snapshot[0],id+" resume continues same run")
		_game.process_mode=Node.PROCESS_MODE_DISABLED
	_pass()
