class_name Game
extends Node2D

signal enemy_killed(enemy: Enemy)
## 一局战斗的总控：创建玩家、按时间刷怪、更新 HUD、处理死亡
## 地图是固定大小的方形场地（LevelDB 的 map），玩家和敌人都被限制在 bounds 里

const SPAWN_DISTANCE := 750.0  # 刷怪距离：略大于半个屏幕对角线，让怪物在屏幕外出现
const GRID_SIZE := 64.0
const GRID_COLOR := Color(1, 1, 1, 0.05)

const POINTS_PER_MINUTE := 15  # 每存活 1 分钟获得的奖励点（一关 10 分钟）
const RING_RADIUS := 450.0     # 包围事件里那一圈敌人离玩家的距离
## 小怪和精英随时间变强（m 是分钟数）：血量 = 1 + HP_LINEAR × m + HP_SQUARE × m²，先慢后快，
## 3 分钟约 2.4 倍、6 分钟约 4.6 倍、9 分钟约 7.8 倍；攻击力每分钟 +DAMAGE_PER_MINUTE（10 分钟 2 倍）
const HP_LINEAR := 0.3
const HP_SQUARE := 0.05
const DAMAGE_PER_MINUTE := 0.1
const EDGE_COLOR := Color(0.03, 0.04, 0.06)  # 没有地图素材时，屏障带涂暗
enum RunState { PLAYING, ENDING, ENDED }

static var bounds := Rect2()       # 可以活动的范围
static var view_bounds := Rect2()  # 镜头能看到的范围（活动范围再加四周的屏障带）

var player: Player
var hud: Hud
var level_up_panel: LevelUpPanel
var pause_menu: PauseMenu
var elapsed := 0.0
var kills := 0
var level_id := LevelDB.selected()  # 主神空间里选的关卡
var level_data: Dictionary = LevelDB.ALL[level_id]
var _spawn_timer := 0.0
var _next_event := 0  # 下一个要触发的定时事件序号
var _next_elite_time := 0.0
## 待选择的奖励，逐个弹出。kind：level 升级或宝箱（title 是面板标题）、god 选神、path 质变、awaken 觉醒、fusion 融合技
var _pending_rewards: Array[Dictionary] = []
var boss: Boss
var _alive_by_type := {}  # 敌人 id -> 当前存活数量
var _next_boss := 0
var _defeated_bosses: Array[String] = []
var reward_points := 0   # 奖励点：局外货币（阶段 8 局外成长时使用）
var _run_recorded := false
var _run_state := RunState.PLAYING
var _codex := {"enemies": {}, "bosses": {}, "upgrades": {}}  # 本局的图鉴记录，见 _note()
var _map_layer: MapLayer
## 第 3 关：本局改写的命运（id -> 是否已发生），只会从 false 变成 true；每局开始时全部清零
var fates := {}
var ever_faith_loki := false  # 本局实际信仰过洛基（之后不再信仰也算）
var battle: VigridBattle      # 第 3 关的神明援助，其他关卡为 null
var _run_result := {}         # _finish_run 冻结下来的结算数据，结局字幕和结算界面读同一份


func _ready() -> void:
	view_bounds = Rect2(-level_data.map["size"] / 2.0, level_data.map["size"])
	bounds = view_bounds.grow(-level_data.map.border)
	MapLayer.obstacles.clear()
	if level_data.map.has("layout"):
		_map_layer = load(level_data.map.layout).new()
		_map_layer.map = level_data.map
		add_child(_map_layer)
	add_child(FxLayer.new())  # 伤害数字和碎片特效
	Audio.music(level_data.music)

	player = Player.new()
	player.character_id = CharacterDB.selected()  # 主神空间里选的角色
	add_child(player)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	player.god_added.connect(_on_god_added)
	for id: String in level_data.get("fates", []):
		fates[id] = false
	if not fates.is_empty():
		battle = VigridBattle.new()
		battle.game = self
		battle.player = player
		add_child(battle)
	MetaDB.apply(player)  # 主神空间购买的永久强化
	add_child(SupplyDrops.new())
	if level_data.map.has("mist"):  # 第 2 关的冥雾
		var mist := Mist.new()
		mist.player = player
		mist.setup(level_data.map.mist)
		add_child(mist)

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

	pause_menu = PauseMenu.new()
	pause_menu.game = self
	pause_menu.abandon_requested.connect(_on_abandon_requested)
	add_child(pause_menu)

	process_physics_priority = -10  # 让推挤网格在所有敌人移动之前重建
	Enemy.crit_chance = 0.0
	GodPower.fusions.clear()
	_queue_reward.call_deferred({"kind": "god"})  # 开局先选第一位神
	_next_elite_time = level_data.elite_from


