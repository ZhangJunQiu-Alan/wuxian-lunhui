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
const MAX_LEVEL := 30
const XP_STEP := 6  # 每升一级，下一级多要这么多经验（2 级要 5，3 级要 11，4 级要 17……）
const RADIUS := 14.0
const INVINCIBLE_DURATION := 0.5  # 受伤后的无敌时间，防止一瞬间被怪群秒杀
const ACTIONS := {"idle": true, "move": true, "attack": false, "hurt": false, "death": false}  # 动作素材：是否循环
const ATTACK_POSE := 0.2  # 没有出招素材时，程序前冲动作的时长
const DASH_DISTANCE := 150.0
const DASH_COOLDOWN := 2.0
const DASH_TIME := 0.14       # 冲出去用的时间：先快后慢地滑过去，而不是瞬间出现在终点
const DASH_INVINCIBLE := 0.12  # 落地后额外的无敌时间；冲刺过程中一直无敌，可以穿过怪群和弹幕
const DASH_GHOST_EVERY := 0.022  # 冲刺途中每隔多久留下一个残影
const DASH_STRETCH := Vector2(1.22, 0.82)  # 冲刺时身体顺着方向拉长、压扁（这是横着冲的比例）

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
var choice_count := 3     # 升级时有几个选项（法师的被动「先知」是 4 个）
var frenzy_time := 0.0    # 枪手「狂野西部秀」剩余时间
var speed_mult := 1.0     # 支线临时改变的移速（寒潮里冻僵、搬运余烬）
var shield_time := 0.0    # 无敌剩余时间（刺客「入阵曲」），和受伤后的无敌不同，不会闪烁

# 全局加成，所有武器和技能共享
var damage_mult := 1.0
var cooldown_mult := 1.0         # 所有攻击（永久强化「专注」、支线奖励）
var weapon_cooldown_mult := 1.0  # 只管基础武器（通用卡「急速」）
var god_cooldown_mult := 1.0     # 只管神术（通用卡「冷却缩短」）
var xp_mult := 1.0
var luck := 0.0           # 抽到高稀有度卡的几率加成（%）
var ward := 0             # 誓言护盾层数（巴德尔「万物之誓」）：每层挡一次伤害
var immune_time := 0.0    # 无敌剩余时间（巴德尔觉醒「无伤之神」）
var slow_immune := false  # 免疫减速（斯卡蒂觉醒）

var level := 1
var xp := 0.0
var xp_to_next := 5
var is_dead := false
var facing := Vector2.RIGHT  # 最后移动的方向

# 大招：击杀充能，满了按 E 释放
var ult_energy := 0.0
var ult_cost := 50.0

var upgrade_levels := {}  # 升级 id -> 已选次数
var faith := {}           # 神明 id -> 信仰值
var gods := {}            # 神明 id -> 神术节点（GodPower）

# 角色的基础武器（只有其中一个不为 null）
var katana: Katana
var revolver: Revolver
var blades: TwinBlades
var nova: ArcaneNova

var _invincible_time := 0.0
var _fear_time := 0.0  # 恐惧：不受控制地远离 _fear_from
var _fear_from := Vector2.ZERO
var _dash_cooldown := 0.0
var _dash_time := 0.0  # 闪现无敌剩余时间
var _dash_t := -1.0   # 冲刺进行了多久；小于 0 表示没在冲刺
var _dash_from := Vector2.ZERO
var _dash_to := Vector2.ZERO
var _ghost_timer := 0.0
var _camera: Camera2D
var _sprite: Node2D
var _actions: AnimatedSprite2D  # 有多动作素材时就是 _sprite，否则为 null
var _hurt_time := 0.0  # 受击动作剩余时间
var _attack_time := 0.0  # 出招动作剩余时间
var _attack_dir := Vector2.RIGHT
var _attack_lunge := 7.0
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
	if Game.view_bounds.has_area():  # 镜头走到地图边缘就停住，不拍地图外面
		_camera.limit_left = int(Game.view_bounds.position.x)
		_camera.limit_top = int(Game.view_bounds.position.y)
		_camera.limit_right = int(Game.view_bounds.end.x)
		_camera.limit_bottom = int(Game.view_bounds.end.y)
	add_child(_camera)

	data = CharacterDB.ALL[character_id]
	max_hp = data.hp
	hp = max_hp
	move_speed = data.speed
	ult_cost = data.ult_cost
	if character_id == "mage":
		choice_count = 4  # 先知

	# 素材：assets/sprites/characters/<角色id>_idle/_move/_hurt/_death.png 动作帧条，没有就用 <角色id>.png
	_actions = SpriteVisual.create_actions(CharacterDB.CUTIN_DIR + character_id, SPRITE_HEIGHT, ACTIONS)
	_sprite = _actions if _actions else SpriteVisual.create(CharacterDB.CUTIN_DIR + character_id, SPRITE_HEIGHT)
	if _sprite:
		add_child(_sprite)

	match character_id:  # 角色的基础武器
		"swordsman":
			katana = Katana.new()
			add_child(katana)
		"gunslinger":
			revolver = Revolver.new()
			add_child(revolver)
		"assassin":
			blades = TwinBlades.new()
			add_child(blades)
		"mage":
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
	if _dash_t >= 0.0:
		_update_dash(delta)
	else:
		var slowed := maxf(speed_mult, 1.0) if slow_immune else speed_mult
		velocity = dir * move_speed * slowed * (1.3 if frenzy_time > 0.0 else 1.0)  # 狂野西部秀：移速 +30%
		move_and_slide()
		position = MapLayer.push_out(Game.clamp_to_map(position, RADIUS), RADIUS)

	if regen > 0.0 and hp < max_hp:
		heal(regen * delta)
	_invincible_time = maxf(0.0, _invincible_time - delta)
	_tick_timers(delta)
	_update_action(dir)
	_update_shake(delta)
	queue_redraw()


