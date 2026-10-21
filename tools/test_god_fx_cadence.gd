extends "res://tools/test_vigrid.gd"

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
	_begin("daylight fire/rest cadence and no hidden damage")
	var phases:=[]
	for cooldown in [1.0,0.1]:
		await _new_game()
		_player.cooldown_mult=cooldown
		_player.god_cooldown_mult=1.0
		_player.damage_mult=1.0
		_player.immune_time=1.0e9
		var power=load("res://scripts/gods/baldr.gd").new()
		_player.add_child(power)
		_player.gods.baldr=power
		power.path="baldr_daylight"
		power.stats={"baldr_prism":3,"baldr_afterglow":3.0}
		var target=_game.spawn_enemy("dead",Vector2.ZERO)
		target.hp=100000
		target.max_hp=100000
		target.crit_chance=0
		var was_active:=true
		var transitions:=[]
		var active_damage:=0.0
		var hidden_frames:=0
		for frame in 900:
			var before: float=target.hp
			var angle: float=power._pillar_angle
			power._process(DT)
			for glow in power._pillar_glows:
				if is_instance_valid(glow) and not glow.is_queued_for_deletion(): glow._process(DT)
			if not power._pillars_active:
				hidden_frames+=1
				_check(target.hp==before,"hidden cooldown causes no pillar or trail damage")
				_check(not is_equal_approx(angle,power._pillar_angle),"rotation continues while hidden")
				_check(power._pillar_glows.is_empty(),"cooldown clears owned laser trails")
			else: active_damage+=before-target.hp
			if was_active!=power._pillars_active:
				transitions.append({"time":(frame+1)*DT,"active":power._pillars_active})
			was_active=power._pillars_active
		_check(active_damage>0.0 and hidden_frames>0,"burst deals damage and has a real rest")
		var rest: float=maxf(1.5,4.0*cooldown)
		for i in transitions.size():
			var expected: float=3.0+(i/2)*(3.0+rest)+(rest if i%2 else 0.0)
			_check(absf(transitions[i].time-expected)<=DT*1.1,"transition matches three-second burst and capped cooldown")
		phases.append({"cooldown_mult":cooldown,"transitions":transitions,"active_damage":active_damage,"hidden_frames":hidden_frames})
	_pass()
	_begin("compact rune rings and snow art leave gameplay damage intact")
	await _new_game()
	var power=load("res://scripts/gods/odin.gd").new()
	_player.add_child(power)
	_player.gods.odin=power
	power.path="odin_nights"
	power.stats={"odin_resonance":300.0}
	var source=_game.spawn_enemy("dead",Vector2.ZERO)
	source.hp=100000
	var far=_game.spawn_enemy("dead",Vector2(250,0))
	far.hp=100000
	var before: float=far.hp
	for i in 60: power.detonate(source)
	_check(far.hp<before,"resonance still damages target 250 pixels away")
	var fx=load("res://scripts/effects/fx_layer.gd").instance
	_check(fx._rings.size()==24,"visible impact rings bounded at 24")
	_check(fx._rings.all(func(r):return r.radius<=48.0 and r.opacity==0.45),"white rune rings use compact radius and lower alpha")
	var winter=load("res://scripts/gods/skadi.gd").new()
	_player.add_child(winter)
	winter.awakened=true
	_check(winter.blizzard_radius()==700.0 and winter.BLIZZARD_VISUAL_RADIUS==128.0,"winter decorative diameter capped at 256 while gameplay radius remains 700")
	_pass()
	_begin("real pause freezes laser phase and hidden angle")
	await _new_game()
	_player.add_god("baldr")
	var laser=_player.gods.baldr
	laser.path="baldr_daylight"
	laser._pillars_active=false
	laser._pillar_remaining=2.0
	_game._spawn_timer=1.0e9
	_game._next_boss=3
	_game.process_mode=Node.PROCESS_MODE_INHERIT
	_game.pause_menu.open()
	var state: Array=[laser._pillar_angle,laser._pillar_remaining]
	await create_timer(0.25).timeout
	_check(paused and [laser._pillar_angle,laser._pillar_remaining]==state,"pause freezes cooldown and rotation")
	_game.pause_menu.close()
	await create_timer(0.1).timeout
	_check(not paused and laser._pillar_remaining<state[1],"resume continues same cooldown")
	_pass()
	await _test_cleanup()
	DirAccess.make_dir_recursive_absolute(_output)
	var file=FileAccess.open(_output.path_join("cadence.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":_checks,"failures":_failures,"log":_log,"phases":phases},"\t"))
	file.close()
	print("GOD_FX_CADENCE_RESULT ",_checks," checks ",_failures," failures")
	OS.delay_msec(200)
	quit(1 if _failures else 0)
