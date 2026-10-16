class_name Boss
extends Enemy
## Boss 基类：所有 Boss 共用的血条信号、技能状态机、击败掉落
## 具体的 Boss 继承它，在 _update_state() 里写自己的技能，在 _draw_telegraph() 里画技能预警
##
## 状态机：Boss 任何时候都处于一个状态（例如 "chase" 追击、"dash" 冲锋），
## 用 change_state() 切换，state_time 记录当前状态持续了多久

signal hp_changed(hp: float, max_hp: float)
signal defeated(boss: Boss)

const ULT_ENERGY_PER_KILL := 30.0  # 打完一个 Boss 总共给多少大招能量（按伤害比例给）
## 动作素材 bosses/<id>_<动作>.png：是否循环。不循环的动作播完停在最后一帧
const BOSS_ACTIONS := {"idle": true, "move": true, "windup": false, "attack": false, "howl": false, "shield": false, "stomp": false}

var title := ""        # 称号，例如「追日之狼」
var intro_line := ""   # 登场台词
var defeat_line := ""  # 击败台词
var state := ""
var state_time := 0.0
var spawner: Callable  # 召唤小怪用，由 game.gd 传入：spawner.call(敌人id, 位置)
var reward_points := 100  # 击败后获得的奖励点
var casts_shadow := true  # 哈提自己画「真身影子」，所以关掉通用影子
var defeated_bosses: Array[String] = []  # 本关已击败的 Boss，由 game.gd 传入（哈提会因斯库尔之死狂暴）
## 状态 -> 动作。没写的状态：chase 播 move，recover 播 idle，以 windup 结尾的播 windup，其余播 attack
var state_actions := {}
var _oneshot := &""   # play_once() 正在播放的动作，播完回到状态动作
var _playing := &""


## 初始化 Boss 属性。hp_scale 和普通敌人一样随时间增长
func setup_boss(id: String, boss_name: String, boss_title: String, base_hp: float, hp_scale: float,
		boss_radius: float, move_speed: float, damage: float) -> void:
	type_id = id
	display_name = boss_name
	title = boss_title
	sprite_dir = "res://assets/sprites/bosses/"
	actions = BOSS_ACTIONS
	max_hp = base_hp * hp_scale
	hp = max_hp
	radius = boss_radius
	speed = move_speed
	contact_damage = damage
	mass = 50.0  # 几乎推不动，反过来会把小怪挤开
	color = Color(0.8, 0.3, 0.3)


## 子类实现：设置自己的属性（一般就是调用一次 setup_boss）
func init_stats(_hp_scale: float) -> void:
	pass


func _ready() -> void:
	super._ready()
	if _actions and _actions.sprite_frames.has_animation(&"attack"):
		_actions.sprite_frames.set_animation_speed(&"attack", SpriteVisual.STRIP_FPS)  # Boss 出招慢而重，和冲锋时长差不多


func change_state(new_state: String) -> void:
	state = new_state
	state_time = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
	if _dead or not is_instance_valid(target):  # 同一帧里被打死后不再行动
		return
	if _frozen_time > 0.0:  # 次元斩、时间暂停对 Boss 同样有效
		_frozen_time -= delta
		queue_redraw()
		return
	state_time += delta
	_update_state(delta)
	queue_redraw()
	if _sprite:
		_sprite.set("flip_h", target.global_position.x < global_position.x)  # 面向玩家
		_anim_t += delta
		SpriteVisual.animate(_sprite, _anim_t * 0.6, 0.5, gait, signf(target.global_position.x - global_position.x) * 0.5)  # Boss 动作慢而沉
		if state.ends_with("windup"):  # 所有蓄力状态都以 windup 结尾
			SpriteVisual.windup_tremble(_sprite, state_time, _actions != null and _actions.animation != &"idle")
		_update_action()
	if global_position.distance_to(target.global_position) < radius + Player.RADIUS:
		target.take_damage(contact_damage)


