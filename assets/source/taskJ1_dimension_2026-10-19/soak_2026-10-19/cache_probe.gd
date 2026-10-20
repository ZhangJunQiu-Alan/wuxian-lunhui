extends SceneTree

var game
var player
var layer
var population: Array = []
var feedback
var origin := Vector2.ZERO
var samples: Array = []
var checks: Array = []
var phases: Array = []
var started := 0
var active_seconds := 0.0
var phase_name := "setup"
var cadence := 0.0
var cast_clock := 0.0
var death_clock := 0.0
var render_frames := 0
var output := "res://validation/"
var casts := {"dimension_slash":0,"wild_west_show":0,"enter_formation":0,"stonehenge":0,"marks":0,"deaths":0}
var cache_files: Array = []
var live := false
var emit_load := false
var cycle_count := 0

func _initialize():
	call_deferred("run")

func check(ok, label, value = null):
	checks.append({"pass":bool(ok),"label":label,"value":value})
	if not ok:push_error(label+" "+str(value))

func write_json(name, value):
	FileAccess.open(output+name,FileAccess.WRITE).store_string(JSON.stringify(value,"\t"))

func sample(tag):
	var counters={"marks":0,"particles":0,"rings":0,"numbers":0}
	if is_instance_valid(layer):
		counters={"marks":layer._marks.size(),"particles":layer._particles.size(),"rings":layer._rings.size(),"numbers":layer._numbers.size()}
	var row={"seconds":(Time.get_ticks_msec()-started)/1000.0,"phase":phase_name,"tag":tag,"cycle":cycle_count,
		"static_bytes":OS.get_static_memory_usage(),"static_peak_bytes":OS.get_static_memory_peak_usage(),
		"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodes":get_node_count(),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"enemies":get_node_count_in_group("enemies"),"effects":counters,
		"j_texture_cache":load("res://scripts/effects/combat_fx.gd")._textures.size(),"fps_monitor":Engine.get_frames_per_second()}
	row["cached_files"]=cache_files.filter(func(path):return ResourceLoader.has_cached(path))
	samples.append(row)
	write_json("soak_samples.json",samples)
	write_json("progress.json",{"phase":phase_name,"seconds":row.seconds,"cycle":cycle_count,"latest":row,"checks":checks.size(),"failures":checks.filter(func(c):return not c.pass),"casts":casts})
	print("SAMPLE ",JSON.stringify(row))
	return row

func cleanup_audio():
	var script=load("res://scripts/core/audio.gd")
	var audio=script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values():tween.kill()
		for node in audio.get_children():
			if node is AudioStreamPlayer:node.stop();node.stream=null
		audio._streams.clear()
		audio.free()
		script._instance=null

func new_game(character, count):
	paused=false
	var save=root.get_node("Save")
	save.selected_character=character
	save.selected_level="midgard"
	save.stats.clears=1
	save.stats.quests_done=3
	save.unlocked_characters.assign(["mage"])
	game=load("res://scripts/game.gd").new()
	root.add_child(game)
	current_scene=game
	game.process_mode=Node.PROCESS_MODE_DISABLED
	await process_frame
	game.level_up_panel.choose(0)
	paused=false
	game.level_up_panel.hide()
	player=game.player
	for power in player.gods.values():power.free()
	player.gods.clear()
	player.faith.clear()
	origin=load("res://scripts/world/map_layer.gd").push_out(Vector2.ZERO,20)
	player.position=origin
	player.hp=player.max_hp
	player.immune_time=100000
	player.shield_time=100000
	player._camera.position_smoothing_enabled=false
	player._camera.force_update_scroll()
	player.pickup_radius=0
	player.damage_mult=0.0
	layer=load("res://scripts/effects/fx_layer.gd").instance
	layer.process_mode=Node.PROCESS_MODE_ALWAYS
	for enemy in get_nodes_in_group("enemies"):enemy.free()
	population.clear()
	for i in count:
		var enemy=game.spawn_enemy("draugr",origin+Vector2.from_angle(i*2.399963)*(55+fmod(i*19,430)),false)
		enemy.hp=100000000
		enemy.target=player
		enemy.process_mode=Node.PROCESS_MODE_ALWAYS
		enemy.set_physics_process(live)
		population.append(enemy)
	var blade=load("res://scripts/weapons/twin_blades.gd").new()
	player.add_child(blade)
	blade.process_mode=Node.PROCESS_MODE_ALWAYS
	var nova=load("res://scripts/weapons/arcane_nova.gd").new()
	player.add_child(nova)
	nova.process_mode=Node.PROCESS_MODE_ALWAYS
	feedback=load("res://scripts/gods/loki.gd").new()
	player.add_child(feedback)
	feedback.process_mode=Node.PROCESS_MODE_DISABLED
	feedback.path="loki_wolf"
	feedback.awakened=true
	feedback._wolf_pos=origin+Vector2(20,0)
	feedback._breath_flash=.3
	check(get_node_count_in_group("enemies")==count,"population setup "+str(cycle_count),get_node_count_in_group("enemies"))

