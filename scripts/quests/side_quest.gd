class_name SideQuest
extends Node2D
## 支线剧情基类
## 流程：主神在地图上放一个发光标记（offered）→ 玩家走过去接受（active）→ 限时内完成目标 → 结束（done）
## 标记一段时间没人接就消失。每个具体支线继承它，实现：
##   _hidden_spot()  隐藏支线的触发物件放在哪里（默认地标中心）
##   _on_accept()    接受时做什么（刷怪、放置物件）
##   _on_update()    每帧检查目标，更新 objective，完成时调用 complete(true)
##   _reward()       完成后发奖励，返回奖励说明文字
##   _draw_quest()   画任务物件（篝火、渡鸦……），画在角色下面
##   _draw_overlay() 画在角色上面的东西（文字、头顶的物件、风雪），用 overlay.draw_*()
##   _active_targets() 进行中时，屏幕边缘箭头要指向哪些位置
##
## 隐藏支线（is_hidden = true）：一开局就藏在地标里，没有光柱和箭头，也不会消失。
## 地上只有一点微光，玩家自己走过去才触发；到了 LevelDB 写的时间，主神会给一句提示（hint_text）
## 同一时间最多一个隐藏支线在进行，这时其他隐藏支线暂时不能触发（blocked）
##
## 这个节点放在世界原点，所以画图时直接用世界坐标

signal accepted(quest: SideQuest)
signal finished(quest: SideQuest, success: bool)

const BEACON := preload("res://assets/sprites/quests/quest_beacon.png")  # 光柱标记，4 帧循环
const OFFER_TIME := 40.0        # 标记存在多久，没接就消失
const ACCEPT_DISTANCE := 40.0
const MARKER_DISTANCE := 380.0  # 标记出现在离玩家多远的地方

var quest_id := ""       # QuestDB 里的 id，图鉴记录用
var title := ""
var offer_text := ""     # 标记出现时（隐藏支线是被发现时）主神的播报
var hint_text := ""      # 隐藏支线：主神的提示
var objective := ""      # 任务目标，显示在右侧任务面板
var time_limit := 60.0
var color := Color(1.0, 0.85, 0.4)
var game: Game
var player: Player
var marker_pos := Vector2.ZERO
var landmark := {}  # 支线所在的地标（LevelDB 的 map.landmarks），为空时出现在玩家附近
var is_hidden := false
var blocked := false  # 隐藏支线：已经有别的隐藏支线在进行
var state := "offered"
var time_left := 0.0
var was_accepted := false
var overlay: Node2D  # 画在角色上面的图层
var _offer_left := OFFER_TIME
var _time := 0.0


func _ready() -> void:
	z_index = -1  # 画在敌人和玩家下面
	overlay = Node2D.new()
	overlay.z_index = 20
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	if is_hidden:
		marker_pos = _hidden_spot()
	elif landmark.is_empty():
		marker_pos = player.global_position + Vector2.from_angle(randf() * TAU) * MARKER_DISTANCE
	else:
		marker_pos = landmark.pos + Vector2.from_angle(randf() * TAU) * randf() * landmark.radius * 0.4
		_offer_left += player.global_position.distance_to(marker_pos) / player.move_speed  # 地标越远，留给玩家赶路的时间越多
	marker_pos = Game.clamp_to_map(marker_pos, 80.0)
	marker_pos = MapLayer.push_out(marker_pos, Player.RADIUS + 16.0)
	objective = tr("前往标记处接受支线")


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	overlay.queue_redraw()
	match state:
		"offered":
			if not is_hidden:
				_offer_left -= delta
			if not blocked and player.global_position.distance_to(marker_pos) < ACCEPT_DISTANCE:
				state = "active"
				was_accepted = true
				time_left = time_limit
				_on_accept()
				Audio.sfx("quest_start")
				accepted.emit(self)
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


## 屏幕边缘箭头要指向的位置。隐藏支线被发现之前没有箭头
func pointer_targets() -> Array[Vector2]:
	if state == "offered":
		if is_hidden:
			return []
		var targets: Array[Vector2] = [marker_pos]
		return targets
	return _active_targets()


func _hidden_spot() -> Vector2:
	return landmark.pos


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


func _draw_overlay() -> void:
	pass


func _draw() -> void:
	_draw_quest()
	if state == "offered" and is_hidden:
		if not blocked:
			draw_glimmer(marker_pos)
	elif state == "offered":
		# 光柱标记
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_circle(marker_pos, 30.0 + 6.0 * pulse, Color(color, 0.15))
		SpriteVisual.draw_frame(self, BEACON, 4, int(_time * 8.0), marker_pos, Vector2(16, 126))
		draw_arc(marker_pos, ACCEPT_DISTANCE, 0.0, TAU, 32, Color(color, 0.8), 2.0)


## 隐藏支线的微光：几颗忽明忽暗的小星点，要走近了才注意得到
func draw_glimmer(pos: Vector2) -> void:
	for i in 3:
		var k := 0.5 + 0.5 * sin(_time * 3.0 + i * 2.1)
		var p := pos + Vector2.from_angle(i * 2.1 + _time * 0.4) * 14.0 + Vector2(0, -10)
		var c := Color(1.0, 0.95, 0.8, 0.25 + 0.5 * k)
		draw_line(p + Vector2(-3 - 2 * k, 0), p + Vector2(3 + 2 * k, 0), c, 1.5)
		draw_line(p + Vector2(0, -3 - 2 * k), p + Vector2(0, 3 + 2 * k), c, 1.5)
