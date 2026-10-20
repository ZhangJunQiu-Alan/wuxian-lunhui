class_name SeaGiantQuest
extends SideQuest
## 隐藏支线「冰海来客」（码头）：冰面上有一串巨大的脚印通向东边的冰海
## 一只扛着战利品的霜巨人（精英）正顺着脚印走回冰海。在它走到海边之前击杀它，战利品会掉成一个宝箱
## 奖励：支线剧情点 +1，奖励点 +80，宝箱

const GIANT_SPEED := 30.0
const ESCAPE_REACH := 30.0
const FOOTPRINT := preload("res://assets/sprites/quests/giant_footprint.png")  # 单个脚印，脚趾朝上；左脚是右脚翻转
const STEP := 46.0  # 脚印间距

var _giant: Enemy
var _start := Vector2.ZERO
var _escape := Vector2.ZERO


func _init() -> void:
	title = tr("冰海来客")
	offer_text = tr("【主神】发现隐藏支线：冰海来客。别让霜巨人逃回冰海")
	hint_text = tr("【主神】码头的冰面上，有一串不属于人类的脚印")
	time_limit = 90.0
	color = Color(0.6, 0.75, 1.0)
	is_hidden = true


func _hidden_spot() -> Vector2:
	_start = landmark.pos + Vector2(-110, -50)
	_escape = Vector2(Game.bounds.end.x - 40.0, landmark.pos.y - 200.0)
	return landmark.pos + Vector2(-260, 120)


func _on_accept() -> void:
	_giant = game.spawn_enemy("frost_giant", _start, true, true)
	if _giant == null:
		complete(false)
		return
	_giant.speed = GIANT_SPEED
	_giant.flee_to = _escape
	_giant.killed.connect(_on_giant_killed)


func _on_update(_delta: float) -> void:
	if not is_instance_valid(_giant):
		return
	var left := _giant.global_position.distance_to(_escape)
	objective = tr("击杀霜巨人  离冰海还有 %d 米") % ceili(left / 20.0)
	if left < ESCAPE_REACH:
		FxLayer.burst(_giant.global_position, color, 20, 160.0)
		FxLayer.floating_text(_giant.global_position + Vector2(0, -50), tr("霜巨人逃回了冰海"), color)
		game.despawn_enemy(_giant)
		_giant = null
		complete(false)


func _on_giant_killed(giant: Enemy) -> void:
	var chest := Chest.new()
	chest.player = player
	chest.position = giant.position
	chest.opened.connect(game.queue_reward.bind(tr("霜巨人的战利品！选择一项奖励")))
	game.add_child.call_deferred(chest)
	_giant = null
	complete(true)


func _on_end() -> void:
	if is_instance_valid(_giant):
		game.despawn_enemy(_giant)


func _reward() -> String:
	game.add_reward_points(80)
	game.add_story_points(1)
	return tr("支线剧情点 +1，奖励点 +80，霜巨人的战利品（宝箱）")


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if is_instance_valid(_giant):
		targets.append(_giant.global_position)
	return targets


func _draw_quest() -> void:
	# 一串左右交替的大脚印，从触发处一直通向冰海
	var from := marker_pos
	var dir := from.direction_to(_escape)
	var side := dir.orthogonal() * 9.0
	var steps := int(from.distance_to(_escape) / STEP)
	for i in steps:
		var p := from + dir * STEP * i + side * (1.0 if i % 2 == 0 else -1.0)
		SpriteVisual.draw_frame(self, FOOTPRINT, 1, 0, p, Vector2(16, 16), dir.angle() + PI / 2, Vector2(1.0 if i % 2 == 0 else -1.0, 1.0), Color(1, 1, 1, 0.7))
	if state == "active":
		draw_arc(_escape, 40.0, 0.0, TAU, 32, Color(color, 0.5 + 0.3 * sin(_time * 5.0)), 3.0)
