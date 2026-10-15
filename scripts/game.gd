extends Node2D
## 一局战斗的总控：创建玩家、按时间刷怪、更新 HUD、处理死亡

const SPAWN_DISTANCE := 750.0  # 刷怪距离：略大于半个屏幕对角线，让怪物在屏幕外出现
const GRID_SIZE := 64.0
const GRID_COLOR := Color(1, 1, 1, 0.05)

# 敌人数据表。以后会挪到独立的数据文件里，现在先放这里方便理解
const ENEMY_TYPES := {
	"draugr": {"name": "尸鬼", "hp": 20.0, "speed": 70.0, "damage": 8.0, "radius": 13.0, "xp": 1, "color": Color(0.45, 0.62, 0.5)},
	"wolf": {"name": "狼", "hp": 10.0, "speed": 140.0, "damage": 5.0, "radius": 10.0, "xp": 1, "color": Color(0.62, 0.62, 0.72)},
}

var player: Player
var hud: Hud
var elapsed := 0.0
var kills := 0
var _spawn_timer := 0.0


func _ready() -> void:
	player = Player.new()
	add_child(player)
	player.died.connect(_on_player_died)

	hud = Hud.new()
	add_child(hud)
	player.hp_changed.connect(hud.set_hp)
	player.xp_changed.connect(hud.set_xp)
	hud.set_hp(player.hp, player.max_hp)
	hud.set_xp(player.xp, player.xp_to_next, player.level)


func _process(delta: float) -> void:
	elapsed += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _spawn_interval()
		_spawn_enemy()
	hud.set_stats(elapsed, kills)
	queue_redraw()  # 背景网格跟着玩家重画


## 刷怪间隔随时间缩短：开局 1 秒一只，2 分钟后到达下限 0.15 秒
func _spawn_interval() -> float:
	return maxf(0.15, 1.0 - elapsed / 120.0)


func _spawn_enemy() -> void:
	var type_id := "draugr"
	if elapsed > 30.0 and randf() < 0.4:
		type_id = "wolf"

	var enemy := Enemy.new()
	enemy.setup(ENEMY_TYPES[type_id], 1.0 + elapsed / 90.0)  # 血量随时间变强
	enemy.target = player
	var angle := randf() * TAU
	enemy.position = player.position + Vector2.from_angle(angle) * SPAWN_DISTANCE
	enemy.killed.connect(_on_enemy_killed)
	add_child(enemy)


func _on_enemy_killed(_enemy: Enemy) -> void:
	kills += 1


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
