class_name DimensionSlash
extends Node2D
## 剑士的大招「次元斩」
## 1. 画面变暗，屏幕内的敌人全部被定住
## 2. 空间裂痕一道接一道浮现
## 3. 所有裂痕同时爆开，重创屏幕内所有敌人

const CUT_COUNT := 14
const APPEAR_TIME := 0.5   # 裂痕在这段时间内逐条浮现
const BURST_AT := 0.75     # 第几秒爆开
const END_AT := 1.3        # 第几秒特效结束
const DAMAGE := 120.0

var player: Player
var _time := 0.0
var _burst_done := false
var _half_size := Vector2.ZERO
var _cuts: Array[Dictionary] = []  # 每道裂痕：from、to、appear（浮现时间）


static func cast(caster: Player) -> void:
	var fx := DimensionSlash.new()
	fx.player = caster
	caster.active_ultimate = fx
	fx.global_position = caster.global_position
	caster.get_parent().add_child(fx)


func _ready() -> void:
	z_index = 20  # 画在所有敌人和特效上面
	_half_size = get_viewport_rect().size / 2.0
	for i in CUT_COUNT:
		var center := Vector2(randf_range(-_half_size.x, _half_size.x), randf_range(-_half_size.y, _half_size.y)) * 0.85
		var dir := Vector2.from_angle(randf() * TAU)
		var half_len := randf_range(90.0, 220.0)
		_cuts.append({"from": center - dir * half_len, "to": center + dir * half_len, "appear": APPEAR_TIME * i / CUT_COUNT})

	for enemy in _enemies_on_screen():
		enemy.freeze(BURST_AT + 0.15)
	player.shake(3.0, 0.15)


func _process(delta: float) -> void:
	_time += delta
	if not _burst_done and _time >= BURST_AT:
		_burst()
	if _time >= END_AT:
		queue_free()
	queue_redraw()


func _burst() -> void:
	_burst_done = true
	var dmg := DAMAGE * player.damage_mult
	for enemy in _enemies_on_screen():
		enemy.take_damage(dmg, Vector2.ZERO, true)
	player.shake(12.0, 0.35)


func _enemies_on_screen() -> Array[Enemy]:
	var rect := Rect2(global_position - _half_size, _half_size * 2.0)
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if rect.has_point(enemy.global_position):
			result.append(enemy)
	return result


func _draw() -> void:
	var cover := Rect2(-_half_size * 1.3, _half_size * 2.6)

	if not _burst_done:
		# 蓄势阶段：画面逐渐变暗，裂痕一道道浮现
		draw_rect(cover, Color(0.02, 0.02, 0.08, 0.55 * minf(1.0, _time / 0.2)))
		for cut in _cuts:
			if _time >= cut.appear:
				var dir: Vector2 = cut.to - cut.from
				if not CombatFx.draw(self, "dimension_cut", 0.0, (cut.from + cut.to) * 0.5, dir.angle(), Vector2(dir.length() / 87.0, 0.45)):
					draw_line(cut.from, cut.to, Color(0, 0, 0, 0.9), 6.0)
					draw_line(cut.from, cut.to, Color(0.8, 0.85, 1.0), 1.5)
		return

	# 爆开阶段：白光一闪，裂痕变宽后淡出
	var t := (_time - BURST_AT) / (END_AT - BURST_AT)  # 0 → 1
	draw_rect(cover, Color(1, 1, 1, 0.6 * (1.0 - t) * (1.0 - t)))
	for cut in _cuts:
		var width := lerpf(4.0, 22.0, t)
		var dir: Vector2 = cut.to - cut.from
		if not CombatFx.draw(self, "dimension_cut", _time - BURST_AT, (cut.from + cut.to) * 0.5, dir.angle(), Vector2(dir.length() / 87.0, lerpf(12.0, 22.0, t) / 27.0), Color(1, 1, 1, 1.0 - t)):
			draw_line(cut.from, cut.to, Color(0.55, 0.65, 1.0, 0.8 * (1.0 - t)), width)
			draw_line(cut.from, cut.to, Color(1, 1, 1, 1.0 - t), width * 0.3)
