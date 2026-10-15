class_name Player
extends CharacterBody2D
## 玩家：移动、受伤、经验与升级、信仰。武器和神明技能作为子节点挂在玩家身上

signal died
signal hp_changed(hp: float, max_hp: float)
signal xp_changed(xp: float, xp_to_next: int, level: int)
signal leveled_up(level: int)

const RADIUS := 14.0
const INVINCIBLE_DURATION := 0.5  # 受伤后的无敌时间，防止一瞬间被怪群秒杀

# 基础属性
var move_speed := 220.0
var max_hp := 100.0
var hp := 100.0
var pickup_radius := 90.0
var regen := 0.0          # 每秒回复生命
var dodge_chance := 0.0   # 闪避几率，0~1

# 全局加成，所有武器和技能共享
var damage_mult := 1.0
var cooldown_mult := 1.0
var xp_mult := 1.0

var level := 1
var xp := 0.0
var xp_to_next := 5
var is_dead := false
var facing := Vector2.RIGHT  # 最后移动的方向，太刀朝这里砍

var upgrade_levels := {}  # 升级 id -> 已选次数
var faith := {}           # 神明 id -> 信仰值

# 武器与神明技能，还没获得时为 null
var katana: Katana
var lightning: LightningStrike
var rune_bolt: RuneBolt
var fire_aura: FireAura
var feathers: FeatherOrbit

var _invincible_time := 0.0


func _ready() -> void:
	add_to_group("player")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	add_child(camera)

	katana = Katana.new()  # 初始武器：太刀
	add_child(katana)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# 方向键 + WASD 都能移动
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	dir.x += float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	dir.y += float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	dir = dir.limit_length(1.0)
	if dir != Vector2.ZERO:
		facing = dir.normalized()
	velocity = dir * move_speed
	move_and_slide()

	if regen > 0.0 and hp < max_hp:
		heal(regen * delta)
	_invincible_time = maxf(0.0, _invincible_time - delta)
	queue_redraw()


func take_damage(amount: float) -> void:
	if is_dead or _invincible_time > 0.0:
		return
	_invincible_time = INVINCIBLE_DURATION
	if randf() < dodge_chance:
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func add_xp(amount: float) -> void:
	xp += amount * xp_mult
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.25) + 3
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)


func _draw() -> void:
	var color := Color(0.95, 0.85, 0.55)
	if _invincible_time > 0.0 and int(_invincible_time * 20.0) % 2 == 0:
		color = Color(1, 0.4, 0.4)  # 受伤闪烁
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_line(Vector2.ZERO, facing * (RADIUS + 6.0), Color(1, 1, 1, 0.8), 3.0)  # 朝向指示
	draw_arc(Vector2.ZERO, pickup_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.06))
