class_name BaldrQuest
extends SideQuest
## 支线「巴德尔的低语」：在海拉的大厅深处找到光明之神的灵魂，护送他 30 秒
## 灵魂跟着玩家走；敌人碰到他会让他变弱，光芒熄灭就失败；离玩家太远时护送暂停
## 奖励：奖励点 +80，本局获得一次复活

const ESCORT_TIME := 30.0
const FOLLOW_SPEED := 150.0
const FOLLOW_GAP := 50.0
const NEAR := 220.0
const SOUL_HP := 100.0
const HIT_DPS := 12.0       # 每个贴着他的敌人每秒减少多少光芒
const SOUL_PATH := "res://assets/sprites/quests/bright_soul_move.png"  # 64×64 的 4 帧
const LIGHT := Color(1.0, 0.92, 0.6)

var _soul := Vector2.ZERO
var _soul_hp := SOUL_HP
var _escorted := 0.0
var _strip: Texture2D


func _init() -> void:
	title = "巴德尔的低语"
	offer_text = "【主神】支线剧情：海拉的大厅深处，有一点温暖的光。找到他，带他离开"
	time_limit = 70.0
	color = LIGHT


func _ready() -> void:
	super._ready()
	if ResourceLoader.exists(SOUL_PATH):
		_strip = load(SOUL_PATH)


func _on_accept() -> void:
	_soul = marker_pos


func _on_update(delta: float) -> void:
	var to := player.global_position - _soul
	if to.length() > FOLLOW_GAP:
		_soul += to.normalized() * minf(FOLLOW_SPEED * delta, to.length() - FOLLOW_GAP)
	var near := to.length() < NEAR
	if near:
		_escorted += delta
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.global_position.distance_to(_soul) < enemy.radius + 18.0:
			_soul_hp -= HIT_DPS * delta
	if _soul_hp <= 0.0:
		FxLayer.burst(_soul, LIGHT, 30, 200.0, 4.0)
		complete(false)
		return
	objective = "护送巴德尔的灵魂  %d / %d 秒%s" % [int(_escorted), int(ESCORT_TIME), "" if near else "（离他太远了）"]
	if _escorted >= ESCORT_TIME:
		complete(true)


func _reward() -> String:
	game.add_reward_points(80)
	player.revives += 1
	return "奖励点 +80，本局获得一次复活"


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if player.global_position.distance_to(_soul) > NEAR:
		targets.append(_soul)
	return targets


func _draw_quest() -> void:
	if state == "offered":
		draw_circle(marker_pos + Vector2(0, -20), 12.0 + sin(_time * 3.0) * 2.0, Color(LIGHT, 0.5))
		return
	if state != "active":
		return
	var k := _soul_hp / SOUL_HP
	draw_circle(_soul, 40.0, Color(LIGHT, 0.08 + 0.1 * k))
	if _strip:
		SpriteVisual.draw_frame(self, _strip, 4, int(_time * 8.0), _soul, Vector2(32, 58), 0.0, Vector2.ONE, Color(1, 1, 1, 0.5 + 0.5 * k))
	else:
		draw_circle(_soul + Vector2(0, -18), 12.0, Color(LIGHT, 0.5 + 0.5 * k))
	draw_rect(Rect2(_soul + Vector2(-20, 12), Vector2(40 * k, 4)), LIGHT)
