class_name Stonehenge
extends Node2D
## 法师的大招「巨石阵」
## 1. 一圈巨石从天而降，落地时重创石阵内和石阵附近的敌人，并把它们震开
## 2. 之后 8 秒，敌人无法进入石阵（被挡在圈外）；玩家可以自由进出
## 3. 结界挡下所有远程攻击：飞进圈内的子弹（冰锥、箭、Boss 的弹幕）被击碎，圈外的幽魂吸不到圈内玩家的血

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
	add_to_group("stonehenge")


## pos 是否在某个已经落地的巨石阵里（远程攻击打不进去）
static func shields(tree: SceneTree, pos: Vector2) -> bool:
	for node in tree.get_nodes_in_group("stonehenge"):
		var henge := node as Stonehenge
		if henge._landed and henge.global_position.distance_to(pos) < RADIUS:
			return true
	return false


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
	for shot in get_tree().get_nodes_in_group("enemy_projectiles"):  # 挡下飞进来的子弹
		if (shot as Node2D).global_position.distance_to(global_position) < RADIUS:
			FxLayer.burst(shot.global_position, MAGIC_COLOR, 5, 90.0, 2.5)
			shot.queue_free()


func _stone_offset(i: int) -> Vector2:
	return Vector2.from_angle(TAU * i / STONES) * RADIUS


func _draw() -> void:
	var fall := clampf(_time / DROP_TIME, 0.0, 1.0)
	var remain := DROP_TIME + DURATION - _time
	var fade := clampf(remain, 0.0, 1.0)  # 最后一秒淡出
	if _landed:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		if not CombatFx.draw(self, "stonehenge_circle", 0.0, Vector2.ZERO, 0.0, Vector2.ONE * RADIUS / 62.0, Color(1, 1, 1, (0.25 + 0.12 * pulse) * fade), RADIUS):
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
		if not CombatFx.draw(self, "stonehenge_stone", 0.0, base + drop + Vector2(0, 14), 0.0, Vector2.ONE * 0.75, Color(1, 1, 1, fade)):
			draw_rect(Rect2(base + drop + Vector2(-9, -30), Vector2(18, 44)), color)
			draw_rect(Rect2(base + drop + Vector2(-9, -30), Vector2(18, 44)), Color(0.25, 0.26, 0.3, fade), false, 2.0)
		# 每两根立石上架一块横石，组成巨石阵的「三石塔」
		if i % 2 == 0 and _landed:
			var next := _stone_offset(i + 1)
			if not CombatFx.draw(self, "stonehenge_lintel", 0.0, (base + next) * 0.5 + Vector2(0, -32), (next - base).angle(), Vector2(base.distance_to(next) / 60.0, 9.0 / 14.0), Color(1, 1, 1, fade)):
				draw_line(base + Vector2(0, -32), next + Vector2(0, -32), Color(0.48, 0.49, 0.55, fade), 9.0)