func _process(delta: float) -> void:
	if not is_running():
		return
	elapsed += delta
	var wave := _current_wave()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = wave.interval * (2.0 if is_instance_valid(boss) else 1.0)  # Boss 战时小怪减半
		if get_tree().get_node_count_in_group("enemies") < level_data.max_enemies:
			var type_id := _pick_weighted(wave.weights)
			if _alive_by_type.get(type_id, 0) >= EnemyDB.ALL[type_id].get("max_alive", INF):
				type_id = level_data.get("base_enemy", "draugr")
			var pos := _random_spawn_position()
			var pack: int = EnemyDB.ALL[type_id].get("pack", 1)  # 成群出现的敌人一次刷一堆
			for i in pack:
				spawn_enemy(type_id, pos + Vector2.from_angle(TAU * i / pack) * (18.0 * sqrt(pack) if pack > 1 else 0.0))
	_update_elites(wave)
	_update_events()
	_update_bosses()
	hud.set_stats(elapsed, kills)
	queue_redraw()  # 背景网格跟着玩家重画


func _physics_process(_delta: float) -> void:
	if not is_running():
		return
	for node in get_tree().get_nodes_in_group("enemies"):  # 冲锋、击退都不能把敌人推出地图，也不能穿过长屋、岩石
		var enemy := node as Enemy
		var corrected := clamp_to_map(enemy.position, enemy.radius)
		if not enemy.ghost:
			corrected = MapLayer.push_out(corrected, enemy.radius)
		if corrected != enemy.position:
			enemy.position = corrected


## 把位置限制在地图里，margin 是离边缘至少多远
static func clamp_to_map(pos: Vector2, margin: float = 0.0) -> Vector2:
	if not bounds.has_area():
		return pos
	return pos.clamp(bounds.position + Vector2.ONE * margin, bounds.end - Vector2.ONE * margin)


## 在 center 周围 distance 远的地方找一个地图内的点（随机方向，靠墙时换方向再试）
func _point_around(center: Vector2, distance: float) -> Vector2:
	var inner := bounds.grow(-40.0)
	for i in 12:
		var p := center + Vector2.from_angle(randf() * TAU) * distance
		if inner.has_point(p):
			return p
	for i in 16:
		var p := center + Vector2.from_angle(TAU * i / 16.0) * distance
		if inner.has_point(p):
			return p
	return clamp_to_map(center + Vector2.from_angle(randf() * TAU) * distance, 40.0)


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
	return _point_around(player.position, SPAWN_DISTANCE)


func _update_elites(wave: Dictionary) -> void:
	if elapsed < _next_elite_time:
		return
	_next_elite_time += level_data.elite_every
	var pool: Array = level_data.elite_pool.filter(func(id: String) -> bool: return wave.weights.has(id))
	if pool.is_empty():
		return
	var enemy := spawn_enemy(pool.pick_random(), _random_spawn_position(), true)
	if enemy:
		hud.announce(tr("%s 出现了！") % enemy.display_name)


func _update_events() -> void:
	while _next_event < level_data.events.size() and elapsed >= level_data.events[_next_event].time:
		var event: Dictionary = level_data.events[_next_event]
		_next_event += 1
		if event.type == "ring":
			for i in event.count:
				var angle: float = TAU * i / event.count
				spawn_enemy(event.enemy, clamp_to_map(player.position + Vector2.from_angle(angle) * RING_RADIUS, 40.0))
		hud.announce(tr(event.text))


## required 只用于 Boss 机制的必需目标，允许越过常规敌人上限
func spawn_enemy(type_id: String, pos: Vector2, elite: bool = false, required: bool = false) -> Enemy:
	if not is_running() or (not required and get_tree().get_node_count_in_group("enemies") >= level_data.max_enemies):
		return null
	var data: Dictionary = EnemyDB.ALL[type_id]
	var enemy: Enemy = load(data.script).new() if data.has("script") else Enemy.new()
	enemy.setup(type_id, enemy_hp_scale(), elite, enemy_damage_scale())
	enemy.target = player
	enemy.position = clamp_to_map(pos, enemy.radius)
	if not enemy.ghost:
		enemy.position = MapLayer.push_out(enemy.position, enemy.radius)
	enemy.killed.connect(_on_enemy_killed)
	add_child(enemy)
	_alive_by_type[type_id] = _alive_by_type.get(type_id, 0) + 1
	return enemy


