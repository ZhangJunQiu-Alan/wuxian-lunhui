class_name HealPickup
extends Node2D
## 回复生命的拾取物：弗蕾亚的金羽和金泪、弗雷的苹果。玩家进入拾取范围后被吸过去
## 素材（可选）：assets/sprites/effects/gods/pickup_<kind>.png（16×16），没有就画一个小图形

const FLY_SPEED := 420.0
const LIFETIME := 15.0
const COLORS := {"feather": Color(1.0, 0.85, 0.35), "apple": Color(0.95, 0.3, 0.25), "tear": Color(1.0, 0.92, 0.5)}

var player: Player
var heal := 5.0
var kind := "feather"
var _life := LIFETIME
var _time := 0.0
var _attracted := false


func _process(delta: float) -> void:
	_time += delta
	_life -= delta
	if _life <= 0.0 or not is_instance_valid(player):
		queue_free()
		return
	var dist := global_position.distance_to(player.global_position)
	if dist < player.pickup_radius:
		_attracted = true
	if _attracted:
		global_position = global_position.move_toward(player.global_position, FLY_SPEED * delta)
		if dist < 12.0:
			player.heal(heal)
			FxLayer.floating_text(player.global_position + Vector2(0, -30), "+%d" % ceili(heal), Color(0.5, 1.0, 0.5))
			Audio.sfx_or("heal_pickup", "pickup_xp", -4.0, 0.3)
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, roundf(sin(_time * 4.0) * 2.0))
	var color: Color = COLORS.get(kind, Color.WHITE)
	var alpha := clampf(_life / 2.0, 0.0, 1.0)
	draw_circle(bob, 9.0, Color(color, 0.2 * alpha))
	var tex := GodPower.art("pickup_" + kind)
	if tex:
		draw_texture(tex, bob - tex.get_size() * 0.5, Color(1, 1, 1, alpha))
		return
	match kind:
		"apple":
			draw_circle(bob, 5.0, Color(color, alpha))
			draw_line(bob + Vector2(0, -5), bob + Vector2(2, -8), Color(0.4, 0.8, 0.3, alpha), 2.0)
		"tear":
			draw_colored_polygon(PackedVector2Array([bob + Vector2(0, -8), bob + Vector2(4, 1), bob + Vector2(0, 5), bob + Vector2(-4, 1)]), Color(color, alpha))
		_:
			draw_line(bob + Vector2(-5, 5), bob + Vector2(5, -6), Color(color, alpha), 3.0)
			draw_line(bob + Vector2(-5, 5), bob + Vector2(5, -6), Color(1, 1, 1, 0.7 * alpha), 1.0)
