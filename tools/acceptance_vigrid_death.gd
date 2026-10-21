extends "res://tools/acceptance_vigrid_visual.gd"

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _out=arg.trim_prefix("--output=")
	var save=root.get_node("Save")
	if save.path==save.DEFAULT_PATH or _out.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	save.reset()
	save.cleared_levels.assign(["midgard","helheim"])
	save.selected_level="vigrid"
	await _resize(Vector2i(1280,720))
	await _new_game()
	for power in _player.gods.values(): power.free()
	_player.gods.clear()
	_player.faith.clear()
	var wolf=await _spawn_boss(1)
	_game.process_mode=Node.PROCESS_MODE_DISABLED
	_player.revives=1
	var checks:=[]
	for attempt in 2:
		_player.immune_time=0.0
		_player._invincible_time=0.0
		_player.shield_time=0.0
		_player._dash_time=0.0
		_player.dodge_chance=0.0
		_player.ward=0
		wolf.maw_hinge=Vector2.ZERO
		wolf.maw_axis=Vector2.RIGHT
		wolf.maw_gap=load("res://scripts/data/vigrid_tuning.gd").MAW_GAP
		var polygon=wolf.fatal_polygon(wolf.maw_hinge,wolf.maw_axis,wolf.maw_gap)
		_teleport((polygon[0]+polygon[2])*0.5)
		wolf._committed=false
		wolf._commit_swallow()
		if attempt==0:
			checks.append({"name":"real swallow consumes one revive and restores half HP","pass":not _player.is_dead and _player.revives==0 and _player.hp==_player.max_hp*0.5 and _game.is_running()})
			await _shot("swallow_revived","Actual fatal swallow through Player.take_damage and Game revive callback; invincibility explicitly disabled before hit")
		else:
			checks.append({"name":"real swallow without revive begins death","pass":_player.is_dead and not _game.is_running()})
			await create_timer(_player.death_duration()+0.6).timeout
			await _shot("swallow_death_result","Actual fatal swallow with zero revives, death animation and result; no synthetic died signal")
			var runs: int=save.stats.runs
			for i in 20: _game._on_player_died()
			checks.append({"name":"death settles exactly once despite repeated callbacks","pass":runs==1 and save.stats.runs==runs and not save.cleared_levels.has("vigrid")})
	var failures=checks.filter(func(c):return not c.pass).size()
	var file=FileAccess.open(_out.path_join("death.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"controlled real-renderer normal damage, no invincibility for fatal hits, Master muted","checks":checks,"captures":_shots,"failures":failures},"\t"))
	file.close()
	_game.queue_free()
	await process_frame
	print("DEATH_RESULT ",checks.size()," checks ",failures," failures")
	quit(1 if failures else 0)
