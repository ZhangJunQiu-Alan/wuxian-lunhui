class_name RuneBolt
extends Node2D
## 武器「符文飞弹」：每隔一段时间向最近的敌人发射一枚飞弹

var cooldown := 0.6
var damage := 12.0
var projectile_speed := 520.0
var pierce := 1  # 能穿透几个敌人
var _timer := 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_timer = cooldown

	var p := Projectile.new()
	p.global_position = global_position
	p.direction = global_position.direction_to(target.global_position)
	p.speed = projectile_speed
	p.damage = damage
	p.pierce = pierce
	get_tree().current_scene.add_child(p)


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var best := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			nearest = enemy
	return nearest
