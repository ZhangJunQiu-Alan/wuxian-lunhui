class_name Shockwave
extends Node2D
## 赫列姆的冰霜冲击波：从中心向外扩散的圆环，环上有几个缺口
## 圆环扫过玩家时，如果玩家不在缺口方向上就会受伤（每圈只伤一次）

const SPEED := 300.0
const MAX_RADIUS := 700.0
const BAND := 26.0          # 圆环宽度
const GAP_HALF := 0.42      # 每个缺口的半角（弧度），约 24°
const DAMAGE := 30.0
const COLOR := Color(0.55, 0.85, 1.0)

var gaps: Array[float] = []
var player: Player
var _radius := 0.0
var _hit := false


static func spawn(parent: Node, pos: Vector2, gap_angles: Array[float], target: Player) -> void:
	var wave := Shockwave.new()
	wave.position = pos
	wave.gaps = gap_angles
	wave.player = target
	parent.add_child(wave)


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_radius += SPEED * delta
	if _radius > MAX_RADIUS:
		queue_free()
		return
	queue_redraw()
	if _hit or not is_instance_valid(player):
		return
	var offset := player.global_position - global_position
	if absf(offset.length() - _radius) < BAND * 0.5 + Player.RADIUS and not _in_gap(offset.angle()):
		_hit = true
		player.take_damage(DAMAGE)


func _in_gap(angle: float) -> bool:
	for gap in gaps:
		if absf(angle_difference(angle, gap)) < GAP_HALF:
			return true
	return false


func _draw() -> void:
	var alpha := 1.0 - _radius / MAX_RADIUS * 0.6
	# 把整圈按缺口切成几段弧，只画缺口之外的部分
	var sorted := gaps.duplicate()
	sorted.sort()
	for i in sorted.size():
		var from: float = sorted[i] + GAP_HALF
		var to: float = sorted[(i + 1) % sorted.size()] - GAP_HALF
		if to < from:
			to += TAU
		draw_arc(Vector2.ZERO, _radius, from, to, 48, Color(COLOR, 0.8 * alpha), BAND)
		draw_arc(Vector2.ZERO, _radius, from, to, 48, Color(1, 1, 1, 0.6 * alpha), 3.0)
