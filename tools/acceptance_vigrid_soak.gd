extends "res://tools/stress_vigrid.gd"

const LOADOUTS := [
	{"thor":"thor_static","odin":"odin_nights","loki":"loki_road","freyja":"freyja_hawk"},
	{"baldr":"baldr_daylight","ran":"ran_drowned","freyr":"freyr_field","skadi":"skadi_winter"},
]
var _stage := 0
var _issues: Array[String] = []
var _wall_start := 0
var _indices := [-1,0,1,2]
var _reentries := 12
var _plain := false
var _mortal := false
var _all_awake := false
var _awake := ""
var _profile_gods := false
var _cpu_only := false

func _run() -> void:
	_seconds=240.0
	for arg in OS.get_cmdline_user_args():
		if arg == "--plain": _plain=true
		if arg == "--cpu-only": _cpu_only=true
		if arg == "--profile-gods": _profile_gods=true
		if arg == "--mortal": _mortal=true
		if arg == "--all-awake": _all_awake=true
		if arg.begins_with("--awake="): _awake=arg.trim_prefix("--awake=")
		if arg.begins_with("--stages="): _indices=Array(arg.trim_prefix("--stages=").split(",")).map(func(v):return int(v))
		if arg.begins_with("--reentries="): _reentries=int(arg.trim_prefix("--reentries="))
		if arg.begins_with("--output="): _out=arg.trim_prefix("--output=")
		if arg.begins_with("--seconds="): _seconds=float(arg.trim_prefix("--seconds="))
	var save=root.get_node("Save")
	if save.path==save.DEFAULT_PATH or _out.is_empty() or (DisplayServer.get_name()=="headless" and not _cpu_only):
		push_error("Real renderer, isolated save and output required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0,true)
	save.reset()
	save.cleared_levels.assign(["midgard","helheim"])
	save.selected_level="vigrid"
	_wall_start=Time.get_ticks_msec()
	_report={"scope":"local real-renderer soak, invincible player, reachable four-god build (one awakened at faith12, three paths at faith6), regular enemies have 1000000 HP to maintain sustained spell load without unrealistic whole-army respawns every frame; mixed ordinary enemies refilled to configured cap; Boss HP maintained, Surtr phases forced; sound streams run under Master mute; not balance or natural-clear evidence", "all_awake":_all_awake,"awake_override":_awake,"seconds_per_stage":_seconds,"stages":[],"reentry":[],"machine":{"os":OS.get_name(),"cpu":OS.get_processor_name(),"cores":OS.get_processor_count(),"renderer":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info()},"violations":_issues}
	for index in _indices:
		_stage=index+1
		await _new_game()
		_report.stages.append(await _measure(index))
		_flush()
	for i in _reentries:
		_stage=i%4
		await _new_game()
		_fill()
		await _active_wait(3.0)
		_game._on_abandon_requested()
		_game.hud._on_hub_pressed()
		await process_frame
		await process_frame
		await _active_wait(0.3)
		var snapshot := _sample()
		snapshot["round"]=i
		snapshot["enemies_left"]=get_node_count_in_group("enemies")
		snapshot["hazards_left"]=get_node_count_in_group("vigrid_hazards")
		snapshot["fragments_left"]=get_node_count_in_group("gleipnir_fragments")
		if snapshot.enemies_left or snapshot.hazards_left or snapshot.fragments_left: _issues.append("scene residue after reentry %d"%i)
		_report.reentry.append(snapshot)
		current_scene.queue_free()
		await process_frame
		_flush()
	_report["wall_seconds"]=(Time.get_ticks_msec()-_wall_start)/1000.0
	_report["completed"]=true
	_report["violations"]=_issues
	_flush()
	print("SOAK_DONE ",JSON.stringify({"wall_seconds":_report.wall_seconds,"violations":_issues,"reentries":_report.reentry.size()}))
	_release()
	var audio_script=load("res://scripts/core/audio.gd")
	var audio=audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for voice in audio.get_children():
			if voice is AudioStreamPlayer:
				voice.stop()
				voice.stream=null
		audio._streams.clear()
		audio.free()
		audio_script._instance=null
	load("res://scripts/world/vigrid_map.gd").fire_material=null
	await process_frame
	quit(0 if _issues.is_empty() else 1)

func _new_game() -> void:
	_release()
	await super._new_game()
	_game._spawn_timer=1.0e9
	_game._next_elite_time=1.0e9
	if _plain: return
	var player=_game.player
	var db=load("res://scripts/data/upgrade_db.gd")
	var god_index:=0
	for god: String in LOADOUTS[_stage%2]:
		player.add_god(god)
		if _profile_gods and god=="odin":
			player.gods[god].set_script(load("res://assets/source/taskK_independent_qa_2026-10-20/diagnostics/odin_profile.gd"))
			player.gods[god].player=player
			player.gods[god].god_id=god
		var boons=db.UPGRADES.keys().filter(func(id): return db.UPGRADES[id].kind=="boon" and db.UPGRADES[id].god==god)
		var is_awake: bool=_all_awake or (god==_awake if not _awake.is_empty() else god_index==0)
		var boon_count:=11 if is_awake else 5
		for i in boon_count:
			var available=boons.filter(func(id): return db._is_available(id,player))
			if not available.is_empty(): db.apply({"id":available[i%available.size()],"rarity":3},player)
		player.gods[god].set_path(LOADOUTS[_stage%2][god])
		if is_awake: player.gods[god].awaken()
		player.faith[god]=12 if is_awake else 6
		god_index+=1
	_game.fates.thor_saved=true

func _process(_delta: float) -> bool:
	if is_instance_valid(_game) and _game.pause_menu._root.visible:
		_game.pause_menu.close()
	return false

func _release() -> void:
	for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)

