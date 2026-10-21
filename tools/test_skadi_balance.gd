extends "res://tools/test_vigrid.gd"

var measurements := []

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output=arg.trim_prefix("--output=")
	var save=root.get_node("Save")
	if save.path==save.DEFAULT_PATH or _output.is_empty():
		quit(2)
		return
	_boss_db=load("res://scripts/data/boss_db.gd")
	AudioServer.set_bus_mute(0,true)
	save.reset()
	save.cleared_levels.assign(["midgard","helheim"])
	save.selected_level="vigrid"
	_begin("winter damage/frost/ice stacking before vs after")
	for version in ["before","after"]:
		for cooldown in [1.0,0.1]:
			for icefield in [0.0,9.0]:
				await _measure(version,cooldown,icefield)
	for row in measurements.filter(func(r):return r.version=="after"):
		var old=measurements.filter(func(r):return r.version=="before" and r.cooldown==row.cooldown and r.icefield==row.icefield)[0]
		_check(row.damage<=old.damage*0.5,"winter damage reduced at cooldown %.1f ice %.1f"%[row.cooldown,row.icefield])
		_check(row.dps<=5.5,"winter base-DPS cap: %.2f"%row.dps)
		if row.icefield>0:
			_check(row.max_ice_patches==1,"stationary ice refreshes one zone, does not stack: %d"%row.max_ice_patches)
	_check(measurements.all(func(r):return r.awakened_radius==700.0),"full-screen awakened radius preserved")
	_pass()
	DirAccess.make_dir_recursive_absolute(_output)
	var f=FileAccess.open(_output.path_join("balance.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope":"controlled 12-second actual damage simulations; enemy has 10000 HP, no criticals, max chill, unchanged global multiplier; before script retained verbatim", "checks":_checks,"failures":_failures,"log":_log,"measurements":measurements},"\t"))
	f.close()
	await _test_cleanup()
	print("SKADI_BALANCE_RESULT ",_checks," checks ",_failures," failures")
	OS.delay_msec(200)
	quit(1 if _failures else 0)

func _measure(version: String, cd: float, icefield: float) -> void:
	await _new_game()
	var player=_player
	player.immune_time=1.0e9
	player.god_cooldown_mult=cd
	var file: String="res://assets/source/taskK_independent_qa_2026-10-20/before/skadi.gd" if version=="before" else "res://scripts/gods/skadi.gd"
	var power=load(file).new()
	power.god_id="skadi"
	player.add_child(power)
	player.gods.skadi=power
	player.faith.skadi=12
	power.path="skadi_winter"
	power.awakened=true
	power.stats={"skadi_chill":4.0,"skadi_volley":6.0,"skadi_icefield":icefield}
	var enemy=_game.spawn_enemy("dead",Vector2(10,0))
	enemy.speed=0
	enemy.hp=10000
	enemy.max_hp=10000
	var frozen:=0
	var patches:=0
	for i in 720:
		power._process(DT)
		enemy._physics_process(DT)
		if enemy.is_frozen(): frozen+=1
		await process_frame
		var zones=_game.get_children().filter(func(n):return n.get_script() and n.get_script().resource_path.ends_with("god_zone.gd") and not n.is_queued_for_deletion())
		patches=maxi(patches,zones.size())
		for zone in zones: zone._process(DT)
	var row={"version":version,"cooldown":cd,"icefield":icefield,"damage":10000-enemy.hp,"dps":(10000-enemy.hp)/12.0,"frozen_frame_fraction":frozen/720.0,"max_ice_patches":patches,"awakened_radius":power.blizzard_radius()}
	measurements.append(row)
	print("MEASURE ",JSON.stringify(row))