func _on_enemy_killed(enemy: Enemy) -> void:
	if not enemy is Boss:
		_note("enemies", enemy.type_id, 1)
	if player.frenzy_time > 0.0:  # 狂野西部秀：击杀回血
		player.heal(1.0)
	_alive_by_type[enemy.type_id] = _alive_by_type.get(enemy.type_id, 1) - 1
	kills += 1
	player.add_ult_energy(1.0)
	enemy_killed.emit(enemy)


## 关卡可以用 enemy_growth 覆盖成长系数（只有第 3 关设置了），没设置的用上面的常量
func enemy_hp_scale() -> float:
	var m := elapsed / 60.0
	var growth: Dictionary = level_data.get("enemy_growth", {})
	return 1.0 + growth.get("hp_linear", HP_LINEAR) * m + growth.get("hp_square", HP_SQUARE) * m * m


func enemy_damage_scale() -> float:
	return 1.0 + level_data.get("enemy_growth", {}).get("damage_per_minute", DAMAGE_PER_MINUTE) * elapsed / 60.0


## 不算击杀地移除一个敌人（例如逃走了），不掉经验
func despawn_enemy(enemy: Enemy) -> void:
	if enemy._dead:
		return
	_alive_by_type[enemy.type_id] = _alive_by_type.get(enemy.type_id, 1) - 1
	enemy._dead = true
	enemy.remove_from_group("enemies")
	enemy.update_spatial_index()
	enemy.queue_free()


func _update_bosses() -> void:
	var bosses: Array = level_data.bosses
	if _next_boss >= bosses.size() or elapsed < bosses[_next_boss].time:
		return
	if is_instance_valid(boss):
		return  # 上一个 Boss 还没被击败，等它
	var id: String = bosses[_next_boss].id
	_next_boss += 1
	boss = BossDB.create(id, 1.0 + elapsed / level_data.boss_hp_growth)
	if boss == null:
		return
	boss.target = player
	boss.spawner = spawn_enemy
	boss.defeated_bosses = _defeated_bosses
	boss.position = _point_around(player.position, 520.0)
	boss.killed.connect(_on_enemy_killed)
	boss.hp_changed.connect(hud.set_boss_hp)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)
	_note("bosses", id, 0)
	hud.show_boss(boss.display_name, boss.title, boss.max_hp)
	hud.announce(boss.intro_line)
	Audio.sfx("boss_warning")
	Audio.music("boss")
	player.shake(8.0, 0.4)


## 按 id 找地标，没有就返回空字典
func landmark_by_id(id: String) -> Dictionary:
	for landmark: Dictionary in level_data.map.landmarks:
		if landmark.get("id", "") == id:
			return landmark
	return {}


## 图鉴记录：本局遇到的东西，一局结束时写进存档
func _note(category: String, id: String, count: int) -> void:
	_codex[category][id] = _codex[category].get(id, 0) + count


func add_reward_points(amount: int) -> void:
	reward_points += amount


## 一局结束：结算存活时间和通关奖励，写进存档，返回结算界面要显示的数据
## 只结算一次：之后再调用（结局字幕跳过、重复回调）都返回第一次冻结的同一份数据
func _finish_run(cleared: bool) -> Dictionary:
	if _run_recorded:
		return _run_result
	_run_recorded = true
	add_reward_points(int(elapsed / 60.0) * POINTS_PER_MINUTE)
	if cleared:
		add_reward_points(level_data.clear_reward + fate_count() * VigridTuning.FATE_REWARD)
	Save.record_codex(_codex)
	if not fates.is_empty():
		Save.record_fates(level_id, fates, ever_faith_loki)
	Save.record_run(level_id, reward_points, cleared, elapsed, kills)
	_run_result = {"elapsed": elapsed, "kills": kills, "level": player.level,
		"reward_points": reward_points, "reward_total": Save.reward_points}
	if not fates.is_empty():
		_run_result.merge({"fates": fates.duplicate(), "fate_count": fate_count(), "ever_faith_loki": ever_faith_loki})
	return _run_result


## 命运真的发生了（托尔活下来、维达介入、弗雷参战）。每种只记一次，返回这次是不是第一次
func confirm_fate(id: String) -> bool:
	if not is_running() or not fates.has(id) or fates[id]:
		return false
	fates[id] = true
	return true


func fate_count() -> int:
	return fates.values().count(true)


func _on_god_added(god_id: String) -> void:
	if god_id == "loki":
		ever_faith_loki = true


