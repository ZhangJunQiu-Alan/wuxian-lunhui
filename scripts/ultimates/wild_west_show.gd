class_name WildWestShow
extends Node2D
## 安妮·奥克利的大招「狂野西部秀」：8 秒狂热状态
## 射速 ×4、不用换弹、子弹额外穿透（在 revolver.gd 里处理）；移速 +30%（player.gd）；击杀回血（game.gd）
## 这个节点只负责表演：玩家身边绕着旋转的金星，脚下扬起尘土

const DURATION := 8.0
const COLOR := Color(1.0, 0.75, 0.35)

var player: Player
var _time := 0.0


static func cast(caster: Player) -> void:
	caster.frenzy_time = DURATION
	var fx := WildWestShow.new()
	fx.player = caster
	caster.add_child(fx)
	caster.shake(5.0, 0.2)
	FxLayer.burst(caster.global_position, COLOR, 30, 260.0)


func _ready() -> void:
	show_behind_parent = true


func _process(delta: float) -> void:
	_time += delta
	if player.frenzy_time <= 0.0:
		queue_free()
		return
	if randf() < 0.5:  # 跑动时扬起尘土
		FxLayer.burst(player.global_position + Vector2(randf_range(-10, 10), 12), Color(0.75, 0.6, 0.4), 1, 40.0, 3.0)
	queue_redraw()


func _draw() -> void:
	var fade := minf(1.0, player.frenzy_time / 0.5)  # 最后半秒淡出
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, Color(COLOR, 0.5 * fade), 2.0)
	for i in 5:  # 五颗绕身旋转的星
		var p := Vector2.from_angle(_time * 4.0 + TAU * i / 5) * 34.0
		var star := PackedVector2Array()
		for k in 10:
			star.append(p + Vector2.from_angle(TAU * k / 10 - PI / 2) * (6.0 if k % 2 == 0 else 2.5))
		draw_colored_polygon(star, Color(COLOR, fade))
