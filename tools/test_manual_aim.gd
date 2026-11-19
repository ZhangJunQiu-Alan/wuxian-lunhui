extends SceneTree
## 手动瞄准回归：四个角色都只在玩家按攻击时出手，朝鼠标方向；大招按房间范围算。
## 用法：godot --headless --path . --log-file /dev/null --script res://tools/test_manual_aim.gd -- --save-file=user://test_save.json --settings-file=user://test_settings.cfg

var checks := 0
var failures := 0
var game: Node
var player


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func start(character: String) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	paused = false
	root.get_node("Save").selected_character = character
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)  # 不刷怪
	await process_frame
	game.level_up_panel.choose(0)
	game._pending_rewards.clear()
	game.pause_menu.free()
	paused = false
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()
	player = game.player
	for power in player.gods.values():
		power.free()  # 只看基础武器
	player.gods.clear()
	await wait(0.6)  # 开局的武器冷却走完


func dummy(offset: Vector2):
	var enemy = load("res://scripts/entities/enemy.gd").new()
	enemy.setup("draugr", 1.0)
	enemy.target = player
	enemy.position = player.position + offset
	enemy.hp = 10000.0
	game.add_child(enemy)
	enemy.freeze(1000.0)  # 站着不动、不打人；不关掉处理，子弹要靠它登记位置才打得中
	return enemy


## 在屏幕上点一下世界坐标 point（按下和松开在同一帧，和真实单击一样）
func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = player.get_canvas_transform() * point
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func run() -> void:
	if root.get_node("Save").path == "user://save.json" or root.get_node("Settings").path == "user://settings.cfg":
		push_error("Use isolated --save-file and --settings-file")
		quit(2)
		return
	for character in ["swordsman", "gunslinger", "assassin", "mage"]:
		await start(character)
		check(not player.auto_attack, character + " starts with manual aim")
		var right = dummy(Vector2(60, 0))
		await wait(1.0)
		check(right.hp == 10000.0, character + " does not attack without input")
		if character != "mage":  # 奥术新星以自身为中心，没有方向
			click(player.position + Vector2(-120, 0))
			await wait(0.5)
			check(right.hp == 10000.0, character + " aiming away does not hit (%.0f)" % right.hp)
			await wait(1.2)
		click(player.position + Vector2(120, 0))
		await wait(0.6)
		check(right.hp < 10000.0, character + " aimed click hits the enemy in front")
		right.free()

	# 大招按房间算：房间角落里、镜头外的敌人也会中（房间外的敌人不中见 test_combat_art；主游戏里敌人出不了活动范围）
	await start("swordsman")
	var room: Rect2 = load("res://scripts/game.gd").bounds
	var near = dummy(Vector2(90, 0))
	var far_inside = dummy(room.end - player.position - Vector2(60, 60))
	load("res://scripts/ultimates/dimension_slash.gd").cast(player)
	await wait(1.6)
	check(near.hp < 10000.0, "dimension slash hits the enemy beside the player")
	check(far_inside.hp < 10000.0, "dimension slash reaches the far corner of the room, off camera")
	print("MANUAL_AIM_RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
