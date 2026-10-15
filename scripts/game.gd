extends Node2D
## 一局战斗的总控：创建玩家、按时间刷怪、更新 HUD、处理死亡

const SPAWN_DISTANCE := 750.0  # 刷怪距离：略大于半个屏幕对角线，让怪物在屏幕外出现
const GRID_SIZE := 64.0
const GRID_COLOR := Color(1, 1, 1, 0.05)

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
var _pending_level_ups := 0  # 一次吃到很多经验可能连升几级，逐个弹出选择


func _ready() -> void:
	player = Player.new()
	add_child(player)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)

	hud = Hud.new()
	add_child(hud)
	player.hp_changed.connect(hud.set_hp)
	player.xp_changed.connect(hud.set_xp)
	player.ult_changed.connect(hud.set_ult)
	hud.set_hp(player.hp, player.max_hp)
	hud.set_xp(player.xp, player.xp_to_next, player.level)
	hud.set_ult(player.ult_energy, player.ult_cost)

	level_up_panel = LevelUpPanel.new()
	add_child(level_up_panel)
	level_up_panel.chosen.connect(_on_upgrade_chosen)

	process_physics_priority = -10  # 让推挤网格在所有敌人移动之前重建
	_next_elite_time = level_data.elite_from


func _process(delta: float) -> void:
	elapsed += delta
	var wave := _current_wave()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = wave.interval
		if get_tree().get_node_count_in_group("enemies") < level_data.max_enemies:
			_spawn_enemy(_pick_weighted(wave.weights), _random_spawn_position())
	_update_elites(wave)
	_update_events()
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
	var enemy := _spawn_enemy(pool.pick_random(), _random_spawn_position(), true)
	hud.announce("%s 出现了！" % enemy.display_name)


func _update_events() -> void:
	while _next_event < level_data.events.size() and elapsed >= level_data.events[_next_event].time:
		var event: Dictionary = level_data.events[_next_event]
		_next_event += 1
		if event.type == "ring":
			for i in event.count:
				var angle: float = TAU * i / event.count
				_spawn_enemy(event.enemy, player.position + Vector2.from_angle(angle) * RING_RADIUS)
		hud.announce(event.text)


func _spawn_enemy(type_id: String, pos: Vector2, elite: bool = false) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(EnemyDB.ALL[type_id], 1.0 + elapsed / level_data.hp_growth, elite)
	enemy.target = player
	enemy.position = pos
	enemy.killed.connect(_on_enemy_killed)
	add_child(enemy)
	return enemy


func _on_enemy_killed(_enemy: Enemy) -> void:
	kills += 1
	player.add_ult_energy(1.0)


func _on_player_leveled_up(_level: int) -> void:
	_pending_level_ups += 1
	if _pending_level_ups == 1:
		get_tree().paused = true
		level_up_panel.open(UpgradeDB.get_choices(player, 3), player)


func _on_upgrade_chosen(id: String) -> void:
	UpgradeDB.apply(id, player)
	hud.set_faith(player.faith)
	_pending_level_ups -= 1
	if _pending_level_ups > 0:
		level_up_panel.open(UpgradeDB.get_choices(player, 3), player)
	else:
		get_tree().paused = false


func _on_player_died() -> void:
	get_tree().paused = true
	hud.show_game_over(elapsed, kills, player.level)


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
