class_name Game
extends Node2D
## 一局战斗的总控：创建玩家、按时间刷怪、更新 HUD、处理死亡

const SPAWN_DISTANCE := 750.0  # 刷怪距离：略大于半个屏幕对角线，让怪物在屏幕外出现
const GRID_SIZE := 64.0
const GRID_COLOR := Color(1, 1, 1, 0.05)

const POINTS_PER_MINUTE := 10  # 每存活 1 分钟获得的奖励点
const RING_RADIUS := 450.0     # 包围事件里那一圈敌人离玩家的距离

var player: Player
var hud: Hud
var level_up_panel: LevelUpPanel
var elapsed := 0.0
var kills := 0
var level_data: Dictionary = LevelDB.NORSE_1
var _spawn_timer := 0.0
var _next_event := 0  # 下一个要触发的定时事件序号
var _next_elite_time := 0.0
var _pending_rewards: Array[String] = []  # 待选择的奖励（升级或宝箱），逐个弹出；内容是面板标题，空字符串 = 普通升级
var boss: Boss
var _alive_by_type := {}  # 敌人 id -> 当前存活数量
var _next_boss := 0
var _defeated_bosses: Array[String] = []
var spawn_mult := 1.0  # 刷怪速度倍率（瓦尔基里的试炼会临时提高）
var reward_points := 0   # 奖励点：局外货币（阶段 8 局外成长时使用）
var story_points := 0    # 支线剧情点：稀有货币
var quest: SideQuest     # 当前的支线（同一时间最多一个）
var _quest_queue: Array = []
var _next_quest_slot := 0
var _quests_done := 0
var _quests_seen := 0
var _run_recorded := false


func _ready() -> void:
	add_child(FxLayer.new())  # 伤害数字和碎片特效

	player = Player.new()
	player.character_id = CharacterDB.selected()  # 主神空间里选的角色
	add_child(player)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	MetaDB.apply(player)  # 主神空间购买的永久强化

	hud = Hud.new()
	hud.character_id = player.character_id
	add_child(hud)
	player.hp_changed.connect(hud.set_hp)
	player.xp_changed.connect(hud.set_xp)
	player.ult_changed.connect(hud.set_ult)
	player.ult_cast.connect(hud.show_cutin)
	hud.set_hp(player.hp, player.max_hp)
	hud.set_xp(player.xp, player.xp_to_next, player.level)
	hud.set_ult(player.ult_energy, player.ult_cost)

	level_up_panel = LevelUpPanel.new()
	add_child(level_up_panel)
	level_up_panel.chosen.connect(_on_upgrade_chosen)
	level_up_panel.reroll_requested.connect(_on_reroll_requested)

	process_physics_priority = -10  # 让推挤网格在所有敌人移动之前重建
	_next_elite_time = level_data.elite_from
	_quest_queue = level_data.quests.duplicate()
	_quest_queue.shuffle()


func _process(delta: float) -> void:
	elapsed += delta
	var wave := _current_wave()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = wave.interval * (2.0 if is_instance_valid(boss) else 1.0) / spawn_mult  # Boss 战时小怪减半
		if get_tree().get_node_count_in_group("enemies") < level_data.max_enemies:
			var type_id := _pick_weighted(wave.weights)
			if _alive_by_type.get(type_id, 0) >= EnemyDB.ALL[type_id].get("max_alive", INF):
				type_id = "draugr"
			spawn_enemy(type_id, _random_spawn_position())
	_update_elites(wave)
	_update_events()
	_update_bosses()
	_update_quests()
	hud.set_stats(elapsed, kills)
	queue_redraw()  # 背景网格跟着玩家重画


func _physics_process(_delta: float) -> void:
	Enemy.rebuild_grid(get_tree())


## 当前时间对应的刷怪阶段
func _current_wave() -> Dictionary:
	var current: Dictionary = level_data.waves[0]
	for wave: Dictionary in level_data.waves:
		if elapsed >= wave.from:
			current = wave
	return current


