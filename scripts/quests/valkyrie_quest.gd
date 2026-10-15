class_name ValkyrieQuest
extends SideQuest
## 支线「瓦尔基里的试炼」：女武神在空中注视。60 秒内击杀 150 个敌人，证明你配进入英灵殿
## 试炼期间刷怪速度变为 3 倍
## 奖励：奖励点 +100，额外一次升级选择

const KILL_GOAL := 150
const SPAWN_MULT := 3.0

var _start_kills := 0


func _init() -> void:
	title = "瓦尔基里的试炼"
	offer_text = "【主神】支线剧情：女武神在空中注视，接受她的试炼吗？"
	time_limit = 60.0
	color = Color(1.0, 0.85, 0.4)


func _on_accept() -> void:
	_start_kills = game.kills
	game.spawn_mult = SPAWN_MULT


func _on_update(_delta: float) -> void:
	var count := game.kills - _start_kills
	objective = "击杀敌人  %d / %d" % [mini(count, KILL_GOAL), KILL_GOAL]
	if count >= KILL_GOAL:
		complete(true)


func _on_end() -> void:
	game.spawn_mult = 1.0


func _reward() -> String:
	game.add_reward_points(100)
	game.queue_reward("瓦尔基里的赠礼！选择一项奖励")
	return "奖励点 +100，瓦尔基里的赠礼（额外一次升级）"


func _draw_quest() -> void:
	# 女武神的注视：玩家头顶一对金色羽翼
	if state != "active":
		return
	var p := player.global_position + Vector2(0, -34)
	var spread := 4.0 * sin(_time * 3.0)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(side * (30.0 + spread), -10), p + Vector2(side * 22.0, 4)]), Color(color, 0.8))
