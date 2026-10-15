class_name Player
extends CharacterBody2D
## 玩家：移动、受伤、经验与升级、信仰。武器和神明技能作为子节点挂在玩家身上
## 用哪个角色由 character_id 决定（在加入场景前设置），基础属性、武器、大招都从 CharacterDB 读取

signal died
signal hp_changed(hp: float, max_hp: float)
signal xp_changed(xp: float, xp_to_next: int, level: int)
signal leveled_up(level: int)
signal ult_changed(energy: float, cost: float)
signal ult_cast(character_id: String)

const SPRITE_HEIGHT := 48.0
const RADIUS := 14.0
const INVINCIBLE_DURATION := 0.5  # 受伤后的无敌时间，防止一瞬间被怪群秒杀

var character_id := CharacterDB.DEFAULT_ID
var data: Dictionary  # 角色数据（CharacterDB 里的一项）

# 基础属性（开局时按角色数据设置）
var move_speed := 220.0
var max_hp := 100.0
var hp := 100.0
var pickup_radius := 90.0
var regen := 0.0          # 每秒回复生命
var dodge_chance := 0.0   # 闪避几率，0~1
var rerolls := 0          # 本局还能重抽几次升级选项（主神空间购买）
var revives := 0          # 本局还能复活几次（主神空间购买）
var choice_count := 3     # 升级时有几个选项（梅林的被动「先知」是 4 个）
var frenzy_time := 0.0    # 安妮「狂野西部秀」剩余时间
var shield_time := 0.0    # 无敌剩余时间（兰陵王「入阵曲」），和受伤后的无敌不同，不会闪烁

# 全局加成，所有武器和技能共享
var damage_mult := 1.0
var cooldown_mult := 1.0
var xp_mult := 1.0

var level := 1
var xp := 0.0
var xp_to_next := 5
var is_dead := false
var facing := Vector2.RIGHT  # 最后移动的方向

# 大招：击杀充能，满了按空格释放
var ult_energy := 0.0
var ult_cost := 50.0

var upgrade_levels := {}  # 升级 id -> 已选次数
var faith := {}           # 神明 id -> 信仰值

# 角色的基础武器（只有其中一个不为 null）
var katana: Katana
var revolver: Revolver
var blades: TwinBlades
var nova: ArcaneNova

# 神明技能，还没获得时为 null
var lightning: LightningStrike
var rune_bolt: RuneBolt
var fire_aura: FireAura
var feathers: FeatherOrbit

var _invincible_time := 0.0
var _fear_time := 0.0  # 恐惧：不受控制地远离 _fear_from
var _fear_from := Vector2.ZERO
var _camera: Camera2D
var _sprite: Node2D
var _shake_strength := 0.0
var _shake_time := 0.0


func _ready() -> void:
	add_to_group("player")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	add_child(_camera)

	data = CharacterDB.ALL[character_id]
	max_hp = data.hp
	hp = max_hp
	move_speed = data.speed
	ult_cost = data.ult_cost
	if character_id == "merlin":
		choice_count = 4  # 先知

	# 素材：assets/sprites/characters/<角色id>.png（或 _move.png 帧条）
	_sprite = SpriteVisual.create(CharacterDB.CUTIN_DIR + character_id, SPRITE_HEIGHT)
	if _sprite:
		add_child(_sprite)

	match character_id:  # 角色的基础武器
		"musashi":
			katana = Katana.new()
			add_child(katana)
		"annie":
			revolver = Revolver.new()
			add_child(revolver)
		"lanling":
			blades = TwinBlades.new()
			add_child(blades)
		"merlin":
			nova = ArcaneNova.new()
			add_child(nova)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# 方向键 + WASD 都能移动
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	dir.x += float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	dir.y += float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	dir = dir.limit_length(1.0)
	if _fear_time > 0.0:
		_fear_time -= delta
		dir = (global_position - _fear_from).normalized()
	if dir != Vector2.ZERO:
		facing = dir.normalized()
	velocity = dir * move_speed * (1.3 if frenzy_time > 0.0 else 1.0)  # 狂野西部秀：移速 +30%
	move_and_slide()

	if regen > 0.0 and hp < max_hp:
		heal(regen * delta)
	_invincible_time = maxf(0.0, _invincible_time - delta)
	_tick_timers(delta)
	_update_shake(delta)
	queue_redraw()


