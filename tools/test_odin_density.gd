extends "res://tools/test_vigrid.gd"

var records := []

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output=arg.trim_prefix("--output=")
	var save=root.get_node("Save")
	if save.path==save.DEFAULT_PATH or _output.is_empty():
		quit(2)
		return
	_boss_db=load("res://scripts/data/boss_db.gd")
	save.reset()
	save.cleared_levels.assign(["midgard","helheim"])
	save.selected_level="vigrid"
	AudioServer.set_bus_mute(0,true)
	_begin("Odin overlapping-night damage and rune equivalence")
	var before=await _measure("before")
	var after=await _measure("after")
	_check(before.snapshots==after.snapshots,"damage, rune stacks and membership match before optimization through moves and deaths")
	_check(after.microseconds<before.microseconds,"overlapping-night cache reduces measured work")
	_pass()
	await _test_cadence()
	await _test_cleanup()
	DirAccess.make_dir_recursive_absolute(_output)
	var file=FileAccess.open(_output.path_join("odin.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":_checks,"failures":_failures,"log":_log,"records":records},"\t"))
	file.close()
	print("ODIN_DENSITY_RESULT ",_checks," checks ",_failures," failures")
	OS.delay_msec(200)
	quit(1 if _failures else 0)

func _measure(version: String) -> Dictionary:
	await _new_game()
	var source: String="res://assets/source/taskK_independent_qa_2026-10-20/before/odin_dedup_reference.gd" if version=="before" else "res://scripts/gods/odin.gd"
	var power=load(source).new()
	_player.add_child(power)
	_player.gods.odin=power
	_player.faith.odin=12
	power.god_id="odin"
	power.path="odin_nights"
	power.awakened=true
	var enemies:=[]
	for i in 120:
		var e=_game.spawn_enemy("dead",Vector2(i%12-6,i/12-5)*18.0)
		e.hp=100000
		e.max_hp=100000
		enemies.append(e)
	var gp=load("res://scripts/gods/god_power.gd")
	for i in 24:
		var zone=power.zone(Vector2(i%6-3,i/6-2)*24.0,100.0,100.0,1.0,Callable(),Color.WHITE)
		power._circles.append(zone)
	await process_frame
	var time:=0
	var snapshots:=[]
	for round_index in 3:
		if round_index==1:
			enemies[0].position=Vector2(900,900)
			enemies[1].position+=Vector2(20,0)
		if round_index==2:
			_game.despawn_enemy(enemies[2])
		var start:=Time.get_ticks_usec()
		for i in 48: power.detonate(enemies[10+i%24])
		time+=Time.get_ticks_usec()-start
		var state:=[]
		for e in enemies:
			state.append([e.hp,e.stack_count("rune")])
		snapshots.append(state)
	var result:={"version":version,"microseconds":time,"snapshots":snapshots}
	records.append(result)
	print("ODIN_MEASURE ",version," ",time,"us")
	return result

func _test_cadence() -> void:
	_begin("one-second shared circle damage and awakening spread limits")
	for awake in [false,true]:
		var snapshots:=[]
		for count in [1,24]:
			await _new_game()
			var power=load("res://scripts/gods/odin.gd").new()
			_player.add_child(power)
			_player.gods.odin=power
			power.god_id="odin"
			power.path="odin_nights"
			power.awakened=awake
			var target=_game.spawn_enemy("dead",Vector2(100,0))
			target.hp=10000
			target.max_hp=10000
			target.crit_chance=0
			for i in count: power._rune_circle(target.position,false)
			var states:=[]
			for time in [0.0,0.999,1.0,1.999,2.0]:
				power._time=time
				for circle in power._circles: circle.on_tick.call(target)
				states.append([target.hp,target.stack_count("rune")])
			_check(is_equal_approx(10000.0-target.hp,36.0),"three circle ticks plus one detonation over 2 seconds: count=%d awake=%s"%[count,awake])
			snapshots.append(states)
		_check(snapshots[0]==snapshots[1],"24 overlapping circles equal one circle, including sub-second repeats, awake=%s"%awake)
	await _new_game()
	var power=load("res://scripts/gods/odin.gd").new()
	_player.add_child(power)
	_player.gods.odin=power
	power.path="odin_nights"
	power.awakened=true
	var source=_game.spawn_enemy("dead",Vector2(500,500))
	source.hp=100000
	var target=_game.spawn_enemy("dead",Vector2(100,0))
	for i in 24: power._rune_circle(target.position,false)
	for time in [0.0,0.999,1.0,1.999,2.0]:
		power._time=time
		for i in 48: power.detonate(source)
		_check(target.stack_count("rune")==int(floor(time))+1,"propagation capped across 48 detonations and 24 circles at t=%.3f"%time)
	var stacks=target.stack_count("rune")
	power.add_rune(target,1)
	_check(target.stack_count("rune")!=stacks,"direct missile rune grant remains independent of circle cadence")
	for i in 600: power._night_hit_at[i]=-10.0
	power._time=10.0
	power._timer=1.0e9
	power.tick(0.0)
	_check(power._night_hit_at.is_empty(),"stale cadence history pruned")
	_pass()
