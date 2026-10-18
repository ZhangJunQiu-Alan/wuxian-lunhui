extends SceneTree

var game
var player
var art
var fx
var output := "res://validation/"
var shots: Array = []
var origin := Vector2.ZERO

func _initialize():
	call_deferred("run")

func stop_audio():
	var script=load("res://scripts/core/audio.gd")
	var audio=script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values():tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream=null
		audio._streams.clear()
		audio.free()
		script._instance=null

func new_game(character):
	print("NEW GAME ",character)
	if is_instance_valid(game):
		game.free()
	paused=false
	root.get_node("Save").selected_level="midgard"
	root.get_node("Save").selected_character=character
	root.get_node("Save").stats.clears=1
	root.get_node("Save").stats.quests_done=3
	root.get_node("Save").unlocked_characters.assign(["mage"])
	game=load("res://scripts/game.gd").new()
	root.add_child(game)
	current_scene=game
	game.process_mode=Node.PROCESS_MODE_DISABLED
	await process_frame
	game.level_up_panel.choose(0)
	paused=false
	game.level_up_panel.hide()
	game.pause_menu.close()
	game.pause_menu.hide()
	player=game.player
	for power in player.gods.values():power.free()
	player.gods.clear()
	player.faith.clear()
	game.hud.set_faith(player)
	if player.character_id!=character:push_error("Wrong capture character "+player.character_id)
	origin=load("res://scripts/world/map_layer.gd").push_out(Vector2.ZERO,20)
	player.position=origin
	player._camera.position_smoothing_enabled=false
	player._camera.offset=Vector2.ZERO
	fx=load("res://scripts/effects/fx_layer.gd").instance
	for at in [Vector2(110,0),Vector2(-100,75),Vector2(60,-130),Vector2(220,90)]:
		var enemy=game.spawn_enemy("draugr",origin+at,false)
		enemy.process_mode=Node.PROCESS_MODE_DISABLED
		enemy.hp=1000000
	clear_feedback()

func clear_feedback():
	fx._numbers.clear()
	fx._particles.clear()
	fx._marks.clear()
	fx._rings.clear()
	if fx.get("_boss_effects")!=null:fx.get("_boss_effects").clear()

func redraw(node):
	if node is CanvasItem:node.queue_redraw()
	for child in node.get_children():redraw(child)

func capture(name, description):
	game.pause_menu.close()
	game.pause_menu.hide()
	paused=false
	redraw(game)
	player._camera.force_update_scroll()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var err=root.get_texture().get_image().save_png(output+name+".png")
	shots.append({"file":name+".png","description":description,"write_error":err,"game_scene":"scripts/game.gd","level":game.level_id,"viewport":[1280,720]})
	print("CAPTURE ",name," ",err)

func pair(name, description):
	var saved=art._textures.duplicate()
	for id in art.ART:art._textures[id]=null
	await capture(name+"_before",description+"; original geometry fallback")
	art._textures=saved
	await capture(name+"_after",description+"; integrated J art")

func ult(id):
	var node=load("res://scripts/ultimates/"+id+".gd").new()
	node.player=player
	node.position=origin
	node.process_mode=Node.PROCESS_MODE_DISABLED
	game.add_child(node)
	return node

