extends SceneTree

var checks: Array = []
var game
var player
var fx
var art
var enemy_script

func _initialize():
	call_deferred("run")

func check(ok, label, value = null):
	checks.append({"pass":bool(ok), "label":label, "value":value})
	if not ok:
		push_error(label + " " + str(value))

func clear_enemies():
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()

func spawn(at, hp = 10000.0):
	var enemy = enemy_script.new()
	enemy.setup("draugr", 1.0)
	enemy.target = player
	enemy.position = at
	enemy.hp = hp
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	game.add_child(enemy)
	return enemy

func weapon(path):
	var node = load("res://scripts/weapons/"+path+".gd").new()
	player.add_child(node)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	return node

func ultimate(path):
	var node = load("res://scripts/ultimates/"+path+".gd").new()
	node.player = player
	node.process_mode = Node.PROCESS_MODE_DISABLED
	game.add_child(node)
	return node

func run():
	if root.get_node("Save").path == "user://save.json":
		push_error("Use isolated --save-file")
		quit(2)
		return
	root.get_node("Save").selected_level = "midgard"
	root.get_node("Save").selected_character = "swordsman"
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	current_scene = game
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	game.level_up_panel.choose(0)
	paused = false
	player = game.player
	player.position = Vector2.ZERO
	player.damage_mult = 1.0
	for power in player.gods.values():
		power.free()
	player.gods.clear()
	fx = load("res://scripts/effects/fx_layer.gd").instance
	art = load("res://scripts/effects/combat_fx.gd")
	enemy_script = load("res://scripts/entities/enemy.gd")
	enemy_script.crit_chance = 0.0
	for id in art.ART:
		var texture = art.texture(id)
		var count = art.ART[id].get("frames",4)
		var size = art.ART[id].size
		check(texture != null and texture.get_size() == Vector2(size.x*count,size.y), "actual imported texture dimensions "+id)
		for i in count:
			var fps = art.ART[id].get("fps",16.0)
			check(art.frame_index(id,(i+0.1)/fps)==i, "frame phase "+id+" "+str(i))
		check(art.frame_index(id,10.0) < count, "bounded frame selection "+id)
		if art.ART[id].get("loop",false):
			check(art.frame_index(id,float(count)/art.ART[id].fps)==0,"loop wraps "+id)
		else:
			check(art.frame_index(id,10.0)==count-1,"one-shot holds final frame "+id)
	for half in [0.45,0.7,PI]:
		for angle in [0.0,0.73,PI, -PI/2]:
			var poly = art.sector(Vector2(11,17),220.0,angle,half)
			check(poly.size()>=8,"sector polygon has arc "+str(half)+"/"+str(angle))
			for p in poly:
				var delta = p-Vector2(11,17)
				check(delta.length()<=220.001,"sector radius bound")
				if delta.length()>0.01 and half<PI:
					check(abs(Vector2.from_angle(angle).angle_to(delta))<=half+0.0001,"sector angular bound")
	var blade = weapon("twin_blades")
	var front = spawn(Vector2(55,0))
	var side = spawn(Vector2.from_angle(0.72)*55)
	var behind = spawn(Vector2(-55,0))
	blade._timer = 0
	blade._process(0)
	check(front.hp<10000,"twin blades actual hit")
	check(side.hp==10000 and behind.hp==10000,"twin blades outside fan untouched")
	check(is_equal_approx(blade._slash_time,0.25),"twin blade art visual lifetime0.25")
	check(is_equal_approx(blade._timer,blade.cooldown*player.weapon_cooldown()),"weapon cooldown unchanged")
	var damaged = front.hp
	blade._process(0.1)
	check(front.hp==damaged,"art frames do not reapply weapon damage")
	blade._process(0.151)
	check(blade._slash_time<=0,"blade art expires")
	blade.free()
	clear_enemies()
	var nova = weapon("arcane_nova")
	front=spawn(Vector2(80,0))
	var outside=spawn(Vector2(250,0))
	nova._timer=0
	nova._process(0.18)
	check(front.hp<10000 and outside.hp==10000,"nova radial hit and outside bound")
	damaged=front.hp
	nova._process(0.1)
	check(front.hp==damaged,"nova once per enemy per wave")
	nova._process(0.3)
	check(nova._waves.is_empty(),"nova wave cleanup")
	nova.free()
	clear_enemies()
	var slash=ultimate("dimension_slash")
	front=spawn(Vector2(80,0))
	outside=spawn(Vector2(1600,0))
	slash._process(0.74)
	check(front.hp==10000 and not slash._burst_done,"dimension no damage before burst")
	slash._process(0.011)
	check(slash._burst_done and front.hp==9880 and outside.hp==10000,"dimension burst damage and screen bound")
	slash._process(0.3)
	check(front.hp==9880,"dimension burst only once")
	slash._process(0.3)
	check(slash.is_queued_for_deletion(),"dimension expires at original END_AT")
	slash.free()
	clear_enemies()
	var west_script=load("res://scripts/ultimates/wild_west_show.gd")
	west_script.cast(player)
	var west=player.get_children().filter(func(n):return n.get_script()==west_script)[0]
	check(player.frenzy_time==8.0,"west cast keeps eight-second frenzy")
	west._process(0.2)
	check(not west.is_queued_for_deletion(),"west art persists while frenzy active")
	player.frenzy_time=0
	west._process(0)
	check(west.is_queued_for_deletion(),"west art expires with original frenzy state")
	west.free()
	var henge=ultimate("stonehenge")
	front=spawn(Vector2(50,0))
	outside=spawn(Vector2(250,0))
	henge._process(0.44)
	check(not henge._landed and front.hp==10000,"henge drop windup preserved")
	henge._process(0.011)
	check(henge._landed and front.hp==9900 and outside.hp==10000,"henge impact unchanged")
	check(henge.shields(self,Vector2(139,0)) and not henge.shields(self,Vector2(141,0)),"henge shields exact boundary")
	var inner_shot=Node2D.new()
	var outer_shot=Node2D.new()
	game.add_child(inner_shot)
	game.add_child(outer_shot)
	inner_shot.add_to_group("enemy_projectiles")
	outer_shot.add_to_group("enemy_projectiles")
	inner_shot.position=Vector2(139,0)
	outer_shot.position=Vector2(141,0)
	henge._physics_process(0)
	check(inner_shot.is_queued_for_deletion() and not outer_shot.is_queued_for_deletion(),"henge keeps actual projectile blocking boundary")
	inner_shot.free()
	outer_shot.free()
	check(front.position.length()>=henge.RADIUS+front.radius-0.001,"henge pushes enemy to real outer edge")
	henge._process(8.0)
	check(henge.is_queued_for_deletion(),"henge expires at original duration")
	henge.free()
	clear_enemies()
	var formation=ultimate("enter_formation")
	front=spawn(Vector2(100,0))
	var shield_before = player.shield_time
	formation._strike(front)
	check(front.hp==9910,"formation strike damage unchanged; crit flag only changes feedback")
	check(formation._trails.size()==1 and formation._struck.size()==1,"formation one trail per strike")
	check(player.shield_time==shield_before,"visual draw does not change invulnerability")
	formation._start_cavalry()
	formation._cavalry_t=0.55
	var x=formation._cavalry_x()
	front.position=Vector2(x,formation._center.y)
	var hp=front.hp
	formation._process(0)
	check(front.hp==hp-60,"formation cavalry original damage")
	formation._process(0)
	check(front.hp==hp-60,"formation cavalry each enemy only once")
	formation._process(1.1)
	check(formation.is_queued_for_deletion(),"formation original lifetime cleanup")
	formation.free()
	clear_enemies()
	player.position=Vector2.ZERO
	var wolf=load("res://scripts/gods/loki.gd").new()
	player.add_child(wolf)
	wolf.path="loki_wolf"
	wolf.awakened=true
	wolf.process_mode=Node.PROCESS_MODE_DISABLED
	wolf._wolf_pos=Vector2.ZERO
	wolf._wolf_bite=100
	wolf._breath=0
	front=spawn(Vector2(160,0))
	side=spawn(Vector2.from_angle(0.47)*160)
	outside=spawn(Vector2(230,0))
	wolf._tick_wolf(0)
	check(front.hp==9982,"wolf breath actual damage unchanged")
	check(side.hp==10000 and outside.hp==10000,"wolf breath actual cone limits")
	check(wolf._breath_flash==0.4,"wolf breath keeps original display window")
	wolf._tick_wolf(0.41)
	check(wolf._breath_flash==0,"wolf breath visual cleanup")
	wolf.free()
	clear_enemies()
	var layer_script=load("res://scripts/effects/fx_layer.gd")
	fx._marks.clear()
	var nodes=get_node_count()
	for i in 250:
		layer_script.mark(Vector2(i,0),0,32,Color.WHITE,"claw" if i%2 else "bite")
	check(fx._marks.size()==120,"central marks hard cap120")
	check(get_node_count()==nodes,"marks allocate no nodes")
	check(fx._marks.all(func(m):return is_equal_approx(m.duration,0.25)),"claw bite16fps complete lifetime")
	fx._process(0.251)
	check(fx._marks.is_empty(),"all hit art clears after lifetime")
	layer_script.mark(Vector2.ZERO,0,32,Color.WHITE)
	check(fx._marks[0].life==0.22,"generic slash unchanged0.22")
	fx._marks.clear()
	fx._particles.clear()
	front=spawn(Vector2(100,0),1)
	front.take_damage(10)
	check(fx._marks.any(func(m):return m.kind=="death"),"real enemy death emits texture mark")
	check(fx._particles.is_empty(),"death does not duplicate old burst")
	check(front._dead,"enemy death logic still completes")
	fx._process(0.26)
	check(fx._marks.is_empty(),"death art cleans centrally")
	check(not art.draw(fx,"undefined_asset",0),"unknown art leaves geometry fallback available")
	art._textures["death_shards"]=null
	check(not layer_script.death(Vector2.ZERO,Color.WHITE),"missing death art returns fallback")
	art._textures.erase("death_shards")
	clear_enemies()
	game.queue_free()
	var audio_script=load("res://scripts/core/audio.gd")
	var audio=audio_script._instance
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
	await create_timer(0.2).timeout
	var failures=checks.filter(func(c):return not c.pass)
	FileAccess.open("res://validation/combat_art_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"count":checks.size(),"failures":failures,"engine":Engine.get_version_info(),"scope":"actual Godot game nodes and damage/state/lifecycle checks; visual review separate"},"\t"))
	print("RESULT J ART ",checks.size()," checks ",failures.size()," failures")
	quit(1 if failures.size() else 0)
