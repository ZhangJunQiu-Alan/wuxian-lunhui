class_name Hrym
extends Boss
## 赫列姆 · 霜巨人之王（篇章一 第 1 关 14:00，本关最终 Boss）
## 技能（轮流使用）：
##   冰霜践踏：砸地放出一圈向外扩散的冲击波，冲击波上有缺口，站到缺口方向才能躲开
##   冰柱牢笼：在玩家脚下画出预警圈，然后升起一圈冰柱，困住没跑出去的玩家
##   冰川巨盾：举盾一段时间，站在他正面时攻击会被格挡，要绕到背后打
## 第二阶段（血量低于 50%）：召唤霜巨人卫队，践踏变为连续两圈

const CHASE_TIME := 2.6
const STOMP_WINDUP := 1.1
const STOMP_GAPS := 2            # 每圈冲击波有几个缺口
const CAGE_WINDUP := 0.9
const CAGE_RADIUS := 95.0
const CAGE_PILLARS := 12
const CAGE_DURATION := 3.0
const SHIELD_TIME := 4.0
const SHIELD_HALF_ANGLE := 1.3   # 正面多大角度内会被格挡（弧度，约 75°）
const SHIELD_TURN_SPEED := 1.1   # 举盾时转向玩家的速度（弧度/秒），比玩家绕圈慢
const GUARDS := 4
const FROST_COLOR := Color(0.55, 0.85, 1.0)

var _facing := Vector2.DOWN
var _skill_index := 0
var _phase2 := false
var _second_stomp := false
var _cage_center := Vector2.ZERO
var _gaps: Array[float] = []     # 下一圈冲击波的缺口角度，预警时就画出来


func _init() -> void:
	intro_line = "赫列姆 · 霜巨人之王 —— 他从冰封的海上走来"
	defeat_line = "「无所谓……纳吉尔法尔……已经起航了……」"


func init_stats(hp_scale: float) -> void:
	setup_boss("hrym", "赫列姆", "霜巨人之王", 750.0, hp_scale, 46.0, 75.0, 25.0)
	gait = "heavy"
	color = Color(0.45, 0.58, 0.85)
	state_actions = {"shield": &"shield"}
	reward_points = 300


func _ready() -> void:
	super._ready()
	change_state("chase")


func _update_state(delta: float) -> void:
	if not _phase2 and hp < max_hp * 0.5:
		_phase2 = true
		_summon_guards()

	match state:
		"chase":
			chase(delta)
			_facing = global_position.direction_to(target.global_position)
			if state_time >= CHASE_TIME:
				_next_skill()
		"stomp_windup":
			if state_time >= STOMP_WINDUP:
				_stomp()
				if _phase2 and not _second_stomp:
					_second_stomp = true
					_gaps = _random_gaps()
					change_state("stomp_windup")  # 第二阶段：紧接着再踩一次，缺口位置不同
					state_time = STOMP_WINDUP * 0.45
				else:
					_second_stomp = false
					change_state("chase")
		"cage_windup":
			if state_time >= CAGE_WINDUP:
				for i in CAGE_PILLARS:
					var pos := _cage_center + Vector2.from_angle(TAU * i / CAGE_PILLARS) * CAGE_RADIUS
					IcePillar.spawn(get_parent(), pos, CAGE_DURATION)
				target.shake(5.0, 0.2)
				play_once(&"attack")
				change_state("chase")
		"shield":
			# 慢慢转向玩家：转得比玩家绕圈慢，所以绕到背后就能打
			var want := global_position.direction_to(target.global_position)
			_facing = _facing.rotated(clampf(_facing.angle_to(want), -SHIELD_TURN_SPEED * delta, SHIELD_TURN_SPEED * delta))
			chase(delta, 0.3)
			if state_time >= SHIELD_TIME:
				change_state("chase")


func _next_skill() -> void:
	_skill_index += 1
	match _skill_index % 3:
		1:
			_gaps = _random_gaps()
			change_state("stomp_windup")
		2:
			_cage_center = target.global_position  # 锁定玩家当前位置，预警期间跑出去就能躲开
			change_state("cage_windup")
		0:
			change_state("shield")


func _random_gaps() -> Array[float]:
	var gaps: Array[float] = []
	var start := randf() * TAU
	for i in STOMP_GAPS:
		gaps.append(start + TAU * i / STOMP_GAPS + randf_range(-0.4, 0.4))
	return gaps


func _stomp() -> void:
	play_once(&"stomp")
	target.shake(10.0, 0.3)
	FxLayer.burst(global_position, FROST_COLOR, 30, 260.0)
	FxLayer.ring(global_position, 150.0)
	Shockwave.spawn(get_parent(), global_position, _gaps, target)


func _summon_guards() -> void:
	target.shake(8.0, 0.4)
	FxLayer.floating_text(global_position + Vector2(0, -radius - 20), "霜巨人卫队！", FROST_COLOR)
	for i in GUARDS:
		spawner.call("frost_giant", global_position + Vector2.from_angle(TAU * i / GUARDS) * (radius + 60.0))


## 举盾时，玩家在他正面的攻击全部被格挡
func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if state == "shield" and absf(_facing.angle_to(target.global_position - global_position)) < SHIELD_HALF_ANGLE:
		_flash_time = 0.05
		if randf() < 0.3:  # 不用每次都飘字，避免刷屏
			FxLayer.floating_text(global_position + _facing * radius, "格挡", FROST_COLOR)
		return
	super.take_damage(amount, knockback, crit)


func _draw_telegraph() -> void:
	match state:
		"stomp_windup":
			var t := state_time / STOMP_WINDUP
			draw_circle_telegraph(self, Vector2.ZERO, radius + 30.0 + 40.0 * t, t, FROST_COLOR)
			# 用绿色箭头标出缺口方向：冲击波来时站到这些方向上
			for gap in _gaps:
				var dir := Vector2.from_angle(gap)
				draw_line(dir * (radius + 20.0), dir * (radius + 130.0), Color(0.4, 1.0, 0.5, 0.4 + 0.5 * t), 6.0)
		"cage_windup":
			var t := state_time / CAGE_WINDUP
			var center := _cage_center - global_position
			for i in CAGE_PILLARS:
				var pos := center + Vector2.from_angle(TAU * i / CAGE_PILLARS) * CAGE_RADIUS
				draw_circle(pos, IcePillar.RADIUS * t, Color(FROST_COLOR, 0.4))
			draw_arc(center, CAGE_RADIUS, 0.0, TAU, 48, Color(FROST_COLOR, 0.3 + 0.4 * t), 2.0)
		"shield":
			# 盾牌：正面一道粗弧线
			var a := _facing.angle()
			draw_arc(Vector2.ZERO, radius + 12.0, a - SHIELD_HALF_ANGLE, a + SHIELD_HALF_ANGLE, 24, Color(0.85, 0.95, 1.0, 0.9), 8.0)
	# 朝向标记
	draw_line(_facing * radius * 0.5, _facing * (radius + 4.0), Color(1, 1, 1, 0.7), 4.0)
