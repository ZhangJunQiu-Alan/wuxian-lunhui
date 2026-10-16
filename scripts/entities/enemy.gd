class_name Enemy
extends Area2D
## 敌人：按行为追击或远程射击，彼此推挤不重叠，死亡掉落经验宝石

signal killed(enemy: Enemy)

const GRID_CELL := 48.0  # 推挤用的网格大小，要不小于两个普通敌人的半径之和
const KNOCKBACK_DECAY := 10.0  # 击退速度衰减，越大停得越快
const SPRITE_DIR := "res://assets/sprites/enemies/"
const ACTIONS := {"move": true, "attack": false}  # 动作素材 <id>_move.png / <id>_attack.png：是否循环
const ATTACK_TIME := 0.34      # 一次攻击动作：后撤蓄力 → 前扑 → 收回
const ATTACK_STRIKE := 0.45    # 动作进行到这个比例时出手（播放爪痕等特效）
const ATTACK_COOLDOWN := 1.0
const ATTACK_REACH := 14.0     # 离玩家比接触距离再远这么多就开始出招
const CAST_TIME := 0.45        # 远程敌人开火前的聚能时间

## 网格坐标 -> 该格里的敌人。每个物理帧由 game.gd 重建一次，
## 这样每个敌人只需要检查周围 9 个格子，而不是所有敌人
static var _grid := {}

var type_id := ""
var sprite_dir := SPRITE_DIR  # Boss 会改成 bosses 目录
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
var gait := "walk"
var attack_kind := "claw"
var actions := ACTIONS  # 要找的动作帧条，Boss 有更多动作
var flee_to := Vector2.INF  # 设置后不再追玩家，而是走向这里（支线「冰海来客」的霜巨人）

# 远程敌人
var shoot_range := 0.0
var shoot_cooldown := 0.0
var projectile_damage := 0.0
var _shoot_timer := 0.0

var _flash_time := 0.0
var _frozen_time := 0.0  # 被定住的剩余时间（次元斩、时间暂停）
var _knockback := Vector2.ZERO
var _sprite: Node2D  # 有素材时的图片节点，没有素材时为 null，用占位图形
var _actions: AnimatedSprite2D  # 有 move/attack 帧条时就是 _sprite
var _attack_t := 0.0  # 攻击动作剩余时间
var _attack_cd := randf() * ATTACK_COOLDOWN
var _attack_dir := Vector2.RIGHT
var _casting := false  # 远程敌人正在聚能
var _anim_t := randf() * 10.0  # 程序动画的时间，随机起点让怪物步伐错开
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
## knockback 是把敌人从中心向外推开的力度
static func damage_in_radius(tree: SceneTree, center: Vector2, radius: float, amount: float, knockback: float = 0.0) -> void:
	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var offset := enemy.global_position - center
		if offset.length() <= radius + enemy.radius:
			enemy.take_damage(amount, offset.normalized() * knockback)


