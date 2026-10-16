class_name SideQuest
extends Node2D
## 支线剧情基类
## 流程：主神在地图上放一个发光标记（offered）→ 玩家走过去接受（active）→ 限时内完成目标 → 结束（done）
## 标记一段时间没人接就消失。每个具体支线继承它，实现：
##   _on_accept()    接受时做什么（刷怪、放置物件）
##   _on_update()    每帧检查目标，更新 objective，完成时调用 complete(true)
##   _reward()       完成后发奖励，返回奖励说明文字
##   _draw_quest()   画任务物件（篝火、渡鸦……）
##   _active_targets() 进行中时，屏幕边缘箭头要指向哪些位置
##
## 这个节点放在世界原点，所以画图时直接用世界坐标

signal finished(quest: SideQuest, success: bool)

const OFFER_TIME := 40.0        # 标记存在多久，没接就消失
const ACCEPT_DISTANCE := 40.0
const MARKER_DISTANCE := 380.0  # 标记出现在离玩家多远的地方

var title := ""
var offer_text := ""     # 标记出现时主神的播报
var objective := ""      # 任务目标，显示在右侧任务面板
var time_limit := 60.0
var color := Color(1.0, 0.85, 0.4)
var game: Game
var player: Player
var marker_pos := Vector2.ZERO
var landmark := {}  # 支线所在的地标（LevelDB 的 map.landmarks），为空时出现在玩家附近
var state := "offered"
var time_left := 0.0
var was_accepted := false
var _offer_left := OFFER_TIME
var _time := 0.0


func _ready() -> void:
	z_index = -1  # 画在敌人和玩家下面
	if landmark.is_empty():
		marker_pos = player.global_position + Vector2.from_angle(randf() * TAU) * MARKER_DISTANCE
	else:
		marker_pos = landmark.pos + Vector2.from_angle(randf() * TAU) * randf() * landmark.radius * 0.4
		_offer_left += player.global_position.distance_to(marker_pos) / player.move_speed  # 地标越远，留给玩家赶路的时间越多
	marker_pos = Game.clamp_to_map(marker_pos, 80.0)
	objective = "前往标记处接受支线"


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	match state:
		"offered":
			_offer_left -= delta
			if player.global_position.distance_to(marker_pos) < ACCEPT_DISTANCE:
				state = "active"
				was_accepted = true
				time_left = time_limit
				_on_accept()
			elif _offer_left <= 0.0:
				complete(false)
		"active":
			time_left -= delta
			_on_update(delta)
			if state == "active" and time_left <= 0.0:
				complete(false)


func complete(success: bool) -> void:
	if state == "done":
		return
	state = "done"
	_on_end()
	finished.emit(self, success)
	queue_free()


## 屏幕边缘箭头要指向的位置
func pointer_targets() -> Array[Vector2]:
	if state == "offered":
		var targets: Array[Vector2] = [marker_pos]
		return targets
	return _active_targets()


func _on_accept() -> void:
	pass


func _on_update(_delta: float) -> void:
	pass


## 结束时（无论成败）的清理
func _on_end() -> void:
	pass


func _reward() -> String:
	return ""


func _active_targets() -> Array[Vector2]:
	return []


func _draw_quest() -> void:
	pass


func _draw() -> void:
	_draw_quest()
	if state == "offered":
		# 光柱标记：一束上下浮动的光
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_circle(marker_pos, 30.0 + 6.0 * pulse, Color(color, 0.15))
		draw_rect(Rect2(marker_pos + Vector2(-6, -140), Vector2(12, 140)), Color(color, 0.25 + 0.2 * pulse))
		draw_arc(marker_pos, ACCEPT_DISTANCE, 0.0, TAU, 32, Color(color, 0.8), 2.0)
