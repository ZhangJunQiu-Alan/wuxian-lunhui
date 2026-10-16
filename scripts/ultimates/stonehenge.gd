class_name Stonehenge
extends Node2D
## 法师的大招「巨石阵」
## 1. 一圈巨石从天而降，落地时重创石阵内和石阵附近的敌人，并把它们震开
## 2. 之后 8 秒，敌人无法进入石阵（被挡在圈外）；玩家可以自由进出

const RADIUS := 140.0
const STONES := 10
const DROP_TIME := 0.45
const DURATION := 8.0
const IMPACT_DAMAGE := 100.0
const IMPACT_KNOCKBACK := 520.0
const STONE_COLOR := Color(0.55, 0.56, 0.62)
const MAGIC_COLOR := Color(0.65, 0.55, 1.0)

var player: Player
var _time := 0.0
var _landed := false


static func cast(caster: Player) -> void:
	var fx := Stonehenge.new()
	fx.player = caster
	fx.global_position = caster.global_position
	caster.get_parent().add_child(fx)


func _ready() -> void:
	z_index = -1  # 石阵在地面上，画在敌人和玩家下面


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if not _landed and _time >= DROP_TIME:
		_landed = true
		player.shake(12.0, 0.35)
		Enemy.damage_in_radius(get_tree(), global_position, RADIUS + 30.0, IMPACT_DAMAGE * player.damage_mult, IMPACT_KNOCKBACK)
		for i in STONES:
			FxLayer.burst(global_position + _stone_offset(i), STONE_COLOR, 6, 140.0, 4.0)
	if _time >= DROP_TIME + DURATION:
		queue_free()


func _physics_process(_delta: float) -> void:
	if not _landed:
		return
	# 结界：把圈内的敌人推回圈外
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var offset := enemy.global_position - global_position
		var limit := RADIUS + enemy.radius
		if offset.length() < limit:
			if offset == Vector2.ZERO:
				offset = Vector2.RIGHT
			enemy.global_position = global_position + offset.normalized() * limit


func _stone_offset(i: int) -> Vector2:
	return Vector2.from_angle(TAU * i / STONES) * RADIUS


func _draw() -> void:
	var fall := clampf(_time / DROP_TIME, 0.0, 1.0)
	var remain := DROP_TIME + DURATION - _time
	var fade := clampf(remain, 0.0, 1.0)  # 最后一秒淡出
	if _landed:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(Vector2.ZERO, RADIUS, Color(MAGIC_COLOR, (0.06 + 0.04 * pulse) * fade))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(MAGIC_COLOR, 0.6 * fade), 3.0)
	for i in STONES:
		var base := _stone_offset(i)
		var drop := Vector2(0, -320.0 * (1.0 - fall * fall))  # 从天而降，越落越快
		# 落地前先在地上画影子
		draw_set_transform(base + Vector2(0, 14), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.4 * fall))
		draw_set_transform(Vector2.ZERO)
		var color := Color(STONE_COLOR, fade)
		draw_rect(Rect2(base + drop + Vector2(-9, -30), Vector2(18, 44)), color)
		draw_rect(Rect2(base + drop + Vector2(-9, -30), Vector2(18, 44)), Color(0.25, 0.26, 0.3, fade), false, 2.0)
		# 每两根立石上架一块横石，组成巨石阵的「三石塔」
		if i % 2 == 0 and _landed:
			var next := _stone_offset(i + 1)
			draw_line(base + Vector2(0, -32), next + Vector2(0, -32), Color(0.48, 0.49, 0.55, fade), 9.0)
