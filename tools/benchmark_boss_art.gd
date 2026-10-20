extends "res://tools/review_boss_art.gd"

var population: Array = []

func run():
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280,720)
	await new_boss("hel")
	boss_node._fight_time = 100
	boss_node.queue_redraw()
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.set_process(false)
	player.set_physics_process(false)
	for child in player.get_children():
		if child != player._camera:
			child.process_mode = Node.PROCESS_MODE_DISABLED
	player.immune_time = 1000
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 350:
		var at = origin + Vector2.from_angle(i * 2.399963) * (100 + fmod(i * 19,450))
		var enemy = game.spawn_enemy("draugr", at, false, true)
		enemy.hp = 1000000
		enemy.set_physics_process(false)
		population.append(enemy)
	var results: Array = []
	for phase in ["350_animated_sprites_no_fx", "350_animated_sprites_40_fx", "350_animated_sprites_no_fx_repeat", "350_live_AI_no_fx", "350_live_AI_40_fx"]:
		var ai = phase.contains("live_AI")
		for enemy in population:
			enemy.set_physics_process(ai)
		await create_timer(1.5).timeout
		fx._boss_effects.clear()
		var times: Array = []
		var deltas: Array = []
		var start = Time.get_ticks_usec()
		var before = start
		var next_fx = 0
		var max_fx = 0
		while Time.get_ticks_usec() - start < 5000000:
			if phase.ends_with("40_fx") and Time.get_ticks_usec() >= next_fx:
				next_fx = Time.get_ticks_usec() + 250000
				for i in 20:
					fx_script.play("hel_army_summon", origin + Vector2.from_angle(i * 2.4) * (80 + i * 15))
			await process_frame
			var now = Time.get_ticks_usec()
			times.append((now - before) / 1000.0)
			deltas.append(game.get_process_delta_time() * 1000.0)
			max_fx = maxi(max_fx, fx._boss_effects.size())
			before = now
		times.sort()
		var sum = 0.0
		for value in times:sum += value
		results.append({"phase":phase,"frames":times.size(),"mean_frame_ms":sum/times.size(),"median_frame_ms":times[times.size()/2],"p95_frame_ms":times[int(times.size()*.95)],"fps_over_interval":times.size()*1000.0/sum,"enemies":get_node_count_in_group("enemies"),"peak_boss_effects":max_fx,"nodes":get_node_count(),"time_scale":Engine.time_scale,"last_process_delta_ms":deltas.back()})
		print("MEASURE ", results.back())
	fx._boss_effects.clear()
	await create_timer(0.7).timeout
	results.append({"phase":"cleanup","active_boss_effects":fx._boss_effects.size(),"nodes":get_node_count()})
	FileAccess.open(OUTPUT+"performance.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info(),"viewport":[1280,720],"level":game.level_id,"renderer":"gl_compatibility","measurements":results,"scope":"local Apple M2 render; 1.5s warmup plus5s each phase; animated-only pair isolates art cost; live AI pair separate"},"\t"))
	game.queue_free()
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values():tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream=null
		audio._streams.clear()
		audio.free()
		audio_script._instance=null
	await process_frame
	await process_frame
	quit()