func _on_boss_defeated(defeated_boss: Boss) -> void:
	if not is_running() or _defeated_bosses.has(defeated_boss.type_id):
		return
	_defeated_bosses.append(defeated_boss.type_id)
	_note("bosses", defeated_boss.type_id, 1)
	hud.hide_boss()
	var all_defeated: bool = _defeated_bosses.size() >= level_data.bosses.size()
	if not all_defeated:
		Audio.music(level_data.music)
	hud.announce(defeated_boss.defeat_line)
	add_reward_points(defeated_boss.reward_points)
	FxLayer.floating_text(defeated_boss.global_position + Vector2(0, -60), tr("奖励点 +%d") % defeated_boss.reward_points, Color(1.0, 0.85, 0.4))
	if all_defeated:
		_begin_ending()
		get_tree().create_timer(3.0).timeout.connect(_on_level_cleared)  # 留 3 秒看击败演出
		return
	var chest := Chest.new()
	chest.player = player
	chest.position = defeated_boss.position
	chest.opened.connect(queue_reward.bind(tr("宝箱！选择一项奖励")))
	add_child.call_deferred(chest)
	# 再撒一圈大经验宝石
	for i in 5:
		var gem := XpGem.new()
		gem.value = EnemyDB.ELITE_XP
		gem.big = true
		gem.player = player
		gem.position = defeated_boss.position + Vector2.from_angle(TAU * i / 5) * 60.0
		add_child.call_deferred(gem)


func _on_player_leveled_up(level: int) -> void:
	Audio.sfx("level_up")
	if UpgradeDB.GOD_LEVELS.has(level) and player.faith.size() < UpgradeDB.MAX_GODS:
		_queue_reward({"kind": "god"})  # 5、10、15 级：选一位新的神
	else:
		queue_reward("")


## 加入一次升级选择（宝箱也用它），title 是面板标题，空字符串 = 普通升级
func queue_reward(title: String) -> void:
	_queue_reward({"kind": "level", "title": title})


## 加入一次奖励选择。如果当前没有在选，就暂停游戏并弹出面板
func _queue_reward(entry: Dictionary) -> void:
	if not is_running():
		return
	_pending_rewards.append(entry)
	if _pending_rewards.size() == 1:
		get_tree().paused = true
		_open_reward()


func _open_reward() -> void:
	if not is_running() or _pending_rewards.is_empty():
		return
	var entry: Dictionary = _pending_rewards[0]
	level_up_panel.open(_offers(entry), player, entry)
	match entry.kind:  # 选神、质变、觉醒、融合技各有一段提示音，没有素材时借用升级音效
		"god", "path":
			Audio.sfx_or(entry.kind + "_choose", "level_up")
		"awaken", "fusion":
			Audio.sfx_or(entry.kind, "level_up")


func _offers(entry: Dictionary) -> Array[Dictionary]:
	match entry.kind:
		"god":
			return UpgradeDB.god_choices(player, player.choice_count)
		"path":
			return UpgradeDB.path_choices(entry.god)
		"awaken":
			return UpgradeDB.awaken_choice(player.gods[entry.god].path)
		"fusion":
			return [{"id": "fusion_" + entry.fusion, "rarity": -1}]
	return UpgradeDB.get_choices(player, player.choice_count, elapsed / 60.0)


func _on_upgrade_chosen(offer: Dictionary) -> void:
	if not is_running() or _pending_rewards.is_empty():
		return
	UpgradeDB.apply(offer, player)
	_note("upgrades", offer.id, 1)
	_pending_rewards.pop_front()
	_check_faith()
	hud.set_faith(player)
	if not _pending_rewards.is_empty():
		_open_reward()
	else:
		get_tree().paused = false


## 信仰到 6 弹出质变、到 12 弹出觉醒；两位神都觉醒后弹出他们的融合技。插在其他奖励前面
func _check_faith() -> void:
	var at := 1 if level_up_panel.visible else 0  # 面板正开着时，排在当前这一次后面
	for god: String in player.faith:
		var power: GodPower = player.gods[god]
		var faith: int = player.faith[god]
		if faith >= UpgradeDB.FAITH_PATH and power.path == "" and not _is_pending("path", god):
			_pending_rewards.insert(at, {"kind": "path", "god": god})
			at += 1
		elif faith >= UpgradeDB.FAITH_AWAKEN and power.path != "" and not power.awakened and not _is_pending("awaken", god):
			_pending_rewards.insert(at, {"kind": "awaken", "god": god})
			at += 1
	var gods: Array = player.gods.keys()
	for i in gods.size():
		for j in range(i + 1, gods.size()):
			var fusion := Gods.fusion_between(gods[i], gods[j])
			if fusion == "" or GodPower.has_fusion(fusion) or _is_pending("fusion", fusion):
				continue
			if player.gods[gods[i]].awakened and player.gods[gods[j]].awakened:
				_pending_rewards.insert(at, {"kind": "fusion", "fusion": fusion})
				at += 1


