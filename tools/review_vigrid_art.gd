extends "res://tools/acceptance_vigrid_visual.gd"

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _out=arg.trim_prefix("--output=")
	var save=root.get_node("Save")
	if save.path==save.DEFAULT_PATH or _out.is_empty() or DisplayServer.get_name()=="headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	save.reset()
	save.cleared_levels.assign(["midgard","helheim"])
	save.selected_level="vigrid"
	for size in [Vector2i(1280,720),Vector2i(960,540)]:
		await _resize(size)
		await _new_game()
		_quiet()
		await _shot("m_spawn_%d"%size.x,"production VigridMap new terrain, native camera")
		for i in 10:
			var enemy=_game.spawn_enemy("dead",Vector2(35,0)+Vector2.from_angle(TAU*i/10)*110)
			enemy.max_hp=1.0e6
			enemy.hp=enemy.max_hp
			enemy.process_mode=Node.PROCESS_MODE_DISABLED
		var fire=await _spawn_boss(2)
		fire.position=Vector2(240,0)
		fire._sweep_dir=Vector2.LEFT
		fire.change_state("sweep_windup")
		fire.state_time=.7
		fire.queue_redraw()
		_game.process_mode=Node.PROCESS_MODE_DISABLED
		var fx=load("res://scripts/effects/fx_layer.gd")
		var layer=fx.instance
		fire._sweep()
		for effect in layer._boss_effects:
			if effect.id=="surtr_sword_arc_large": effect.age=1.01/16.0
		layer.queue_redraw()
		await _shot("m_sword_peak_%d"%size.x,"actual Surtr._sweep dispatch; production BossFx; 640px frames scale1; real warning overlay")
		layer._boss_effects.clear()
		layer.queue_redraw()
		await _shot("m_danger_%d"%size.x,"production map with ten enemies, real Surtr telegraph and residual fire patches")
		for god in ["freyja","baldr","ran","skadi"]:
			for power in _player.gods.values(): power.free()
			_player.gods.clear()
			_player.faith.clear()
			_player.add_god(god)
			_player.gods[god].process_mode=Node.PROCESS_MODE_DISABLED
			_player.gods[god].visible=false
			layer._aid_effects.clear()
			layer._rings.clear()
			layer._particles.clear()
			_game.battle._aid_timer=0.0
			_game.battle._aid_index=0
			_game.battle._tick_aid(load("res://scripts/data/vigrid_tuning.gd").AID_EVERY)
			if layer._aid_effects.size()!=1:
				push_error("production periodic aid did not emit: "+god)
				quit(1)
				return
			var event: Dictionary=_game.battle.events.back()
			for frame in [1,4,7]:
				layer._aid_effects[0].age=(float(frame)+.01)/12.0
				layer.queue_redraw()
				await _shot("m_aid_%s_f%d_%d"%[god,frame+1,size.x],"production periodic dispatch and FxLayer draw; selected age; center="+str(event.world_position))
	var file=FileAccess.open(_out.path_join("captures.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"actual production Game, map, Surtr._sweep, VigridBattle._tick_aid and FxLayer; selected visual ages/controlled enemies, no preview renderer","captures":_shots},"\t"))
	file.close()
	_game.queue_free()
	await process_frame
	var audio_script=load("res://scripts/core/audio.gd")
	var audio=audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream=null
		audio._streams.clear()
		audio.free()
		audio_script._instance=null
	load("res://scripts/world/vigrid_map.gd").fire_material=null
	await process_frame
	print("M_VISUAL_DONE ",_shots.size()," captures")
	quit()

func _quiet() -> void:
	AudioServer.set_bus_mute(0,true)
	for weapon in [_player.katana,_player.revolver,_player.blades,_player.nova]:
		if weapon: weapon.process_mode=Node.PROCESS_MODE_DISABLED
	for power in _player.gods.values(): power.free()
	_player.gods.clear()
	_player.faith.clear()
	_player.immune_time=1.0e9
	var layer=load("res://scripts/effects/fx_layer.gd").instance
	for field in ["_aid_effects","_boss_effects","_numbers","_particles","_marks","_rings"]:
		layer.get(field).clear()

func _shot(name: String, note: String) -> void:
	_game.pause_menu.close()
	await super._shot(name,note)