func run():
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1280,720)
	art=load("res://scripts/effects/combat_fx.gd")
	for id in art.ART:art.texture(id)
	if "--benchmark" in OS.get_cmdline_user_args():
		await benchmark()
		return
	await new_game("swordsman")
	var slash=ult("dimension_slash")
	slash._time=0.65
	await pair("J1_dimension_charge","pre-burst space cuts; preserve darkening")
	slash._burst_done=true
	slash._time=0.84
	await pair("J1_dimension_burst","burst stage; preserve white flash")
	slash._time=1.1
	await capture("J1_dimension_decay","final strip frame fades until original end")
	slash.free()
	await new_game("gunslinger")
	var west=ult("wild_west_show")
	west.reparent(player)
	west.position=Vector2.ZERO
	player.frenzy_time=8
	west._time=0.1
	await pair("J2_west_entry","five single-shot badges plus looping aura")
	for i in 4:
		west._time=0.5+i*0.125
		await capture("J2_west_loop_"+str(i),"loop phase; actor and bullets remain visible")
	west.free()
	await new_game("assassin")
	var formation=ult("enter_formation")
	formation.position=Vector2.ZERO
	formation._trails=[{"from":origin+Vector2(-170,-70),"to":origin+Vector2(200,100),"life":0.26}]
	await pair("J3_formation_slash","instant-strike trail follows actual from/to")
	formation._trails.clear()
	formation._phase="cavalry"
	formation._center=origin
	formation._cavalry_t=0.55
	await pair("J3_cavalry","42 riders in existing14x3 loop; no child sprite nodes")
	for i in [0,2,4]:
		formation._cavalry_t=0.55+i*0.125
		await capture("J3_cavalry_phase_"+str(i),"rider gait phase within original advance")
	formation.free()
	await new_game("mage")
	var henge=ult("stonehenge")
	henge._time=0.3
	await pair("J4_henge_drop","standing stones keep falling trajectory and shadow")
	henge._time=1.0
	henge._landed=true
	await pair("J4_henge_landed","10 stones and5 connecting lintels; exact shield ring remains")
	henge._time=8.2
	await capture("J4_henge_decay","original final-second fade")
	henge.free()
	await new_game("assassin")
	var blade=load("res://scripts/weapons/twin_blades.gd").new()
	player.add_child(blade)
	blade.process_mode=Node.PROCESS_MODE_DISABLED
	blade._slash_time=0.17
	for angle in [0.0,0.8,PI]:
		blade._aim=Vector2.from_angle(angle)
		await pair("J5_blades_"+str(int(angle*100)),"clipped to actual aim cone despite alternating offset")
	blade.free()
	await new_game("mage")
	var nova=load("res://scripts/weapons/arcane_nova.gd").new()
	player.add_child(nova)
	nova.process_mode=Node.PROCESS_MODE_DISABLED
	for t in [0.1,0.25,0.4]:
		nova._waves=[{"t":t,"hit":{}}]
		await pair("J6_nova_"+str(int(t*100)),"same code radius; transparent center")
	nova.free()
	clear_feedback()
	var layer=load("res://scripts/effects/fx_layer.gd")
	for kind in ["claw","bite"]:
		layer.mark(origin+Vector2(100,0),0,70,Color.WHITE,kind)
		fx._process(0.08)
		await pair("J7_"+kind,"actual central FxLayer mark")
		clear_feedback()
	var victim=get_nodes_in_group("enemies")[0]
	victim.hp=1
	victim.take_damage(10)
	fx._numbers.clear()
	fx._process(0.08)
	await capture("J7_death_after","real enemy death emits one central animated shard mark")
	clear_feedback()
	await new_game("swordsman")
	var wolf=load("res://scripts/gods/loki.gd").new()
	player.add_child(wolf)
	wolf.process_mode=Node.PROCESS_MODE_DISABLED
	wolf.path="loki_wolf"
	wolf.awakened=true
	wolf._wolf_pos=origin+Vector2(40,0)
	for angle in [0.0,0.8,PI]:
		wolf._breath_dir=Vector2.from_angle(angle)
		wolf._breath_flash=0.3
		await pair("J8_wolf_breath_"+str(int(angle*100)),"sprite clipped to original220-length0.45-half-angle cone")
	wolf.free()
	FileAccess.open(output+"render_review.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info(),"screenshots":shots,"scope":"actual Game viewport, controlled skill states; full manual playthrough not tested"},"\t"))
	game.free()
	stop_audio()
	await process_frame
	await process_frame
	print("REVIEW COMPLETE ",shots.size()," actual game captures")
	quit()

func benchmark():
	await new_game("assassin")
	for enemy in get_nodes_in_group("enemies"):enemy.free()
	game.process_mode=Node.PROCESS_MODE_INHERIT
	game.set_process(false)
	player.set_physics_process(false)
	for child in player.get_children():
		if child!=player._camera:child.process_mode=Node.PROCESS_MODE_DISABLED
	player.immune_time=10000
	for i in 350:
		var enemy=game.spawn_enemy("draugr",origin+Vector2.from_angle(i*2.399963)*(100+fmod(i*19,450)),false)
		enemy.hp=1000000
		enemy.set_physics_process(false)
	var cavalry=ult("enter_formation")
	cavalry._phase="cavalry"
	cavalry._center=origin
	cavalry._cavalry_t=0.55
	var saved=art._textures.duplicate()
	var results:Array=[]
	fx.process_mode=Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for phase in ["old_geometry","new_art","old_geometry_repeat","new_art_repeat"]:
		art._textures=saved.duplicate()
		if phase.begins_with("old"):
			for id in art.ART:art._textures[id]=null
		clear_feedback()
		await create_timer(1.0).timeout
		var start=Time.get_ticks_usec()
		var before=start
		var times:Array=[]
		var peak=0
		var layer=load("res://scripts/effects/fx_layer.gd")
		while Time.get_ticks_usec()-start<4000000:
			for i in range(120-fx._marks.size()):layer.mark(origin+Vector2.from_angle(i*2.4)*(60+fmod(i*25,250)),i*.3,50,Color.WHITE,"claw" if i%2 else "bite")
			cavalry.queue_redraw()
			await process_frame
			for i in range(120-fx._marks.size()):layer.mark(origin+Vector2.from_angle(i*2.4)*(60+fmod(i*25,250)),i*.3,50,Color.WHITE,"claw" if i%2 else "bite")
			RenderingServer.force_draw(false)
			var now=Time.get_ticks_usec()
			times.append((now-before)/1000.0)
			before=now
			peak=maxi(peak,fx._marks.size())
		times.sort()
		var total=0.0
		for t in times:total+=t
		results.append({"phase":phase,"frames":times.size(),"mean_ms":total/times.size(),"p95_ms":times[int(times.size()*.95)],"fps":times.size()*1000.0/total,"enemies":get_node_count_in_group("enemies"),"marks_peak":peak,"nodes":get_node_count(),"42_cavalry":true})
		print("BENCH ",results.back())
	clear_feedback()
	await create_timer(.4).timeout
	results.append({"phase":"cleanup","marks":fx._marks.size(),"particles":fx._particles.size(),"nodes":get_node_count()})
	FileAccess.open(output+"performance.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info(),"viewport":[1280,720],"scope":"local rendered350 animated enemies,42 cavalry,exactly120 central marks at draw;manual render loop1draw per sample;1s warmup and4s phases; no long-session guarantee","measurements":results},"\t"))
	game.free()
	stop_audio()
	await process_frame
	await create_timer(0.2).timeout
	quit()
