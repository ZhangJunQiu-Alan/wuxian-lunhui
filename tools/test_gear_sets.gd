extends SceneTree
## 装备回归：10 套套装效果的数值、Boss 掉落、存档。
## 用法：godot --headless --path . --log-file /dev/null --script tools/test_gear_sets.gd -- --save-file=user://test_save.json --settings-file=user://test_settings.cfg

var game
var player
var effects
var checks := 0
var failures: Array[String] = []
var gear_db  # 工具脚本编译时还没有自动加载，游戏里的类都在运行时 load
var set_effects


func _initialize():
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func near(a: float, b: float, tolerance: float = 0.01) -> bool:
	return absf(a - b) <= tolerance


## 穿上一整套（空字符串 = 什么都不穿），重新开一局，停掉刷怪、武器和开局选神
func start(set_id: String) -> void:
	var save = root.get_node("Save")
	save.gear = {}
	save.equipped = {}
	save.gear_new = {}
	save.selected_character = "swordsman"
	save.swordsman_weapon = "katana"
	save.selected_level = "midgard"
	save.meta = {}
	if set_id != "":
		for slot in gear_db.SLOTS:
			save.gear[gear_db.item_id(set_id, slot)] = true
		save.equip_set(set_id)
	paused = false
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	game = current_scene
	player = game.player
	game._pending_rewards.clear()
	game.level_up_panel.visible = false
	paused = false
	game.set_process(false)
	player.base_weapon().set_process(false)
	effects = set_effects.active
	await process_frame


## 一个站着不动、不会打人的敌人
func dummy(at: Vector2, hp: float = 100000.0, elite: bool = false):
	game._run_state = game.RunState.PLAYING
	var enemy = game.spawn_enemy("draugr", at, elite, true)
	enemy.behavior = "still"
	enemy.max_hp = hp
	enemy.hp = hp
	return enemy


func hit_player(amount: float, source = null) -> float:
	player._invincible_time = 0.0
	var before: float = player.hp
	player.take_damage(amount, source)
	return before - player.hp


