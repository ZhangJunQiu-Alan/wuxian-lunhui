class_name LightningFx
extends Node2D
## 闪电特效：一道闪电（素材 4 帧，竖直画的，按起点终点旋转拉伸）+ 落点的爆炸圈，0.2 秒后消失

const BOLT := preload("res://assets/sprites/effects/lightning.png")
const BOLT_LENGTH := 252.0  # 素材里闪电从落点到顶端的像素数
const DURATION := 0.2

var from := Vector2.ZERO
var to := Vector2.ZERO
var blast_radius := 0.0
var _time := DURATION


static func spawn(parent: Node, from_pos: Vector2, to_pos: Vector2, radius: float) -> void:
	var fx := LightningFx.new()
	fx.from = from_pos
	fx.to = to_pos
	fx.blast_radius = radius
	parent.add_child(fx)


func _ready() -> void:
	z_index = 10  # 画在敌人上面


func _process(delta: float) -> void:
	_time -= delta
	if _time <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := _time / DURATION
	var frame := mini(3, int((1.0 - alpha) * 4.0))
	var length := from.distance_to(to)
	SpriteVisual.draw_frame(self, BOLT, 4, frame, to, Vector2(32, 254), (from - to).angle() + PI / 2, Vector2(minf(1.0, length / 160.0), length / BOLT_LENGTH))
	if blast_radius > 0.0:
		draw_circle(to, blast_radius, Color(0.6, 0.85, 1.0, 0.35 * alpha))