func _tick_timers(delta: float) -> void:
	frenzy_time = maxf(0.0, frenzy_time - delta)
	shield_time = maxf(0.0, shield_time - delta)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		try_ultimate()


func add_ult_energy(amount: float) -> void:
	ult_energy = minf(ult_cost, ult_energy + amount)
	ult_changed.emit(ult_energy, ult_cost)


func try_ultimate() -> void:
	if is_dead or ult_energy < ult_cost:
		return
	ult_energy = 0.0
	ult_changed.emit(ult_energy, ult_cost)
	match character_id:
		"musashi":
			DimensionSlash.cast(self)
		"annie":
			WildWestShow.cast(self)
		"lanling":
			EnterFormation.cast(self)
		"merlin":
			Stonehenge.cast(self)
	ult_cast.emit(character_id)


## 镜头震动，strength 是最大偏移像素
func shake(strength: float, duration: float) -> void:
	strength *= Settings.screen_shake  # 设置里可以调低或关闭
	if strength <= 0.0:
		return
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)


func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time -= delta
	if _shake_time <= 0.0:
		_shake_strength = 0.0
		_camera.offset = Vector2.ZERO
	else:
		_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength


func take_damage(amount: float) -> void:
	if is_dead or _invincible_time > 0.0 or shield_time > 0.0:
		return
	_invincible_time = INVINCIBLE_DURATION
	if randf() < dodge_chance:
		return
	hp = maxf(0.0, hp - amount)
	shake(4.0, 0.15)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		is_dead = true
		died.emit()


## 复活：恢复一半生命，短暂无敌，并震开身边的敌人
func revive() -> void:
	revives -= 1
	is_dead = false
	hp = max_hp * 0.5
	_invincible_time = 2.0
	hp_changed.emit(hp, max_hp)
	shake(10.0, 0.4)
	FxLayer.burst(global_position, Color(1.0, 0.9, 0.5), 50, 320.0, 4.0)
	Enemy.damage_in_radius(get_tree(), global_position, 260.0, 0.0, 900.0)


## 恐惧：duration 秒内不受控制地远离 from
func fear(from: Vector2, duration: float) -> void:
	if is_dead:
		return
	_fear_from = from
	_fear_time = duration


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
	var hurt_blink := _invincible_time > 0.0 and int(_invincible_time * 20.0) % 2 == 0
	if _fear_time > 0.0:  # 恐惧时头顶有紫色漩涡
		draw_arc(Vector2(0, -RADIUS - 10), 7.0, _fear_time * 10.0, _fear_time * 10.0 + 4.5, 12, Color(0.75, 0.45, 1.0), 2.5)
	if revolver and revolver.reload_progress() >= 0.0:  # 安妮换弹：头顶一圈进度
		draw_arc(Vector2(0, -RADIUS - 12), 6.0, -PI / 2, -PI / 2 + TAU * revolver.reload_progress(), 16, Revolver.COLOR, 3.0)
	if _sprite:
		_sprite.modulate = Color(0.3, 0.1, 0.12) if shield_time > 0.0 else (Color(1, 0.4, 0.4) if hurt_blink else Color.WHITE)
		if facing.x != 0.0:
			_sprite.set("flip_h", facing.x < 0.0)
		draw_arc(Vector2.ZERO, pickup_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.06))
		return
	var color: Color = Color(1, 0.4, 0.4) if hurt_blink else data.color  # 受伤闪烁
	if shield_time > 0.0:
		color = Color(0.2, 0.05, 0.08)  # 入阵曲：化为鬼影
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_line(Vector2.ZERO, facing * (RADIUS + 6.0), Color(1, 1, 1, 0.8), 3.0)  # 朝向指示
	draw_arc(Vector2.ZERO, pickup_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.06))