## 用 EnemyDB 里的数据初始化。hp_scale 让后期的怪更肉，elite 表示精英怪
func setup(id: String, hp_scale: float, elite: bool = false) -> void:
	var data: Dictionary = EnemyDB.ALL[id]
	type_id = id
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
	gait = data.get("gait", "walk")
	attack_kind = data.get("attack", "claw")
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

	# 素材放在 assets/sprites/enemies/<敌人 id>.png（或 _move.png / _attack.png 帧条）就会自动使用
	# 精英怪优先使用 <id>_elite 素材，没有就用普通素材
	var paths: Array[String] = [sprite_dir + type_id]
	if is_elite:
		paths.push_front(sprite_dir + type_id + "_elite")
	# 每个路径先找动作帧条，再找静态图；精英有自己的静态图时不会借用普通怪的动作
	for path in paths:
		_actions = SpriteVisual.create_actions(path, radius * 2.6, actions)
		_sprite = _actions if _actions else SpriteVisual.create(path, radius * 2.6)
		if _sprite:
			break
	if _actions:
		_actions.animation_finished.connect(_on_action_finished)
	if _sprite:
		add_child(_sprite)


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
	if flee_to.is_finite():
		move = global_position.direction_to(flee_to)
	elif behavior == "ranged":
		move = _ranged_move(dir, dist, delta)
	position += move * speed * delta + _knockback * delta + _separation()
	_knockback *= exp(-KNOCKBACK_DECAY * delta)
	_update_attack(dir, dist, delta)
	if _sprite:
		var look := _attack_dir if _attack_t > 0.0 else dir
		if look.x != 0.0:
			_sprite.set("flip_h", look.x < 0.0)  # 素材默认朝右，往左走时翻转
		_anim_t += delta
		var lift := Vector2(0, -5.0) if _casting else Vector2.ZERO  # 聚能时浮起
		SpriteVisual.animate(_sprite, _anim_t, maxf(0.25, move.length()), gait, move.x, _attack_offset() + lift)  # 站着不动时也轻微呼吸

	if dist < radius + Player.RADIUS:
		target.take_damage(contact_damage)


## 近身攻击动作（纯表现，伤害仍按接触计算）：靠近玩家时后撤蓄力、前扑，出手瞬间播放特效
## 有 <id>_attack.png 帧条就同时播放它
func _update_attack(dir: Vector2, dist: float, delta: float) -> void:
	_attack_cd -= delta
	if _attack_t > 0.0:
		var before := _attack_t
		_attack_t -= delta
		var strike_at := ATTACK_TIME * (1.0 - ATTACK_STRIKE)
		if before > strike_at and _attack_t <= strike_at:
			_strike()
	elif _attack_cd <= 0.0 and dist < radius + Player.RADIUS + ATTACK_REACH:
		_attack_t = ATTACK_TIME
		_attack_cd = ATTACK_COOLDOWN * randf_range(0.85, 1.15)
		_attack_dir = dir
		_play_attack_frames()


## 攻击动作播完回到行走
func _on_action_finished() -> void:
	if _actions.animation == &"attack":
		_actions.play(&"move" if _actions.sprite_frames.has_animation(&"move") else &"idle")


## 有 <id>_attack.png 就播放一遍，播完自动回到行走
func _play_attack_frames() -> void:
	if _actions and _actions.sprite_frames.has_animation(&"attack"):
		_actions.play(&"attack")


## 攻击动作的位移：先往后缩，再猛地扑出去，然后收回。巨人是慢慢举高再砸回地面
func _attack_offset() -> Vector2:
	if _attack_t <= 0.0:
		return Vector2.ZERO
	var k := 1.0 - _attack_t / ATTACK_TIME  # 0 → 1
	var dist := radius * 0.5 + 5.0  # 体型越大扑得越远
	if attack_kind == "slam":
		return Vector2(0, -dist * k / ATTACK_STRIKE) if k < ATTACK_STRIKE else Vector2.ZERO
	var reach: float
	if k < ATTACK_STRIKE:
		reach = -0.5 * k / ATTACK_STRIKE  # 后撤蓄力
	elif k < ATTACK_STRIKE + 0.15:
		reach = lerpf(-0.5, 1.0, (k - ATTACK_STRIKE) / 0.15)  # 前扑
	else:
		reach = 1.0 - (k - ATTACK_STRIKE - 0.15) / (0.85 - ATTACK_STRIKE)  # 收回
	return _attack_dir * dist * reach


