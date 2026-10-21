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
	await _new_game()
	_begin("separation vector equivalence including coincident actors")
	seed(20261020)
	for i in 350:
		var enemy=_game.spawn_enemy("dead",Vector2.ZERO if i<2 else Vector2(randf_range(-250,250),randf_range(-250,250)))
		enemy.mass=randf_range(0.5,10.0)
	var source=load("res://scripts/entities/enemy.gd")
	source.rebuild_grid(self)
	for enemy in get_nodes_in_group("enemies"):
		seed(enemy.get_instance_id())
		var before=_separation_reference(enemy)
		seed(enemy.get_instance_id())
		_check(before.distance_to(enemy._separation())<0.0001,"separation vector remains equivalent")
	_pass()
	await _test_cleanup()
	DirAccess.make_dir_recursive_absolute(_output)
	var file=FileAccess.open(_output.path_join("buffers.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":_checks,"failures":_failures,"log":_log},"\t"))
	file.close()
	print("DENSITY_BUFFERS_RESULT ",_checks," checks ",_failures," failures")
	OS.delay_msec(200)
	quit(1 if _failures else 0)

func _separation_reference(enemy) -> Vector2:
	var push:=Vector2.ZERO
	var source=load("res://scripts/entities/enemy.gd")
	var cell:=Vector2i((enemy.global_position/source.GRID_CELL).floor())
	for x in range(cell.x-1,cell.x+2):
		for y in range(cell.y-1,cell.y+2):
			for other in source._grid.get(Vector2i(x,y),[]):
				if other==enemy:continue
				var offset: Vector2=enemy.global_position-other.global_position
				var overlap: float=enemy.radius+other.radius-offset.length()
				if overlap<=0.0:continue
				if offset==Vector2.ZERO:offset=Vector2.from_angle(randf()*TAU)
				push+=offset.normalized()*overlap*other.mass/(enemy.mass+other.mass)
	return push*0.5
