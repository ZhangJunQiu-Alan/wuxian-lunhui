class_name Enemy
extends Area2D
## 敌人：追着玩家走，碰到就造成伤害，死亡掉落经验宝石

signal killed(enemy: Enemy)

var display_name := ""
var max_hp := 20.0
var hp := 20.0
var speed := 80.0
var contact_damage := 8.0
var radius := 12.0
var xp_value := 1
var color := Color.WHITE
var target: Player
var _flash_time := 0.0
var _frozen_time := 0.0  # 被定住的剩余时间（次元斩、时间暂停）
var _dead := false


## 对一个圆形范围内的所有敌人造成伤害（落雷、火焰等范围技能共用）
static func damage_in_radius(tree: SceneTree, center: Vector2, radius: float, amount: float) -> void:
	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.global_position.distance_to(center) <= radius + enemy.radius:
			enemy.take_damage(amount)


## 用数据表里的一行来初始化，hp_scale 让后期的怪更肉
func setup(data: Dictionary, hp_scale: float) -> void:
	display_name = data.name
	max_hp = data.hp * hp_scale
	hp = max_hp
	speed = data.speed
	contact_damage = data.damage
	radius = data.radius
	xp_value = data.xp
	color = data.color


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2  # 第 2 层 = 敌人，子弹只检测这一层
	collision_mask = 0
	monitoring = false

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	if _frozen_time > 0.0:  # 被定住时不移动、不造成伤害
		_frozen_time -= delta
		if _frozen_time <= 0.0:
			queue_redraw()
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist > 1.0:
		position += to_target / dist * speed * delta
	if dist < radius + Player.RADIUS:
		target.take_damage(contact_damage)

	if _flash_time > 0.0:
		_flash_time -= delta
		queue_redraw()


func freeze(duration: float) -> void:
	_frozen_time = maxf(_frozen_time, duration)
	queue_redraw()


func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	_flash_time = 0.08
	queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	var gem := XpGem.new()
	gem.value = xp_value
	gem.player = target
	gem.position = position
	# 在物理回调中不能直接加碰撞体相关节点，所以用 call_deferred 延迟到帧末
	get_parent().call_deferred("add_child", gem)
	killed.emit(self)
	queue_free()


func _draw() -> void:
	var c := color
	if _flash_time > 0.0:
		c = Color.WHITE
	elif _frozen_time > 0.0:
		c = color.lerp(Color(0.6, 0.7, 1.0), 0.5)  # 被定住时偏蓝
	draw_circle(Vector2.ZERO, radius, c)