## 出手瞬间的特效
func _strike() -> void:
	var at := global_position + _attack_dir * (radius + 4.0)
	var size := radius * 2.0 + 10.0
	match attack_kind:
		"bite":
			FxLayer.mark(at, _attack_dir.angle(), size * 0.7, Color(1.0, 0.9, 0.85), "bite")
		"slam":
			var ground := global_position + Vector2(0, radius * 0.6)
			FxLayer.ring(ground, radius * 2.6, Color(0.7, 0.85, 1.0))
			FxLayer.burst(ground, Color(0.75, 0.85, 1.0), 12, 200.0, 4.0)
			if is_instance_valid(target) and target.global_position.distance_to(global_position) < radius * 3.0:
				target.shake(3.0 if not is_elite else 5.0, 0.12)
		_:
			FxLayer.mark(at, _attack_dir.angle() + 0.9, size, Color(1.0, 0.35, 0.3), "claw")


## 远程敌人：太远就靠近，进入射程后停下定时射击（不会后退，近战角色可以追上去砍）
## 开火前 CAST_TIME 秒聚能：身前亮起越来越大的冰光
func _ranged_move(dir: Vector2, dist: float, delta: float) -> Vector2:
	var was_casting := _casting
	_casting = false
	if dist <= shoot_range:
		_shoot_timer -= delta
		_casting = _shoot_timer < CAST_TIME
		if _casting and not was_casting:
			_play_attack_frames()  # 远程敌人的出招动作就是施法
		if _shoot_timer <= 0.0:
			_shoot_timer = shoot_cooldown
			_casting = false
			EnemyProjectile.spawn(get_parent(), global_position, dir, projectile_damage)
			FxLayer.burst(global_position + dir * radius, color.lightened(0.4), 6, 120.0, 3.0)
	if _casting or was_casting:
		queue_redraw()
	if dist > shoot_range * 0.9:
		return dir
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


## knockback 是击退方向乘以力度；crit 为 true 时伤害数字显示为金色大字
func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if _dead:
		return
	hp -= amount
	_knockback += knockback / mass  # 越重越难击退
	_flash_time = 0.08
	queue_redraw()
	if amount > 0.0:  # 只击退不造成伤害时（例如复活震开）不显示数字
		FxLayer.damage_number(global_position + Vector2(randf_range(-8, 8), -radius - 4), amount, crit)
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
	FxLayer.burst(global_position, color, 30 if is_elite else 8, 220.0 if is_elite else 150.0)
	if is_elite:
		target.shake(6.0, 0.2)
	killed.emit(self)
	queue_free()


func _draw() -> void:
	var tint := Color.WHITE
	if _flash_time > 0.0:
		tint = Color(3, 3, 3)  # 受击闪白
	elif _frozen_time > 0.0:
		tint = Color(0.6, 0.75, 1.3)  # 被定住时偏蓝
	var pop := 1.0 + 0.15 * _flash_time / 0.08  # 受击时略微放大
	if _casting and is_instance_valid(target):
		var k := 1.0 - maxf(0.0, _shoot_timer) / CAST_TIME  # 聚能进度 0 → 1
		var orb := global_position.direction_to(target.global_position) * (radius + 2.0) + Vector2(0, -5.0)
		draw_circle(orb, 3.0 + 7.0 * k, Color(color.lightened(0.3), 0.25 + 0.3 * k))
		draw_circle(orb, 1.5 + 3.0 * k, Color(1, 1, 1, 0.6 + 0.4 * k))
		tint = tint.lerp(Color(1.5, 1.7, 2.0), 0.5 * k)  # 身体也跟着变亮
	if _sprite:
		SpriteVisual.draw_shadow(self, radius, Color(1.0, 0.8, 0.3, 0.7) if is_elite else Color(0, 0, 0, 0.35))  # 精英怪是金色影子
		_sprite.modulate = tint
		return
	if is_elite:
		draw_circle(Vector2.ZERO, radius * pop + 4.0, Color(1.0, 0.8, 0.3, 0.9))  # 精英怪带金边

	draw_circle(Vector2.ZERO, radius * pop, color * tint if _flash_time <= 0.0 else Color.WHITE)
	if behavior == "ranged":
		draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.8))  # 远程敌人中间有个亮核
