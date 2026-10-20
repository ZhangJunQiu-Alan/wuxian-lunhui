class_name ThokkQuest
extends SideQuest
## 隐藏支线「不肯哭泣的女巨人」（加姆的洞窟旁的小洞）：万物都为巴德尔哭泣，只有她不肯
## 她其实是诡计之神变的。击败她化身的精英，她会逃走一次：在她跑远之前再追上击败她
## 奖励：支线剧情点 +1，奖励点 +100；信仰洛基时洛基的信仰额外 +1

const FLEE_DISTANCE := 1400.0

var _giant: Enemy
var _fleeing := false


func _init() -> void:
	title = tr("不肯哭泣的女巨人")
	offer_text = tr("【主神】隐藏支线：「我只会流干涩的眼泪。」她不是普通的女巨人")
	hint_text = tr("【主神】洞窟旁的小洞里，有人在冷笑")
	is_hidden = true
	time_limit = 60.0
	color = Color(1.0, 0.55, 0.2)


func _hidden_spot() -> Vector2:
	return landmark.pos + Vector2(-300, 340)


func _on_accept() -> void:
	_giant = game.spawn_enemy("thokk", marker_pos + Vector2(0, -40), true, true)
	if _giant == null:
		complete(false)
		return
	_giant.killed.connect(_on_giant_killed)


func _on_giant_killed(_e: Enemy) -> void:
	if _fleeing:
		complete(true)
		return
	_fleeing = true  # 第一次被打倒：化作一道火光逃走
	var at := _giant.global_position
	FxLayer.floating_text(at + Vector2(0, -40), tr("「你抓不住我！」"), color)
	FxLayer.burst(at, color, 30, 260.0, 4.0)
	_giant = game.spawn_enemy("thokk", at, true, true)
	if _giant == null:
		complete(false)
		return
	_giant.speed *= 1.6
	_giant.flee_to = Game.clamp_to_map(at + (at - player.global_position).normalized() * FLEE_DISTANCE, 80.0)
	_giant.killed.connect(_on_giant_killed)


func _on_update(_delta: float) -> void:
	objective = tr("追上她，击败她") if _fleeing else tr("击败不肯哭泣的女巨人")
	if _fleeing and is_instance_valid(_giant) and _giant.global_position.distance_to(_giant.flee_to) < 20.0:
		FxLayer.floating_text(_giant.global_position + Vector2(0, -40), tr("哈哈哈……"), color)
		complete(false)


func _on_end() -> void:
	if is_instance_valid(_giant):
		game.despawn_enemy(_giant)


func _reward() -> String:
	game.add_story_points(1)
	game.add_reward_points(100)
	var text := tr("支线剧情点 +1，奖励点 +100")
	if player.faith.has("loki"):
		game.add_faith("loki", 1)
		text += tr("，洛基的信仰 +1")
	return text


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if is_instance_valid(_giant):
		targets.append(_giant.global_position)
	return targets
