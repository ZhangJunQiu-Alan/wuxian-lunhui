class_name RuneBolt
extends Node2D
## 奥丁·符文飞弹：每隔一段时间向射程内最近的几个敌人各发射一枚飞弹

const RANGE := 600.0  # 射程：约等于半个屏幕宽，敌人进入射程才会发射

var cooldown := 0.8
var damage := 12.0
var projectile_speed := 520.0
var pierce := 1  # 能穿透几个敌人
var count := 1   # 每次发射几枚
var player: Player
var _timer := 0.0


func _ready() -> void:
	player = get_parent() as Player


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var targets := _find_nearest_enemies(count)
	if targets.is_empty():
		return
	_timer = cooldown * player.cooldown_mult

	for i in count:
		var target: Node2D = targets[i % targets.size()]  # 敌人不够时重复瞄准
		var p := Projectile.new()
		p.global_position = global_position
		p.direction = global_position.direction_to(target.global_position)
		p.speed = projectile_speed
		p.damage = damage * player.damage_mult
		p.pierce = pierce
		get_tree().current_scene.add_child(p)


func _find_nearest_enemies(n: int) -> Array:
	var origin := global_position
	var enemies := get_tree().get_nodes_in_group("enemies").filter(func(e: Node2D) -> bool:
		return e.global_position.distance_to(origin) <= RANGE)
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	return enemies.slice(0, n)
