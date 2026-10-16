class_name RatatoskrQuest
extends SideQuest
## 支线「拉塔托斯克的流言」：松鼠在世界树上传递流言，挑拨巨鹰与尼德霍格
## 它在树根附近乱窜，玩家靠近就逃。抓住它 3 次（每次它都会挣脱跳到别处）
## 奖励：支线剧情点 +1，一次升级

const CATCHES := 3
const CATCH_DISTANCE := 26.0
const SPEED := 175.0           # 比玩家慢一点，但会突然折返
const SCARE_DISTANCE := 160.0
const HOP := 260.0             # 被抓到后跳出去多远
const SQUIRREL_PATH := "res://assets/sprites/quests/squirrel_move.png"  # 32×32 的 4 帧

var _pos := Vector2.ZERO
var _dir := Vector2.RIGHT
var _turn := 0.0
var _caught := 0
var _strip: Texture2D


func _init() -> void:
	title = "拉塔托斯克的流言"
	offer_text = "【主神】支线剧情：一只松鼠正在世界树下散布流言。抓住它"
	time_limit = 50.0
	color = Color(0.85, 0.5, 0.3)


func _ready() -> void:
	super._ready()
	if ResourceLoader.exists(SQUIRREL_PATH):
		_strip = load(SQUIRREL_PATH)


func _on_accept() -> void:
	_pos = marker_pos + Vector2.from_angle(randf() * TAU) * 120.0


func _on_update(delta: float) -> void:
	var away := _pos - player.global_position
	_turn -= delta
	if away.length() < SCARE_DISTANCE:
		if _turn <= 0.0:  # 隔一会儿突然折向一侧
			_turn = randf_range(0.5, 1.1)
			_dir = away.normalized().rotated(randf_range(-1.2, 1.2))
	elif _turn <= 0.0:
		_turn = randf_range(0.8, 1.6)
		_dir = Vector2.from_angle(randf() * TAU)
	var speed := SPEED if away.length() < SCARE_DISTANCE else SPEED * 0.35
	_pos = MapLayer.push_out(Game.clamp_to_map(_pos + _dir * speed * delta, 30.0), 6.0)
	if _pos.distance_to(landmark.get("pos", marker_pos)) > 650.0:  # 不离开树根太远
		_dir = _pos.direction_to(landmark.get("pos", marker_pos))
	if player.global_position.distance_to(_pos) < CATCH_DISTANCE + Player.RADIUS:
		_caught += 1
		FxLayer.floating_text(_pos + Vector2(0, -20), "吱！", color.lightened(0.3))
		Audio.sfx("card_pick")
		if _caught >= CATCHES:
			complete(true)
			return
		_pos = Game.clamp_to_map(_pos + Vector2.from_angle(randf() * TAU) * HOP, 40.0)
	objective = "抓住松鼠  %d / %d" % [_caught, CATCHES]


func _reward() -> String:
	game.add_story_points(1)
	game.queue_reward("松鼠吐出了一样珍藏！选择一项奖励")
	return "支线剧情点 +1，一次升级"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = [_pos]
	return targets


func _draw_quest() -> void:
	if state != "active":
		return
	if _strip:
		SpriteVisual.draw_frame(self, _strip, 4, int(_time * 10.0), _pos, Vector2(16, 28), 0.0, Vector2(-1.0 if _dir.x < 0.0 else 1.0, 1.0))
		return
	draw_circle(_pos, 7.0, Color(0.7, 0.35, 0.2))
	draw_circle(_pos + Vector2(-8 if _dir.x > 0.0 else 8, -6), 6.0, Color(0.85, 0.5, 0.3))  # 大尾巴