func _is_pending(kind: String, key: String) -> bool:
	return _pending_rewards.any(func(e: Dictionary) -> bool: return e.kind == kind and (e.get("god", "") == key or e.get("fusion", "") == key))


func _on_reroll_requested() -> void:
	if not is_running() or player.rerolls <= 0 or _pending_rewards.is_empty() or not ["level", "god"].has(_pending_rewards[0].kind):
		return
	player.rerolls -= 1
	_open_reward()


func is_running() -> bool:
	return _run_state == RunState.PLAYING


func _begin_ending() -> void:
	_run_state = RunState.ENDING
	get_tree().paused = true
	_pending_rewards.clear()
	level_up_panel.visible = false
	if is_instance_valid(pause_menu):
		pause_menu.close()
	if is_instance_valid(FxLayer.instance):
		FxLayer.instance.process_mode = Node.PROCESS_MODE_ALWAYS


func _on_level_cleared() -> void:
	if _run_state == RunState.ENDED:
		return
	_begin_ending()
	_run_state = RunState.ENDED
	Audio.music("victory")
	var run := _finish_run(true)  # 先冻结结算并存档，结局字幕怎么推进、跳过都不会再结算一次
	var story := tr(level_data.clear_text) if level_data.clear_text != "" else ""
	var beats := load_ending(level_data.get("ending", ""))
	if beats.is_empty():
		hud.show_result("victory", tr(level_data.name), story, run, player)
		return
	Audio.sfx("milestone")  # 篇章完成：整段结局只响一次
	hud.show_ending(beats, hud.show_result.bind("victory", tr(level_data.name), story, run, player))


## 读取篇章结局的分段字幕（K7 交接的 ending_timeline.json），字段不对就返回空数组，直接显示结算
static func load_ending(path: String) -> PackedStringArray:
	var beats := PackedStringArray()
	if path == "" or not FileAccess.file_exists(path):
		return beats
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("format_version") != 1.0 or not data.get("beats") is Array:
		push_error("结局字幕格式不对：" + path)
		return beats
	var list: Array = data.beats
	for i in list.size():
		var beat: Variant = list[i]
		if not beat is Dictionary or beat.get("index") != float(i) or not beat.get("text") is String or beat.text == "":
			push_error("结局字幕第 %d 段格式不对：%s" % [i, path])
			return PackedStringArray()
		beats.append(beat.text)
	return beats


func _on_abandon_requested() -> void:
	if not is_running():
		return
	_begin_ending()
	_run_state = RunState.ENDED
	hud.show_result("abandon", tr(level_data.name), "", _finish_run(false), player)


func _on_player_died() -> void:
	if not is_running():
		return
	if player.revives > 0:
		player.revive()
		hud.announce(tr("【主神】主神的眷顾：复活！"))
		return
	_begin_ending()
	player.play_death()  # 画面定格，只有玩家播完倒地动作再结算
	var delay := player.death_duration()
	Audio.music("defeat")
	if delay > 0.0:
		await get_tree().create_timer(delay + 0.4).timeout
	_run_state = RunState.ENDED
	hud.show_result("death", tr(level_data.name), "", _finish_run(false), player)


func _draw() -> void:
	if player == null or _map_layer:
		return
	var view := get_canvas_transform().affine_inverse() * get_viewport_rect()  # 镜头看到的范围
	# 没有地图素材时，地图内画网格，这样移动时能看出位移
	var area := view.intersection(bounds)
	var x := ceilf(area.position.x / GRID_SIZE) * GRID_SIZE
	while x < area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), GRID_COLOR)
		x += GRID_SIZE
	var y := ceilf(area.position.y / GRID_SIZE) * GRID_SIZE
	while y < area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), GRID_COLOR)
		y += GRID_SIZE
	# 屏障带涂暗，边缘画一圈边线
	for outside: Rect2 in [Rect2(view.position.x, view.position.y, view.size.x, bounds.position.y - view.position.y),
			Rect2(view.position.x, bounds.end.y, view.size.x, view.end.y - bounds.end.y),
			Rect2(view.position.x, view.position.y, bounds.position.x - view.position.x, view.size.y),
			Rect2(bounds.end.x, view.position.y, view.end.x - bounds.end.x, view.size.y)]:
		if outside.size.x > 0.0 and outside.size.y > 0.0:
			draw_rect(outside, EDGE_COLOR)
	draw_rect(bounds, Color(0.75, 0.85, 1.0, 0.35), false, 3.0)
