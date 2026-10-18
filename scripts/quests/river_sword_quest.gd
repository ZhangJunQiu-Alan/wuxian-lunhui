class_name RiverSwordQuest
extends SideQuest
## 隐藏支线「冥河里的刀剑」（结冰的浅滩）：冥河中流着刀剑，有一把还在发光
## 站在冰上把剑凿出来（累计 15 秒），冰面会碎裂，冥雾幽魂从河里涌出
## 奖励：本局基础武器伤害 +20%，奖励点 +40

const DIG_TIME := 15.0
const ZONE_RADIUS := 90.0
const WAVE_EVERY := 4.0
const WAVE_SIZE := 4
const SWORD := preload("res://assets/sprites/quests/river_sword.png")

var _dug := 0.0
var _wave_timer := 2.0


func _init() -> void:
	title = tr("冥河里的刀剑")
	offer_text = tr("【主神】隐藏支线：浅滩的冰下冻着一把发光的剑。把它凿出来")
	hint_text = tr("【主神】浅滩的冰下，冻着一把还在发光的剑")
	is_hidden = true
	time_limit = 45.0
	color = Color(0.7, 0.9, 1.0)


func _on_update(delta: float) -> void:
	if player.global_position.distance_to(marker_pos) < ZONE_RADIUS:
		_dug += delta
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_EVERY
		for i in WAVE_SIZE:
			game.spawn_enemy("mist_wraith", marker_pos + Vector2(randf_range(-400, 400), randf_range(-60, 60)))
	objective = tr("凿冰取剑  %d / %d 秒") % [int(_dug), int(DIG_TIME)]
	if _dug >= DIG_TIME:
		complete(true)


func _reward() -> String:
	for weapon in [player.katana, player.revolver, player.blades, player.nova]:
		if weapon:
			weapon.damage *= 1.2
	game.add_reward_points(40)
	return tr("本局基础武器伤害 +20%，奖励点 +40")


func _active_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if player.global_position.distance_to(marker_pos) > ZONE_RADIUS:
		targets.append(marker_pos)
	return targets


func _draw_quest() -> void:
	if state != "active":
		return
	var k := _dug / DIG_TIME
	draw_circle(marker_pos, ZONE_RADIUS, Color(color, 0.1))
	draw_arc(marker_pos, ZONE_RADIUS, -PI / 2, -PI / 2 + TAU * k, 48, color, 4.0)
	for i in 6:  # 冰面裂纹越来越长
		var dir := Vector2.from_angle(i * 1.05 + 0.3)
		draw_line(marker_pos, marker_pos + dir * ZONE_RADIUS * k, Color(0.9, 0.97, 1.0, 0.35), 1.0)
	SpriteVisual.draw_frame(self, SWORD, 4, int(_time * 8.0), (marker_pos + Vector2(0, 12)).round(), Vector2(16, 62))