func _tick_timers(delta: float) -> void:
	frenzy_time = maxf(0.0, frenzy_time - delta)
	shield_time = maxf(0.0, shield_time - delta)
	immune_time = maxf(0.0, immune_time - delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	_attack_time = maxf(0.0, _attack_time - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_dash_time = maxf(0.0, _dash_time - delta)


## 武器出招时调用：转向出招方向；有 <角色id>_attack.png 就播放，否则身体朝出招方向前冲一下
## lunge 是前冲的像素数（开枪只需要很小的动作）
## interval 是武器两次出手的间隔：出手比动作还快时（双刃、狂野西部秀）动作加速，保证每次都完整播一遍
func play_attack(dir: Vector2, lunge: float = 7.0, interval: float = 0.0) -> void:
	_attack_dir = dir
	_attack_lunge = lunge
	_attack_time = ATTACK_POSE
	if _has_action(&"attack"):
		var frames := _actions.sprite_frames
		var length := frames.get_frame_count(&"attack") / frames.get_animation_speed(&"attack")
		_actions.speed_scale = maxf(1.0, length / interval) if interval > 0.0 else 1.0
		_attack_time = length / _actions.speed_scale
		_actions.play(&"attack")
		_actions.frame = 0


func _has_action(action: StringName) -> bool:
	return _actions != null and _actions.sprite_frames.has_animation(action)


## 程序出招动作：先往前冲再收回，身体跟着前倾
func _update_attack_pose() -> void:
	if not _sprite or _has_action(&"attack"):
		return
	var base_pos: Vector2 = _sprite.get_meta("base_pos", Vector2.ZERO)
	var k := sin((1.0 - _attack_time / ATTACK_POSE) * PI) if _attack_time > 0.0 else 0.0
	_sprite.position = base_pos + _attack_dir * _attack_lunge * k
	_sprite.rotation = _attack_dir.x * 0.025 * _attack_lunge * k


## 按状态切换动作：受击 > 出招 > 跑步 > 待机
func _update_action(dir: Vector2) -> void:
	_update_attack_pose()
	if not _actions:
		return
	var action := &"idle"
	if _hurt_time > 0.0:
		action = &"hurt"
	elif _attack_time > 0.0 and _has_action(&"attack"):
		action = &"attack"
	elif dir != Vector2.ZERO:
		action = &"move"
	if not _actions.sprite_frames.has_animation(action):
		action = &"move" if action == &"idle" else &"idle"
		if not _actions.sprite_frames.has_animation(action):
			return
	if _actions.animation != action:
		if action != &"attack":
			_actions.speed_scale = 1.0
		_actions.play(action)


## 倒地动作的时长（秒），没有倒地素材时为 0
func death_duration() -> float:
	if not (_actions and _actions.sprite_frames.has_animation(&"death")):
		return 0.0
	var frames := _actions.sprite_frames
	return frames.get_frame_count(&"death") / frames.get_animation_speed(&"death")


## 播放倒地动作。游戏会在玩家死亡时暂停，所以让精灵在暂停时也继续播放
func play_death() -> void:
	if death_duration() <= 0.0:
		return
	_actions.process_mode = Node.PROCESS_MODE_ALWAYS
	_actions.modulate = Color.WHITE
	_actions.play(&"death")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not (key and key.pressed and not key.echo):
		return
	if key.keycode == KEY_SPACE:
		try_dash()
	elif key.keycode == KEY_E:
		try_ultimate()


## 闪现：往移动方向快速冲出一段距离（DASH_TIME 秒内先快后慢地滑过去），可以穿过怪物和物件，但出不了地图
## 起步时身体拉长、脚下扬起一圈气流，途中留下一串残影，落地时身体回弹
func try_dash() -> void:
	if is_dead or _dash_t >= 0.0 or _dash_cooldown > 0.0 or _fear_time > 0.0:
		return
	_dash_cooldown = DASH_COOLDOWN
	_dash_time = DASH_TIME + DASH_INVINCIBLE
	_dash_from = position
	_dash_to = MapLayer.push_out(Game.clamp_to_map(position + facing * DASH_DISTANCE, RADIUS), RADIUS)
	_dash_t = 0.0
	_ghost_timer = 0.0
	Audio.sfx("dash")
	FxLayer.burst(global_position, Color(0.75, 0.9, 1.0), 10, 110.0, 2.5)
	for i in 6:  # 起步的气流向身后喷出
		FxLayer.burst(global_position - facing * 10.0, Color(0.85, 0.95, 1.0, 0.8), 1, 60.0 + i * 25.0, 2.0)
	get_tree().call_group("god_powers", "on_dash")


func _update_dash(delta: float) -> void:
	_dash_t += delta
	var k := minf(1.0, _dash_t / DASH_TIME)
	position = _dash_from.lerp(_dash_to, 1.0 - pow(1.0 - k, 3.0))
	velocity = Vector2.ZERO
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = DASH_GHOST_EVERY
		_spawn_ghost(0.6 * (1.0 - k) + 0.3)
	if _sprite:
		var base: Vector2 = _sprite.get_meta("base_scale", Vector2.ONE)
		var vertical := absf((_dash_to - _dash_from).normalized().y)  # 上下冲刺时竖着拉长
		var stretch := Vector2(lerpf(DASH_STRETCH.x, DASH_STRETCH.y, vertical), lerpf(DASH_STRETCH.y, DASH_STRETCH.x, vertical))
		_sprite.scale = base * Vector2.ONE.lerp(stretch, 1.0 - k * k)
	if k >= 1.0:
		_dash_t = -1.0
		FxLayer.burst(global_position, Color(0.75, 0.9, 1.0), 8, 90.0, 2.0)
		if _sprite:  # 落地回弹：先压扁一点，再弹回原样
			var base: Vector2 = _sprite.get_meta("base_scale", Vector2.ONE)
			_sprite.scale = base * Vector2(0.9, 1.1)
			var tween := create_tween()
			tween.tween_property(_sprite, "scale", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 在当前位置留下一个渐隐的蓝色残影
func _spawn_ghost(alpha: float) -> void:
	if not _sprite:
		return
	var ghost: Node2D = _sprite.duplicate()
	if ghost is AnimatedSprite2D:
		ghost.stop()
		ghost.frame = _actions.frame
	ghost.position = position + _sprite.position
	ghost.modulate = Color(0.7, 1.1, 1.6, alpha)  # 大于 1 的颜色让残影发亮
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)


func add_ult_energy(amount: float) -> void:
	if ult_energy < ult_cost and ult_energy + amount >= ult_cost:
		Audio.sfx("ult_ready")
	ult_energy = minf(ult_cost, ult_energy + amount)
	ult_changed.emit(ult_energy, ult_cost)


func try_ultimate() -> void:
	if is_dead or ult_energy < ult_cost:
		return
	ult_energy = 0.0
	ult_changed.emit(ult_energy, ult_cost)
	Audio.sfx("ult_" + character_id)
	match character_id:
		"swordsman":
			DimensionSlash.cast(self)
		"gunslinger":
			WildWestShow.cast(self)
		"assassin":
			EnterFormation.cast(self)
		"mage":
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
	if is_dead or _invincible_time > 0.0 or shield_time > 0.0 or _dash_time > 0.0 or immune_time > 0.0:
		return
	_invincible_time = INVINCIBLE_DURATION
	if randf() < dodge_chance:
		return
	if ward > 0:  # 誓言护盾挡下这一次
		ward -= 1
		FxLayer.burst(global_position, Color(1.0, 0.92, 0.6), 12, 140.0, 3.0)
		return
	hp = maxf(0.0, hp - amount)
	_hurt_time = 0.25
	Audio.sfx("player_death" if hp <= 0.0 else "player_hurt")
	shake(4.0, 0.15)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		is_dead = true
		died.emit()
	else:
		get_tree().call_group("god_powers", "on_player_hurt")


## 信仰一位新的神：信仰 1，获得他的神术
func add_god(god_id: String) -> void:
	faith[god_id] = 1
	var power := GodPower.create(god_id)
	gods[god_id] = power
	add_child(power)


## 基础武器的冷却倍率
func weapon_cooldown() -> float:
	return cooldown_mult * weapon_cooldown_mult


## 基础武器伤害 +bonus（没有数值的武器卡抽到高稀有度时的附带加成）
func weapon_damage_bonus(bonus: float) -> void:
	for weapon: Node in [katana, revolver, blades, nova]:
		if weapon:
			weapon.damage *= 1.0 + bonus


## 持续伤害（吸血、冥雾）：不触发受伤后的无敌和闪烁，闪避也躲不掉
func take_dot(amount: float) -> void:
	if is_dead or shield_time > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		is_dead = true
		Audio.sfx("player_death")
		died.emit()


## 复活：恢复一半生命，短暂无敌，并震开身边的敌人
func revive() -> void:
	revives -= 1
	is_dead = false
	if _actions:
		_actions.process_mode = Node.PROCESS_MODE_INHERIT
		_actions.play(&"idle")
	hp = max_hp * 0.5
	_invincible_time = 2.0
	hp_changed.emit(hp, max_hp)
	shake(10.0, 0.4)
	Audio.sfx("revive")
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
	if level >= MAX_LEVEL:
		return
	xp += amount * xp_mult
	while level < MAX_LEVEL and xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next += XP_STEP
		leveled_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0.0
	xp_changed.emit(xp, xp_to_next, level)


func _draw() -> void:
	if _dash_t >= 0.0:  # 冲刺途中：从起点到身体的一道渐细的光
		var tail := _dash_from - position
		var side := tail.normalized().orthogonal() * 9.0
		var fade := 1.0 - minf(1.0, _dash_t / DASH_TIME)
		draw_colored_polygon(PackedVector2Array([tail, side, -side]), Color(0.6, 0.85, 1.0, 0.28 * fade + 0.1))
		draw_line(tail * 0.6, Vector2.ZERO, Color(0.9, 0.97, 1.0, 0.45 * fade + 0.15), 2.0)
	var hurt_blink := _invincible_time > 0.0 and int(_invincible_time * 20.0) % 2 == 0
	if _fear_time > 0.0:  # 恐惧时头顶有紫色漩涡
		draw_arc(Vector2(0, -RADIUS - 10), 7.0, _fear_time * 10.0, _fear_time * 10.0 + 4.5, 12, Color(0.75, 0.45, 1.0), 2.5)
	if revolver and revolver.reload_progress() >= 0.0:  # 枪手换弹：头顶一圈进度
		draw_arc(Vector2(0, -RADIUS - 12), 6.0, -PI / 2, -PI / 2 + TAU * revolver.reload_progress(), 16, Revolver.COLOR, 3.0)
	if _dash_cooldown > 0.0:  # 闪现冷却：脚下一条短进度条
		var k := 1.0 - _dash_cooldown / DASH_COOLDOWN
		draw_line(Vector2(-12, 30), Vector2(12, 30), Color(0, 0, 0, 0.5), 3.0)
		draw_line(Vector2(-12, 30), Vector2(-12 + 24 * k, 30), Color(0.6, 0.85, 1.0, 0.8), 3.0)
	if _sprite:
		_sprite.modulate = Color(0.3, 0.1, 0.12) if shield_time > 0.0 else (Color(1, 0.4, 0.4) if hurt_blink else Color.WHITE)
		var look := _attack_dir if _attack_time > 0.0 else facing  # 出招时面向敌人
		if look.x != 0.0:
			_sprite.set("flip_h", look.x < 0.0)
		draw_arc(Vector2.ZERO, pickup_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.06))
		return
	var color: Color = Color(1, 0.4, 0.4) if hurt_blink else data.color  # 受伤闪烁
	if shield_time > 0.0:
		color = Color(0.2, 0.05, 0.08)  # 入阵曲：化为鬼影
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_line(Vector2.ZERO, facing * (RADIUS + 6.0), Color(1, 1, 1, 0.8), 3.0)  # 朝向指示
	draw_arc(Vector2.ZERO, pickup_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.06))