## 按权重随机挑一种敌人，例如 {"draugr": 3, "wolf": 1} 有 75% 是尸鬼
func _pick_weighted(weights: Dictionary) -> String:
	var total := 0.0
	for w in weights.values():
		total += w
	var roll := randf() * total
	for id: String in weights:
		roll -= weights[id]
		if roll <= 0.0:
			return id
	return weights.keys()[0]


func _random_spawn_position() -> Vector2:
	return player.position + Vector2.from_angle(randf() * TAU) * SPAWN_DISTANCE


func _update_elites(wave: Dictionary) -> void:
	if elapsed < _next_elite_time:
		return
	_next_elite_time += level_data.elite_every
	var pool: Array = level_data.elite_pool.filter(func(id: String) -> bool: return wave.weights.has(id))
	if pool.is_empty():
		return
	var enemy := spawn_enemy(pool.pick_random(), _random_spawn_position(), true)
	hud.announce("%s 出现了！" % enemy.display_name)


func _update_events() -> void:
	while _next_event < level_data.events.size() and elapsed >= level_data.events[_next_event].time:
		var event: Dictionary = level_data.events[_next_event]
		_next_event += 1
		if event.type == "ring":
			for i in event.count:
				var angle: float = TAU * i / event.count
				spawn_enemy(event.enemy, player.position + Vector2.from_angle(angle) * RING_RADIUS)
		hud.announce(event.text)


func spawn_enemy(type_id: String, pos: Vector2, elite: bool = false) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(type_id, 1.0 + elapsed / level_data.hp_growth, elite)
	enemy.target = player
	enemy.position = pos
	enemy.killed.connect(_on_enemy_killed)
	add_child(enemy)
	_alive_by_type[type_id] = _alive_by_type.get(type_id, 0) + 1
	return enemy


func _on_enemy_killed(enemy: Enemy) -> void:
	if player.frenzy_time > 0.0:  # 狂野西部秀：击杀回血
		player.heal(1.0)
	_alive_by_type[enemy.type_id] = _alive_by_type.get(enemy.type_id, 1) - 1
	kills += 1
	player.add_ult_energy(1.0)


func _update_bosses() -> void:
	var bosses: Array = level_data.bosses
	if _next_boss >= bosses.size() or elapsed < bosses[_next_boss].time:
		return
	var id: String = bosses[_next_boss].id
	_next_boss += 1
	boss = BossDB.create(id, 1.0 + elapsed / level_data.hp_growth)
	if boss == null:
		return
	boss.target = player
	boss.spawner = spawn_enemy
	boss.defeated_bosses = _defeated_bosses
	boss.position = player.position + Vector2.from_angle(randf() * TAU) * 520.0
	boss.killed.connect(_on_enemy_killed)
	boss.hp_changed.connect(hud.set_boss_hp)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)
	hud.show_boss(boss.display_name, boss.title, boss.max_hp)
	hud.announce(boss.intro_line)
	player.shake(8.0, 0.4)


func _update_quests() -> void:
	if is_instance_valid(quest):
		hud.show_quest(quest)
		return
	var slots: Array = level_data.quest_slots
	if _next_quest_slot >= slots.size() or elapsed < slots[_next_quest_slot] or is_instance_valid(boss) or _quest_queue.is_empty():
		return
	_next_quest_slot += 1
	quest = QuestDB.create(_quest_queue.pop_front())
	if quest == null:
		return
	_quests_seen += 1
	quest.game = self
	quest.player = player
	quest.finished.connect(_on_quest_finished)
	add_child(quest)
	hud.announce(quest.offer_text)


func _on_quest_finished(finished_quest: SideQuest, success: bool) -> void:
	hud.hide_quest()
	if success:
		_quests_done += 1
		hud.announce("【主神】支线剧情完成：%s。%s" % [finished_quest.title, finished_quest._reward()])
	elif finished_quest.was_accepted:
		hud.announce("【主神】支线剧情失败：" + finished_quest.title)
	else:
		hud.announce("错过了支线剧情：" + finished_quest.title)


func add_reward_points(amount: int) -> void:
	reward_points += amount


func add_story_points(amount: int) -> void:
	story_points += amount