## 当前状态对应的动作
func state_action() -> StringName:
	if state_actions.has(state):
		return state_actions[state]
	if state == "chase":
		return &"move"
	if state == "recover":
		return &"idle"
	if state.ends_with("windup"):
		return &"windup"
	return &"attack"


## 插播一次动作（例如砸地瞬间），播完回到当前状态的动作
func play_once(action: StringName) -> void:
	if _actions and _actions.sprite_frames.has_animation(action):
		_oneshot = action
		_playing = &""


func _update_action() -> void:
	if not _actions:
		return
	var want := _oneshot if _oneshot else state_action()
	if want == _playing:
		return
	_playing = want
	var frames := _actions.sprite_frames
	if not frames.has_animation(want):
		want = &"idle" if frames.has_animation(&"idle") else &"move"
	_actions.play(want)
	_actions.frame = 0


func _on_action_finished() -> void:
	if _actions.animation == _oneshot:
		_oneshot = &""


## 子类实现：每帧根据当前状态行动
func _update_state(_delta: float) -> void:
	pass


## 子类实现：画技能预警（例如冲锋路线），会画在 Boss 身体下面
func _draw_telegraph() -> void:
	pass


## 技能预警的通用画法（静态函数，Boss 和召唤物都能用：传入要画在哪个节点上）
## 直线冲锋预警（长条）。t 从 0 到 1，越接近出招越亮
static func draw_line_telegraph(canvas: CanvasItem, dir: Vector2, length: float, half_width: float, t: float, tint: Color = Color(1.0, 0.15, 0.1)) -> void:
	var perp := dir.orthogonal() * half_width
	var far := dir * length
	canvas.draw_colored_polygon(PackedVector2Array([perp, perp + far, -perp + far, -perp]), Color(tint, 0.12 + 0.25 * t))
	canvas.draw_polyline(PackedVector2Array([perp, perp + far, -perp + far, -perp, perp]), Color(tint.lightened(0.2), 0.6), 2.0)


## 圆形范围预警。内圈逐渐扩大，碰到外圈的瞬间就是出招
static func draw_circle_telegraph(canvas: CanvasItem, center: Vector2, r: float, t: float, tint: Color = Color(1.0, 0.15, 0.1)) -> void:
	canvas.draw_circle(center, r, Color(tint, 0.08 + 0.2 * t))
	canvas.draw_arc(center, r, 0.0, TAU, 64, Color(tint.lightened(0.2), 0.7), 2.0)
	canvas.draw_arc(center, r * t, 0.0, TAU, 64, Color(tint.lightened(0.3), 0.5), 2.0)


func chase(delta: float, speed_mult: float = 1.0) -> void:
	position += global_position.direction_to(target.global_position) * speed * speed_mult * delta


func take_damage(amount: float, _knockback: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if _dead:
		return
	super.take_damage(amount, Vector2.ZERO, crit)  # Boss 不会被击退
	hp_changed.emit(maxf(hp, 0.0), max_hp)
	target.add_ult_energy(amount / max_hp * ULT_ENERGY_PER_KILL)


func _die() -> void:
	_dead = true
	FxLayer.burst(global_position, color, 60, 320.0, 5.0)
	FxLayer.burst(global_position, Color(1.0, 0.85, 0.4), 40, 240.0, 4.0)
	target.shake(14.0, 0.5)
	defeated.emit(self)
	killed.emit(self)
	queue_free()


func _draw() -> void:
	_draw_telegraph()
	var tint := Color(3, 3, 3) if _flash_time > 0.0 else Color.WHITE
	if _frozen_time > 0.0:
		tint = Color(0.6, 0.75, 1.3)
	if _sprite:
		if casts_shadow:
			SpriteVisual.draw_shadow(self, radius)
		_sprite.modulate = tint
		return
	draw_circle(Vector2.ZERO, radius + 3.0, Color(0.1, 0.05, 0.05))
	draw_circle(Vector2.ZERO, radius, Color.WHITE if _flash_time > 0.0 else color * tint)