func is_timed_ultimate(node):
	return node.get_script() in [load("res://scripts/ultimates/dimension_slash.gd"),load("res://scripts/ultimates/enter_formation.gd"),load("res://scripts/ultimates/stonehenge.gd")]

func cast_all():
	for id in ["dimension_slash","wild_west_show","enter_formation","stonehenge"]:
		var script=load("res://scripts/ultimates/"+id+".gd")
		script.cast(player)
		casts[id]+=1
	for node in game.get_children():
		if is_timed_ultimate(node):node.process_mode=Node.PROCESS_MODE_ALWAYS
	for node in player.get_children():
		if node.get_script()==load("res://scripts/ultimates/wild_west_show.gd"):node.process_mode=Node.PROCESS_MODE_ALWAYS

func _process(delta):
	if is_instance_valid(player):player.frenzy_time=maxf(0.0,player.frenzy_time-delta)
	if not emit_load or not is_instance_valid(game):return false
	active_seconds+=delta
	render_frames+=1
	cadence-=delta
	cast_clock-=delta
	death_clock-=delta
	if cadence<=0:
		cadence=.1
		for i in 55:
			layer.mark(origin+Vector2.from_angle(i*2.4+active_seconds)*(40+fmod(i*23,260)),active_seconds+i*.2,48,Color.WHITE,"claw" if i%2 else "bite")
		casts.marks+=55
		check(layer._marks.size()<=120,"central cap at emission") if casts.marks%33000==0 else null
		feedback._breath_flash=.3
		feedback._breath_dir=Vector2.from_angle(active_seconds*.4)
		feedback.queue_redraw()
	if cast_clock<=0:
		cast_clock=12.0
		cast_all()
	if death_clock<=0:
		death_clock=2.0
		for i in 8:
			load("res://scripts/effects/fx_layer.gd").death(origin+Vector2.from_angle(active_seconds+i)*150,Color(.7,.5,.8),i==0)
		casts.deaths+=8
	if live:
		for enemy in population:
			if is_instance_valid(enemy) and enemy.position.distance_to(origin)>650:enemy.position=origin+Vector2.from_angle(randf()*TAU)*400
	return false

func clear_game():
	emit_load=false
	population.clear()
	if is_instance_valid(game):game.free()
	game=null
	player=null
	feedback=null
	layer=null
	await process_frame
	await process_frame
	check(load("res://scripts/effects/fx_layer.gd").instance==null,"FxLayer static cleared on scene exit "+str(cycle_count))