func run():
	if root.get_node("Save").path == "user://save.json":
		print("拒绝在真实存档上运行：加上 -- --save-file=user://test_save.json")
		quit(2)
		return
	gear_db = load("res://scripts/data/gear_db.gd")
	set_effects = load("res://scripts/gear/set_effects.gd")

	await start("")
	check(effects == null, "不穿套装时没有套装效果")
	var weapon_damage: float = player.weapon_damage()
	check(weapon_damage > 0.0, "能读到基础武器伤害")
	var foe = dummy(player.position + Vector2(400, 0))
	foe.take_damage(10.0)
	check(near(foe.max_hp - foe.hp, 10.0), "不穿套装时伤害不变")

	await start("thornoath")
	check(effects != null and effects.set_id == "thornoath", "荆誓骑士：穿齐 4 件生效")
	var attacker = dummy(player.position + Vector2(60, 0))
	var bystander = dummy(player.position + Vector2(-90, 0))
	var far = dummy(player.position + Vector2(300, 0))
	var taken := hit_player(10.0, attacker)
	check(near(taken, 10.0), "荆棘反刺：自己照常掉血")
	check(near(attacker.max_hp - attacker.hp, 10.0 * 3.0 + player.weapon_damage()), "荆棘反刺：攻击者受到 伤害×3 + 武器伤害（实际 %.1f）" % (attacker.max_hp - attacker.hp))
	check(bystander._knockback.length() > 0.0 and near(bystander.hp, bystander.max_hp), "荆棘反刺：120 像素内的敌人被推开但不掉血")
	check(far._knockback.length() == 0.0, "荆棘反刺：120 像素外的敌人不受影响")
	var hp_before: float = attacker.hp
	hit_player(10.0, attacker)
	check(near(attacker.hp, hp_before), "荆棘反刺：0.5 秒内只触发一次")

	await start("xingtian")
	check(near(hit_player(10.0), 10.0), "猛志：第一下不减伤")
	check(near(hit_player(10.0), 9.2), "猛志：1 层减 8%")
	check(near(hit_player(10.0), 8.4), "猛志：2 层减 16%")
	for i in 5:
		hit_player(1.0)
	check(effects._mengzhi == 5 and near(hit_player(10.0), 6.0), "猛志：最多 5 层减 40%")
	effects._process(9.0)
	check(effects._mengzhi == 5, "猛志：10 秒内不消失")
	effects._process(1.5)
	check(effects._mengzhi == 4, "猛志：10 秒没挨打开始逐层消失")

	await start("nightcount")
	player.hp = 50.0
	foe = dummy(player.position + Vector2(400, 0))
	foe.take_damage(200.0)
	check(near(player.hp, 52.0), "血契：回复伤害的 1%%（实际 %.2f）" % player.hp)

	await start("nemean")
	foe = dummy(player.position + Vector2(400, 0))
	var elite = dummy(player.position + Vector2(400, 100), 100000.0, true)
	foe.take_damage(100.0)
	elite.take_damage(100.0)
	check(near(foe.max_hp - foe.hp, 100.0), "十二伟业：小怪不加伤害")
	check(near(elite.max_hp - elite.hp, 135.0), "十二伟业：精英 +35%")

	await start("dragonslayer")
	check(near(hit_player(10.0), 10.0), "龙血：龙鳞没结好时照常掉血")
	effects._process(20.5)
	check(effects._scale_time <= 0.0, "龙血：20 秒结一层龙鳞")
	check(near(hit_player(10.0), 0.0), "龙血：龙鳞完全挡下一次伤害")
	check(effects._scale_time > 19.0 and near(hit_player(10.0), 10.0), "龙血：挡下后重新计时")

	await start("yellowwind")
	effects._process(5.1)
	check(effects._storms.size() == 1, "三昧神风：5 秒卷起一道沙尘暴")
	var storm = effects._storms[0]
	check(storm.position.distance_to(player.position) <= 301.0, "三昧神风：出现在身边 300 像素内")
	foe = dummy(storm.position)
	await process_frame
	await physics_frame
	foe.hp = foe.max_hp  # 前面等的两帧里可能已经跳过一次
	storm._tick = 0.0
	storm._process(0.01)
	check(near(foe.max_hp - foe.hp, player.weapon_damage() * 0.5), "三昧神风：每跳造成武器伤害的 50%%（实际 %.2f）" % (foe.max_hp - foe.hp))
	check(near(foe._hit_slow, 0.3), "三昧神风：减速 30%")
	effects._process(5.1)
	effects._process(5.1)
	check(effects._storms.size() <= 2, "三昧神风：同时最多 2 道")

	await start("grail")
	foe = dummy(player.position + Vector2(400, 0))
	foe.take_damage(100.0)
	check(near(foe.max_hp - foe.hp, 140.0), "无瑕：满血 +40%")
	player.hp -= 1.0
	foe.hp = foe.max_hp
	foe.take_damage(100.0)
	check(near(foe.max_hp - foe.hp, 100.0), "无瑕：不满血没有加成")

	await start("lotus")
	foe = dummy(player.position + Vector2(400, 0), 10000000.0)
	seed(7)
	for i in 2000:
		foe.take_damage(10.0)
	await process_frame
	await process_frame
	var ratio: float = (foe.max_hp - foe.hp) / 20000.0
	check(ratio > 1.15 and ratio < 1.25, "三头八臂：约 20%% 几率再打一次（实际 ×%.3f）" % ratio)
	foe.hp = foe.max_hp
	for i in 500:
		foe.take_dot(10.0)
	await process_frame
	check(near(foe.max_hp - foe.hp, 5000.0), "三头八臂：持续伤害不触发")
	var ult := Node.new()
	root.add_child(ult)
	player.active_ultimate = ult
	foe.hp = foe.max_hp
	for i in 500:
		foe.take_damage(10.0)
	await process_frame
	check(near(foe.max_hp - foe.hp, 5000.0), "三头八臂：大招期间不触发")
	ult.free()

	await start("valhalla")
	check(is_instance_valid(effects._guardian), "英灵分身：常驻 1 个")
	foe = dummy(player.position + Vector2(120, 0))
	var outside = dummy(player.position + Vector2(500, 0))
	for i in 150:
		await process_frame
	var hits: float = (foe.max_hp - foe.hp) / (player.weapon_damage() * 0.5)
	check(hits >= 1.0 and near(hits, roundf(hits), 0.05), "英灵分身：每一下是武器伤害的 50%%（打了 %.2f 下）" % hits)
	check(near(outside.hp, outside.max_hp), "英灵分身：不打 220 像素外的敌人")

	await start("bearskin")
	var base: float = player.weapon_cooldown()
	player.hp = player.max_hp * 0.5
	check(near(player.weapon_cooldown(), base / 1.5, 0.001), "狂暴：损失 50% 生命，出手速度 +50%")
	player.hp = player.max_hp

	# Boss 掉落和存档
	await start("")
	var save = root.get_node("Save")
	game._drop_gear(Vector2.ZERO)
	game._drop_gear(Vector2.ZERO)
	check(game.loot.size() == 2 and game.loot[0] != game.loot[1], "掉落：每个 Boss 掉一件，不重复")
	check(gear_db.items_of_level("midgard").has(game.loot[0]), "掉落：只掉这一关的套装")
	var result: Dictionary = game._finish_run(false)
	check(result.loot.size() == 2 and save.gear.has(game.loot[0]) and save.gear_new.has(game.loot[0]), "掉落：结算时收进行囊并标成新装备")
	save.equip(game.loot[0])
	save.load_game()
	check(save.gear.size() == 2 and save.equipped.size() == 1, "存档：装备和穿戴能存能读")
	for id in gear_db.items_of_level("midgard"):
		save.gear[id] = true
	game.loot.clear()
	game._drop_gear(Vector2.ZERO)
	check(game.loot.is_empty(), "掉落：这一关的都有了就不再掉")
	check(gear_db.SETS.size() == 10 and gear_db.items_of_level("helheim").size() == 12 and gear_db.items_of_level("vigrid").size() == 12, "数据：10 套，第二、三关各 3 套")
	for set_id in gear_db.SETS:
		for slot in gear_db.SLOTS:
			check(ResourceLoader.exists(gear_db.ICON_DIR + gear_db.SETS[set_id].pieces[slot].icon + ".png"), "图标存在：%s_%s" % [set_id, slot])
		check(ResourceLoader.exists(gear_db.SET_ICON_DIR + set_id + ".png"), "套装图标存在：" + set_id)

	print("GEAR_SETS checks=%d failures=%d" % [checks, failures.size()])
	paused = false
	current_scene.queue_free()
	await process_frame
	var audio_script = load("res://scripts/core/audio.gd")
	var audio = audio_script._instance
	if is_instance_valid(audio):
		for tween in audio._tweens.values(): tween.kill()
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
		audio._streams.clear()
		audio.free()
		audio_script._instance = null
	quit(1 if failures.size() > 0 else 0)
