class_name Hati
extends Boss
## 哈提 · 逐月之狼（篇章一 第 1 关 10:00）
## 技能：
##   月牙连扑：连续两次短距离扑击，第二次会重新瞄准
##   月蚀嚎叫：蓄力后放出一圈声波，范围内的玩家陷入恐惧，不受控制地后退
##   月影分身：血量低于 75% 时分出 2 个虚影，之后每 25 秒一次。虚影打不掉血，只有本体脚下有影子
##   如果斯库尔已经被击败：哈提狂暴，移动和出招都更快

const CHASE_TIME := 2.0
const LUNGE_WINDUP := 0.6
const LUNGE_SPEED := 1100.0
const LUNGE_TIME := 0.25
const LUNGE_LENGTH := LUNGE_SPEED * LUNGE_TIME
const MOON_COLOR := Color(0.6, 0.6, 1.0)
const LUNGE_DAMAGE := 28.0
const RECOVER_TIME := 0.6
const HOWL_WINDUP := 1.1
const HOWL_RADIUS := 280.0
const FEAR_DURATION := 1.5
const SPLIT_EVERY := 25.0
const PHANTOM_COUNT := 2

var lunge_dir := Vector2.RIGHT  # 虚影会读取这些，和本体同步出招
var _lunges_left := 0
var _skill_index := 0           # 轮流使用的技能
var _split_timer := 0.0
var _split_unlocked := false
var _enraged := false
var _speed_mult := 1.0          # 狂暴时出招更快


func _init() -> void:
	intro_line = "哈提 · 逐月之狼 —— 月光越暗，它越强"
	defeat_line = "「兄弟……月亮……还给你们了……」"


func init_stats(hp_scale: float) -> void:
	setup_boss("hati", "哈提", "逐月之狼", 650.0, hp_scale, 32.0, 165.0, 18.0)
	color = Color(0.72, 0.78, 0.95)
	casts_shadow = false  # 真身影子在 _draw_telegraph 里画，这是分辨真假的线索


func _ready() -> void:
	super._ready()
	if "skoll" in defeated_bosses:
		_enraged = true
		_speed_mult = 1.4
		speed *= 1.25
		intro_line = "哈提 · 逐月之狼 —— 兄弟之死让它陷入狂暴！"
	change_state("chase")


func windup_time(base: float) -> float:
	return base / _speed_mult


func _update_state(delta: float) -> void:
	if not _split_unlocked and hp < max_hp * 0.75:
		_split_unlocked = true
		_split_timer = 0.0
	if _split_unlocked:
		_split_timer -= delta

	match state:
		"chase":
			chase(delta)
			if state_time >= CHASE_TIME / _speed_mult:
				_next_skill()
		"lunge_windup":
			if state_time >= windup_time(LUNGE_WINDUP):
				change_state("lunge")
		"lunge":
			position += lunge_dir * LUNGE_SPEED * delta
			if global_position.distance_to(target.global_position) < radius + Player.RADIUS:
				target.take_damage(LUNGE_DAMAGE)
			if state_time >= LUNGE_TIME:
				_lunges_left -= 1
				if _lunges_left > 0:
					_aim_lunge()  # 第二扑重新瞄准
				else:
					change_state("recover")
		"recover":
			if state_time >= RECOVER_TIME:
				change_state("chase")
		"howl_windup":
			if state_time >= windup_time(HOWL_WINDUP):
				if global_position.distance_to(target.global_position) < HOWL_RADIUS:
					target.fear(global_position, FEAR_DURATION)
				target.shake(6.0, 0.3)
				change_state("recover")
		"split":
			if state_time >= 0.8:
				_split()
				change_state("chase")


func _next_skill() -> void:
	if _split_unlocked and _split_timer <= 0.0:
		change_state("split")
		return
	_skill_index += 1
	if _skill_index % 3 == 0:
		change_state("howl_windup")
	else:
		_lunges_left = 2
		_aim_lunge()


func _aim_lunge() -> void:
	lunge_dir = global_position.direction_to(target.global_position)
	change_state("lunge_windup")


func _split() -> void:
	_split_timer = SPLIT_EVERY
	FxLayer.burst(global_position, color, 30, 260.0)
	for i in PHANTOM_COUNT:
		var phantom := HatiPhantom.new()
		phantom.hati = self
		phantom.target = target
		phantom.radius = radius
		phantom.color = color
		phantom.speed = speed
		phantom.contact_damage = contact_damage * 0.5
		var side := -1.0 if i == 0 else 1.0
		phantom.position = position + global_position.direction_to(target.global_position).orthogonal() * side * 140.0
		get_parent().add_child(phantom)


func _draw_telegraph() -> void:
	match state:
		"lunge_windup":
			draw_line_telegraph(self, lunge_dir, LUNGE_LENGTH + radius, radius, state_time / windup_time(LUNGE_WINDUP), MOON_COLOR)
		"howl_windup":
			draw_circle_telegraph(self, Vector2.ZERO, HOWL_RADIUS, state_time / windup_time(HOWL_WINDUP), Color(0.7, 0.4, 1.0))
	# 只有本体脚下有影子 —— 这是分辨真假的线索
	draw_set_transform(Vector2(0, radius * 0.85), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0, 0, 0, 0.55))
	draw_set_transform(Vector2.ZERO)
