class_name GleipnirFragment
extends Node2D
## 格莱普尼尔的锁链碎片：芬里尔战时散落在场上，玩家走过去捡起，立刻束缚芬里尔一段时间（只能捡一次）
## 不在敌人组里，不会被锁定；芬里尔被击败时一起消失

const TEXTURE := "res://assets/sprites/pickups/gleipnir_fragment.png"  # 24×24，中心锚点 (12,12)
const PICKUP_DISTANCE := 26.0

var fenrir: Fenrir
var player: Player
var taken := false
var _time := randf() * 3.0
var _texture: Texture2D


func _ready() -> void:
	z_index = -1
	add_to_group("gleipnir_fragments")
	if ResourceLoader.exists(TEXTURE):
		_texture = load(TEXTURE)


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if taken or not is_instance_valid(player) or not is_instance_valid(fenrir):
		return
	if global_position.distance_to(player.global_position) < PICKUP_DISTANCE and fenrir.can_bind():
		taken = true  # 先标记再生效：同一帧里不会被捡两次
		Audio.sfx("chest_open")
		FxLayer.burst(global_position, Color(1.0, 0.85, 0.5), 16, 160.0, 3.0)
		fenrir.bind()
		queue_free()


func _draw() -> void:
	var glow := 0.5 + 0.5 * sin(_time * 5.0)
	draw_circle(Vector2.ZERO, 18.0, Color(1.0, 0.85, 0.5, 0.12 + 0.12 * glow))
	if _texture:
		draw_texture(_texture, Vector2(-12, -12 + roundf(sin(_time * 3.0) * 2.0)))
	else:
		draw_circle(Vector2.ZERO, 7.0, Color(0.85, 0.8, 0.65))