func _active_wait(seconds: float) -> void:
	var start=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < seconds*1000.0:
		await process_frame
		if is_instance_valid(_game) and _game.level_up_panel.visible: _game.level_up_panel.choose(0)

func _sample() -> Dictionary:
	var classes := {}
	if is_instance_valid(_game):
		for node in _game.get_children():
			var id: String=node.get_script().resource_path.get_file() if node.get_script() else node.get_class()
			classes[id]=classes.get(id,0)+1
	var output := []
	OS.execute("/bin/ps",["-o","rss=","-p",str(OS.get_process_id())],output)
	var rss := float(str(output[0]).strip_edges())/1024.0 if not output.is_empty() else -1.0
	var audio=load("res://scripts/core/audio.gd")._shared()
	var active:=0
	var sounds:={}
	for voice in audio._voices:
		if voice.playing:
			active+=1
			var sound: String=voice.get_meta("sound","")
			sounds[sound]=sounds.get(sound,0)+1
	var max_same: int=sounds.values().max() if not sounds.is_empty() else 0
	return {"node_classes":classes,"rss_mb":rss,"static_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"enemies":get_node_count_in_group("enemies"),"hazards":get_node_count_in_group("vigrid_hazards"),"sfx_voices":active,"same_sound_max":max_same,"voice_pool":audio._voices.size(),"master_muted":AudioServer.is_bus_mute(0),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}

func _measure(index: int) -> Dictionary:
	var boss: Node2D=null
	if index>=0:
		_game._next_boss=index
		_game.elapsed=_game.level_data.bosses[index].time
		_game._update_bosses()
		_game._next_boss=3
		boss=_game.boss
		boss.max_hp=1.0e9
		boss.hp=boss.max_hp
	else: _game.elapsed=540.0
	var start:=Time.get_ticks_msec()
	var last:=Time.get_ticks_usec()
	var next_sample:=0.0
	var next_fill:=0.0
	var next_blast:=10.0
	var frames: Array[float]=[]
	var samples:=[]
	var states:={}
	var level_start: float=_game.elapsed
	var enemy_max:=0
	var voices_max:=0
	var same_max:=0
	var phases:={}
	while Time.get_ticks_msec()-start < _seconds*1000.0:
		await process_frame
		var now:=Time.get_ticks_usec()
		frames.append((now-last)/1000.0)
		last=now
		var t: float=(Time.get_ticks_msec()-start)/1000.0
		if _game.level_up_panel.visible: _game.level_up_panel.choose(0)
		var dir:=Vector2.from_angle(t*0.1).orthogonal()
		for item in [["ui_left",dir.x< -0.3],["ui_right",dir.x>0.3],["ui_up",dir.y< -0.3],["ui_down",dir.y>0.3]]:
			if item[1]: Input.action_press(item[0])
			else: Input.action_release(item[0])
		if is_instance_valid(boss):
			var ratio:=0.8
			if boss.type_id=="surtr":
				ratio=0.2 if t>_seconds*0.67 else (0.5 if t>_seconds*0.33 else 0.8)
				phases[boss.phase]=true
			elif boss.type_id=="jormungandr" and t>_seconds*0.5: ratio=0.49
			boss.hp=boss.max_hp*ratio
			states[boss.state]=true
		if t>=next_fill:
			next_fill+=1.0
			_fill()
			if not _mortal:
				for enemy in get_nodes_in_group("enemies"):
					if enemy == boss or enemy.has_meta("soak_hp"): continue
					enemy.set_meta("soak_hp",true)
					enemy.max_hp=1.0e6
					enemy.hp=enemy.max_hp
		if t>=next_blast:
			next_blast+=10.0
			var giants=get_nodes_in_group("enemies").filter(func(e):return e.type_id=="fire_giant")
			for giant in giants.slice(0,3): giant.take_damage(giant.max_hp*2.0)
		var count:=get_node_count_in_group("enemies")
		enemy_max=maxi(enemy_max,count)
		if count>350 and not _issues.has("enemy cap exceeded"): _issues.append("enemy cap exceeded")
		if t>=next_sample:
			next_sample+=5.0
			var sample:=_sample()
			sample["t"]=t
			sample["level_time"]=_game.elapsed
			sample["boss_state"]=boss.state if is_instance_valid(boss) else "none"
			sample["god_build"]=LOADOUTS[_stage%2]
			voices_max=maxi(voices_max,sample.sfx_voices)
			same_max=maxi(same_max,sample.same_sound_max)
			if not sample.master_muted or sample.sfx_voices>24 or sample.same_sound_max>4: _issues.append("audio bound/mute violated at %.1f"%t)
			samples.append(sample)
			if int(t)%30<5: print("SOAK_SAMPLE stage=",index," ",JSON.stringify(sample))
		if not _cpu_only and int(t) in [10,int(_seconds*0.5),int(_seconds)-2] and not states.has("shot_"+str(int(t))):
			states["shot_"+str(int(t))]=true
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png(_out.path_join("stage%d_t%d.png"%[index,int(t)]))
	_release()
	var measured: float=_game.elapsed-level_start
	var wall: float=(Time.get_ticks_msec()-start)/1000.0
	if measured<wall*0.9: _issues.append("stage %d active time %.1f too short for wall %.1f"%[index,measured,wall])
	var ordered:=frames.slice(mini(60,int(frames.size()/10)))
	ordered.sort()
	var pick:=func(p:float)->float: return ordered[mini(ordered.size()-1,int(ordered.size()*p))] if not ordered.is_empty() else 0.0
	var result:={"boss":boss.type_id if is_instance_valid(boss) else "none","wall_seconds":wall,"unpaused_seconds":measured,"frames":frames.size(),"p50_ms":pick.call(0.5),"p95_ms":pick.call(0.95),"p99_ms":pick.call(0.99),"max_ms":frames.max(),"over_33ms":frames.filter(func(ms):return ms>33.3).size(),"over_100ms":frames.filter(func(ms):return ms>100).size(),"max_enemies":enemy_max,"max_sfx":voices_max,"max_same_sfx":same_max,"states":states.keys(),"phases":phases.keys(),"samples":samples}
	if _profile_gods and _game.player.gods.has("odin"):
		result["god_profile"]=_game.player.gods.odin.timings
		result["zone_profile"]=load("res://assets/source/taskK_independent_qa_2026-10-20/diagnostics/zone_profile.gd").timings
	print("STAGE_DONE ",JSON.stringify({"boss":result.boss,"p95":result.p95_ms,"max_ms":result.max_ms,"nodes_last":samples.back().nodes,"unpaused_seconds":measured,"wall_seconds":wall}))
	return result

func _flush() -> void:
	_report["violations"]=_issues
	var file:=FileAccess.open(_out.path_join("soak.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(_report,"\t"))
	file.close()
