class_name FeatherOrbit
extends Node2D
## 弗蕾亚·女武神之羽：几片羽刃绕着玩家旋转，切割碰到的敌人

const FEATHER := preload("res://assets/sprites/effects/feather_blade.png")
const ORBIT_RADIUS := 85.0
const FEATHER_SIZE := 10.0
const HIT_COOLDOWN := 0.5  # 同一个敌人被羽刃连续伤害的最短间隔

var count := 2
var damage := 10.0
var spin_speed := 3.0  # 弧度/秒
var player: Player
var _angle := 0.0
var _time := 0.0
var _last_hit := {}  # 敌人 instance_id -> 上次被击中的时间


func _ready() -> void:
	player = get_parent() as Player


func _process(delta: float) -> void:
	_time += delta
	_angle = fmod(_angle + spin_speed * delta, TAU)
	queue_redraw()

	var dmg := damage * player.damage_mult
	var enemies := get_tree().get_nodes_in_group("enemies")
	for i in count:
		var p := global_position + _feather_offset(i)
		for node in enemies:
			var enemy := node as Enemy
			if enemy.global_position.distance_to(p) > enemy.radius + FEATHER_SIZE:
				continue
			var id := enemy.get_instance_id()
			if _time - _last_hit.get(id, -INF) < HIT_COOLDOWN:
				continue
			_last_hit[id] = _time
			enemy.take_damage(dmg, (enemy.global_position - global_position).normalized() * 120.0)
			Audio.sfx("feather_hit", -4.0)

	if _last_hit.size() > 300:  # 清理早已过期的记录，避免越存越多
		for id in _last_hit.keys():
			if _time - _last_hit[id] > HIT_COOLDOWN:
				_last_hit.erase(id)


func _feather_offset(i: int) -> Vector2:
	return Vector2.from_angle(_angle + TAU * i / count) * ORBIT_RADIUS


func _draw() -> void:
	for i in count:
		var p := _feather_offset(i)
		SpriteVisual.draw_frame(self, FEATHER, 1, 0, p, Vector2(16, 16), p.angle() + PI / 2)  # 羽刃顺着旋转方向
