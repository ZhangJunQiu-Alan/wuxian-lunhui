class_name Enemy
extends Area2D
## 敌人：按行为追击或远程射击，彼此推挤不重叠，死亡掉落经验宝石

signal killed(enemy: Enemy)

const GRID_CELL := 48.0  # 推挤用的网格大小，要不小于两个普通敌人的半径之和

## 网格坐标 -> 该格里的敌人。每个物理帧由 game.gd 重建一次，
## 这样每个敌人只需要检查周围 9 个格子，而不是所有敌人
static var _grid := {}

var display_name := ""
var behavior := "chase"
var max_hp := 20.0
var hp := 20.0
var speed := 80.0
var contact_damage := 8.0
var radius := 12.0
var mass := 1.0
var xp_value := 1
var color := Color.WHITE
var is_elite := false
var target: Player

# 远程敌人
var shoot_range := 0.0
var shoot_cooldown := 0.0
var projectile_damage := 0.0
var _shoot_timer := 0.0

var _flash_time := 0.0
var _frozen_time := 0.0  # 被定住的剩余时间（次元斩、时间暂停）
var _dead := false


static func rebuild_grid(tree: SceneTree) -> void:
	_grid.clear()
	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var cell := Vector2i((enemy.global_position / GRID_CELL).floor())
		if _grid.has(cell):
			_grid[cell].append(enemy)
		else:
			_grid[cell] = [enemy]


## 对一个圆形范围内的所有敌人造成伤害（落雷、火焰等范围技能共用）
static func damage_in_radius(tree: SceneTree, center: Vector2, radius: float, amount: float) -> void:
	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.global_position.distance_to(center) <= radius + enemy.radius:
			enemy.take_damage(amount)


## 用数据表里的一行来初始化。hp_scale 让后期的怪更肉，elite 表示精英怪
func setup(data: Dictionary, hp_scale: float, elite: bool = false) -> void:
	display_name = data.name
	behavior = data.get("behavior", "chase")
	max_hp = data.hp * hp_scale
	speed = data.speed
	contact_damage = data.damage
	radius = data.radius
	mass = data.get("mass", 1.0)
	xp_value = data.xp
	color = data.color
	shoot_range = data.get("shoot_range", 0.0)
	shoot_cooldown = data.get("shoot_cooldown", 0.0)
	projectile_damage = data.get("projectile_damage", 0.0)
	_shoot_timer = shoot_cooldown * randf()  # 错开射击时机，避免同时开火

	if elite:
		is_elite = true
		display_name = "精英" + display_name
		max_hp *= EnemyDB.ELITE_HP
		radius *= EnemyDB.ELITE_SIZE
		contact_damage *= EnemyDB.ELITE_DAMAGE
		projectile_damage *= EnemyDB.ELITE_DAMAGE
		mass *= 3.0
		xp_value = EnemyDB.ELITE_XP
	hp = max_hp


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
	if _flash_time > 0.0:
		_flash_time -= delta
		queue_redraw()
	if not is_instance_valid(target):
		return
	if _frozen_time > 0.0:  # 被定住时不移动、不攻击
		_frozen_time -= delta
		if _frozen_time <= 0.0:
			queue_redraw()
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var dir := to_target / dist if dist > 0.01 else Vector2.ZERO

	var move := dir
	if behavior == "ranged":
		move = _ranged_move(dir, dist, delta)
	position += move * speed * delta + _separation()

	if dist < radius + Player.RADIUS:
		target.take_damage(contact_damage)


## 远程敌人：太远就靠近，太近就后退，在射程内定时射击
func _ranged_move(dir: Vector2, dist: float, delta: float) -> Vector2:
	if dist <= shoot_range:
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = shoot_cooldown
			EnemyProjectile.spawn(get_parent(), global_position, dir, projectile_damage)
	if dist > shoot_range * 0.9:
		return dir
	if dist < shoot_range * 0.6:
		return -dir
	return Vector2.ZERO


## 推挤：和周围重叠的敌人互相推开，越重的越不容易被推动
func _separation() -> Vector2:
	var push := Vector2.ZERO
	var cell := Vector2i((global_position / GRID_CELL).floor())
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			for other: Enemy in _grid.get(Vector2i(x, y), []):
				if other == self:
					continue
				var offset := global_position - other.global_position
				var overlap := radius + other.radius - offset.length()
				if overlap <= 0.0:
					continue
				if offset == Vector2.ZERO:
					offset = Vector2.from_angle(randf() * TAU)
				push += offset.normalized() * overlap * other.mass / (mass + other.mass)
	return push * 0.5  # 每帧只推一半，移动更平滑


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
	gem.big = is_elite
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
	if is_elite:
		draw_circle(Vector2.ZERO, radius + 4.0, Color(1.0, 0.8, 0.3, 0.9))  # 精英怪带金边
	draw_circle(Vector2.ZERO, radius, c)
	if behavior == "ranged":
		draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.8))  # 远程敌人中间有个亮核