func pressure_phase(name, seconds, use_ai):
	phase_name=name
	live=use_ai
	for enemy in population:enemy.set_physics_process(live)
	emit_load=true
	cast_clock=0
	var start=Time.get_ticks_msec()
	var last=start
	var next_sample=start
	var times:Array=[]
	sample("start")
	while Time.get_ticks_msec()-start<int(seconds*1000):
		await process_frame
		var now=Time.get_ticks_msec()
		times.append(now-last)
		last=now
		if now>=next_sample:
			next_sample=now+10000
			sample("steady")
			check(get_node_count_in_group("enemies")==350,"steady population "+name)
			check(layer._marks.size()<=120,"mark cap "+name)
			check(layer._particles.size()<=800,"particle cap "+name)
			check(load("res://scripts/effects/combat_fx.gd")._textures.size()==14,"bounded texture cache "+name)
	emit_load=false
	times.sort()
	var total=0.0
	for t in times:total+=t
	phases.append({"name":name,"wall_seconds":(Time.get_ticks_msec()-start)/1000.0,"frames":times.size(),"mean_ms":total/times.size(),"p95_ms":times[int(times.size()*.95)],"live_ai":use_ai})
	sample("end")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+name+".png")

func run():
	started=Time.get_ticks_msec()
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("Settings").sfx_volume=0
	root.get_node("Settings").music_volume=0
	root.get_node("Settings").apply()
	var art=load("res://scripts/effects/combat_fx.gd")
	for id in art.ART:check(art.texture(id)!=null,"resource preload "+id)
	cache_files=JSON.parse_string(FileAccess.get_file_as_string("res://validation/cache_paths.json"))
	var short=false
	await new_game("assassin",350)
	sample("cache_probe_initial")
	phase_name="effect_drain"
	for child in player.get_children():
		if child!=player._camera and child.get_script()!=load("res://scripts/ultimates/wild_west_show.gd"):child.process_mode=Node.PROCESS_MODE_DISABLED
	for child in game.get_children():
		if is_timed_ultimate(child):child.process_mode=Node.PROCESS_MODE_ALWAYS
	await create_timer(10.0).timeout
	sample("drained")
	check(layer._marks.is_empty() and layer._particles.is_empty() and layer._rings.is_empty(),"feedback arrays drain without manual clearing")
	check(player.get_children().filter(func(n):return n.get_script()==load("res://scripts/ultimates/wild_west_show.gd")).is_empty(),"frenzy visuals expire naturally")
	check(game.get_children().filter(func(n):return is_timed_ultimate(n)).is_empty(),"ultimates expire naturally")
	await clear_game()
	phase_name="scene_cycles"
	var count=3 if short else 60
	for i in count:
		cycle_count=i+1
		live=false
		await new_game(["swordsman","gunslinger","assassin","mage"][i%4],12)
		emit_load=true
		cast_clock=0
		await create_timer(1.4).timeout
		await clear_game()
		await create_timer(.2).timeout
		sample("after_free")
		check(get_node_count_in_group("enemies")==0,"no enemies after scene free "+str(i))
		check(get_node_count_in_group("stonehenge")==0,"no henge after scene free "+str(i))
	phase_name="final_idle"
	cleanup_audio()
	await create_timer(5.0).timeout
	sample("all_released")
	var failures=checks.filter(func(c):return not c.pass)
	write_json("soak_result.json",{"engine":Engine.get_version_info(),"pid":OS.get_process_id(),"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"smoke":short,"samples":samples,"checks":checks,"failures":failures,"phases":phases,"casts":casts,"scene_cycles":cycle_count,"scope":"committed J Game nodes; actual automatic OpenGL rendering; test-controlled damage_mult=0 and immune stationary player; wave timer/quest progression disabled; source code unchanged"})
	var before_record_release=OS.get_static_memory_usage()
	var saved_samples=samples.size()
	var saved_checks=checks.size()
	samples.clear()
	checks.clear()
	var after_record_release=OS.get_static_memory_usage()
	write_json("recorder_release.json",{"before_bytes":before_record_release,"after_bytes":after_record_release,"released_bytes":before_record_release-after_record_release,"samples":saved_samples,"checks":saved_checks})
	print("CACHE_PROBE_COMPLETE ",saved_checks," checks ",failures.size()," failures; recorder release bytes=",before_record_release-after_record_release)
	quit(1 if failures.size() else 0)
