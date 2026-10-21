class_name GodZone
extends Node2D
## 地上持续生效的一块区域：圆形（to 为零）或一条带子（从自身位置到 position + to，宽 radius × 2）
## 每隔 tick_every 秒对区域里的每个敌人调用 on_tick(敌人)。光带、冰面、火路、麦田、漩涡、电网都用它
## follow 不为空时跟着那个节点走（觉醒后跟着玩家的麦田）
## 素材（可选）：texture 不为空时，圆形区域把它铺满整个圆，带子区域沿方向拉伸

var radius := 40.0
var to := Vector2.ZERO
var life := 2.0
var tick_every := 0.5
var tick_query: Callable
var on_tick: Callable
var on_end: Callable  # 消失时调用一次（不带参数）
var color := Color.WHITE
var follow: Node2D
var texture: Texture2D
var pull := 0.0  # 每秒把区域里的敌人往中心拉多少像素（漩涡）
var _age := 0.0
var _tick := 0.0


func _ready() -> void:
	z_index = -1  # 画在地上，在敌人下面


func _process(delta: float) -> void:
	_age += delta
	if is_instance_valid(follow):
		global_position = follow.global_position
	if _age >= life:
		if on_end.is_valid():
			on_end.call()
		queue_free()
		return
	_tick -= delta
	var targets: Array[Enemy] = []
	if pull > 0.0 or (_tick <= 0.0 and on_tick.is_valid()):
		targets = tick_query.call() if tick_query.is_valid() else enemies_inside()
	if _tick <= 0.0:
		_tick = tick_every
		if on_tick.is_valid():
			for enemy in targets:
				if not enemy._dead:
					on_tick.call(enemy)
	if pull > 0.0:
		for enemy in targets:
			if not enemy._dead and not enemy is Boss:
				enemy.position = enemy.position.move_toward(global_position, pull * delta)
	queue_redraw()


func enemies_inside() -> Array[Enemy]:
	if to == Vector2.ZERO:
		return Enemy.query_radius(global_position, radius)
	return Enemy.query_line(global_position, global_position + to, radius * 2.0)


func contains(pos: Vector2, margin: float = 0.0) -> bool:
	if to == Vector2.ZERO:
		return pos.distance_to(global_position) <= radius + margin
	var p := Geometry2D.get_closest_point_to_segment(pos, global_position, global_position + to)
	return p.distance_to(pos) <= radius + margin


func _draw() -> void:
	var fade := clampf((life - _age) / 0.4, 0.0, 1.0) * clampf(_age / 0.15, 0.0, 1.0)
	if to == Vector2.ZERO:
		if texture:
			draw_texture_rect(texture, Rect2(-Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color(1, 1, 1, fade))
		else:
			draw_circle(Vector2.ZERO, radius, Color(color, 0.16 * fade))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.5 * fade), 2.0)
		return
	if texture:
		var length := to.length()
		draw_set_transform(Vector2.ZERO, to.angle(), Vector2.ONE)
		draw_texture_rect(texture, Rect2(0, -radius, length, radius * 2.0), false, Color(1, 1, 1, fade))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_line(Vector2.ZERO, to, Color(color, 0.22 * fade), radius * 2.0)
		draw_line(Vector2.ZERO, to, Color(color, 0.45 * fade), maxf(2.0, radius * 0.5))
