class_name PoisonPool
extends Node2D
## 尼德霍格毒息留在地上的毒池：玩家站在里面持续掉血，一段时间后消失

const RADIUS := 48.0  # 和素材一样宽，按 1 倍显示
const LIFETIME := 7.0
const DPS := 7.0
const STRIP_PATH := "res://assets/sprites/effects/poison_pool.png"  # 96×48 的 4 帧循环
const COLOR := Color(0.35, 0.6, 0.25)

var _life := LIFETIME
var _player: Player
var _strip: Texture2D


static func spawn(parent: Node, pos: Vector2) -> void:
	var pool := PoisonPool.new()
	pool.position = pos
	parent.add_child.call_deferred(pool)


func _ready() -> void:
	z_index = -1  # 画在角色下面
	_player = get_tree().get_first_node_in_group("player") as Player
	if ResourceLoader.exists(STRIP_PATH):
		_strip = load(STRIP_PATH)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _inside():
		_player.take_dot(DPS * delta)
	queue_redraw()


## 毒池是扁的椭圆（宽是高的两倍）
func _inside() -> bool:
	if not is_instance_valid(_player):
		return false
	var d := (_player.global_position + Vector2(0, MapLayer.FOOT) - global_position) * Vector2(1, 2)
	return d.length() < RADIUS


func _draw() -> void:
	var fade := minf(1.0, _life / 0.8) * minf(1.0, (LIFETIME - _life) / 0.3)
	if _strip:
		var frame := int((LIFETIME - _life) * 8.0) % 4
		SpriteVisual.draw_frame(self, _strip, 4, frame, Vector2.ZERO, Vector2(48, 24), 0.0, Vector2.ONE, Color(1, 1, 1, fade))
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, RADIUS, Color(COLOR, 0.45 * fade))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(COLOR.lightened(0.3), 0.7 * fade), 2.0)
	for i in 4:  # 冒泡
		var t := fmod((LIFETIME - _life) * 0.8 + i * 0.25, 1.0)
		draw_circle(Vector2.from_angle(i * 1.7) * RADIUS * 0.5, 3.0 + t * 4.0, Color(COLOR.lightened(0.4), (1.0 - t) * fade))
	draw_set_transform(Vector2.ZERO)