## 一局结束：结算存活时间和通关奖励，写进存档，返回结算界面上显示的文字
func _finish_run(cleared: bool) -> String:
	if not _run_recorded:
		_run_recorded = true
		add_reward_points(int(elapsed / 60.0) * POINTS_PER_MINUTE)
		if cleared:
			add_reward_points(level_data.clear_reward)
		Save.record_run(reward_points, story_points, cleared, elapsed, kills, _quests_done)
	return "支线完成 %d / %d\n本局获得：奖励点 +%d　支线剧情点 +%d\n累计：奖励点 %d　支线剧情点 %d" % [
		_quests_done, _quests_seen, reward_points, story_points, Save.reward_points, Save.story_points]


func _on_boss_defeated(defeated_boss: Boss) -> void:
	_defeated_bosses.append(defeated_boss.type_id)
	hud.hide_boss()
	hud.announce(defeated_boss.defeat_line)
	add_reward_points(defeated_boss.reward_points)
	FxLayer.floating_text(defeated_boss.global_position + Vector2(0, -60), "奖励点 +%d" % defeated_boss.reward_points, Color(1.0, 0.85, 0.4))
	if defeated_boss.type_id == level_data.final_boss:
		get_tree().create_timer(3.0).timeout.connect(_on_level_cleared)  # 留 3 秒看击败演出
		return
	var chest := Chest.new()
	chest.player = player
	chest.position = defeated_boss.position
	chest.opened.connect(queue_reward.bind("宝箱！选择一项奖励"))
	add_child.call_deferred(chest)
	# 再撒一圈大经验宝石
	for i in 5:
		var gem := XpGem.new()
		gem.value = EnemyDB.ELITE_XP
		gem.big = true
		gem.player = player
		gem.position = defeated_boss.position + Vector2.from_angle(TAU * i / 5) * 60.0
		add_child.call_deferred(gem)


func _on_player_leveled_up(_level: int) -> void:
	queue_reward("")


## 加入一次奖励选择。如果当前没有在选，就暂停游戏并弹出面板
func queue_reward(title: String) -> void:
	_pending_rewards.append(title)
	if _pending_rewards.size() == 1:
		get_tree().paused = true
		level_up_panel.open(UpgradeDB.get_choices(player, player.choice_count), player, title)


func _on_upgrade_chosen(id: String) -> void:
	UpgradeDB.apply(id, player)
	hud.set_faith(player.faith)
	_pending_rewards.pop_front()
	if not _pending_rewards.is_empty():
		level_up_panel.open(UpgradeDB.get_choices(player, player.choice_count), player, _pending_rewards[0])
	else:
		get_tree().paused = false


func _on_reroll_requested() -> void:
	if player.rerolls <= 0 or _pending_rewards.is_empty():
		return
	player.rerolls -= 1
	level_up_panel.open(UpgradeDB.get_choices(player, player.choice_count), player, _pending_rewards[0])


func _on_level_cleared() -> void:
	if player.is_dead:
		return
	get_tree().paused = true
	hud.show_victory(level_data.name, level_data.clear_text, elapsed, kills, player.level, _finish_run(true))


func _on_player_died() -> void:
	if player.revives > 0:
		player.revive()
		hud.announce("【主神】主神的眷顾：复活！")
		return
	get_tree().paused = true
	hud.show_game_over(elapsed, kills, player.level, _finish_run(false))


func _draw() -> void:
	# 画一个跟随玩家的网格地面，这样移动时能看出位移
	if player == null:
		return
	var c := player.position
	var x := floorf((c.x - 700.0) / GRID_SIZE) * GRID_SIZE
	while x < c.x + 700.0:
		draw_line(Vector2(x, c.y - 420.0), Vector2(x, c.y + 420.0), GRID_COLOR)
		x += GRID_SIZE
	var y := floorf((c.y - 420.0) / GRID_SIZE) * GRID_SIZE
	while y < c.y + 420.0:
		draw_line(Vector2(c.x - 700.0, y), Vector2(c.x + 700.0, y), GRID_COLOR)
		y += GRID_SIZE
