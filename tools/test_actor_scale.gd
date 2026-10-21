extends SceneTree

var checks := 0
var failures := []
var rows := []
var output := ""
var game
var actor_script
var visual
var enemies
var player_script

func _initialize():
	call_deferred("run")

func check(ok, label):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func foot_offset(actor, sprite):
	if actor.get("type_id") != null:
		var foot = enemies.ALL.get(actor.type_id, {}).get("foot", Vector2.ZERO)
		if foot != Vector2.ZERO:
			var tex_height = sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_height() if sprite is AnimatedSprite2D else sprite.texture.get_height()
			return Vector2(0, foot.y - tex_height)
	return Vector2.ZERO

func verify(actor, old_sprite, factor, label):
	check(actor._sprite != null and old_sprite != null, "art exists " + label)
	if actor._sprite == null or old_sprite == null: return
	var sprite = actor._sprite
	var expected = old_sprite.scale * factor
	check(sprite.scale.is_equal_approx(expected), "actual scale " + label)
	var anchor = foot_offset(actor, sprite)
	check((sprite.position + anchor * sprite.scale).is_equal_approx(old_sprite.position + anchor * old_sprite.scale), "foot pivot unchanged " + label)
	check(sprite.get_meta("base_scale").is_equal_approx(expected), "animation base preserved " + label)
	check((sprite.get_meta("base_pos") + anchor * sprite.scale).is_equal_approx(old_sprite.get_meta("base_pos") + anchor * old_sprite.scale), "animation pivot preserved " + label)
	if factor > 1:
		check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest sampling " + label)
	var base_pos = sprite.position
	var gait = actor.get("gait") if actor.get("gait") != null else "walk"
	visual.animate(sprite, 0.0, 0.0, gait)
	visual.animate(old_sprite, 0.0, 0.0, gait)
	check(sprite.scale.is_equal_approx(expected) and (sprite.position + anchor * sprite.scale).is_equal_approx(old_sprite.position + anchor * old_sprite.scale), "idle animation cannot reset scale " + label)
	rows.append({"actor": label, "scale": [sprite.scale.x, sprite.scale.y], "before": [old_sprite.scale.x, old_sprite.scale.y], "factor": factor, "pivot": [base_pos.x, base_pos.y]})

func old_enemy_sprite(node):
	var base = node.sprite_dir + (node.sprite_name if node.sprite_name != "" else node.type_id)
	var paths = [base + "_elite", base] if node.is_elite else [base]
	var height = node.radius * 2.6 / (enemies.ELITE_SIZE if node.is_elite else 1.0)
	var sprite
	for path in paths:
		sprite = visual.create_actions(path, height, node.actions)
		if sprite == null: sprite = visual.create(path, height)
		if sprite: break
	if sprite and node.is_elite:
		for key in ["base_scale", "base_pos"]: sprite.set_meta(key, sprite.get_meta(key) * enemies.ELITE_VISUAL)
		sprite.scale *= enemies.ELITE_VISUAL
		sprite.position *= enemies.ELITE_VISUAL
	if sprite:
		var foot = enemies.ALL.get(node.type_id, {}).get("foot", Vector2.ZERO)
		if foot != Vector2.ZERO:
			var tex_height = sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_height() if sprite is AnimatedSprite2D else sprite.texture.get_height()
			var base_pos = Vector2(0, 20.0 + (tex_height - foot.y) * sprite.scale.y)
			sprite.position = base_pos
			sprite.set_meta("base_pos", base_pos)
	return sprite

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty() or root.get_node("Save").path == "user://save.json": quit(2); return
	var save = root.get_node("Save")
	save.reset()
	actor_script = load("res://scripts/entities/enemy.gd")
	player_script = load("res://scripts/entities/player.gd")
	visual = load("res://scripts/entities/sprite_visual.gd")
	enemies = load("res://scripts/data/enemy_db.gd")
	var characters = load("res://scripts/data/character_db.gd")
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	current_scene = game
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	game.level_up_panel.choose(0)
	paused = false
	for power in game.player.gods.values(): power.free()
	game.player.gods.clear()
	check(visual.ACTOR_SCALE == 1.1, "requested ten percent multiplier")
	for id in characters.ALL:
		var player = player_script.new()
		player.character_id = id
		game.add_child(player)
		var old_sprite = visual.create_actions(characters.CUTIN_DIR + id, player_script.SPRITE_HEIGHT, player_script.ACTIONS)
		if old_sprite == null: old_sprite = visual.create(characters.CUTIN_DIR + id, player_script.SPRITE_HEIGHT)
		verify(player, old_sprite, 1.1, id)
		check(player.scale == Vector2.ONE and player.move_speed == characters.ALL[id].speed and player.max_hp == characters.ALL[id].hp, "player stats and root unchanged " + id)
		for child in player.get_children():
			if child is CollisionShape2D: check(child.shape.radius == 14, "player hitbox remains fourteen " + id)
		# Walk, attack, hurt and death select the same atlas frames and retain the enlarged base.
		for action in ["idle", "move", "attack", "hurt", "death"]:
			if player._actions and player._actions.sprite_frames.has_animation(action):
				player._actions.play(action)
				visual.animate(player._actions, 0.0, 0.0)
				check(player._actions.scale.is_equal_approx(old_sprite.scale * 1.1), "action scaling " + id + "/" + action)
		old_sprite.free()
		player.free()
	for id in enemies.ALL:
		for elite in [false, true]:
			var enemy = game.spawn_enemy(id, Vector2(100, 100), elite, true)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			var old_sprite = old_enemy_sprite(enemy)
			var expected_factor = 1.0 if enemy.behavior == "still" else 1.1
			verify(enemy, old_sprite, expected_factor, id + ("_elite" if elite else ""))
			var data = enemies.ALL[id]
			check(enemy.radius == data.radius * (enemies.ELITE_SIZE if elite else 1.0), "enemy hitbox unchanged " + id)
			check(enemy.scale == Vector2.ONE, "enemy root unchanged " + id)
			for child in enemy.get_children():
				if child is CollisionShape2D: check(is_equal_approx(child.shape.radius, enemy.radius), "collision shape unchanged " + id)
			if old_sprite: old_sprite.free()
			enemy.free()
	# Bosses also inherit Enemy but have their own visual and geometry contracts.
	var boss_db = load("res://scripts/data/boss_db.gd")
	var ids = ["skoll", "hati", "hrym", "garm", "nidhogg", "hel"]
	if load("res://scripts/data/level_db.gd").is_built("vigrid"): ids += ["jormungandr", "fenrir", "surtr"]
	for id in ids:
		var boss = boss_db.create(id, 1.0)
		boss.target = game.player
		boss.spawner = game.spawn_enemy
		game.add_child(boss)
		boss.process_mode = Node.PROCESS_MODE_DISABLED
		var old_sprite = old_enemy_sprite(boss)
		check(boss._sprite != null and old_sprite != null, "Boss art exists " + id)
		if old_sprite:
			check(boss._sprite.scale.is_equal_approx(old_sprite.scale), "Boss scale unchanged " + id)
			old_sprite.free()
		boss.free()
	await process_frame
	game.free()
	await process_frame
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer: child.stop(); child.stream = null
		await create_timer(0.2).timeout
		audio._streams.clear()
		audio.free()
		audio_script._instance = null
	await process_frame
	check(get_nodes_in_group("enemies").is_empty(), "exit clears actor index")
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "actors": rows}, "\t"))
	file.close()
	print("RESULT ACTOR SCALE: ", checks, " checks, ", failures.size(), " failures")
	quit(1 if not failures.is_empty() else 0)
